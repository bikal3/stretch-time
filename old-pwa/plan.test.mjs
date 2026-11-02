// Run: node plan.test.mjs
import assert from 'node:assert';
import { buildPlan, totalSecs, fmt } from './plan.js';

const cfg = { work: 30, rest: 15, exercises: 10, rounds: 3, reset: 10 };
assert.equal(fmt(totalSecs(buildPlan(cfg))), '22:05'); // matches reference screenshot
assert.equal(buildPlan(cfg).at(-1).type, 'work');      // no trailing rest/reset
assert.equal(buildPlan({ ...cfg, rest: 0, reset: 0 }).length, 30);
assert.equal(fmt(3725), '62:05');
console.log('ok');
