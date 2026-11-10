// Pure workout model + timer engine. No Flutter imports, so it's unit-testable.

class Workout {
  final String name;
  final int work, rest, rounds, reset; // seconds, except rounds
  final List<String> exercises; // one entry per exercise, '' = unnamed
  /// Per exercise: true = held on the left, then the right. May be shorter
  /// than [exercises] (old saved data); missing entries are false.
  final List<bool> sided;

  /// true (default): every exercise once per round, then repeat (1,2,3…,1,2,3…).
  /// false: each exercise for all its rounds, then the next (1,1,1,2,2,2…).
  final bool circuit;

  const Workout({
    this.name = '',
    required this.work,
    required this.rest,
    required this.exercises,
    this.sided = const [],
    required this.rounds,
    required this.reset,
    this.circuit = true,
  });

  int get count => exercises.length;

  String exerciseName(int i) {
    final n = exercises[i].trim();
    return n.isEmpty ? 'Exercise ${i + 1}' : n;
  }

  bool isSided(int i) => i < sided.length && sided[i];

  bool get hasNames => exercises.any((e) => e.trim().isNotEmpty);

  int get totalSecs => buildPlan(this).fold(0, (s, p) => s + p.secs);

  /// Grows/shrinks the exercise list, keeping existing names and sides.
  Workout withCount(int n) => copyWith(
    exercises: List.generate(n, (i) => i < count ? exercises[i] : ''),
    sided: List.generate(n, isSided),
  );

  Workout copyWith({
    String? name,
    int? work,
    int? rest,
    List<String>? exercises,
    List<bool>? sided,
    int? rounds,
    int? reset,
    bool? circuit,
  }) => Workout(
    name: name ?? this.name,
    work: work ?? this.work,
    rest: rest ?? this.rest,
    exercises: exercises ?? this.exercises,
    sided: sided ?? this.sided,
    rounds: rounds ?? this.rounds,
    reset: reset ?? this.reset,
    circuit: circuit ?? this.circuit,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'work': work,
    'rest': rest,
    'exercises': exercises,
    'sided': sided,
    'rounds': rounds,
    'reset': reset,
    'circuit': circuit,
  };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
    name: j['name'] ?? '',
    work: j['work'],
    rest: j['rest'],
    exercises: List<String>.from(j['exercises']),
    sided: List<bool>.from(j['sided'] ?? const []),
    rounds: j['rounds'],
    reset: j['reset'],
    circuit: j['circuit'] ?? true,
  );

  /// Same timings and exercises, ignoring the name.
  bool sameAs(Workout o) =>
      work == o.work &&
      rest == o.rest &&
      rounds == o.rounds &&
      reset == o.reset &&
      circuit == o.circuit &&
      exercises.join('\n') == o.exercises.join('\n') &&
      [for (var i = 0; i < count; i++) isSided(i)].join() ==
          [for (var i = 0; i < o.count; i++) o.isSided(i)].join();

  String get summary =>
      '${fmt(work)} work · ${fmt(rest)} rest · $count ex · ${rounds}x';
}

enum Phase { ready, work, rest, reset }

class Segment {
  final Phase phase;
  final int secs, round, exercise; // round 1-based, exercise 0-based
  final int side; // 0 = not sided, 1 = left, 2 = right
  const Segment(
    this.phase,
    this.secs,
    this.round,
    this.exercise, [
    this.side = 0,
  ]);
}

/// Rest sits between sets and, in circuit mode, Round Reset between rounds;
/// never after the last set. A Rest/Reset segment's [round] and [exercise]
/// are those of the set coming next. A both-sides exercise is two work
/// segments, left then right, with nothing between.
List<Segment> buildPlan(Workout w, {int ready = 0}) {
  final sets = w.circuit
      ? [
          for (var r = 1; r <= w.rounds; r++)
            for (var e = 0; e < w.count; e++) (r, e),
        ]
      : [
          for (var e = 0; e < w.count; e++)
            for (var r = 1; r <= w.rounds; r++) (r, e),
        ];
  return [
    if (ready > 0) Segment(Phase.ready, ready, 1, 0),
    for (var i = 0; i < sets.length; i++) ...[
      for (final side in w.isSided(sets[i].$2) ? const [1, 2] : const [0])
        Segment(Phase.work, w.work, sets[i].$1, sets[i].$2, side),
      if (i < sets.length - 1) ?_gap(w, sets[i].$1, sets[i + 1]),
    ],
  ];
}

Segment? _gap(Workout w, int round, (int, int) next) {
  final (r, e) = next;
  final newRound = r != round && w.circuit;
  final secs = newRound ? w.reset : w.rest;
  return secs > 0
      ? Segment(newRound ? Phase.reset : Phase.rest, secs, r, e)
      : null;
}

String fmt(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

// Workout log: local date ('2026-11-03') -> seconds worked, ended early or not.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _daysAgo(DateTime today, int n) =>
    DateTime(today.year, today.month, today.day - n);

/// Consecutive days with a workout, ending today, or ending yesterday so the
/// streak holds until today's workout is done.
int streak(Map<String, int> log, DateTime today) {
  final from = log.containsKey(dayKey(today)) ? 0 : 1;
  var n = 0;
  while (log.containsKey(dayKey(_daysAgo(today, from + n)))) {
    n++;
  }
  return n;
}

/// Seconds worked over the last 7 days, today included.
int weekSecs(Map<String, int> log, DateTime today) =>
    [for (var i = 0; i < 7; i++) log[dayKey(_daysAgo(today, i))] ?? 0]
        .fold(0, (a, b) => a + b);

/// When the next daily reminder is due: today at [mins] past midnight, or
/// tomorrow if that has passed or today's workout is already done.
DateTime nextReminder(DateTime now, int mins, bool doneToday) {
  DateTime at(int day) =>
      DateTime(now.year, now.month, day, mins ~/ 60, mins % 60);
  final today = at(now.day);
  return doneToday || !today.isAfter(now) ? at(now.day + 1) : today;
}

/// Time is derived from timestamps, not tick counts, so a throttled or
/// backgrounded app never drifts; [update] just catches up.
class TimerEngine {
  final List<Segment> plan;
  int index = 0;
  Duration _endAt;
  Duration? _pausedLeft;

  TimerEngine(this.plan, Duration now)
    : _endAt = now + Duration(seconds: plan.first.secs);

  bool get done => index >= plan.length;
  bool get paused => _pausedLeft != null;
  Segment get current => plan[index];

  /// Advances to [now]. Returns true if the segment changed.
  bool update(Duration now) {
    if (paused || done) return false;
    var changed = false;
    while (!done && now >= _endAt) {
      index++;
      changed = true;
      if (!done) _endAt += Duration(seconds: plan[index].secs);
    }
    return changed;
  }

  int msLeft(Duration now) =>
      done ? 0 : (_pausedLeft ?? (_endAt - now)).inMilliseconds;

  int secondsLeft(Duration now) => (msLeft(now) / 1000).ceil();

  int totalLeft(Duration now) =>
      secondsLeft(now) + plan.skip(index + 1).fold(0, (s, p) => s + p.secs);

  void pause(Duration now) => _pausedLeft ??= _endAt - now;

  void resume(Duration now) {
    if (_pausedLeft == null) return;
    _endAt = now + _pausedLeft!;
    _pausedLeft = null;
  }

  void skip(Duration now) {
    if (done) return;
    _pausedLeft = null;
    _endAt = now;
    update(now);
  }

  /// Like a music player: restart the segment, or go to the previous one
  /// if we're within its first 2 seconds.
  void back(Duration now) {
    if (done) return;
    final elapsed = current.secs * 1000 - msLeft(now);
    if (elapsed < 2000 && index > 0) index--;
    final full = Duration(seconds: current.secs);
    if (paused) {
      _pausedLeft = full;
    } else {
      _endAt = now + full;
    }
  }
}

const presets = [
  Workout(
    name: 'Morning Stretch',
    work: 30,
    rest: 10,
    rounds: 1,
    reset: 0,
    exercises: [
      'Neck stretch',
      'Shoulder rolls',
      'Chest opener',
      'Side bend',
      'Forward fold',
      'Quad stretch',
      'Hip flexor lunge',
      "Child's pose",
    ],
    sided: [true, false, false, true, false, true, true, false],
  ),
  Workout(
    name: 'Desk Break',
    work: 20,
    rest: 5,
    rounds: 1,
    reset: 0,
    exercises: [
      'Neck tilt',
      'Shoulder shrugs',
      'Wrist stretch',
      'Seated twist',
      'Upper back stretch',
      'Calf raises',
    ],
    sided: [true, false, true, true, false, false],
  ),
  Workout(
    name: 'Full Body Stretch',
    work: 45,
    rest: 15,
    rounds: 2,
    reset: 30,
    exercises: [
      'Neck stretch',
      'Triceps stretch',
      'Chest opener',
      'Cat-cow',
      'Downward dog',
      'Hamstring stretch',
      'Butterfly',
      'Pigeon pose',
      'Quad stretch',
      'Calf stretch',
    ],
    sided: [true, true, false, false, false, true, false, true, true, true],
  ),
  Workout(
    name: 'Bedtime Wind-Down',
    work: 60,
    rest: 10,
    rounds: 1,
    reset: 0,
    exercises: [
      "Child's pose",
      'Supine twist',
      'Happy baby',
      'Legs up the wall',
      'Reclined butterfly',
    ],
    sided: [false, true, false, false, false],
  ),
  Workout(
    name: 'HIIT 30/15',
    work: 30,
    rest: 15,
    rounds: 3,
    reset: 10,
    exercises: ['', '', '', '', '', '', '', '', '', ''],
  ),
];
