import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background.dart';
import 'models.dart';
import 'protocol.dart';

/// Owns the bulb connection, the current light, scene playback and the schedule clock.
class BulbController extends ChangeNotifier {
  final BluetoothDevice device;
  BulbController(this.device) {
    _init();
  }

  BluetoothCharacteristic? _char;
  StreamSubscription? _conn;
  bool get connected => _char != null;

  LightState state = const LightState();
  List<Scene> scenes = [];
  List<Schedule> schedules = [];
  String? playingId;

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final sc = p.getString('scenes'), sh = p.getString('schedules');
    scenes = sc == null ? presetScenes() : [for (final j in jsonDecode(sc)) Scene.fromJson(j)];
    schedules = sh == null ? [] : [for (final j in jsonDecode(sh)) Schedule.fromJson(j)];
    if ((p.getInt('presets') ?? 1) < presetsVersion) {
      // Replace built-in scenes from older versions, keep the user's own.
      scenes.removeWhere((s) => s.id.startsWith('preset_') || oldPresetNames.contains(s.name));
      scenes.insertAll(0, presetScenes());
      await p.setInt('presets', presetsVersion);
      save();
    }
    final session = p.getString('session'); // a scene the service is still playing from before
    if (session != null) playingId = (jsonDecode(session) as Map)['sceneId'];
    notifyListeners();
    Background.listen(_onService);

    _conn = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.connected) {
        _setup();
      } else {
        _char = null;
        notifyListeners();
      }
    });
    _connectLoop();
  }

  bool _disposed = false;
  String? error;

  // Direct connect with retry: Android's autoConnect background mode can take minutes to find the bulb.
  Future<void> _connectLoop() async {
    while (!_disposed) {
      if (!device.isConnected) {
        try {
          await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 10), mtu: null);
        } catch (e) {
          error = 'Connect: $e';
          notifyListeners();
        }
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _setup() async {
    try {
      _char = await unlockLamp(device);
      error = null;
      notifyListeners();
      _write();
    } catch (e) {
      error = 'Setup: $e';
      notifyListeners();
      await device.disconnect(); // _connectLoop retries
    }
  }

  bool _writing = false, _pending = false;

  // Coalesces rapid updates (slider drags, fades): at most one write in flight, always ending on the latest state.
  Future<void> _write() async {
    final c = _char;
    if (c == null) return;
    if (_writing) {
      _pending = true;
      return;
    }
    _writing = true;
    do {
      _pending = false;
      try {
        await writeTo(c, state.packet);
      } catch (e) {
        error = 'Write: $e';
        notifyListeners();
      }
    } while (_pending);
    _writing = false;
  }

  void _set(LightState s) {
    state = s;
    notifyListeners();
    _write();
  }

  /// Manual change from the UI: stops any running scene.
  void apply(LightState s) {
    if (playingId != null) stop();
    _set(s);
  }

  // Scenes are played by the background service so they keep going after the app is closed.
  void stop() {
    playingId = null;
    Background.setSession(null);
    notifyListeners();
  }

  Future<void> play(Scene scene) async {
    await Background.setSession({'sceneId': scene.id});
    playingId = scene.id;
    notifyListeners(); // HomePage starts the service if needed; it then reads the session
  }

  // Frames from the service (scene playback, schedules) keep the screen in sync without writing to the lamp.
  void _onService(Map<String, dynamic> d) {
    state = LightState.fromJson(Map<String, dynamic>.from(d['state']));
    playingId = d['playing'];
    notifyListeners();
  }

  Scene? sceneById(String? id) => scenes.where((s) => s.id == id).firstOrNull;

  Future<void> save() async {
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('scenes', jsonEncode(scenes));
    await p.setString('schedules', jsonEncode(schedules));
  }

  @override
  void dispose() {
    _disposed = true;
    Background.unlisten();
    _conn?.cancel();
    device.disconnect();
    super.dispose();
  }
}
