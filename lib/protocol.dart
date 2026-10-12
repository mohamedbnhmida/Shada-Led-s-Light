// Shada "LED's light" BLE protocol, from the decompiled com.shada.ledslight 2.2.1 (BluetoothLeService).
// Bulb uses a Quintic BLE chip. Model 600750 is 2700K + RGB: it has warm-white LEDs only, the cold channel drives nothing. It has no timer of its own, so scenes and schedules run in the app.
import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:flutter/painting.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final serviceUuid = Guid('0000cc02-0000-1000-8000-00805f9b34fb');
final advUuid = Guid('ffffcc02-0000-1000-8000-00805f9b34fb');
final handshakeUuid = Guid('0000ee02-0000-1000-8000-00805f9b34fb'); // write "quintic" once after connect
final colorWriteUuid = Guid('0000ee03-0000-1000-8000-00805f9b34fb');
const handshake = 'quintic';

/// Same write type as the original app ("without response"), falling back if the bulb doesn't advertise it.
Future<void> writeTo(BluetoothCharacteristic c, List<int> bytes) =>
    c.write(bytes, withoutResponse: c.properties.writeWithoutResponse);

/// On a connected lamp: finds the service, sends the "quintic" unlock and returns the colour characteristic.
Future<BluetoothCharacteristic> unlockLamp(BluetoothDevice device) async {
  final svc = (await device.discoverServices())
      .firstWhere((s) => s.uuid == serviceUuid, orElse: () => throw 'Service cc02 not found on this device');
  final chars = {for (final c in svc.characteristics) c.uuid: c};
  final hand = chars[handshakeUuid] ?? (throw 'Handshake characteristic ee02 missing');
  final color = chars[colorWriteUuid] ?? (throw 'Color characteristic ee03 missing');
  await writeTo(hand, utf8.encode(handshake));
  return color;
}

// 10-byte packet: [on, G, white, cold, on, B, on, R, white, warm]. The bulb has no brightness byte; scale RGB instead.
List<int> rgbPacket(int r, int g, int b, {bool on = true}) {
  int c(int v) => v.clamp(1, 255); // original app never sends 0
  final o = on ? 1 : 0;
  return [o, c(g), 0, 0, o, c(b), o, c(r), 0, 0];
}

// White mode: cold + warm channels. Off keeps the levels but clears the white flags (the app's "ColdPass").
List<int> whitePacket({required int cold, required int warm, bool on = true}) {
  int c(int v) => v.clamp(1, 255);
  final w = on ? 1 : 0;
  return [0, 0, w, c(cold), 0, 0, 0, 0, w, c(warm)];
}

/// What the bulb should show. hue 0-360, brightness 0.05-1 (RGB level, or warm-white level in white mode).
class LightState {
  final bool on, white;
  final double hue, brightness;
  const LightState({this.on = true, this.white = false, this.hue = 30, this.brightness = 1});

  LightState copyWith({bool? on, bool? white, double? hue, double? brightness}) => LightState(
      on: on ?? this.on,
      white: white ?? this.white,
      hue: hue ?? this.hue,
      brightness: brightness ?? this.brightness);

  Color get rgb => HSVColor.fromAHSV(1, hue, 1, brightness).toColor();

  /// Colour for on-screen previews.
  Color get preview => !on
      ? const Color(0xFF2A2833)
      : white
          ? Color.lerp(const Color(0xFF5C4A33), const Color(0xFFFFC98A), brightness)!
          : HSVColor.fromAHSV(1, hue, 1, 0.35 + brightness * 0.65).toColor();

  List<int> get packet {
    if (white) {
      return whitePacket(cold: 0, warm: (brightness * 255).round(), on: on);
    }
    final c = rgb;
    return rgbPacket((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round(), on: on);
  }

  /// Fades only within the same mode; switching mode or power jumps straight to [b].
  static LightState lerp(LightState a, LightState b, double t) => a.white != b.white || !a.on || !b.on
      ? b
      : b.copyWith(
          hue: lerpDouble(a.hue, b.hue, t),
          brightness: lerpDouble(a.brightness, b.brightness, t));

  Map<String, dynamic> toJson() => {'on': on, 'white': white, 'hue': hue, 'brightness': brightness};

  factory LightState.fromJson(Map<String, dynamic> j) => LightState(
      on: j['on'] as bool,
      white: j['white'] as bool,
      hue: (j['hue'] as num).toDouble(),
      brightness: (j['brightness'] as num).toDouble());
}
