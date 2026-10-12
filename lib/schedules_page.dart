import 'package:flutter/material.dart';

import 'bulb.dart';
import 'models.dart';
import 'protocol.dart';
import 'scenes_page.dart';
import 'settings.dart';
import 'widgets.dart';

List<String> _days(BuildContext context) => context.t('days').split(',');

String _two(int v) => v.toString().padLeft(2, '0');

String _mins(int m) => m < 60 ? '$m min' : '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60}'}';

class SchedulesPage extends StatelessWidget {
  final BulbController bulb;
  const SchedulesPage({super.key, required this.bulb});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
        children: [
          if (bulb.schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(children: [
                Icon(Icons.schedule_rounded, size: 56, color: context.pal.muted),
                const SizedBox(height: 12),
                Text(context.t('no_sched'), style: TextStyle(color: context.pal.muted)),
              ]),
            ),
          for (final s in bulb.schedules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                onTap: () => editSchedule(context, bulb, s),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_two(s.hour)}:${_two(s.minute)}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: s.enabled ? null : context.pal.muted)),
                      const SizedBox(height: 6),
                      Row(children: [
                        for (var d = 1; d <= 7; d++)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: Text(_days(context)[d - 1],
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: s.days.contains(d) ? Theme.of(context).colorScheme.primary : context.pal.muted.withValues(alpha: 0.4))),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      _ActionChip(bulb: bulb, schedule: s),
                    ]),
                  ),
                  Switch(
                    value: s.enabled,
                    onChanged: (v) {
                      s.enabled = v;
                      bulb.save();
                    },
                  ),
                ]),
              ),
            ),
        ],
      );
}

/// One-line summary of what a schedule does.
class _ActionChip extends StatelessWidget {
  final BulbController bulb;
  final Schedule schedule;
  const _ActionChip({required this.bulb, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final scene = bulb.sceneById(s.sceneId);
    final (Decoration dot, String label) = switch (s.action) {
      ScheduleAction.on => (
          BoxDecoration(shape: BoxShape.circle, color: s.light.preview),
          '${context.t('on_action')} · ${context.t(s.light.white ? 'white' : 'color')} ${(s.light.brightness * 100).round()}% · ${_mins(s.minutes)}'
        ),
      ScheduleAction.off => (BoxDecoration(shape: BoxShape.circle, color: context.pal.off), context.t('turn_off')),
      ScheduleAction.scene => (
          BoxDecoration(shape: BoxShape.circle, gradient: scene == null ? null : sceneGradient(scene), color: scene == null ? context.pal.muted : null),
          scene == null ? context.t('deleted_scene') : '${sceneName(context, scene)} · ${_mins(s.minutes)}'
        ),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 14, height: 14, decoration: dot),
      const SizedBox(width: 8),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted))),
    ]);
  }
}

/// Bottom sheet to create ([s] == null) or edit a schedule.
Future<void> editSchedule(BuildContext context, BulbController bulb, [Schedule? s]) async {
  final isNew = s == null;
  // Edit a copy so dismissing the sheet discards changes.
  final sch = s == null ? Schedule(hour: 7, minute: 0, sceneId: bulb.scenes.firstOrNull?.id) : Schedule.fromJson(s.toJson());
  sch.sceneId ??= bulb.scenes.firstOrNull?.id;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.pal.card,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        final l = sch.light;
        void setLight(LightState v) => setSheet(() => sch.light = v);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(context.t(isNew ? 'new_schedule' : 'edit_schedule'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: sch.hour, minute: sch.minute));
                    if (t != null) {
                      setSheet(() {
                        sch.hour = t.hour;
                        sch.minute = t.minute;
                      });
                    }
                  },
                  child: Text('${_two(sch.hour)}:${_two(sch.minute)}',
                      textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300)),
                ),
              ),
              _label(context, context.t('repeat')),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var d = 1; d <= 7; d++)
                    GestureDetector(
                      onTap: () => setSheet(() => sch.days.contains(d) ? sch.days.remove(d) : sch.days.add(d)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: sch.days.contains(d) ? shadaYellow : context.pal.track),
                        child: Text(_days(context)[d - 1],
                            style: TextStyle(fontWeight: FontWeight.w700, color: sch.days.contains(d) ? shadaSlate : context.pal.muted)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _label(context, context.t('action')),
              PillSegments<ScheduleAction>(
                expand: true,
                items: [
                  (ScheduleAction.on, context.t('on_action'), Icons.lightbulb_rounded),
                  (ScheduleAction.off, context.t('turn_off'), Icons.power_settings_new_rounded),
                  (ScheduleAction.scene, context.t('scene_action'), Icons.auto_awesome),
                ],
                value: sch.action,
                onChanged: (v) => setSheet(() => sch.action = v),
              ),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: switch (sch.action) {
                  ScheduleAction.on => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        PillSegments<bool>(
                          dense: true,
                          items: [(false, context.t('color'), Icons.palette_rounded), (true, context.t('white'), Icons.wb_incandescent_rounded)],
                          value: l.white,
                          onChanged: (v) => setLight(l.copyWith(white: v)),
                        ),
                        const Spacer(),
                        GlowBulb(color: l.preview, on: true, size: 40),
                      ]),
                      const SizedBox(height: 16),
                      if (!l.white) ...[
                        _label(context, context.t('hue')),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: GradientSlider(value: l.hue, max: 359, colors: hueColors, onChanged: (v) => setLight(l.copyWith(hue: v))),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _label(context, '${context.t(l.white ? 'warm_white' : 'brightness')} · ${(l.brightness * 100).round()}%'),
                      GradientSlider(
                        icon: Icons.brightness_6_rounded,
                        value: l.brightness,
                        min: 0.05,
                        colors: l.white
                            ? const [Color(0xFF3A2E1F), Color(0xFFFFC98A)]
                            : [Colors.black, HSVColor.fromAHSV(1, l.hue, 1, 1).toColor()],
                        onChanged: (v) => setLight(l.copyWith(brightness: v)),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.visibility_rounded),
                          label: Text(context.t('try_lamp')),
                          onPressed: () => bulb.apply(l.copyWith(on: true)),
                        ),
                      ),
                    ]),
                  ScheduleAction.off => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: context.pal.track, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Icon(Icons.nights_stay_rounded, color: context.pal.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Text(context.t('off_hint'), style: TextStyle(color: context.pal.muted))),
                      ]),
                    ),
                  ScheduleAction.scene => SizedBox(
                      height: 112,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final sc in bulb.scenes)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 10),
                              child: SizedBox(
                                width: 104,
                                child: GlassCard(
                                  padding: const EdgeInsets.all(12),
                                  gradient: sceneGradient(sc),
                                  glow: sch.sceneId == sc.id ? shadaYellow : null,
                                  onTap: () => setSheet(() => sch.sceneId = sc.id),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(sceneIcon(sc), color: Colors.white),
                                    const Spacer(),
                                    Text(sceneName(context, sc),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                },
              ),
              if (sch.action != ScheduleAction.off) ...[
                const SizedBox(height: 20),
                // Runs for a limited time, then the lamp switches off; nothing runs forever.
                Row(children: [
                  Icon(Icons.timer_outlined, color: context.pal.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.t('duration'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(context.t('then_off'), style: TextStyle(color: context.pal.muted, fontSize: 12)),
                    ]),
                  ),
                  PopupMenuButton<int>(
                    initialValue: sch.minutes,
                    onSelected: (v) => setSheet(() => sch.minutes = v),
                    itemBuilder: (_) => [for (final m in scheduleDurations) PopupMenuItem(value: m, child: Text(_mins(m)))],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: shadaYellow, borderRadius: BorderRadius.circular(24)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_mins(sch.minutes), style: const TextStyle(color: shadaSlate, fontWeight: FontWeight.w800)),
                        const Icon(Icons.arrow_drop_down_rounded, color: shadaSlate),
                      ]),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 28),
              Row(children: [
                if (!isNew)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(context.t('delete')),
                    onPressed: () {
                      bulb.schedules.remove(s);
                      bulb.save();
                      Navigator.pop(context);
                    },
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: sch.days.isEmpty
                      ? null
                      : () {
                          isNew ? bulb.schedules.add(sch) : bulb.schedules[bulb.schedules.indexOf(s)] = sch;
                          bulb.schedules.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
                          bulb.save();
                          Navigator.pop(context);
                        },
                  child: Text(context.t('save')),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
