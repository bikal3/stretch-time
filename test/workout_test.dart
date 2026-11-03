import 'package:flutter_test/flutter_test.dart';
import 'package:stretch_time/workout.dart';

Duration s(num secs) => Duration(milliseconds: (secs * 1000).round());

void main() {
  // 30/15, 10 ex, 3 rounds, 10 reset, run as a circuit (the default)
  final hiit = presets.last;

  test('plan matches the reference screenshot total', () {
    expect(fmt(hiit.totalSecs), '22:05');
    expect(buildPlan(hiit).last.phase, Phase.work); // no trailing rest/reset
    expect(buildPlan(hiit.copyWith(rest: 0, reset: 0)).length, 30);
    expect(buildPlan(hiit, ready: 5).first.phase, Phase.ready);
  });

  test('per-exercise order runs each exercise for all rounds first', () {
    final w = presets.last
        .withCount(2)
        .copyWith(circuit: false); // 30/15, 3 rounds
    final work = buildPlan(w).where((p) => p.phase == Phase.work);
    expect(
      [for (final p in work) (p.exercise, p.round)],
      [
        (0, 1), (0, 2), (0, 3), (1, 1), (1, 2), (1, 3), //
      ],
    );
    // Rest between every set, no Round Reset: 6×30 + 5×15.
    expect(w.totalSecs, 255);
    expect(buildPlan(w).any((p) => p.phase == Phase.reset), isFalse);
    // Same exercise list as a circuit: 0,1,0,1,0,1.
    final circ = buildPlan(w.copyWith(circuit: true))
        .where((p) => p.phase == Phase.work);
    expect([for (final p in circ) p.exercise], [0, 1, 0, 1, 0, 1]);
  });

  test('order survives save/load; old data defaults to circuit', () {
    final each = hiit.copyWith(circuit: false);
    expect(Workout.fromJson(each.toJson()).circuit, isFalse);
    expect(Workout.fromJson(each.toJson()..remove('circuit')).circuit, isTrue);
    expect(each.sameAs(hiit), isFalse);
  });

  test('rest segment points at the next exercise', () {
    final p = buildPlan(presets.first);
    expect(p[1].phase, Phase.rest);
    expect(p[1].exercise, 1);
  });

  test('engine counts down, catches up, pauses, skips, goes back', () {
    final e = TimerEngine(buildPlan(hiit), s(0));
    expect(e.secondsLeft(s(0.1)), 30);
    expect(e.totalLeft(s(0)), 1325);

    // App was asleep for 35s: lands 5s into the first rest.
    expect(e.update(s(35)), isTrue);
    expect(e.current.phase, Phase.rest);
    expect(e.secondsLeft(s(35)), 10);

    e.pause(s(35));
    expect(e.update(s(500)), isFalse);
    expect(e.secondsLeft(s(500)), 10);
    e.resume(s(500));
    expect(e.secondsLeft(s(501)), 9);

    e.skip(s(501));
    expect(e.current.phase, Phase.work);
    expect(e.current.exercise, 1);

    e.back(s(501.5)); // within 2s -> previous segment, full length
    expect(e.current.phase, Phase.rest);
    expect(e.secondsLeft(s(501.5)), 15);

    e.update(s(100000));
    expect(e.done, isTrue);
    expect(e.totalLeft(s(100000)), 0);
  });

  test('withCount keeps names and pads with blanks', () {
    final w = presets.first.withCount(10);
    expect(w.exercises[0], 'Neck stretch');
    expect(w.exerciseName(9), 'Exercise 10');
    expect(w.withCount(2).exercises, ['Neck stretch', 'Shoulder rolls']);
  });

  test('streak counts back from today, or from yesterday', () {
    final today = DateTime(2026, 3, 2); // crosses into February
    final log = {
      for (final d in ['2026-02-27', '2026-02-28', '2026-03-01']) d: 60,
    };
    expect(streak(log, today), 3); // today not done yet
    expect(streak({...log, '2026-03-02': 60}, today), 4);
    expect(streak(log, DateTime(2026, 3, 3)), 0); // missed yesterday
    expect(weekSecs({...log, '2026-02-23': 60}, today), 180); // 8 days ago
  });
}
