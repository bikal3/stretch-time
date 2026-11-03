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
    ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'StretchTime',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.values.byName(app.settings.themeMode),
        home: HomeScreen(app),
      ),
    ),
  );
}

ThemeData buildTheme(Brightness b) => ThemeData(
  brightness: b,
  colorSchemeSeed: pink,
  fontFamilyFallback: const ['Roboto', 'Helvetica Neue', 'Arial'],
);

const pink = Color(0xFFF5435A);
const darkRed = Color(0xFF6B1420);
const tabular = [FontFeature.tabularFigures()];
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF6A55), Color(0xFFF5435A), Color(0xFFEC1C5C)],
);

/// Accent colors for one setting, per brightness.
class Tone {
  final IconData icon;
  final Color darkFg, darkBg, lightFg, lightBg;
  const Tone(this.icon, this.darkFg, this.darkBg, this.lightFg, this.lightBg);

  bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color fg(BuildContext c) => _dark(c) ? darkFg : lightFg;
  Color bg(BuildContext c) => _dark(c) ? darkBg : lightBg;
}

const tones = {
  'work': Tone(
    Icons.play_arrow_rounded,
    Color(0xFF5EE39A),
    Color(0xFF243A2F),
    Color(0xFF15803D),
    Color(0xFFDDF5E7),
  ),
  'rest': Tone(
    Icons.pause_rounded,
    Color(0xFFFF6B83),
    Color(0xFF3F2128),
    Color(0xFFE11D48),
    Color(0xFFFDE4E9),
  ),
  'exercises': Tone(
    Icons.self_improvement_rounded,
    Color(0xFFE2E2E2),
    Color(0xFF333333),
    Color(0xFF3F4652),
    Color(0xFFECEEF2),
  ),
  'rounds': Tone(
    Icons.replay_rounded,
    Color(0xFF8D99FF),
    Color(0xFF262A44),
    Color(0xFF4F46E5),
    Color(0xFFE6E7FD),
  ),
  'reset': Tone(
    Icons.schedule_rounded,
    Color(0xFFF5D061),
    Color(0xFF3B3424),
    Color(0xFFB45309),
    Color(0xFFFBF0D5),
  ),
};

Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

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

  Widget logo({double size = 40}) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: brandGradient,
    ),
    child: Icon(
      Icons.self_improvement_rounded,
      color: Colors.white,
      size: size * 0.62,
    ),
  );

  /// 2×2 grid of timing tiles plus a full-width exercises tile.
  List<Widget> settingTiles(BuildContext context) {
    final w = app.current;
    const gap = SizedBox(width: 12, height: 12);

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
      color: tones[key]!.fg(context),
      onChanged: (v) => app.edit(apply(v)),
    );

    Widget badge(Tone t) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.fg(context).withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(t.icon, color: t.fg(context), size: 24),
    );

    Widget tile(String key, String label, String value, VoidCallback onTap) {
      final t = tones[key]!;
      return Material(
        color: t.bg(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    badge(t),
                    const Spacer(),
                    Icon(Icons.edit_outlined, size: 18, color: muted(context)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: TextStyle(fontSize: 15, color: muted(context)),
                ),
                FittedBox(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: t.fg(context),
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ex = tones['exercises']!;
    return [
      Row(
        children: [
          Expanded(
            child: tile(
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
          ),
          gap,
          Expanded(
            child: tile(
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
          ),
        ],
      ),
      gap,
      Row(
        children: [
          Expanded(
            child: tile(
              'rounds',
              'Rounds',
              '${w.rounds}×',
              () => edit(
                'rounds',
                'Rounds',
                w.rounds,
                [1, 2, 3, 4, 5, 8, 10],
                (v) => app.current.copyWith(rounds: v),
                isTime: false,
              ),
            ),
          ),
          if (w.circuit) ...[
            gap,
            Expanded(
              child: tile(
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
            ),
          ],
        ],
      ),
      if (w.rounds > 1) ...[
        gap,
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.repeat_one_rounded),
                label: Text(
                  '${w.rounds}× each exercise',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const ButtonSegment(
                value: true,
                icon: Icon(Icons.repeat_rounded),
                label: Text('Circuit', overflow: TextOverflow.ellipsis),
              ),
            ],
            selected: {w.circuit},
            onSelectionChanged: (v) =>
                app.edit(app.current.copyWith(circuit: v.first)),
          ),
        ),
      ],
      gap,
      Material(
        color: ex.bg(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExercisesScreen(app)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                badge(ex),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercises',
                        style: TextStyle(fontSize: 15, color: muted(context)),
                      ),
                      Text(
                        w.hasNames
                            ? [
                                for (var i = 0; i < w.count; i++)
                                  w.exerciseName(i),
                              ].join(' · ')
                            : 'Tap to name your stretches',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${w.count}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ex.fg(context),
                    fontFeatures: tabular,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted(context)),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget heroCard(
    BuildContext context,
    Workout w, {
    bool compact = false,
  }) => Container(
    padding: EdgeInsets.all(compact ? 24 : 40),
    decoration: BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: pink.withValues(alpha: 0.35),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                w.name.isEmpty ? 'Custom workout' : w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w600,
                  color: darkRed,
                ),
              ),
            ),
            if (compact)
              IconButton(
                tooltip: 'Save workout',
                color: darkRed,
                onPressed: () => askSaveName(context, app),
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TOTAL TIME',
              style: TextStyle(fontSize: 13, letterSpacing: 3, color: darkRed),
            ),
            FittedBox(
              child: Text(
                fmt(w.totalSecs),
                style: TextStyle(
                  fontSize: compact ? 88 : 150,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -3,
                  fontFeatures: tabular,
                ),
              ),
            ),
            Text(
              '${plural(w.count, 'exercise')} · ${plural(w.rounds, 'round')} · ${fmt(w.work)} work / ${fmt(w.rest)} rest',
              style: TextStyle(
                fontSize: compact ? 14 : 17,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 24),
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
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: pink,
                  size: 30,
                ),
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
      ],
    ),
  );

  Widget sectionTitle(
    BuildContext context,
    String title, {
    String? sub,
    Widget? trailing,
    double top = 32,
  }) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 12, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        if (sub != null) ...[
          const SizedBox(width: 12),
          Text(sub, style: TextStyle(color: muted(context))),
        ],
        const Spacer(),
        ?trailing,
      ],
    ),
  );

  Widget workoutCard(BuildContext context, Workout w) {
    final cs = Theme.of(context).colorScheme;
    final selected = w.sameAs(app.current);
    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? pink : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => app.load(w),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.name.isEmpty ? 'Custom workout' : w.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: Text(
                  w.hasNames
                      ? [for (var i = 0; i < w.count; i++) w.exerciseName(i)]
                            .join(' · ')
                      : '${plural(w.count, 'exercise')} · ${fmt(w.work)} work / ${fmt(w.rest)} rest',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: muted(context)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    fmt(w.totalSecs),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${w.rounds}×', style: TextStyle(color: muted(context))),
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

  // ----------------------------------------------------------------- phone

  Widget phoneLayout(BuildContext context) {
    final w = app.current;
    final quick = [...app.saved, ...presets];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                logo(size: 36),
                const SizedBox(width: 10),
                const Text(
                  'StretchTime',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Saved & recent',
                  onPressed: () => showWorkouts(context, app),
                  icon: const Icon(Icons.history_rounded),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => openSettings(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            heroCard(context, w, compact: true),
            sectionTitle(context, 'Customize', top: 28),
            ...settingTiles(context),
            sectionTitle(
              context,
              'Quick start',
              top: 28,
              trailing: TextButton(
                onPressed: () => showWorkouts(context, app),
                child: const Text('See all'),
              ),
            ),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: quick.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    SizedBox(width: 220, child: workoutCard(context, quick[i])),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: startBar(context, w),
    );
  }

  /// Always-visible start button at the bottom of the phone layout.
  Widget startBar(BuildContext context, Workout w) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: brandGradient,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: pink.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () => start(context),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: pink,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Start workout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    fmt(w.totalSecs),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular,
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------------ wide

  Widget wideLayout(BuildContext context) {
    final w = app.current;
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      logo(size: 44),
                      const SizedBox(width: 12),
                      const Text(
                        'StretchTime',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
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
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                      ),
                    ],
                  ),
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
                              sectionTitle(context, 'Customize', top: 0),
                              ...settingTiles(context),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.saved.isNotEmpty) ...[
                    sectionTitle(
                      context,
                      'Your workouts',
                      sub: 'Click to load, ▶ to start right away',
                      top: 48,
                    ),
                    workoutGrid(context, app.saved),
                  ],
                  sectionTitle(
                    context,
                    'Presets',
                    sub: 'Ready-made routines to get you started',
                    top: 48,
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
}
