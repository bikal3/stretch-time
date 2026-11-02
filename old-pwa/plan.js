// Ordered timed segments for a workout. Rest sits between exercises and
// Round Reset between rounds, never after the last one.
export function buildPlan({ work, rest, exercises, rounds, reset }) {
  const plan = [];
  for (let r = 1; r <= rounds; r++) {
    for (let e = 1; e <= exercises; e++) {
      plan.push({ type: 'work', secs: work, round: r, exercise: e });
      if (e < exercises && rest) plan.push({ type: 'rest', secs: rest, round: r, exercise: e });
    }
    if (r < rounds && reset) plan.push({ type: 'reset', secs: reset, round: r, exercise: exercises });
  }
  return plan;
}

export const totalSecs = plan => plan.reduce((s, p) => s + p.secs, 0);

export const fmt = s => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
