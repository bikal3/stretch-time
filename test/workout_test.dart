import 'package:flutter_test/flutter_test.dart';
import 'package:stretch_time/workout.dart';

Duration s(num secs) => Duration(milliseconds: (secs * 1000).round());

void main() {
  final hiit = presets.last; // 30/15, 10 ex, 3 rounds, 10 reset

  test('plan matches the reference screenshot total', () {
    expect(fmt(hiit.totalSecs), '22:05');
    expect(buildPlan(hiit).last.phase, Phase.work); // no trailing rest/reset
    expect(buildPlan(hiit.copyWith(rest: 0, reset: 0)).length, 30);
    expect(buildPlan(hiit, ready: 5).first.phase, Phase.ready);
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
}
