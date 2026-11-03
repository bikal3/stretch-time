import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_state.dart';
import 'sheets.dart' show isWide;
import 'workout.dart';

const phaseColors = {
  Phase.ready: Color(0xFF2A2F38),
  Phase.work: Color(0xFF1E7A4C),
  Phase.rest: Color(0xFFB3213F),
  Phase.reset: Color(0xFF9A7A16),
};
const phaseLabels = {
  Phase.ready: 'Get Ready',
  Phase.work: 'Work',
  Phase.rest: 'Rest',
  Phase.reset: 'Round Reset',
};

/// Brighter phase colors for the dark lock-screen card.
const liveColors = {
  Phase.ready: 0xFFFFFFFF,
  Phase.work: 0xFF5EE39A,
  Phase.rest: 0xFFFF6B83,
  Phase.reset: 0xFFF5D061,
};

/// The iOS Live Activity (lock screen + Dynamic Island), see AppDelegate.swift.
const liveActivity = MethodChannel('stretch_time/live_activity');

/// The Apple Health workout that runs alongside the timer, see AppDelegate.swift.
const healthWorkout = MethodChannel('stretch_time/workout');
final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Beeps, speech and haptics, each gated by its setting.
class Cues {
  final Settings s;
  final _tts = FlutterTts();
  final _beep = AudioPlayer(),
      _gong = AudioPlayer(),
      _keepAlive = AudioPlayer();

  Cues(this.s) {
    // Mix with (and duck) the user's music instead of stopping it.
    AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }
    _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    // iOS suspends a backgrounded app, which would silence the cues while the
    // phone is locked. Looping silence (with the `audio` background mode in
    // Info.plist) keeps it running for the length of the workout.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _keepAlive.setReleaseMode(ReleaseMode.loop);
      _keepAlive.play(AssetSource('silence.wav'));
    }
  }

  /// Workout over: let the app suspend again once in the background.
  void finished() => _keepAlive.stop();

  void countdown(int n) {
    if (s.voice) {
      _tts.speak('$n');
    } else if (s.sound) {
      _beep.play(AssetSource('beep.wav'));
    }
    if (s.vibration) HapticFeedback.lightImpact();
  }

  void phase(String speech) {
    if (s.sound) _gong.play(AssetSource('gong.wav'));
    if (s.voice) _tts.speak(speech);
    if (s.vibration) HapticFeedback.heavyImpact();
  }

  void dispose() {
    _tts.stop();
    _beep.dispose();
    _gong.dispose();
    _keepAlive.dispose();
  }
}

class RunScreen extends StatefulWidget {
  final AppState app;
  const RunScreen(this.app, {super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late final Workout w = widget.app.current;
  late final Settings settings = widget.app.settings;
  late final Cues cues = Cues(settings);
  late final TimerEngine engine;
  late final Timer ticker;
  int? lastSecond;

  // ponytail: wall clock, so time keeps passing while the phone sleeps;
  // a manual clock change mid-workout would jump the timer.
  Duration get now =>
      Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    widget.app.recordRun();
    engine = TimerEngine(buildPlan(w, ready: settings.readySecs), now);
    if (settings.keepAwake) WakelockPlus.enable();
    if (isIOS) healthWorkout.invokeMethod('start');
    ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    announce();
  }

  @override
  void dispose() {
    ticker.cancel();
    cues.dispose();
    WakelockPlus.disable();
    // Already ended when done; ending again could hit the workout and card
    // that "Again" has started by the time this screen is disposed.
    if (isIOS && !engine.done) {
      liveActivity.invokeMethod('end');
      healthWorkout.invokeMethod('end', false);
    }
    super.dispose();
  }

  String speechFor(Segment seg) => switch (seg.phase) {
    Phase.ready => 'Get ready. First, ${w.exerciseName(0)}',
    Phase.work => w.hasNames ? w.exerciseName(seg.exercise) : 'Work',
    Phase.rest => 'Rest. Next, ${w.exerciseName(seg.exercise)}',
    Phase.reset => 'Round reset. Round ${seg.round} next',
  };

  void announce() {
    if (engine.done) {
      cues.phase('Workout complete. Great job!');
    } else {
      cues.phase(speechFor(engine.current));
    }
    showLive();
  }

  /// Sent on phase changes and pause/skip; the system counts down in between.
  void showLive() {
    if (!isIOS) return;
    if (engine.done) {
      liveActivity.invokeMethod('end');
      return;
    }
    final t = now, seg = engine.current;
    final end = DateTime.now().add(Duration(milliseconds: engine.msLeft(t)));
    final name = w.exerciseName(seg.exercise);
    liveActivity.invokeMethod('update', {
      'phase': phaseLabels[seg.phase],
      'title': seg.phase == Phase.work ? name : 'Next: $name',
      'detail':
          'Round ${seg.round}/${w.rounds} · Exercise ${seg.exercise + 1}/${w.count}',
      'color': liveColors[seg.phase],
      'start': end.subtract(Duration(seconds: seg.secs)).millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      if (engine.paused) 'pausedSecs': engine.secondsLeft(t),
    });
  }

  void tick() {
    final t = now;
    if (engine.update(t)) {
      lastSecond = null;
      announce();
      if (engine.done) {
        ticker.cancel();
        cues.finished();
        widget.app.logRun(w.totalSecs);
        if (isIOS) healthWorkout.invokeMethod('end', true);
      }
    }
    final left = engine.secondsLeft(t);
    if (left == lastSecond) return; // repaint only when the display changes
    if (lastSecond != null && left <= 3 && left > 0 && !engine.paused) {
      cues.countdown(left);
    }
    setState(() => lastSecond = left);
  }

  void act(void Function(Duration) f) {
    f(now);
    lastSecond = null;
    tick();
    showLive();
    if (isIOS) healthWorkout.invokeMethod(engine.paused ? 'pause' : 'resume');
    setState(() {});
  }

  Future<void> confirmStop() async {
    if (engine.done) {
      Navigator.pop(context);
      return;
    }
    final wasPaused = engine.paused;
    act(engine.pause);
    final stop = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('End workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (stop == true) {
      Navigator.pop(context);
      return;
    }
    if (!wasPaused) act(engine.resume);
  }

  @override
  Widget build(BuildContext context) {
    final t = now;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : confirmStop(),
      // Keyboard control for the web/desktop.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): togglePause,
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              act(engine.skip),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              act(engine.back),
          const SingleActivator(LogicalKeyboardKey.escape): confirmStop,
        },
        child: Focus(
          autofocus: true,
          child: engine.done ? doneView() : runView(t),
        ),
      ),
    );
  }

  void togglePause() {
    if (engine.done) {
      Navigator.pop(context);
    } else {
      act(engine.paused ? engine.resume : engine.pause);
    }
  }

  Widget runView(Duration t) {
    final seg = engine.current;
    final total = engine.plan.fold(0, (s, p) => s + p.secs);
    final next = switch (seg.phase) {
      Phase.work => null,
      _ => 'Next: ${w.exerciseName(seg.exercise)}',
    };

    return Scaffold(
      backgroundColor: phaseColors[seg.phase],
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          iconSize: 30,
                          color: Colors.white,
                          tooltip: 'End workout',
                          onPressed: confirmStop,
                          icon: const Icon(Icons.close),
                        ),
                        const Spacer(),
                        if (seg.phase != Phase.ready)
                          Text(
                            'Round ${seg.round}/${w.rounds}',
                            style: const TextStyle(fontSize: 18),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      phaseLabels[seg.phase]!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (seg.phase == Phase.work)
                      Text(
                        w.exerciseName(seg.exercise),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    // Flexible bounds the height so the clock fills big windows without overflowing.
                    Flexible(
                      flex: 4,
                      child: FittedBox(
                        child: Text(
                          fmt(engine.secondsLeft(t)),
                          style: const TextStyle(
                            fontSize: 150,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (seg.phase == Phase.work)
                      Text(
                        'Exercise ${seg.exercise + 1} of ${w.count}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    if (next != null)
                      Text(next, style: const TextStyle(fontSize: 22)),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1 - engine.totalLeft(t) / total,
                        minHeight: 8,
                        color: Colors.white,
                        backgroundColor: Colors.black26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${fmt(engine.totalLeft(t))} remaining',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        roundButton(
                          Icons.skip_previous_rounded,
                          'Back',
                          () => act(engine.back),
                        ),
                        roundButton(
                          engine.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          engine.paused ? 'Resume' : 'Pause',
                          togglePause,
                          big: true,
                        ),
                        roundButton(
                          Icons.skip_next_rounded,
                          'Skip',
                          () => act(engine.skip),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isWide(context))
                      const Text(
                        'Space  pause / resume   ·   ← →  back / skip   ·   Esc  end',
                        style: TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget roundButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool big = false,
  }) => Material(
    color: big ? Colors.black45 : Colors.black26,
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      iconSize: big ? 56 : 34,
      padding: EdgeInsets.all(big ? 20 : 14),
      icon: Icon(icon, color: Colors.white),
    ),
  );

  Widget doneView() => Scaffold(
    body: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6A55), Color(0xFFEC1C5C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 96,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Workout complete!',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${fmt(w.totalSecs)} · ${w.count} exercise${w.count == 1 ? '' : 's'} · ${w.rounds} round${w.rounds == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (streak(widget.app.log, DateTime.now()) case final d
                      when d > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🔥 $d-day streak',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RunScreen(widget.app),
                          ),
                        ),
                        icon: const Icon(Icons.replay),
                        label: const Text('Again'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
