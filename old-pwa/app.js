import { buildPlan, totalSecs, fmt } from './plan.js';

const $ = s => document.querySelector(s);
const FIELDS = {
  work:      { label: 'Work',        time: true,  min: 1, step: 5 },
  rest:      { label: 'Rest',        time: true,  min: 0, step: 5 },
  exercises: { label: 'Exercises',   time: false, min: 1, step: 1 },
  rounds:    { label: 'Rounds',      time: false, min: 1, step: 1 },
  reset:     { label: 'Round Reset', time: true,  min: 0, step: 5 },
};
const MAX = { time: 99 * 60 + 59, count: 99 };
const PHASE = { ready: 'Get Ready', work: 'Work', rest: 'Rest', reset: 'Round Reset', done: 'Done!' };
const READY_SECS = 5;

const store = {
  get(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} },
};

// Config: URL hash (shareable, e.g. #30-15-10-3-10) > last used > defaults.
const KEYS = Object.keys(FIELDS);
const clampField = (k, v) => Math.min(Math.max(Math.round(+v) || 0, FIELDS[k].min), FIELDS[k].time ? MAX.time : MAX.count);
function fromHash() {
  const parts = location.hash.slice(1).split('-');
  if (parts.length !== KEYS.length || parts.some(p => !/^\d+$/.test(p))) return null;
  return Object.fromEntries(KEYS.map((k, i) => [k, clampField(k, parts[i])]));
}
let cfg = fromHash() || store.get('cfg', { work: 30, rest: 15, exercises: 10, rounds: 3, reset: 10 });

function render() {
  for (const k of KEYS) {
    $(`[data-key=${k}] .val`).textContent = FIELDS[k].time ? fmt(cfg[k]) : k === 'rounds' ? `${cfg[k]}X` : cfg[k];
  }
  $('#total').textContent = fmt(totalSecs(buildPlan(cfg)));
  store.set('cfg', cfg);
  history.replaceState(null, '', '#' + KEYS.map(k => cfg[k]).join('-'));
}

// ---------- Edit dialog ----------
const dlg = $('#edit'), mm = $('#mm'), ss = $('#ss');
let editing;
const readEdit = () => FIELDS[editing].time ? (+mm.value || 0) * 60 + (+ss.value || 0) : +ss.value || 0;
function writeEdit(v) {
  v = clampField(editing, v);
  if (FIELDS[editing].time) { mm.value = Math.floor(v / 60); ss.value = String(v % 60).padStart(2, '0'); }
  else ss.value = v;
}
document.querySelectorAll('[data-key]').forEach(b => b.onclick = () => {
  editing = b.dataset.key;
  const time = FIELDS[editing].time;
  $('#editTitle').textContent = FIELDS[editing].label;
  mm.hidden = $('#colon').hidden = !time;
  ss.max = time ? 59 : MAX.count;
  writeEdit(cfg[editing]);
  dlg.returnValue = '';
  dlg.showModal();
});
dlg.querySelectorAll('[data-step]').forEach(b => b.onclick = () => {
  const step = FIELDS[editing].step;
  const v = readEdit();
  // snap to the step grid so 32 +5 -> 35, not 37
  writeEdit(b.dataset.step > 0 ? Math.floor(v / step) * step + step : Math.ceil(v / step) * step - step);
});
dlg.onclose = () => {
  if (dlg.returnValue !== 'ok') return;
  cfg = { ...cfg, [editing]: clampField(editing, readEdit()) };
  render();
};

// ---------- Previous workouts ----------
const summary = c => `${fmt(c.work)} work · ${fmt(c.rest)} rest · ${c.exercises} ex · ${c.rounds}X`;
$('#load').onclick = () => {
  const list = store.get('history', []);
  const ul = $('#history');
  ul.innerHTML = list.length ? '' : '<li class="empty">No workouts yet. Press play to start one.</li>';
  for (const h of list) {
    const li = document.createElement('li'), b = document.createElement('button');
    b.value = 'cancel';
    b.innerHTML = `<strong class="num">${fmt(totalSecs(buildPlan(h)))}</strong><small></small>`;
    b.querySelector('small').textContent = `${summary(h)} · ${new Date(h.at).toLocaleDateString()}`;
    b.onclick = () => { cfg = Object.fromEntries(KEYS.map(k => [k, h[k]])); render(); };
    li.append(b); ul.append(li);
  }
  $('#historyDlg').showModal();
};
function saveHistory() {
  const same = h => KEYS.every(k => h[k] === cfg[k]);
  store.set('history', [{ ...cfg, at: Date.now() }, ...store.get('history', []).filter(h => !same(h))].slice(0, 20));
}

// ---------- Sound, vibration, wake lock ----------
let audio;
function beep(freq = 880, ms = 150) {
  if (!audio) return;
  const o = audio.createOscillator(), g = audio.createGain();
  o.frequency.value = freq;
  g.gain.setValueAtTime(0.3, audio.currentTime);
  g.gain.exponentialRampToValueAtTime(0.001, audio.currentTime + ms / 1000);
  o.connect(g).connect(audio.destination);
  o.start(); o.stop(audio.currentTime + ms / 1000);
}
let wakeLock;
const lockScreen = () => navigator.wakeLock?.request('screen').then(l => wakeLock = l).catch(() => {});
document.addEventListener('visibilitychange', () => { if (run && document.visibilityState === 'visible') lockScreen(); });

// ---------- Runner ----------
// Time is derived from timestamps, not tick counts, so throttled/background
// timers never drift; on wake we just catch up through elapsed segments.
let run = null; // { plan, i, endAt, pausedLeft, lastSec, timer, total, done }
const ICON_PAUSE = '<svg viewBox="0 0 24 24"><path d="M6 4h4v16H6zM14 4h4v16h-4z"/></svg>';
const ICON_PLAY = '<svg viewBox="0 0 24 24"><path d="M7 4v16l13-8z"/></svg>';

$('#play').onclick = () => {
  audio ??= new (window.AudioContext || window.webkitAudioContext)(); // must be created in a tap on iOS
  audio.resume();
  saveHistory();
  const plan = [{ type: 'ready', secs: READY_SECS }, ...buildPlan(cfg)];
  run = { plan, i: 0, endAt: performance.now() + READY_SECS * 1000, total: totalSecs(plan), timer: setInterval(tick, 100) };
  lockScreen();
  $('#run').classList.add('on');
  enter();
  tick();
};

function enter() {
  const seg = run.plan[run.i];
  $('#run').dataset.type = seg.type;
  $('#phase').textContent = PHASE[seg.type];
  $('#meta').textContent = seg.round ? `Exercise ${seg.exercise}/${cfg.exercises} · Round ${seg.round}/${cfg.rounds}` : '';
  $('#pause').innerHTML = ICON_PAUSE;
  run.lastSec = null;
  if (run.i) { beep(1320, 350); navigator.vibrate?.(200); }
}

function tick() {
  if (!run || run.done || run.pausedLeft != null) return;
  const now = performance.now();
  while (now >= run.endAt) {
    if (++run.i >= run.plan.length) return finish();
    run.endAt += run.plan[run.i].secs * 1000;
    enter();
  }
  const left = Math.ceil((run.endAt - now) / 1000);
  if (left !== run.lastSec) {
    if (left <= 3 && run.lastSec != null) beep(660);
    run.lastSec = left;
  }
  draw(left);
}

function draw(left) {
  const rest = run.plan.slice(run.i + 1).reduce((s, p) => s + p.secs, 0) + left;
  $('#clock').textContent = fmt(left);
  $('#remain').textContent = `${fmt(rest)} remaining`;
  $('#progress').style.width = `${100 * (1 - rest / run.total)}%`;
}

$('#pause').onclick = () => {
  if (run.done) return stop();
  if (run.pausedLeft == null) {
    run.pausedLeft = run.endAt - performance.now();
    $('#pause').innerHTML = ICON_PLAY;
  } else {
    run.endAt = performance.now() + run.pausedLeft;
    run.pausedLeft = null;
    $('#pause').innerHTML = ICON_PAUSE;
  }
};
$('#skip').onclick = () => {
  if (!run || run.done) return;
  run.pausedLeft = null;
  run.endAt = performance.now();
  tick();
};
$('#stop').onclick = stop;

function finish() {
  clearInterval(run.timer);
  run.done = true;
  $('#run').dataset.type = 'done';
  $('#phase').textContent = PHASE.done;
  $('#clock').textContent = fmt(run.total - READY_SECS);
  $('#meta').textContent = 'Great job — workout complete';
  $('#remain').textContent = '';
  $('#progress').style.width = '100%';
  $('#pause').innerHTML = ICON_PLAY;
  beep(1320, 600); navigator.vibrate?.([200, 100, 200]);
}

function stop() {
  if (run) clearInterval(run.timer);
  run = null;
  wakeLock?.release().catch(() => {});
  $('#run').classList.remove('on');
}

render();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js');
