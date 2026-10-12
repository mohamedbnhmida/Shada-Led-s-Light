import 'package:flutter/material.dart';

import 'bulb.dart';
import 'models.dart';
import 'settings.dart';
import 'widgets.dart';

const _presetIcons = {
  'preset_sunrise': Icons.wb_twilight_rounded,
  'preset_sunset': Icons.nights_stay_rounded,
  'preset_relax': Icons.spa_rounded,
  'preset_reading': Icons.menu_book_rounded,
  'preset_night': Icons.bedtime_rounded,
  'preset_candle': Icons.local_fire_department_rounded,
  'preset_ocean': Icons.water_rounded,
  'preset_rainbow': Icons.looks_rounded,
  'preset_party': Icons.celebration_rounded,
};

IconData sceneIcon(Scene s) => _presetIcons[s.id] ?? Icons.auto_awesome_rounded;

/// Built-in names are translation keys until the user renames them.
String sceneName(BuildContext context, Scene s) => s.name.startsWith('preset_') ? context.t(s.name) : s.name;

Gradient sceneGradient(Scene s) {
  final c = [for (final st in s.steps.take(5)) st.state.preview];
  if (c.isEmpty) c.add(Colors.grey);
  if (c.length == 1) c.add(Color.lerp(c.first, Colors.black, 0.55)!);
  return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c);
}

class ScenesPage extends StatelessWidget {
  final BulbController bulb;
  const ScenesPage({super.key, required this.bulb});

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.95),
        itemCount: bulb.scenes.length,
        itemBuilder: (context, i) {
          final s = bulb.scenes[i];
          final playing = bulb.playingId == s.id;
          return GlassCard(
            gradient: sceneGradient(s),
            glow: playing ? Colors.white : null,
            onTap: () => playing ? bulb.stop() : bulb.play(s),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16)),
                    child: Icon(playing ? Icons.stop_rounded : sceneIcon(s), color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SceneEditor(bulb: bulb, scene: s))),
                  ),
                ]),
                const Spacer(),
                Text(sceneName(context, s),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Flexible(
                    child: Text(context.t(s.steps.length == 1 ? 'steps_one' : 'steps', {'n': s.steps.length}),
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                  ),
                  if (s.loop) ...const [SizedBox(width: 6), Icon(Icons.repeat_rounded, size: 16, color: Colors.white70)],
                ]),
              ],
            ),
          );
        },
      );
}

class SceneEditor extends StatefulWidget {
  final BulbController bulb;
  final Scene scene;
  const SceneEditor({super.key, required this.bulb, required this.scene});
  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  late final _name = TextEditingController(text: sceneName(context, widget.scene));

  Scene get s => widget.scene;

  void _change(VoidCallback f) {
    setState(f);
    widget.bulb.save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(context.t('edit_scene')),
          actions: [
            IconButton(icon: const Icon(Icons.play_arrow_rounded), onPressed: () => widget.bulb.play(s)),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                widget.bulb.scenes.remove(s);
                widget.bulb.save();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: Text(context.t('add_current')),
          onPressed: () => _change(() => s.steps.add(SceneStep(widget.bulb.state))),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Container(
              height: 110,
              padding: const EdgeInsets.all(18),
              alignment: AlignmentDirectional.bottomStart,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: sceneGradient(s)),
              child: Icon(sceneIcon(s), color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: context.t('name'),
                filled: true,
                fillColor: context.pal.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (v) => _change(() => s.name = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('loop')),
              subtitle: Text(context.t('loop_sub')),
              value: s.loop,
              onChanged: (v) => _change(() => s.loop = v),
            ),
            Text(context.t('tip'), style: TextStyle(color: context.pal.muted, fontSize: 13)),
            const SizedBox(height: 12),
            for (final (i, step) in s.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StepCard(
                  index: i,
                  step: step,
                  onPreview: () => widget.bulb.apply(step.state),
                  onChanged: () => _change(() {}),
                  onUseCurrent: () => _change(() => step.state = widget.bulb.state),
                  onDelete: () => _change(() => s.steps.removeAt(i)),
                ),
              ),
          ],
        ),
      );
}

/// One scene step. Wraps instead of overflowing on narrow screens and long translations.
class _StepCard extends StatelessWidget {
  final int index;
  final SceneStep step;
  final VoidCallback onPreview, onChanged, onUseCurrent, onDelete;
  const _StepCard(
      {required this.index,
      required this.step,
      required this.onPreview,
      required this.onChanged,
      required this.onUseCurrent,
      required this.onDelete});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 0, 12),
        child: Row(children: [
          GestureDetector(
            onTap: onPreview,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.state.preview,
                boxShadow: [BoxShadow(color: step.state.preview.withValues(alpha: 0.5), blurRadius: 12)],
              ),
              child: Icon(step.state.white ? Icons.wb_incandescent_rounded : Icons.palette_rounded, size: 18, color: Colors.black45),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('step', {'n': index + 1}), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PillSegments<bool>(
                  dense: true,
                  items: [(false, context.t('hold'), Icons.pause_rounded), (true, context.t('fade'), Icons.gradient_rounded)],
                  value: step.fade,
                  onChanged: (v) {
                    step.fade = v;
                    onChanged();
                  },
                ),
                PopupMenuButton<double>(
                  initialValue: step.seconds,
                  onSelected: (v) {
                    step.seconds = v;
                    onChanged();
                  },
                  itemBuilder: (_) => [for (final d in durations) PopupMenuItem(value: d, child: Text(formatSeconds(d)))],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: context.pal.track, borderRadius: BorderRadius.circular(24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer_outlined, size: 16, color: context.pal.muted),
                      const SizedBox(width: 6),
                      Text(formatSeconds(step.seconds), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.pal.muted),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert_rounded, color: context.pal.muted),
            itemBuilder: (_) => [
              PopupMenuItem(
                  onTap: onUseCurrent,
                  child: Row(children: [const Icon(Icons.colorize_rounded, size: 20), const SizedBox(width: 12), Text(context.t('use_current'))])),
              PopupMenuItem(
                  onTap: onDelete,
                  child: Row(children: [const Icon(Icons.delete_outline_rounded, size: 20), const SizedBox(width: 12), Text(context.t('delete'))])),
            ],
          ),
        ]),
      );
}
