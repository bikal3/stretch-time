import ActivityKit
import Flutter
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
