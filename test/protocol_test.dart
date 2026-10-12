import 'package:flutter_test/flutter_test.dart';
import 'package:shada_bulb/models.dart';
import 'package:shada_bulb/protocol.dart';

void main() {
  test('rgb packet matches original app layout', () {
    expect(rgbPacket(255, 0, 128), [1, 1, 0, 0, 1, 128, 1, 255, 0, 0]);
    expect(rgbPacket(10, 20, 30, on: false), [0, 20, 0, 0, 0, 30, 0, 10, 0, 0]);
  });

  test('white packet', () {
    expect(const LightState(white: true, brightness: 0.5).packet, [0, 0, 1, 1, 0, 0, 0, 0, 1, 128]);
    expect(whitePacket(cold: 0, warm: 255), [0, 0, 1, 1, 0, 0, 0, 0, 1, 255]);
    expect(whitePacket(cold: 100, warm: 155, on: false), [0, 0, 0, 100, 0, 0, 0, 0, 0, 155]);
  });

  test('fade interpolates within a mode and jumps across modes', () {
    const a = LightState(hue: 0, brightness: 0.2), b = LightState(hue: 100, brightness: 1);
    final mid = LightState.lerp(a, b, 0.5);
    expect(mid.hue, 50);
    expect(mid.brightness, closeTo(0.6, 1e-9));
    const w = LightState(white: true);
    expect(LightState.lerp(a, w, 0.1).white, true);
  });

  test('schedule fires on matching day and minute only', () {
    final s = Schedule(hour: 7, minute: 30, days: {DateTime.monday});
    expect(s.isDue(DateTime(2026, 10, 12, 7, 30)), true); // a Monday
    expect(s.isDue(DateTime(2026, 10, 13, 7, 30)), false);
    expect(s.isDue(DateTime(2026, 10, 12, 7, 31)), false);
    expect((s..enabled = false).isDue(DateTime(2026, 10, 12, 7, 30)), false);
  });

  test('scenes and schedules survive json round trip', () {
    final rainbow = presetScenes().firstWhere((s) => s.id == 'preset_rainbow');
    final scene = Scene.fromJson(rainbow.toJson());
    expect(scene.loop, true);
    expect(scene.steps.first.state.packet, rainbow.steps.first.state.packet);
    final s = Schedule.fromJson(
        Schedule(hour: 6, minute: 5, action: ScheduleAction.on, light: const LightState(hue: 200, brightness: 0.4)).toJson());
    expect((s.hour, s.minute, s.action, s.light.hue, s.light.brightness, s.days.length), (6, 5, ScheduleAction.on, 200.0, 0.4, 7));
    // v1 schedules (no action field) still load
    expect(Schedule.fromJson({'id': 'x', 'hour': 1, 'minute': 2, 'days': [1], 'sceneId': null, 'enabled': true}).action,
        ScheduleAction.off);
  });

  test('due schedules fire once per minute', () {
    final fired = <String>{};
    final s = [Schedule(hour: 7, minute: 30)];
    final t = DateTime(2026, 10, 12, 7, 30, 5);
    expect(dueSchedules(s, t, fired).length, 1);
    expect(dueSchedules(s, t.add(const Duration(seconds: 15)), fired), isEmpty);
    expect(dueSchedules(s, DateTime(2026, 10, 13, 7, 30), fired).length, 1); // next day fires again
  });
}
