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
const pink = Color(0xFFF5435A);
const darkRed = Color(0xFF6B1420);
const tabular = [FontFeature.tabularFigures()];
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF6A55), Color(0xFFF5435A), Color(0xFFEC1C5C)],
);

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
    builder: (context, _) =>
        isWide(context) ? wideLayout(context) : phoneLayout(context),
  );

  void start(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => RunScreen(app)),
  );

  void openSettings(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => SettingsScreen(app)),
  );

  // ---------------------------------------------------------------- shared

  List<Widget> settingRows(BuildContext context) {
    final w = app.current;

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

    void edit(
      String key,
      String label,
      int value,
      List<int> quick,
      Workout Function(int) apply, {
      bool isTime = true,
      int min = 0,
    }) => showValueEditor(
      context,
      title: label,
      value: value,
      min: isTime ? min : 1,
      max: isTime ? 99 * 60 + 59 : 99,
      step: isTime ? 5 : 1,
      isTime: isTime,
      quick: quick,
      color: styles[key]!.fg,
      onChanged: (v) => app.edit(apply(v)),
    );

    return [
      row(
        'work',
        'Work',
        fmt(w.work),
        () => edit(
          'work',
          'Work',
          w.work,
          [10, 15, 20, 30, 45, 60, 90, 120],
          (v) => app.current.copyWith(work: v),
          min: 1,
        ),
      ),
      row(
        'rest',
        'Rest',
        fmt(w.rest),
        () => edit('rest', 'Rest', w.rest, [
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
            ? [for (var i = 0; i < w.count; i++) w.exerciseName(i)].join(' · ')
            : 'Tap to name your stretches',
      ),
      row(
        'rounds',
        'Rounds',
        '${w.rounds}X',
        () => edit(
          'rounds',
          'Rounds',
          w.rounds,
          [1, 2, 3, 4, 5, 8, 10],
          (v) => app.current.copyWith(rounds: v),
          isTime: false,
        ),
      ),
      row(
        'reset',
        'Round Reset',
        fmt(w.reset),
        () => edit('reset', 'Round Reset', w.reset, [
          0,
          10,
          15,
          30,
          60,
          90,
          120,
        ], (v) => app.current.copyWith(reset: v)),
      ),
    ];
  }

  // ----------------------------------------------------------------- phone

  Widget phoneLayout(BuildContext context) {
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
              colors: [Color(0xFFFF6A55), Color(0xFFF5435A), Color(0xFFEC1C5C)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [phoneHeader(context, w), phoneBody(context)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget phoneHeader(BuildContext context, Workout w) => SafeArea(
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
                color: darkRed,
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
                    color: darkRed,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                iconSize: 28,
                color: darkRed,
                onPressed: () => openSettings(context),
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
              style: const TextStyle(fontSize: 18, color: darkRed),
            ),
          ),
        ],
      ),
    ),
  );

  Widget phoneBody(BuildContext context) => Stack(
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
            ...settingRows(context),
          ],
        ),
      ),
    ],
  );

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
        onTap: () => start(context),
        child: const Tooltip(
          message: 'Start workout',
          child: Icon(Icons.play_arrow_rounded, size: 72, color: pink),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------------ wide

  Widget wideLayout(BuildContext context) {
    final w = app.current;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  wideNav(context),
                  const SizedBox(height: 32),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: heroCard(context, w)),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 14, left: 4),
                                child: Text(
                                  'Customize',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ...settingRows(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.saved.isNotEmpty) ...[
                    sectionTitle(
                      'Your workouts',
                      'Click to load, ▶ to start right away',
                    ),
                    workoutGrid(context, app.saved),
                  ],
                  sectionTitle(
                    'Presets',
                    'Ready-made routines to get you started',
                  ),
                  workoutGrid(context, presets),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget wideNav(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: brandGradient,
        ),
        child: const Icon(
          Icons.self_improvement_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      const SizedBox(width: 12),
      const Text(
        'StretchTime',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      TextButton.icon(
        onPressed: () => showWorkouts(context, app),
        icon: const Icon(Icons.history_rounded),
        label: const Text('Saved & recent'),
      ),
      const SizedBox(width: 8),
      TextButton.icon(
        onPressed: () => openSettings(context),
        icon: const Icon(Icons.settings_rounded),
        label: const Text('Settings'),
      ),
    ],
  );

  Widget heroCard(BuildContext context, Workout w) => Container(
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          w.name.isEmpty ? 'Custom workout' : w.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: darkRed,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOTAL TIME',
              style: TextStyle(fontSize: 14, letterSpacing: 3, color: darkRed),
            ),
            FittedBox(
              child: Text(
                fmt(w.totalSecs),
                style: const TextStyle(
                  fontSize: 150,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -3,
                  fontFeatures: tabular,
                ),
              ),
            ),
            Text(
              '${w.count} exercise${w.count == 1 ? '' : 's'} · ${w.rounds} round${w.rounds == 1 ? '' : 's'}'
              ' · ${fmt(w.work)} work / ${fmt(w.rest)} rest',
              style: const TextStyle(fontSize: 17, color: Colors.black87),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => start(context),
              icon: const Icon(Icons.play_arrow_rounded, color: pink, size: 30),
              label: const Text('Start workout'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => askSaveName(context, app),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget sectionTitle(String title, String sub) => Padding(
    padding: const EdgeInsets.only(top: 48, bottom: 16, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Text(sub, style: const TextStyle(color: Colors.white54)),
      ],
    ),
  );

  Widget workoutGrid(BuildContext context, List<Workout> list) => LayoutBuilder(
    builder: (context, c) {
      const gap = 16.0;
      final cols = (c.maxWidth / 210).floor().clamp(1, 5);
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final w in list)
            SizedBox(width: width, child: workoutCard(context, w)),
        ],
      );
    },
  );

  Widget workoutCard(BuildContext context, Workout w) {
    final selected = w.sameAs(app.current);
    return Material(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? pink : Colors.white10,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => app.load(w),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.name.isEmpty ? 'Custom workout' : w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: Text(
                  w.hasNames
                      ? [for (var i = 0; i < w.count; i++) w.exerciseName(i)]
                            .join(' · ')
                      : '${w.count} exercises · ${fmt(w.work)} work / ${fmt(w.rest)} rest',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    fmt(w.totalSecs),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${w.rounds}x',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    tooltip: 'Start now',
                    style: IconButton.styleFrom(
                      backgroundColor: pink,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      app.load(w);
                      start(context);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
