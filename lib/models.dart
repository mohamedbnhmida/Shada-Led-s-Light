import 'protocol.dart';

class SceneStep {
  LightState state;
  double seconds;
  bool fade; // fade from the previous step over [seconds], otherwise jump and hold
  SceneStep(this.state, {this.seconds = 2, this.fade = false});

  Map<String, dynamic> toJson() => {'state': state.toJson(), 'seconds': seconds, 'fade': fade};
  factory SceneStep.fromJson(Map<String, dynamic> j) =>
      SceneStep(LightState.fromJson(j['state']), seconds: (j['seconds'] as num).toDouble(), fade: j['fade'] as bool);
}

class Scene {
  final String id;
  String name;
  bool loop;
  List<SceneStep> steps;
  Scene({String? id, required this.name, this.loop = false, required this.steps})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'loop': loop, 'steps': [for (final s in steps) s.toJson()]};
  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
      id: j['id'],
      name: j['name'],
      loop: j['loop'],
      steps: [for (final s in j['steps']) SceneStep.fromJson(s)]);
}

enum ScheduleAction { on, off, scene }

const scheduleDurations = [15, 30, 60, 120, 180, 240, 360, 480, 720]; // minutes

class Schedule {
  final String id;
  int hour, minute;
  Set<int> days; // DateTime.monday (1) .. DateTime.sunday (7)
  ScheduleAction action;
  LightState light; // for [ScheduleAction.on]
  String? sceneId; // for [ScheduleAction.scene]
  int minutes; // on/scene: how long it runs before the lamp switches off
  bool enabled;
  Schedule(
      {String? id,
      required this.hour,
      required this.minute,
      Set<int>? days,
      this.action = ScheduleAction.on,
      this.light = const LightState(white: true),
      this.sceneId,
      this.minutes = 120,
      this.enabled = true})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        days = days ?? {1, 2, 3, 4, 5, 6, 7};

  bool isDue(DateTime t) => enabled && t.hour == hour && t.minute == minute && days.contains(t.weekday);

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days.toList(),
        'action': action.name,
        'light': light.toJson(),
        'sceneId': sceneId,
        'minutes': minutes,
        'enabled': enabled,
      };
  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
      id: j['id'],
      hour: j['hour'],
      minute: j['minute'],
      days: {for (final d in j['days']) d as int},
      // v1 schedules had no action: a scene id meant "play", none meant "off".
      action: j['action'] != null
          ? ScheduleAction.values.byName(j['action'])
          : j['sceneId'] == null
              ? ScheduleAction.off
              : ScheduleAction.scene,
      light: j['light'] == null ? const LightState(white: true) : LightState.fromJson(j['light']),
      sceneId: j['sceneId'],
      minutes: j['minutes'] ?? 120,
      enabled: j['enabled']);
}

/// Built-in scenes use `preset_*` ids and names; the name is a translation key until the user renames it.
const presetsVersion = 2;
const oldPresetNames = {'Relax', 'Reading', 'Night light', 'Rainbow', 'Party', 'Sunrise', 'Candle'};

LightState _c(double hue, [double b = 1]) => LightState(hue: hue, brightness: b);
LightState _w(double b) => LightState(white: true, brightness: b); // warm white, the bulb's brightest light
Scene _p(String id, List<SceneStep> steps, {bool loop = false}) => Scene(id: id, name: id, loop: loop, steps: steps);

List<Scene> presetScenes() => [
      _p('preset_sunrise', [
        SceneStep(_c(0, 0.05), seconds: 1),
        SceneStep(_c(18, 0.4), seconds: 600, fade: true),
        SceneStep(_c(38, 1), seconds: 600, fade: true),
        SceneStep(_w(1), seconds: 1),
      ]),
      _p('preset_sunset', [
        SceneStep(_w(0.8), seconds: 1),
        SceneStep(_w(0.25), seconds: 600, fade: true),
        SceneStep(_c(22, 0.35), seconds: 1),
        SceneStep(_c(8, 0.12), seconds: 300, fade: true),
        SceneStep(_c(0, 0.05), seconds: 300, fade: true),
        SceneStep(const LightState(on: false), seconds: 1),
      ]),
      _p('preset_relax', [SceneStep(_w(0.4))]),
      _p('preset_reading', [SceneStep(_w(1))]),
      _p('preset_night', [SceneStep(_w(0.06))]),
      _p('preset_candle', loop: true, [
        SceneStep(_w(0.55), seconds: 0.5, fade: true),
        SceneStep(_w(0.8), seconds: 0.3, fade: true),
        SceneStep(_w(0.4), seconds: 0.6, fade: true),
        SceneStep(_w(0.7), seconds: 0.4, fade: true),
        SceneStep(_w(0.5), seconds: 0.8, fade: true),
      ]),
      _p('preset_ocean', loop: true, [
        for (final (h, b) in [(195.0, 1.0), (220.0, 0.7), (180.0, 0.9), (240.0, 0.6)]) SceneStep(_c(h, b), seconds: 4, fade: true),
      ]),
      _p('preset_rainbow', loop: true, [
        for (final h in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0, 359.0]) SceneStep(_c(h), seconds: 3, fade: true),
      ]),
      _p('preset_party', loop: true, [
        for (final h in [0.0, 280.0, 200.0, 120.0, 320.0, 50.0]) SceneStep(_c(h), seconds: 0.5),
      ]),
    ];

/// Plays [scene] starting from [from], calling [set] for every frame (fades tick at 10 Hz).
/// Stops as soon as [alive] returns false. Shared by the app and the background service.
Future<void> playScene(Scene scene, LightState from, void Function(LightState) set, bool Function() alive) async {
  var prev = from;
  do {
    for (final step in scene.steps) {
      if (!alive()) return;
      final ms = (step.seconds * 1000).round();
      if (step.fade) {
        const tick = 100;
        for (var t = tick; t < ms; t += tick) {
          await Future.delayed(const Duration(milliseconds: tick));
          if (!alive()) return;
          set(LightState.lerp(prev, step.state, t / ms));
        }
        set(step.state);
      } else {
        set(step.state);
        await Future.delayed(Duration(milliseconds: ms));
      }
      prev = step.state;
    }
  } while (scene.loop && alive() && scene.steps.isNotEmpty);
}

/// Schedules due at [now] that haven't fired yet this minute; [fired] remembers what already ran.
List<Schedule> dueSchedules(List<Schedule> schedules, DateTime now, Set<String> fired) {
  final minute = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
  return [for (final s in schedules) if (s.isDue(now) && fired.add('${s.id}@$minute')) s];
}
