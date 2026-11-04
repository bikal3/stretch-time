# Posture figures on the run screen

## Goal
While a preset stretch runs, show a figure of the correct posture beside the
timer. An info button reveals, on demand only, a common-mistake figure and
2–3 form tips.

## Data — `lib/postures.dart` (pure Dart, no Flutter imports)
- `Pose`: ~11 joint points (head, neck, hip, elbows, hands, knees, feet) in a
  100×100 box, plus an optional floor line.
- `Posture { Pose correct, Pose wrong, Set<String> wrongLimbs, List<String> tips }`.
- `postureFor(String exerciseName)`: lookup by trimmed, lower-cased name in a
  const map covering all 25 named preset stretches. Custom workouts get a
  figure only when a name matches; otherwise `null`.

## Drawing
One `CustomPainter` draws any `Pose` as a stick figure (round caps, head
circle) in the current foreground colour. Limbs in `wrongLimbs` are drawn red
on the wrong pose. No new dependency; works in light and dark.

## Run screen
- Phone: figure in a translucent rounded card between the exercise name and
  the countdown.
- Wide (desktop/web): card to the side of the timer.
- Work shows the current exercise; Rest and Get Ready show the next one.
- ⓘ on the card opens a bottom sheet: ✓ correct and ✗ common mistake side by
  side, then the tips. The timer keeps running.
- No posture for the exercise → no card; layout is as today.

## Testing
- Unit test: every named exercise in `presets` has a posture.
- Visual check on web in light and dark.

## Out of scope
Figures for unnamed (HIIT) or unmatched custom exercises, animation.
