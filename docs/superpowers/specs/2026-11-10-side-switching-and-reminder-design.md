# Side switching and daily reminder

Two independent features, built in this order.

## 1. Side switching

### Goal
A stretch marked "both sides" runs the full Work time on the left, then the
full Work time on the right, with a "Switch sides" cue between them.

### Model — `lib/workout.dart`
- `Workout.sided`: `List<bool>`, same length as `exercises`, default all
  false. `sided[i]` means exercise `i` is done on both sides.
- JSON key `sided`. Missing (old saved data) or wrong length → all false.
- `withCount`, `copyWith` and `sameAs` keep `sided` in step with `exercises`.
- `Segment.side`: `0` none, `1` left, `2` right (default `0`).
- `buildPlan`: a sided exercise emits two work segments, side 1 then side 2,
  each `w.work` seconds, with no Rest between them. Rest / Round Reset follow
  the second one as they follow any set today. `totalSecs` picks this up
  because it sums the plan.
- `summary` is unchanged.
- Presets: `sided` is true for Neck stretch, Neck tilt, Side bend, Quad
  stretch, Hip flexor lunge, Triceps stretch, Wrist stretch, Seated twist,
  Hamstring stretch, Pigeon pose, Calf stretch, Supine twist. These presets
  get longer.

### Editor — `ExercisesScreen` in `lib/sheets.dart`
- Each row gets a toggle icon button before Remove (tooltip "Both sides"),
  highlighted when on.
- The flag travels with its row on reorder and remove; new rows start off.

### Run screen — `lib/run_screen.dart`
- Work on a sided segment shows the name with the side:
  "Hamstring stretch · Left" / "· Right".
- Speech: side 1 says "<name>, left side"; side 2 says "Switch sides".
  Both go through `Cues.phase`, so gong and vibration fire as on any phase
  change.
- "Exercise n of m" and the round line count a sided stretch once.
- Skip and back move one side at a time (falls out of the engine).
- The iOS Live Activity title carries the same "· Left" / "· Right" suffix.
- Rest and Get Ready previews show the plain name.

## 2. Daily reminder

### Goal
A local notification at a chosen time each day, skipped on days already
stretched. Android and iOS only.

### Settings — `lib/app_state.dart`, `SettingsScreen`
- `Settings.reminder` (bool, default false) and `Settings.reminderMins`
  (minutes after midnight, default 480 = 08:00).
- New "Reminder" group: a "Daily reminder" switch and, when on, a row showing
  the time that opens `showTimePicker`. The group is hidden on web.
- Turning the switch on requests notification permission. Denied → the
  switch stays off and a snackbar says notifications are disabled for the
  app.

### Scheduling — `lib/workout.dart` (pure part), new `lib/reminder.dart`
- `DateTime nextReminder(DateTime now, int mins, bool doneToday)` in
  `workout.dart` — pure: today at `mins` if that is still ahead and
  `doneToday` is false, otherwise tomorrow at `mins`.
- `Future<void> syncReminder(Settings s, Map<String, int> log)`: cancels all
  pending notifications; if `s.reminder`, schedules one one-shot notification
  per day for the next 30 days, starting at `nextReminder(...)`. No-op on web.
  One-shots rather than a repeating notification, because a repeating one on
  iOS matches on time of day only and cannot skip today. The app re-syncs on
  every start, so reminders only stop after 30 days without opening it.
- Called at app start, from `updateSettings`, and from `logRun`. Calls are
  queued so a quick off/on cannot interleave.
- Text: title "Time to stretch", body "Keep your streak going".
- Inexact scheduling on Android (no exact-alarm permission); it may arrive a
  few minutes late.
- Tapping the notification opens the app on the home screen.

### Platform
- Packages: `flutter_local_notifications`, `timezone` (times are scheduled as
  UTC instants, so no device time-zone lookup is needed).
- Android: `RECEIVE_BOOT_COMPLETED` permission, the plugin's
  scheduled-notification and boot receivers in the manifest, core library
  desugaring in `android/app/build.gradle.kts`, a monochrome status-bar icon
  `ic_stat_reminder`.
- iOS: permission is requested from Dart; no Info.plist change.

## Testing
- `buildPlan` with sided exercises: segment order, sides, no rest between
  sides, `totalSecs`, circuit and non-circuit.
- `Workout` JSON round trip with `sided`, and loading JSON without it.
- `nextReminder`: before the time, after the time, done today.
- By hand on a phone: reminder fires, is skipped after a workout, survives a
  reboot (Android); editor toggle survives reorder and remove.

## Out of scope
Web notifications, exact alarms, several reminders or per-weekday schedules,
streak count in the notification text, a pause between sides, custom side
labels.
