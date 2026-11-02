import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'run_screen.dart';
import 'sheets.dart';
import 'workout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState(await SharedPreferences.getInstance());
  runApp(
    MaterialApp(
      title: 'StretchTime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFF5435A),
        scaffoldBackgroundColor: panel,
        fontFamilyFallback: const ['Roboto', 'Helvetica Neue', 'Arial'],
      ),
      home: HomeScreen(app),
    ),
  );
}

const panel = Color(0xFF252525);
const tabular = [FontFeature.tabularFigures()];

class RowStyle {
  final Color fg, bg;
  final IconData icon;
  const RowStyle(this.fg, this.bg, this.icon);
}

const styles = {
  'work': RowStyle(
    Color(0xFF5EE39A),
    Color(0xFF2C4136),
    Icons.play_circle_outline_rounded,
  ),
  'rest': RowStyle(
    Color(0xFFF43F5E),
    Color(0xFF45252D),
    Icons.pause_circle_outline_rounded,
  ),
  'exercises': RowStyle(
    Color(0xFFD4D4D4),
    Color(0xFF3A3A3A),
    Icons.self_improvement_rounded,
  ),
  'rounds': RowStyle(
    Color(0xFF7D8BF7),
    Color(0xFF2B2D42),
    Icons.replay_rounded,
  ),
  'reset': RowStyle(
    Color(0xFFF5D061),
    Color(0xFF413A2B),
    Icons.schedule_rounded,
  ),
};

class HomeScreen extends StatelessWidget {
  final AppState app;
  const HomeScreen(this.app, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) {
      final w = app.current;
      return Scaffold(
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, 0.2, 0.4],
                colors: [
                  Color(0xFFFF6A55),
                  Color(0xFFF5435A),
                  Color(0xFFEC1C5C),
                ],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(children: [header(context, w), body(context, w)]),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget header(BuildContext context, Workout w) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'My workouts',
                iconSize: 30,
                color: const Color(0xFF6B1420),
                onPressed: () => showWorkouts(context, app),
                icon: const Icon(Icons.menu_rounded),
              ),
              const Expanded(
                child: Text(
                  'StretchTime',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B1420),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                iconSize: 28,
                color: const Color(0xFF6B1420),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(app)),
                ),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FittedBox(
            child: Text(
              fmt(w.totalSecs),
              style: const TextStyle(
                fontSize: 110,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: -2,
                fontFeatures: tabular,
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: Text(
              w.name,
              style: const TextStyle(fontSize: 18, color: Color(0xFF6B1420)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget body(BuildContext context, Workout w) {
    Widget row(
      String key,
      String label,
      String value,
      VoidCallback onTap, {
      String? sub,
    }) {
      final s = styles[key]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: s.bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Row(
                children: [
                  Icon(s.icon, color: s.fg, size: 32),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (sub != null)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: s.fg,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    void editTime(
      String key,
      String label,
      int value,
      int min,
      List<int> quick,
      Workout Function(int) apply,
    ) => showValueEditor(
      context,
      title: label,
      value: value,
      min: min,
      max: 99 * 60 + 59,
      step: 5,
      isTime: true,
      quick: quick,
      color: styles[key]!.fg,
      onChanged: (v) => app.edit(apply(v)),
    );

    void editCount(
      String key,
      String label,
      int value,
      List<int> quick,
      Workout Function(int) apply,
    ) => showValueEditor(
      context,
      title: label,
      value: value,
      min: 1,
      max: 99,
      step: 1,
      isTime: false,
      quick: quick,
      color: styles[key]!.fg,
      onChanged: (v) => app.edit(apply(v)),
    );

    return Stack(
      children: [
        // Panel background with a notch the play button sits in.
        Positioned.fill(
          top: 52,
          child: ClipPath(
            clipper: NotchClipper(64),
            child: const ColoredBox(color: panel),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              Center(child: playButton(context)),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 2,
                    ),
                    leading: const Icon(Icons.bookmarks_outlined, size: 28),
                    title: const Text(
                      'Presets & Saved Workouts',
                      style: TextStyle(fontSize: 18),
                    ),
                    trailing: const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                    ),
                    onTap: () => showWorkouts(context, app),
                  ),
                ),
              ),
              row(
                'work',
                'Work',
                fmt(w.work),
                () => editTime('work', 'Work', w.work, 1, [
                  10,
                  15,
                  20,
                  30,
                  45,
                  60,
                  90,
                  120,
                ], (v) => app.current.copyWith(work: v)),
              ),
              row(
                'rest',
                'Rest',
                fmt(w.rest),
                () => editTime('rest', 'Rest', w.rest, 0, [
                  0,
                  5,
                  10,
                  15,
                  20,
                  30,
                  45,
                  60,
                ], (v) => app.current.copyWith(rest: v)),
              ),
              row(
                'exercises',
                'Exercises',
                '${w.count}',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ExercisesScreen(app)),
                ),
                sub: w.hasNames
                    ? [for (var i = 0; i < w.count; i++) w.exerciseName(i)]
                          .join(' · ')
                    : 'Tap to name your stretches',
              ),
              row(
                'rounds',
                'Rounds',
                '${w.rounds}X',
                () => editCount('rounds', 'Rounds', w.rounds, [
                  1,
                  2,
                  3,
                  4,
                  5,
                  8,
                  10,
                ], (v) => app.current.copyWith(rounds: v)),
              ),
              row(
                'reset',
                'Round Reset',
                fmt(w.reset),
                () => editTime('reset', 'Round Reset', w.reset, 0, [
                  0,
                  10,
                  15,
                  30,
                  60,
                  90,
                  120,
                ], (v) => app.current.copyWith(reset: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget playButton(BuildContext context) => Container(
    width: 104,
    height: 104,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: Color(0xFFF0285A), spreadRadius: 6),
        BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
      ],
    ),
    child: Material(
      color: Colors.black,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RunScreen(app)),
        ),
        child: const Tooltip(
          message: 'Start workout',
          child: Icon(
            Icons.play_arrow_rounded,
            size: 72,
            color: Color(0xFFF5435A),
          ),
        ),
      ),
    ),
  );
}

/// Rounded-top rectangle with a circle cut out of the top-center edge.
class NotchClipper extends CustomClipper<Path> {
  final double radius;
  NotchClipper(this.radius);

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: const Radius.circular(28),
        topRight: const Radius.circular(28),
      ),
    ),
    Path()..addOval(
      Rect.fromCircle(center: Offset(size.width / 2, 0), radius: radius),
    ),
  );

  @override
  bool shouldReclip(NotchClipper old) => old.radius != radius;
}
