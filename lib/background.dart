import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'protocol.dart';

/// Android foreground service that owns everything that must outlive the app screen: playing scenes and
/// running schedules. It runs in its own isolate, so both keep going with the app closed or the phone locked.
/// It runs while a scene is playing or at least one schedule is enabled.
///
/// The current "session" (a scene and/or light plus an optional end time) is stored in prefs under 'session',
/// so the service picks it up when it starts; the app pokes it with a 'session' message when it changes.
class Background {
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shada_schedules',
        channelName: 'Shada LED Light',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        allowWakeLock: true,
        autoRunOnBoot: true, // schedules survive a reboot
        autoRunOnMyPackageReplaced: true, // and an app update
      ),
    );
  }

  static bool? _running;
  static String? _shown; // notification text currently displayed

  /// Starts the service when [needed], stops it otherwise. Called on every app change, so it stays cheap.
  /// [reminder] is the translated (title, body) of the "Bluetooth is off" reminder the service may show.
  static Future<void> sync(
      {required bool needed, required String title, required String text, required (String, String) reminder}) async {
    if (needed == _running && (!needed || _shown == '$title|$text|$reminder')) return;
    _running = needed;
    final running = await FlutterForegroundTask.isRunningService;
    if (!needed) {
      if (running) await FlutterForegroundTask.stopService();
      return;
    }
    _shown = '$title|$text|$reminder';
    await (await SharedPreferences.getInstance()).setString('bt_reminder', jsonEncode([reminder.$1, reminder.$2]));
    if (running) {
      // It survived the app closing or started on boot; refresh the text (language may have changed).
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      return;
    }
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // Aggressive OEM battery savers (Infinix, Xiaomi…) kill services without this.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    await FlutterForegroundTask.startService(
      serviceId: 7,
      serviceTypes: [ForegroundServiceTypes.connectedDevice],
      notificationTitle: title,
      notificationText: text,
      callback: _startCallback,
    );
  }

  /// Stores the session ({'sceneId'?, 'light'?, 'until'?}) or clears it (null) and tells a running service.
  static Future<void> setSession(Map<String, dynamic>? session) async {
    final p = await SharedPreferences.getInstance();
    session == null ? await p.remove('session') : await p.setString('session', jsonEncode(session));
    FlutterForegroundTask.sendDataToTask('session'); // ignored if not running; it reads prefs on start
  }

  /// Frames from the service: {'state': LightState json, 'playing': sceneId?}.
  static void listen(void Function(Map<String, dynamic>) onData) =>
      FlutterForegroundTask.addTaskDataCallback(_cb = (d) {
        if (d is Map) onData(Map<String, dynamic>.from(d));
      });
  static void Function(Object)? _cb;
  static void unlisten() {
    if (_cb != null) FlutterForegroundTask.removeTaskDataCallback(_cb!);
  }
}

@pragma('vm:entry-point')
void _startCallback() => FlutterForegroundTask.setTaskHandler(ScheduleRunner());

/// Runs in the service isolate.
class ScheduleRunner extends TaskHandler {
  final _fired = <String>{};
  _LampLink? _link;
  LightState _state = const LightState();
  String? _playing;
  int _run = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[ShadaBG] start ${starter.name}');
    await _notes.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _loadSession();
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'session') _loadSession();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _tick().catchError((e) => debugPrint('[ShadaBG] tick error $e'));

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async => _link?.close();

  Future<SharedPreferences> _prefs() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // pick up what the app just saved
    return p;
  }

  List<Scene> _scenes(SharedPreferences p) => [for (final j in jsonDecode(p.getString('scenes') ?? '[]')) Scene.fromJson(j)];

  void _set(LightState st) {
    _state = st;
    _link?.send(st);
    FlutterForegroundTask.sendDataToMain({'state': st.toJson(), 'playing': _playing}); // keeps the app screen in sync
  }

  /// (Re)starts whatever the stored session describes, or stops playback when there is none.
  Future<void> _loadSession() async {
    final p = await _prefs();
    final deviceId = p.getString('device');
    final raw = p.getString('session');
    if (deviceId == null || raw == null) {
      _run++;
      _playing = null;
      return;
    }
    _link ??= _LampLink(BluetoothDevice.fromId(deviceId));
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final scene = _scenes(p).where((s) => s.id == j['sceneId']).firstOrNull;
    final until = j['until'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['until']);
    if (until != null && !until.isAfter(DateTime.now())) return _end(p, off: true);

    final run = ++_run;
    bool alive() => run == _run;
    _playing = scene?.id;
    if (j['light'] != null) _set(LightState.fromJson(j['light']));
    if (until != null) {
      Timer(until.difference(DateTime.now()), () async {
        if (alive()) _end(await _prefs(), off: true);
      });
    }
    if (scene != null) {
      await playScene(scene, _state, _set, alive);
      // A one-shot scene without an end time is done; with one, its last frame holds until then.
      if (alive() && until == null) _end(p, off: false);
    }
  }

  /// Stops playback, optionally switches the lamp off, clears the stored session.
  Future<void> _end(SharedPreferences p, {required bool off}) async {
    _run++;
    _playing = null;
    off ? _set(_state.copyWith(on: false)) : FlutterForegroundTask.sendDataToMain({'state': _state.toJson(), 'playing': null});
    await p.remove('session');
  }

  // ── Bluetooth reminder: gentle, at most once per 12 h, only after 30 min off, cleared when it comes back. ──
  final _notes = FlutterLocalNotificationsPlugin();
  DateTime? _btOffSince;
  static const _reminderId = 42;

  Future<void> _checkBluetooth(SharedPreferences p) async {
    final on = await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
    final now = DateTime.now();
    if (on) {
      if (_btOffSince != null) await _notes.cancel(id: _reminderId);
      _btOffSince = null;
      return;
    }
    _btOffSince ??= now;
    if (now.difference(_btOffSince!) < const Duration(minutes: 30)) return;
    final last = DateTime.fromMillisecondsSinceEpoch(p.getInt('bt_reminded_at') ?? 0);
    if (now.difference(last) < const Duration(hours: 12)) return;
    final text = jsonDecode(p.getString('bt_reminder') ?? '["Bluetooth is off","Turn it on so your lamp schedules can run."]');
    await p.setInt('bt_reminded_at', now.millisecondsSinceEpoch);
    await _notes.show(
      id: _reminderId,
      title: text[0],
      body: text[1],
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('shada_bluetooth', 'Bluetooth reminder',
            importance: Importance.defaultImportance, priority: Priority.defaultPriority, autoCancel: true),
      ),
    );
  }

  Future<void> _tick() async {
    final p = await _prefs();
    await _checkBluetooth(p);
    final sh = p.getString('schedules');
    final deviceId = p.getString('device');
    if (sh == null || deviceId == null) return;
    final now = DateTime.now();
    for (final s in dueSchedules([for (final j in jsonDecode(sh)) Schedule.fromJson(j)], now, _fired)) {
      final until = now.add(Duration(minutes: s.minutes)).millisecondsSinceEpoch;
      switch (s.action) {
        case ScheduleAction.off:
          _link ??= _LampLink(BluetoothDevice.fromId(deviceId));
          await _end(p, off: true);
        case ScheduleAction.on:
          await p.setString('session', jsonEncode({'light': s.light.copyWith(on: true).toJson(), 'until': until}));
          await _loadSession();
        case ScheduleAction.scene:
          await p.setString('session', jsonEncode({'sceneId': s.sceneId, 'until': until}));
          unawaited(_loadSession()); // scenes can run for hours
      }
    }
  }
}

/// Minimal lamp connection for the service: connects on demand (retrying ~1 min), unlocks, writes the latest state.
class _LampLink {
  final BluetoothDevice device;
  _LampLink(this.device);

  BluetoothCharacteristic? _char;
  bool _writing = false;
  LightState? _pending;

  Future<BluetoothCharacteristic?> _ensure() async {
    if (_char != null && device.isConnected) return _char;
    _char = null;
    for (var attempt = 0; attempt < 6 && _char == null; attempt++) {
      try {
        if (!device.isConnected) {
          await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 10), mtu: null);
        }
        _char = await unlockLamp(device);
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return _char;
  }

  // Coalesces frames: only the newest state is written once the previous write finishes.
  Future<void> send(LightState s) async {
    _pending = s;
    if (_writing) return;
    _writing = true;
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      final c = await _ensure();
      if (c == null) break;
      try {
        await writeTo(c, next.packet);
      } catch (_) {
        _char = null;
      }
    }
    _writing = false;
  }

  Future<void> close() => device.disconnect();
}
