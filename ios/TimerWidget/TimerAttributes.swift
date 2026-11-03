import ActivityKit
import Foundation

/// Shared by the app (which starts and updates the activity) and the widget
/// extension (which draws it), so it is compiled into both targets.
@available(iOS 16.1, *)
struct TimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var phase: String  // "Work", "Rest", ...
    var title: String  // exercise, or "Next: <exercise>"
    var detail: String  // "Round 2/3 · Exercise 4/10"
    var color: Int  // ARGB
    var start: Date
    var end: Date
    var pausedSecs: Int?  // set while paused: the frozen time left
  }
}
