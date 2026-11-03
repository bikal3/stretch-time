import ActivityKit
import Flutter
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A workout can't survive an app restart, so neither should its activity.
    if #available(iOS 16.2, *) { LiveTimer.end() }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveTimer") else {
      return
    }
    FlutterMethodChannel(name: "stretch_time/live_activity", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        if #available(iOS 16.2, *) { LiveTimer.handle(call) }
        result(nil)
      }
    FlutterMethodChannel(name: "stretch_time/workout", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        if #available(iOS 26.0, *) { HealthWorkout.shared.handle(call) }
        result(nil)
      }
  }
}

/// An Apple Health workout for the length of the timer. Besides logging the
/// stretch, it is what lets the locked app keep its Live Activity current:
/// iOS refuses activity updates from an app that is only playing audio.
@available(iOS 26.0, *)
final class HealthWorkout: NSObject, HKWorkoutSessionDelegate {
  static let shared = HealthWorkout()
  private let store = HKHealthStore()
  private var session: HKWorkoutSession?
  private var wanted = false  // false once ended, in case that beats start()
  private var save = false

  func handle(_ call: FlutterMethodCall) {
    switch call.method {
    case "start":
      wanted = true
      Task { await start() }
    case "pause":
      if session?.state == .running { session?.pause() }
    case "resume":
      if session?.state == .paused { session?.resume() }
    default:  // "end", argument: whether to save to Health
      wanted = false
      save = call.arguments as? Bool ?? false
      session?.stopActivity(with: .now)  // finished in didChangeTo .stopped
      session = nil
    }
  }

  @MainActor private func start() async {
    guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
    // Only prompts the first time; if denied the timer still runs, just
    // without Health logging or background Live Activity updates.
    try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
    let config = HKWorkoutConfiguration()
    config.activityType = .flexibility
    config.locationType = .indoor
    guard wanted, session == nil,
      let s = try? HKWorkoutSession(healthStore: store, configuration: config)
    else { return }
    s.delegate = self
    session = s
    s.startActivity(with: .now)
    try? await s.associatedWorkoutBuilder().beginCollection(at: .now)
  }

  func workoutSession(
    _ s: HKWorkoutSession, didChangeTo state: HKWorkoutSessionState,
    from _: HKWorkoutSessionState, date: Date
  ) {
    guard state == .stopped else { return }
    let builder = s.associatedWorkoutBuilder()
    let save = self.save
    Task {
      try? await builder.endCollection(at: date)
      if save { _ = try? await builder.finishWorkout() } else { builder.discardWorkout() }
      s.end()
    }
  }

  func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {
    NSLog("StretchTime workout session failed: \(error)")
  }
}

/// The lock screen / Dynamic Island timer, driven from run_screen.dart.
@available(iOS 16.2, *)
enum LiveTimer {
  static var activity: Activity<TimerAttributes>?

  static func handle(_ call: FlutterMethodCall) {
    guard call.method == "update", let a = call.arguments as? [String: Any] else {
      return end()
    }
    func date(_ key: String) -> Date {
      Date(timeIntervalSince1970: Double(a[key] as? Int ?? 0) / 1000)
    }
    let state = TimerAttributes.ContentState(
      phase: a["phase"] as? String ?? "",
      title: a["title"] as? String ?? "",
      detail: a["detail"] as? String ?? "",
      color: a["color"] as? Int ?? 0xFFFFFFFF,
      start: date("start"),
      end: date("end"),
      pausedSecs: a["pausedSecs"] as? Int)
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity {
      Task { await activity.update(content) }
    } else {
      activity = try? Activity.request(attributes: TimerAttributes(), content: content)
    }
  }

  static func end() {
    activity = nil
    for a in Activity<TimerAttributes>.activities {
      Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
