import 'dart:js_interop';

import 'package:web/web.dart' as web;

// Phone browsers (all iOS ones are Safari underneath) only let a tap start
// audio. A fresh <audio> element per cue, as audioplayers creates, and a
// speech queue that waits for an 'end' event iOS doesn't always send, both
// went silent after the first cue. Instead: one AudioContext and speech,
// unlocked by any tap on the page, then free to play from the timer.

final _ctx = web.AudioContext();
final _sounds = <String, web.AudioBuffer>{};
var _speechUnlocked = false;

/// Call once at startup: preloads the sounds and listens for taps.
void initWebCues() {
  for (final name in ['beep.wav', 'gong.wav']) {
    _load(name);
  }
  for (final type in ['touchend', 'pointerup', 'keydown']) {
    web.document.addEventListener(type, _unlock.toJS, true.toJS);
  }
}

Future<void> _load(String name) async {
  final res = await web.window.fetch('assets/assets/$name'.toJS).toDart;
  final bytes = await res.arrayBuffer().toDart;
  _sounds[name] = await _ctx.decodeAudioData(bytes).toDart;
}

void _unlock(web.Event _) {
  // Every tap, as iOS can suspend the context again (calls, backgrounding).
  if (_ctx.state != 'running') {
    _ctx.resume();
    _play(_ctx.createBuffer(1, 1, 22050));
  }
  if (!_speechUnlocked) {
    _speechUnlocked = true;
    web.window.speechSynthesis.speak(web.SpeechSynthesisUtterance(''));
  }
}

void _play(web.AudioBuffer buffer) {
  final src = _ctx.createBufferSource()..buffer = buffer;
  src.connect(_ctx.destination);
  src.start();
}

void webSound(String asset) {
  final buffer = _sounds[asset];
  if (buffer != null) _play(buffer);
}

/// A new utterance each time: nothing waits on the previous one finishing.
void webSay(String text) =>
    web.window.speechSynthesis.speak(web.SpeechSynthesisUtterance(text));

void webHush() => web.window.speechSynthesis.cancel();
