import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TimerWidgetBundle: WidgetBundle {
  var body: some Widget { TimerLiveActivity() }
}

extension Color {
  init(argb: Int) {
    self.init(
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255)
  }
}

/// Counts down by itself; the app only updates it when the phase changes.
struct Countdown: View {
  let s: TimerAttributes.ContentState
  var body: some View {
    if let secs = s.pausedSecs {
      Text(String(format: "%d:%02d", secs / 60, secs % 60))
    } else {
      Text(timerInterval: s.start...s.end, countsDown: true)
    }
  }
}

struct TimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TimerAttributes.self) { ctx in
      let s = ctx.state
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(s.pausedSecs == nil ? s.phase.uppercased() : "PAUSED")
            .font(.headline.weight(.heavy))
            .foregroundStyle(Color(argb: s.color))
          Spacer()
          Countdown(s: s)
            .font(.system(size: 40, weight: .bold).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140, alignment: .trailing)
        }
        Text(s.title).font(.title3.weight(.semibold)).lineLimit(1)
        Text(s.detail).font(.subheadline).foregroundStyle(.secondary)
        if s.pausedSecs == nil {
          ProgressView(timerInterval: s.start...s.end, countsDown: true) {
          } currentValueLabel: {
          }
          .tint(Color(argb: s.color))
        }
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.75))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { ctx in
      let s = ctx.state
      let color = Color(argb: s.color)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(s.phase).font(.headline).foregroundStyle(color)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(s: s).font(.title2.bold().monospacedDigit())
            .multilineTextAlignment(.trailing).frame(maxWidth: 90)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading) {
            Text(s.title).font(.headline).lineLimit(1)
            Text(s.detail).font(.caption).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        Image(systemName: "figure.flexibility").foregroundStyle(color)
      } compactTrailing: {
        Countdown(s: s).monospacedDigit().foregroundStyle(color)
          .multilineTextAlignment(.trailing).frame(maxWidth: 44)
      } minimal: {
        Image(systemName: "figure.flexibility").foregroundStyle(color)
      }
    }
  }
}
