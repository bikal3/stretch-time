# Side Switching and Daily Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stretches can be marked "both sides" (full Work time left, then right, with a "Switch sides" cue), and phones get a daily reminder notification that is skipped on days already stretched.

**Architecture:** Side switching is a per-exercise flag on `Workout` that `buildPlan` expands into two work segments carrying a `side`; the run screen only labels and announces it. The reminder is a pure `nextReminder` date function plus a thin `lib/reminder.dart` wrapper that schedules 30 one-shot local notifications and is re-synced from `AppState`.

**Tech Stack:** Flutter 3.47, Dart, `shared_preferences`, new: `flutter_local_notifications`, `timezone`.

Spec: `docs/superpowers/specs/2026-11-10-side-switching-and-reminder-design.md`

**Files**
- `lib/workout.dart` — `Workout.sided`, `Segment.side`, `buildPlan`, presets, `nextReminder`
- `lib/sheets.dart` — both-sides toggle in `ExercisesScreen`; Reminder group in `SettingsScreen`
- `lib/run_screen.dart` — side label, speech, Live Activity title
- `lib/app_state.dart` — `Settings.reminder`, `Settings.reminderMins`, sync calls
- `lib/reminder.dart` (new) — notification plugin wrapper
- `lib/main.dart` — sync at start
- `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/app/src/main/res/drawable/ic_stat_reminder.xml` (new)
- `test/workout_test.dart`, `README.md`

Commit messages: plain sentence, no attribution trailers. Commit to `main`; do not push (a push deploys the web app).

---

### Task 1: Model and plan for both-sides stretches

**Files:** Modify `lib/workout.dart`, `test/workout_test.dart`

- [ ] **Step 1: Write failing tests** — add to `test/workout_test.dart`:

```dart
  test('a both-sides stretch runs left then right with no rest between', () {
    const w = Workout(
      work: 30,
      rest: 10,
      exercises: ['Quad stretch', 'Butterfly'],
      sided: [true, false],
      rounds: 2,
      reset: 20,
    );
    final p = buildPlan(w);
    expect(
      [for (final s in p) (s.phase, s.exercise, s.side)],
      [
        (Phase.work, 0, 1), (Phase.work, 0, 2), (Phase.rest, 1, 0), //
        (Phase.work, 1, 0), (Phase.reset, 0, 0),
        (Phase.work, 0, 1), (Phase.work, 0, 2), (Phase.rest, 1, 0),
        (Phase.work, 1, 0),
      ],
    );
    expect(w.totalSecs, 6 * 30 + 2 * 10 + 20);
    final each = buildPlan(w.copyWith(circuit: false))
        .where((s) => s.phase == Phase.work);
    expect(
      [for (final s in each) (s.exercise, s.round, s.side)],
      [(0, 1, 1), (0, 1, 2), (0, 2, 1), (0, 2, 2), (1, 1, 0), (1, 2, 0)],
    );
  });

  test('sided survives save/load, resizing, and old data', () {
    const w = Workout(
      work: 30,
      rest: 10,
      exercises: ['a', 'b'],
      sided: [false, true],
      rounds: 1,
      reset: 0,
    );
    expect(Workout.fromJson(w.toJson()).isSided(1), isTrue);
    expect(Workout.fromJson(w.toJson()..remove('sided')).isSided(1), isFalse);
    expect(w.withCount(3).sided, [false, true, false]);
    expect(w.withCount(1).sided, [false]);
    expect(w.sameAs(w.copyWith(sided: [false, false])), isFalse);
    expect(w.sameAs(w.copyWith(sided: [false, true])), isTrue);
  });

  test('presets mark exactly the one-sided stretches', () {
    const expected = {
      'Neck stretch', 'Neck tilt', 'Side bend', 'Quad stretch',
      'Hip flexor lunge', 'Triceps stretch', 'Wrist stretch', 'Seated twist',
      'Hamstring stretch', 'Pigeon pose', 'Calf stretch', 'Supine twist', //
    };
    for (final w in presets) {
      for (var i = 0; i < w.count; i++) {
        expect(
          w.isSided(i),
          expected.contains(w.exercises[i]),
          reason: '${w.name}: ${w.exercises[i]}',
        );
      }
    }
  });
```

Replace the body of `'rest segment points at the next exercise'` (the first
preset stretch is now two segments):

```dart
    final p = buildPlan(presets.first);
    expect(p[2].phase, Phase.rest);
    expect(p[2].exercise, 1);
```

- [ ] **Step 2:** `flutter test` → FAIL (no `sided` parameter).

- [ ] **Step 3: Implement** in `lib/workout.dart`:

`Workout`: add field, constructor param, accessor.

```dart
  /// Per exercise: true = held on the left, then the right. May be shorter
  /// than [exercises] (old saved data); missing entries are false.
  final List<bool> sided;
  // constructor: this.sided = const [],

  bool isSided(int i) => i < sided.length && sided[i];
```

`withCount`:

```dart
  Workout withCount(int n) => copyWith(
    exercises: List.generate(n, (i) => i < count ? exercises[i] : ''),
    sided: List.generate(n, isSided),
  );
```

`copyWith`: add `List<bool>? sided` → `sided: sided ?? this.sided`.
`toJson`: `'sided': sided`. `fromJson`: `sided: List<bool>.from(j['sided'] ?? const [])`.
`sameAs`: add

```dart
      [for (var i = 0; i < count; i++) isSided(i)].join() ==
          [for (var i = 0; i < o.count; i++) o.isSided(i)].join() &&
```

`Segment`:

```dart
class Segment {
  final Phase phase;
  final int secs, round, exercise; // round 1-based, exercise 0-based
  final int side; // 0 = not sided, 1 = left, 2 = right
  const Segment(this.phase, this.secs, this.round, this.exercise, [this.side = 0]);
}
```

`buildPlan` — replace the single work `Segment(...)` line with:

```dart
      for (final side in w.isSided(sets[i].$2) ? const [1, 2] : const [0])
        Segment(Phase.work, w.work, sets[i].$1, sets[i].$2, side),
```

and extend the doc comment: "A both-sides exercise is two work segments, left then right, with nothing between."

Presets — add `sided:` lists aligned with `exercises`:

- Morning Stretch: `[true, false, false, true, false, true, true, false]`
- Desk Break: `[true, false, true, true, false, false]`
- Full Body Stretch: `[true, true, false, false, false, true, false, true, true, true]`
- Bedtime Wind-Down: `[false, true, false, false, false]`
- HIIT: none.

- [ ] **Step 4:** `flutter test` → all PASS. `flutter analyze` → no issues.
- [ ] **Step 5:** `git commit -am "Run both-sides stretches as left then right"`

### Task 2: Both-sides toggle in the exercises editor

**Files:** Modify `lib/sheets.dart` (`_ExercisesScreenState`)

- [ ] **Step 1:** Add a parallel list and keep it in step:

```dart
  late final List<bool> sided = [
    for (var i = 0; i < widget.app.current.count; i++)
      widget.app.current.isSided(i),
  ];

  void save() => widget.app.edit(
    widget.app.current.copyWith(
      exercises: [for (final c in ctrls) c.text],
      sided: [...sided],
    ),
  );
```

- `add()`: inside `setState`, also `sided.add(false)`.
- `remove(i)`: also `sided.removeAt(i)` right after `ctrls.removeAt(i)`.
- `onReorderItem`: `setState(() { ctrls.insert(to, ctrls.removeAt(from)); sided.insert(to, sided.removeAt(from)); });`

- [ ] **Step 2:** Replace the row's `trailing:` with:

```dart
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Both sides',
                      isSelected: sided[i],
                      color: sided[i]
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).disabledColor,
                      onPressed: () {
                        setState(() => sided[i] = !sided[i]);
                        save();
                      },
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: ctrls.length > 1 ? () => remove(i) : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
```

Help text becomes: `'Name each stretch so the timer can show and say it. Tap ⇄ for both sides. Hold and drag to reorder.'`

- [ ] **Step 3:** `flutter analyze && flutter test` → clean.
- [ ] **Step 4:** `git commit -am "Mark a stretch as both sides in the exercises editor"`

### Task 3: Side label and cue on the run screen

**Files:** Modify `lib/run_screen.dart`

- [ ] **Step 1:** Next to `phaseLabels`, add:

```dart
const sideLabels = ['', ' · Left', ' · Right'];
```

- [ ] **Step 2:** `speechFor`, work case:

```dart
    Phase.work => switch (seg.side) {
      2 => 'Switch sides',
      1 => '${w.hasNames ? w.exerciseName(seg.exercise) : 'Work'}, left side',
      _ => w.hasNames ? w.exerciseName(seg.exercise) : 'Work',
    },
```

- [ ] **Step 3:** In `showLive`, `'title': seg.phase == Phase.work ? name + sideLabels[seg.side] : 'Next: $name'`.
  In `runView`, the work-phase `Text(w.exerciseName(seg.exercise), …)` becomes `Text(w.exerciseName(seg.exercise) + sideLabels[seg.side], …)`.
- [ ] **Step 4:** `flutter analyze && flutter test` → clean. Run `flutter run -d chrome`, load Morning Stretch, check "Neck stretch · Left" → "· Right" with "Switch sides" spoken, and that the total on the home screen grew.
- [ ] **Step 5:** `git commit -am "Show and announce the side on the run screen"`

### Task 4: Reminder time calculation and settings

**Files:** Modify `lib/workout.dart`, `lib/app_state.dart`, `test/workout_test.dart`

- [ ] **Step 1: Failing test:**

```dart
  test('next reminder is today if still ahead and not done, else tomorrow', () {
    final morning = DateTime(2026, 2, 28, 7), evening = DateTime(2026, 2, 28, 21);
    expect(nextReminder(morning, 480, false), DateTime(2026, 2, 28, 8));
    expect(nextReminder(morning, 480, true), DateTime(2026, 3, 1, 8));
    expect(nextReminder(evening, 480, false), DateTime(2026, 3, 1, 8));
    expect(nextReminder(DateTime(2026, 2, 28, 8), 480, false), DateTime(2026, 3, 1, 8));
    expect(nextReminder(morning, 23 * 60 + 45, false), DateTime(2026, 2, 28, 23, 45));
  });
```

- [ ] **Step 2:** `flutter test` → FAIL (`nextReminder` undefined).
- [ ] **Step 3:** In `lib/workout.dart` after `weekSecs`:

```dart
/// When the next daily reminder is due: today at [mins] past midnight, or
/// tomorrow if that has passed or today's workout is already done.
DateTime nextReminder(DateTime now, int mins, bool doneToday) {
  DateTime at(int day) =>
      DateTime(now.year, now.month, day, mins ~/ 60, mins % 60);
  final today = at(now.day);
  return doneToday || !today.isAfter(now) ? at(now.day + 1) : today;
}
```

In `lib/app_state.dart` `Settings`: add `final bool reminder` (default `false`) and `final int reminderMins` (default `480`, comment `// minutes after midnight`) to the fields, constructor, `copyWith`, `toJson`, and `fromJson` (`j['reminder'] ?? false`, `j['reminderMins'] ?? 480`).

- [ ] **Step 4:** `flutter test` → PASS.
- [ ] **Step 5:** `git commit -am "Add reminder settings and the next-reminder calculation"`

### Task 5: Schedule the notifications

**Files:** Create `lib/reminder.dart`, `android/app/src/main/res/drawable/ic_stat_reminder.xml`; modify `pubspec.yaml`, `lib/app_state.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`

- [ ] **Step 1:** `flutter pub add flutter_local_notifications timezone`
- [ ] **Step 2:** Create `lib/reminder.dart`. The named-parameter signatures below are those of flutter_local_notifications 20+; if `flutter analyze` disagrees with the installed version, follow the analyzer.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';
import 'workout.dart';

/// Daily "time to stretch" notification, phones only.
final remindersSupported =
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

final _plugin = FlutterLocalNotificationsPlugin();
Future<void>? _ready;
Future<void> _queue = Future.value();

Future<void> _init() => _ready ??= _plugin.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_reminder'),
    // Asked for when the reminder is switched on, not at launch.
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  ),
);

/// Shows the system permission prompt if needed. False if denied.
Future<bool> requestReminderPermission() async {
  try {
    await _init();
    final granted = defaultTargetPlatform == TargetPlatform.android
        ? await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission()
        : await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  } catch (e) {
    debugPrint('reminder permission: $e');
    return false;
  }
}

/// Replaces all pending reminders to match [s] and today's [log].
/// Queued, so a quick off/on can't interleave.
Future<void> syncReminder(Settings s, Map<String, int> log) =>
    _queue = _queue.then((_) => _sync(s, log));

// ponytail: 30 one-shots, re-armed on every app start, so reminders stop
// after 30 days without opening the app. A repeating notification can't skip
// today on iOS; move to background refresh if that ceiling ever matters.
Future<void> _sync(Settings s, Map<String, int> log) async {
  if (!remindersSupported) return;
  try {
    await _init();
    await _plugin.cancelAll();
    if (!s.reminder) return;
    final now = DateTime.now();
    final first = nextReminder(
      now,
      s.reminderMins,
      log.containsKey(dayKey(now)),
    );
    for (var i = 0; i < 30; i++) {
      final at = DateTime(
        first.year,
        first.month,
        first.day + i,
        first.hour,
        first.minute,
      );
      await _plugin.zonedSchedule(
        id: i,
        title: 'Time to stretch',
        body: 'Keep your streak going',
        // An absolute instant, so the device's time zone name isn't needed.
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('reminder', 'Daily reminder'),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  } catch (e) {
    // A reminder that can't be scheduled must never break a workout.
    debugPrint('reminder: $e');
  }
}
```

- [ ] **Step 3:** Wire it. `lib/app_state.dart`: `import 'reminder.dart';`, then end `logRun` and `updateSettings` with `syncReminder(settings, log);`. `lib/main.dart`: `import 'reminder.dart';` and, right after `AppState` is created, `syncReminder(app.settings, app.log);`.
- [ ] **Step 4:** Android.

`AndroidManifest.xml` — inside `<manifest>`, before `<application>`:

```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

inside `<application>`, after `</activity>`:

```xml
        <!-- Daily reminder: show scheduled notifications, re-arm after reboot. -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

`android/app/build.gradle.kts` — in `compileOptions` add `isCoreLibraryDesugaringEnabled = true`; at the end of the file:

```kotlin
dependencies {
    // Needed by flutter_local_notifications for scheduled notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`android/app/src/main/res/drawable/ic_stat_reminder.xml` (status-bar icons must be single-colour):

```xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,22c1.1,0 2,-0.9 2,-2h-4c0,1.1 0.89,2 2,2zM18,16v-5c0,-3.07 -1.64,-5.64 -4.5,-6.32V4c0,-0.83 -0.67,-1.5 -1.5,-1.5s-1.5,0.67 -1.5,1.5v0.68C7.63,5.36 6,7.92 6,11v5l-2,2v1h16v-1l-2,-2z" />
</vector>
```

- [ ] **Step 5:** Verify: `flutter analyze` clean, `flutter test` pass, `flutter build web --release` succeeds (the plugin import must compile for web), `flutter build apk --debug` succeeds (desugaring + manifest).
- [ ] **Step 6:** `git add -A && git commit -m "Schedule a daily stretch reminder on phones"`

### Task 6: Reminder controls in Settings

**Files:** Modify `lib/sheets.dart` (`SettingsScreen.build`)

- [ ] **Step 1:** `import 'reminder.dart';`. After the `'Workout'` group in the `ListView` children add:

```dart
              if (remindersSupported)
                _group(context, 'Reminder', [
                  toggle(
                    Icons.notifications_outlined,
                    'Daily reminder',
                    'Skipped on days you have already stretched',
                    s.reminder,
                    (v) async {
                      if (v && !await requestReminderPermission()) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notifications are turned off for StretchTime in system settings',
                            ),
                          ),
                        );
                        return;
                      }
                      set(app.settings.copyWith(reminder: v));
                    },
                  ),
                  if (s.reminder)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Remind me at'),
                      trailing: Text(
                        TimeOfDay(
                          hour: s.reminderMins ~/ 60,
                          minute: s.reminderMins % 60,
                        ).format(context),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: s.reminderMins ~/ 60,
                            minute: s.reminderMins % 60,
                          ),
                        );
                        if (t == null) return;
                        set(
                          app.settings.copyWith(
                            reminderMins: t.hour * 60 + t.minute,
                          ),
                        );
                      },
                    ),
                ]),
```

- [ ] **Step 2:** `flutter analyze && flutter test` clean; `flutter build web --release` succeeds.
- [ ] **Step 3:** `git commit -am "Add the daily reminder switch and time to Settings"`

### Task 7: README

- [ ] **Step 1:** Features list: add "Both-sides stretches: left, then a "Switch sides" cue, then right" and "Daily reminder notification on Android and iPhone, skipped once you've stretched". Code list: add "`lib/reminder.dart` — daily reminder notifications".
- [ ] **Step 2:** `git commit -am "Document side switching and the daily reminder"`

### By hand on a phone (cannot be automated here)
- Reminder arrives near the set time; none arrives on a day with a workout logged.
- Android: reminder still arrives after a reboot; release APK (`flutter build apk --release`) still shows it (R8).
- Denying the permission leaves the switch off and shows the snackbar.
- Editor: the ⇄ flag follows its row through reorder and remove.
