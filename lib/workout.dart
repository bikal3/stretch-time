// Pure workout model + timer engine. No Flutter imports, so it's unit-testable.

class Workout {
  final String name;
  final int work, rest, rounds, reset; // seconds, except rounds
  final List<String> exercises; // one entry per exercise, '' = unnamed

  const Workout({
    this.name = '',
    required this.work,
    required this.rest,
    required this.exercises,
    required this.rounds,
    required this.reset,
  });

  int get count => exercises.length;

  String exerciseName(int i) {
    final n = exercises[i].trim();
    return n.isEmpty ? 'Exercise ${i + 1}' : n;
  }

  bool get hasNames => exercises.any((e) => e.trim().isNotEmpty);

  int get totalSecs => buildPlan(this).fold(0, (s, p) => s + p.secs);

  /// Grows/shrinks the exercise list, keeping existing names.
  Workout withCount(int n) => copyWith(
    exercises: List.generate(n, (i) => i < count ? exercises[i] : ''),
  );

  Workout copyWith({
    String? name,
    int? work,
    int? rest,
    List<String>? exercises,
    int? rounds,
    int? reset,
  }) => Workout(
    name: name ?? this.name,
    work: work ?? this.work,
    rest: rest ?? this.rest,
    exercises: exercises ?? this.exercises,
    rounds: rounds ?? this.rounds,
    reset: reset ?? this.reset,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'work': work,
    'rest': rest,
    'exercises': exercises,
    'rounds': rounds,
    'reset': reset,
  };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
    name: j['name'] ?? '',
    work: j['work'],
    rest: j['rest'],
    exercises: List<String>.from(j['exercises']),
    rounds: j['rounds'],
    reset: j['reset'],
  );

  /// Same timings and exercises, ignoring the name.
  bool sameAs(Workout o) =>
      work == o.work &&
      rest == o.rest &&
      rounds == o.rounds &&
      reset == o.reset &&
      exercises.join('\n') == o.exercises.join('\n');

  String get summary =>
      '${fmt(work)} work · ${fmt(rest)} rest · $count ex · ${rounds}x';
}

enum Phase { ready, work, rest, reset }

class Segment {
  final Phase phase;
  final int secs, round, exercise; // round 1-based, exercise 0-based
  const Segment(this.phase, this.secs, this.round, this.exercise);
}

/// Rest sits between exercises and Round Reset between rounds, never after
/// the last one. A Rest/Reset segment's [exercise] is the one coming next.
List<Segment> buildPlan(Workout w, {int ready = 0}) => [
  if (ready > 0) Segment(Phase.ready, ready, 1, 0),
  for (var r = 1; r <= w.rounds; r++) ...[
    for (var e = 0; e < w.count; e++) ...[
      Segment(Phase.work, w.work, r, e),
      if (e < w.count - 1 && w.rest > 0) Segment(Phase.rest, w.rest, r, e + 1),
    ],
    if (r < w.rounds && w.reset > 0) Segment(Phase.reset, w.reset, r + 1, 0),
  ],
];

String fmt(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

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

  int _leftMs(Duration now) =>
      done ? 0 : (_pausedLeft ?? (_endAt - now)).inMilliseconds;

  int secondsLeft(Duration now) => (_leftMs(now) / 1000).ceil();

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
    final elapsed = current.secs * 1000 - _leftMs(now);
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
