import 'package:flutter/material.dart';

import 'bulb.dart';
import 'settings.dart';
import 'widgets.dart';

class ControlPage extends StatelessWidget {
  final BulbController bulb;
  const ControlPage({super.key, required this.bulb});

  static const swatches = [0.0, 25.0, 45.0, 120.0, 175.0, 210.0, 265.0, 310.0];

  @override
  Widget build(BuildContext context) {
    final s = bulb.state;
    void toggle() => bulb.apply(s.copyWith(on: !s.on));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
      children: [
        Center(
          child: PillSegments<bool>(
            items: [
              (false, context.t('color'), Icons.palette_rounded),
              (true, context.t('white'), Icons.wb_incandescent_rounded),
            ],
            value: s.white,
            onChanged: (v) => bulb.apply(s.copyWith(white: v, on: true)),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: s.white
              ? SizedBox(height: 280, child: Center(child: GlowBulb(color: s.preview, on: s.on, size: 190, onTap: toggle)))
              // The wheel's geometry is direction-independent; keep it LTR so Arabic doesn't mirror the hues.
              : Directionality(
                  textDirection: TextDirection.ltr,
                  child: HueWheel(
                    hue: s.hue,
                    onChanged: (h) => bulb.apply(s.copyWith(hue: h, on: true)),
                    child: GlowBulb(color: s.preview, on: s.on, onTap: toggle),
                  ),
                ),
        ),
        const SizedBox(height: 32),
        _label(context, context.t(s.white ? 'warm_white' : 'brightness'), '${(s.brightness * 100).round()}%'),
        GradientSlider(
          icon: Icons.brightness_6_rounded,
          value: s.brightness,
          min: 0.05,
          colors: s.white
              ? const [Color(0xFF3A2E1F), Color(0xFFFFC98A)]
              : [Colors.black, HSVColor.fromAHSV(1, s.hue, 1, 1).toColor()],
          onChanged: (v) => bulb.apply(s.copyWith(brightness: v, on: true)),
        ),
        if (!s.white) ...[
          const SizedBox(height: 24),
          _label(context, context.t('quick_colors'), ''),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in swatches)
                GestureDetector(
                  onTap: () => bulb.apply(s.copyWith(hue: h, on: true)),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HSVColor.fromAHSV(1, h, 1, 1).toColor(),
                      border: Border.all(
                          color: (s.hue - h).abs() < 3 ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _label(BuildContext context, String a, String b) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
        child: Row(children: [
          Text(a, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(b, style: TextStyle(color: context.pal.muted)),
        ]),
      );
}
