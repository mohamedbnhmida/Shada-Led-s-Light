import 'dart:math';

import 'package:flutter/material.dart';

import 'settings.dart';

final hueColors = [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()];

/// Page background that glows in the bulb's current colour.
class GlowBackground extends StatelessWidget {
  final Color color;
  final Widget child;
  const GlowBackground({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 0.9,
            colors: [color.withValues(alpha: 0.18), context.pal.bg],
          ),
        ),
        child: child,
      );
}

/// Ring of hues with a draggable thumb; [child] sits in the middle.
class HueWheel extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;
  final Widget child;
  const HueWheel({super.key, required this.hue, required this.onChanged, required this.child});

  static const ring = 34.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = min(c.maxWidth, 320.0);
        void touch(Offset p) {
          final d = p - Offset(size / 2, size / 2);
          if (d.distance < size / 2 - ring * 2) return; // ignore taps on the centre
          onChanged((atan2(d.dy, d.dx) * 180 / pi + 360) % 360);
        }

        return SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            onPanDown: (d) => touch(d.localPosition),
            onPanUpdate: (d) => touch(d.localPosition),
            child: CustomPaint(
              painter: _WheelPainter(hue),
              child: Center(child: child),
            ),
          ),
        );
      });
}

class _WheelPainter extends CustomPainter {
  final double hue;
  _WheelPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - HueWheel.ring / 2 - 6;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = HueWheel.ring
          ..shader = SweepGradient(colors: hueColors).createShader(Rect.fromCircle(center: c, radius: r)));
    final a = hue * pi / 180;
    final t = c + Offset(cos(a), sin(a)) * r;
    canvas.drawCircle(t, HueWheel.ring / 2 + 4, Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(t, HueWheel.ring / 2 + 3, Paint()..color = Colors.white);
    canvas.drawCircle(t, HueWheel.ring / 2 - 3, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.hue != hue;
}

/// Glowing bulb disc; tap toggles power.
class GlowBulb extends StatelessWidget {
  final Color color;
  final bool on;
  final double size;
  final VoidCallback? onTap;
  const GlowBulb({super.key, required this.color, required this.on, this.size = 150, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: on ? [Colors.white, color] : [context.pal.off, context.pal.card], stops: const [0, 0.85]),
            boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 60, spreadRadius: 8)] : const [],
          ),
          child: Icon(Icons.power_settings_new_rounded, size: size * 0.28, color: on ? Colors.black54 : context.pal.muted),
        ),
      );
}

/// Slider drawn on top of a gradient pill.
class GradientSlider extends StatelessWidget {
  final double value, min, max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  final IconData? icon;
  const GradientSlider(
      {super.key, required this.value, required this.colors, required this.onChanged, this.min = 0, this.max = 1, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: LinearGradient(colors: colors)),
        child: Row(children: [
          if (icon != null) Padding(padding: const EdgeInsets.only(left: 16), child: Icon(icon, color: Colors.black54, size: 20)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                overlayShape: SliderComponentShape.noOverlay,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15, elevation: 4),
              ),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
        ]),
      );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? glow;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.gradient, this.glow});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: gradient == null ? context.pal.card : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glow ?? context.pal.muted.withValues(alpha: 0.12), width: glow == null ? 1 : 2),
          boxShadow: [
            glow == null
                ? BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))
                : BoxShadow(color: glow!.withValues(alpha: 0.5), blurRadius: 24),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

String formatSeconds(double s) => s < 60
    ? '${s % 1 == 0 ? s.toInt() : s}s'
    : s < 3600
        ? '${(s / 60).round()} min'
        : '${(s / 3600).round()} h';

const durations = [0.3, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 30.0, 60.0, 300.0, 600.0, 1800.0, 3600.0];

/// Borderless segmented control: a soft track with a sliding yellow pill.
class PillSegments<T> extends StatelessWidget {
  final List<(T, String, IconData?)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand, dense;
  const PillSegments(
      {super.key, required this.items, required this.value, required this.onChanged, this.expand = false, this.dense = false});

  @override
  Widget build(BuildContext context) {
    Widget seg((T, String, IconData?) item) {
      final (v, label, icon) = item;
      final sel = v == value;
      final fg = sel ? shadaSlate : context.pal.muted;
      return GestureDetector(
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: expand ? 4 : (dense ? 12 : 18), vertical: dense ? 7 : 10),
          decoration: BoxDecoration(color: sel ? shadaYellow : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          // Full-width segments are narrow: stack icon over label and shrink text rather than cropping it.
          child: Flex(
            direction: expand && icon != null ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: dense ? 16 : 18, color: fg), SizedBox(width: 6, height: expand ? 4 : 0)],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      style: TextStyle(color: fg, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: dense ? 13 : 14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.pal.track, borderRadius: BorderRadius.circular(28)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [for (final i in items) expand ? Expanded(child: seg(i)) : seg(i)],
      ),
    );
  }
}
