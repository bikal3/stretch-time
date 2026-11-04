import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'postures.dart';
import 'run_screen.dart';
import 'workout.dart';

const _tabular = [FontFeature.tabularFigures()];

/// − / + button: tap steps once, hold repeats.
class RepeatButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onStep;
  const RepeatButton(this.icon, this.label, this.onStep, {super.key});

  @override
  State<RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {
  Timer? _timer;

  void _stop() => _timer?.cancel();

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: (_) => _timer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => widget.onStep(),
    ),
    onLongPressEnd: (_) => _stop(),
    onLongPressCancel: _stop,
    child: IconButton.filledTonal(
      tooltip: widget.label,
      iconSize: 36,
      padding: const EdgeInsets.all(14),
      onPressed: widget.onStep,
      icon: Icon(widget.icon),
    ),
  );
}

/// Desktop-width window: dialogs instead of bottom sheets, centered pages.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// Bottom sheet on phones, centered dialog on wide screens.
void showPanel(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
}) {
  if (isWide(context)) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: tall
                ? SizedBox(
                    height: MediaQuery.sizeOf(c).height * 0.75,
                    child: builder(c),
                  )
                : builder(c),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: tall,
      builder: (c) => tall
          ? FractionallySizedBox(heightFactor: 0.85, child: builder(c))
          : builder(c),
    );
  }
}

/// Centers and width-limits a page body on wide screens.
Widget pageBody(Widget child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: child,
  ),
);

/// Bottom sheet that edits one number live: hold-to-repeat −/+ and quick picks.
void showValueEditor(
  BuildContext context, {
  required String title,
  required int value,
  required int min,
  required int max,
  required int step,
  required bool isTime,
  required List<int> quick,
  required Color color,
  required ValueChanged<int> onChanged,
}) {
  showPanel(
    context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void set(int v) {
          v = v.clamp(min, max);
          if (v == value) return;
          setState(() => value = v);
          onChanged(v);
        }

        // Snap to the step grid so 32 +5 -> 35, not 37.
        void stepBy(int dir) => set(
          dir > 0
              ? (value ~/ step) * step + step
              : ((value + step - 1) ~/ step) * step - step,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RepeatButton(Icons.remove, 'Decrease', () => stepBy(-1)),
                    Text(
                      isTime ? fmt(value) : '$value',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: _tabular,
                      ),
                    ),
                    RepeatButton(Icons.add, 'Increase', () => stepBy(1)),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final q in quick)
                      ChoiceChip(
                        label: Text(
                          isTime
                              ? (q < 60
                                    ? '${q}s'
                                    : q % 60 == 0
                                    ? '${q ~/ 60}m'
                                    : fmt(q))
                              : '$q',
                        ),
                        selected: q == value,
                        onSelected: (_) => set(q),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void showWorkouts(BuildContext context, AppState app) {
  showPanel(
    context,
    tall: true,
    builder: (context) => DefaultTabController(
      length: 3,
      initialIndex: app.saved.isEmpty ? 0 : 1,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          Widget tile(Workout w, {VoidCallback? onDelete}) {
            final t = ListTile(
              title: Text(w.name.isEmpty ? 'Custom workout' : w.name),
              subtitle: Text(w.summary),
              onTap: () {
                app.load(w);
                Navigator.pop(context);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fmt(w.totalSecs),
                    style: const TextStyle(fontFeatures: _tabular),
                  ),
                  IconButton(
                    tooltip: 'Start now',
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 34),
                    onPressed: () {
                      final nav = Navigator.of(context);
                      app.load(w);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(builder: (_) => RunScreen(app)),
                      );
                    },
                  ),
                ],
              ),
            );
            if (onDelete == null) return t;
            return Dismissible(
              key: ObjectKey(w),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.shade700,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete),
              ),
              onDismissed: (_) => onDelete(),
              child: t,
            );
          }

          Widget empty(String msg) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );

          return Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Presets'),
                  Tab(text: 'Saved'),
                  Tab(text: 'Recent'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(children: [for (final w in presets) tile(w)]),
                    ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton.icon(
                            onPressed: () => askSaveName(context, app),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Save current workout'),
                          ),
                        ),
                        if (app.saved.isEmpty)
                          empty(
                            'Nothing saved yet.\nSet up a workout, then save it here.',
                          ),
                        for (final w in app.saved)
                          tile(w, onDelete: () => app.deleteSaved(w)),
                        if (app.saved.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Swipe left to delete',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                    app.recent.isEmpty
                        ? empty('Workouts you run show up here.')
                        : ListView(
                            children: [for (final w in app.recent) tile(w)],
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> askSaveName(BuildContext context, AppState app) async {
  final ctrl = TextEditingController(text: app.current.name);
  final name = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Save workout'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Morning Stretch'),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (name != null && name.trim().isNotEmpty) app.saveAs(name.trim());
}

class ExercisesScreen extends StatefulWidget {
  final AppState app;
  const ExercisesScreen(this.app, {super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  late final List<TextEditingController> ctrls = [
    for (final e in widget.app.current.exercises)
      TextEditingController(text: e),
  ];

  @override
  void dispose() {
    for (final c in ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void save() => widget.app.edit(
    widget.app.current.copyWith(exercises: [for (final c in ctrls) c.text]),
  );

  void add() {
    if (ctrls.length >= 99) return;
    setState(() => ctrls.add(TextEditingController()));
    save();
  }

  void remove(int i) {
    if (ctrls.length <= 1) return;
    final c = ctrls.removeAt(i);
    setState(() {});
    // The TextField still holds it until this frame rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
    save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Exercises (${ctrls.length})')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add,
      icon: const Icon(Icons.add),
      label: const Text('Add exercise'),
    ),
    body: pageBody(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Name each stretch so the timer can show and say it. Hold and drag to reorder.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                RepeatButton(
                  Icons.remove,
                  'Fewer',
                  () => remove(ctrls.length - 1),
                ),
                const SizedBox(width: 8),
                RepeatButton(Icons.add, 'More', add),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: ctrls.length,
              onReorderItem: (from, to) {
                setState(() => ctrls.insert(to, ctrls.removeAt(from)));
                save();
              },
              itemBuilder: (context, i) => ListTile(
                key: ObjectKey(ctrls[i]),
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: TextField(
                  controller: ctrls[i],
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Exercise ${i + 1}',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => save(),
                ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: ctrls.length > 1 ? () => remove(i) : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  final AppState app;
  const SettingsScreen(this.app, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: pageBody(
      ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final s = app.settings;
          void set(Settings v) => app.updateSettings(v);

          Widget toggle(
            IconData icon,
            String title,
            String sub,
            bool value,
            ValueChanged<bool> onChanged,
          ) => SwitchListTile(
            secondary: Icon(icon),
            title: Text(title),
            subtitle: Text(sub),
            value: value,
            onChanged: onChanged,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _group(context, 'Appearance', [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'system',
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: 'light',
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: 'dark',
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) =>
                          set(s.copyWith(themeMode: v.first)),
                    ),
                  ),
                ),
              ]),
              _group(context, 'Cues', [
                toggle(
                  Icons.record_voice_over_outlined,
                  'Voice announcements',
                  'Says the stretch name, "Rest" and counts down 3, 2, 1',
                  s.voice,
                  (v) => set(s.copyWith(voice: v)),
                ),
                toggle(
                  Icons.volume_up_outlined,
                  'Sounds',
                  'Beeps at phase changes and countdown',
                  s.sound,
                  (v) => set(s.copyWith(sound: v)),
                ),
                toggle(
                  Icons.vibration,
                  'Vibration',
                  'On phones that support it',
                  s.vibration,
                  (v) => set(s.copyWith(vibration: v)),
                ),
              ]),
              _group(context, 'Workout', [
                toggle(
                  Icons.screen_lock_portrait_outlined,
                  'Keep screen on',
                  'While a workout is running',
                  s.keepAwake,
                  (v) => set(s.copyWith(keepAwake: v)),
                ),
                const ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('Get ready countdown'),
                  subtitle: Text(
                    'Time to get into position before the first exercise',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: [
                        for (final v in [0, 3, 5, 10])
                          ButtonSegment(
                            value: v,
                            label: Text(v == 0 ? 'Off' : '${v}s'),
                          ),
                      ],
                      selected: {s.readySecs},
                      onSelectionChanged: (v) =>
                          set(s.copyWith(readySecs: v.first)),
                    ),
                  ),
                ),
              ]),
            ],
          );
        },
      ),
    ),
  );

  Widget _group(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Card.filled(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ],
        ),
      );
}

/// A [Pose] as a stick figure; [red] limbs are drawn in red.
class Figure extends StatelessWidget {
  final Pose pose;
  final Color color;
  final Set<Limb> red;
  const Figure(
    this.pose, {
    super.key,
    required this.color,
    this.red = const {},
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: CustomPaint(painter: _FigurePainter(pose, color, red)),
  );
}

class _FigurePainter extends CustomPainter {
  final Pose pose;
  final Color color;
  final Set<Limb> red;
  _FigurePainter(this.pose, this.color, this.red);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 100;
    Offset at((double, double) p) => Offset(p.$1 * k, p.$2 * k);
    Paint pen(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Path line(List<(double, double)> pts) =>
        Path()..addPolygon([for (final p in pts) at(p)], false);

    for (final p in pose.props) {
      canvas.drawPath(line(p), pen(color.withValues(alpha: 0.45), 1.6));
    }
    final j = pose.joints;
    for (final MapEntry(key: limb, value: idx) in limbJoints.entries) {
      final c = red.contains(limb) ? const Color(0xFFE5484D) : color;
      canvas.drawPath(line([for (final i in idx) j[i]]), pen(c, 3.4));
    }
    final headPen = pen(
      red.contains(Limb.head) ? const Color(0xFFE5484D) : color,
      3.4,
    );
    canvas.drawCircle(at(j[0]), 6.5 * k, headPen..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.pose != pose || old.color != color;
}

/// Correct vs. common-mistake figures and form tips for one exercise.
void showPostureInfo(BuildContext context, String name, Posture p) {
  showPanel(
    context,
    builder: (context) {
      final fg = Theme.of(context).colorScheme.onSurface;
      Widget side(
        Pose pose,
        Set<Limb> red,
        IconData icon,
        Color c,
        String label,
      ) => Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Figure(pose, color: fg, red: red),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: c, size: 20),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: c, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      // Scrolls on short phones, where the sheet is capped below full height.
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    side(
                      p.correct,
                      const {},
                      Icons.check_circle_rounded,
                      const Color(0xFF1E9E5A),
                      'Correct',
                    ),
                    const SizedBox(width: 12),
                    side(
                      p.wrong,
                      p.wrongLimbs,
                      Icons.cancel_rounded,
                      const Color(0xFFE5484D),
                      'Common mistake',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final tip in p.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '•  $tip',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
