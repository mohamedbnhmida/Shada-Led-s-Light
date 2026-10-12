import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background.dart';
import 'bulb.dart';
import 'control_page.dart';
import 'models.dart';
import 'protocol.dart';
import 'scenes_page.dart';
import 'schedules_page.dart';
import 'settings.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Background.init();
  await settings.load();
  final p = await SharedPreferences.getInstance();
  final saved = p.getString('device');
  runApp(ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: 'Shada LED Light',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // The chosen lamp is remembered, so the scan screen only shows the first time or after "Switch lamp".
      home: BluetoothGate(
        child: saved == null
            ? const ScanPage()
            : HomePage(device: BluetoothDevice.fromId(saved), name: p.getString('device_name') ?? ''),
      ),
    ),
  ));
}

/// Shows a "Bluetooth is off" state with a turn-on button instead of [child] while the adapter is off.
class BluetoothGate extends StatelessWidget {
  final Widget child;
  const BluetoothGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) => StreamBuilder<BluetoothAdapterState>(
        stream: FlutterBluePlus.adapterState,
        initialData: FlutterBluePlus.adapterStateNow,
        builder: (context, snap) {
          final state = snap.data ?? BluetoothAdapterState.unknown;
          if (state == BluetoothAdapterState.on || state == BluetoothAdapterState.unknown) return child;
          return Scaffold(
            body: GlowBackground(
              color: const Color(0xFF4A90E2),
              child: SafeArea(
                child: StateView(
                  visual: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: context.pal.card),
                    child: Icon(Icons.bluetooth_disabled_rounded, size: 56, color: context.pal.muted),
                  ),
                  title: context.t('bt_off_title'),
                  hint: context.t('bt_off_hint'),
                  action: FilledButton.icon(
                    icon: const Icon(Icons.bluetooth_rounded),
                    label: Text(context.t('turn_on')),
                    onPressed: () => FlutterBluePlus.turnOn().catchError((_) {}), // Android shows the system prompt
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// Centered full-screen status: a visual, title, hint and one action.
class StateView extends StatelessWidget {
  final Widget visual;
  final String title, hint;
  final Widget? action;
  const StateView({super.key, required this.visual, required this.title, required this.hint, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            visual,
            const SizedBox(height: 32),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)),
            if (action != null) ...[const SizedBox(height: 28), action!],
          ]),
        ),
      );
}

/// Official Shada wordmark; white letters in dark mode so it stays readable on slate.
class ShadaLogo extends StatelessWidget {
  final double size;
  const ShadaLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => Image.asset(
        Theme.of(context).brightness == Brightness.dark ? 'assets/shada_wordmark_dark.png' : 'assets/shada_wordmark_light.png',
        height: size,
      );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _results = [];
  StreamSubscription? _sub;
  StreamSubscription? _scanning;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _sub = FlutterBluePlus.scanResults.listen((r) => setState(() => _results = r));
    _scanning = FlutterBluePlus.isScanning.listen((v) => setState(() => _isScanning = v));
    _scan();
  }

  // The bulb advertises one of these two service UUIDs (same check as the original app).
  void _scan() => FlutterBluePlus.startScan(withServices: [advUuid, serviceUuid], timeout: const Duration(seconds: 10))
      .catchError((_) {});

  @override
  void dispose() {
    _sub?.cancel();
    _scanning?.cancel();
    super.dispose();
  }

  Future<void> _pick(BluetoothDevice d) async {
    FlutterBluePlus.stopScan();
    final p = await SharedPreferences.getInstance();
    await p.setString('device', d.remoteId.str);
    await p.setString('device_name', d.platformName);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BluetoothGate(child: HomePage(device: d, name: d.platformName))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBackground(
          color: shadaYellow,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const ShadaLogo(size: 26),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => showSettings(context)),
                ]),
                const SizedBox(height: 40),
                const Text("LED's light", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300)),
                Text(context.t('smart_bulb'), style: TextStyle(fontSize: 18, color: context.pal.muted)),
                const SizedBox(height: 32),
                Row(children: [
                  Text(_isScanning ? context.t('looking') : context.t('found', {'n': _results.length}),
                      style: TextStyle(color: context.pal.muted)),
                  const Spacer(),
                  if (_isScanning)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    TextButton.icon(onPressed: _scan, icon: const Icon(Icons.refresh_rounded), label: Text(context.t('scan'))),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: _results.isEmpty && !_isScanning
                      ? Center(child: Text(context.t('no_bulb'), textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)))
                      : ListView(children: [
                          for (final r in _results)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                onTap: () => _pick(r.device),
                                child: Row(children: [
                                  const GlowBulb(color: shadaYellow, on: true, size: 44),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(r.device.platformName.isEmpty ? context.t('bulb_default') : r.device.platformName,
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(r.device.remoteId.str, style: TextStyle(color: context.pal.muted, fontSize: 12)),
                                    ]),
                                  ),
                                  Icon(Icons.signal_cellular_alt_rounded, color: r.rssi > -70 ? shadaYellow : context.pal.muted),
                                ]),
                              ),
                            ),
                        ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class HomePage extends StatefulWidget {
  final BluetoothDevice device;
  final String name;
  const HomePage({super.key, required this.device, required this.name});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final bulb = BulbController(widget.device)..addListener(_syncService);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    settings.addListener(_onSettings);
  }

  // Run the background service only while a scene plays or some schedule is enabled.
  void _syncService() => Background.sync(
        needed: bulb.playingId != null || bulb.schedules.any((s) => s.enabled),
        title: 'Shada LED Light',
        text: context.t('bg_text'),
        reminder: (context.t('bt_off_title'), context.t('bt_remind')),
      );

  // Re-translate the notification after the new language has been applied.
  void _onSettings() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncService();
      });

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    bulb.dispose();
    super.dispose();
  }

  Future<void> _forget() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('device');
    await p.remove('device_name');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BluetoothGate(child: ScanPage())));
  }

  String get _lampName => widget.name.isEmpty ? context.t('bulb_default') : widget.name;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: bulb,
        builder: (context, _) => Scaffold(
          extendBody: true, // content scrolls under the floating tab bar
          floatingActionButton: !bulb.connected
              ? null
              : switch (_tab) {
                  1 => FloatingActionButton(
                      child: const Icon(Icons.add_rounded),
                      onPressed: () {
                        bulb.scenes.add(Scene(name: context.t('my_scene'), steps: [SceneStep(bulb.state)]));
                        bulb.save();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SceneEditor(bulb: bulb, scene: bulb.scenes.last)));
                      },
                    ),
                  2 => FloatingActionButton(child: const Icon(Icons.add_alarm_rounded), onPressed: () => editSchedule(context, bulb)),
                  _ => null,
                },
          bottomNavigationBar: bulb.connected ? FloatingTabBar(index: _tab, onTap: (i) => setState(() => _tab = i)) : null,
          body: GlowBackground(
            color: bulb.connected && bulb.state.on ? bulb.state.preview : context.pal.bg,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                _TopBar(
                  glow: bulb.connected && bulb.state.on ? bulb.state.preview : shadaYellow,
                  children: [
                    const ShadaLogo(size: 20),
                    const Spacer(),
                    _StatusPill(connected: bulb.connected, onTap: () => _showLamp(context)),
                    const SizedBox(width: 4),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: context.pal.track),
                      icon: const Icon(Icons.settings_rounded, size: 20),
                      onPressed: () => showSettings(context),
                    ),
                  ],
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !bulb.connected
                        ? StateView(
                            visual: Stack(alignment: Alignment.center, children: [
                              const SizedBox(width: 150, height: 150, child: CircularProgressIndicator(strokeWidth: 3, color: shadaYellow)),
                              GlowBulb(color: shadaYellow, on: false, size: 110),
                            ]),
                            title: context.t('connecting_title'),
                            // Raw BLE errors stay out of the UI; after a failed attempt just say we keep retrying.
                            hint: '$_lampName\n${context.t(bulb.error == null ? 'connecting_hint' : 'retrying')}',
                            action: OutlinedButton.icon(
                                onPressed: _forget,
                                icon: const Icon(Icons.bluetooth_searching_rounded),
                                label: Text(context.t('switch_bulb'))),
                          )
                        : KeyedSubtree(
                            key: ValueKey(_tab),
                            child: [ControlPage(bulb: bulb), ScenesPage(bulb: bulb), SchedulesPage(bulb: bulb)][_tab],
                          ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  /// Lamp details: live glow, name, address, connection state, switch lamp.
  void _showLamp(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true, // size to content instead of the default 9/16 screen cap
        showDragHandle: true,
        backgroundColor: context.pal.card,
        builder: (context) => ListenableBuilder(
          listenable: bulb,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GlowBulb(
                color: bulb.state.preview,
                on: bulb.connected && bulb.state.on,
                size: 96,
                onTap: bulb.connected ? () => bulb.apply(bulb.state.copyWith(on: !bulb.state.on)) : null,
              ),
              const SizedBox(height: 20),
              Text(_lampName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text("Shada LED's light · 600750", style: TextStyle(color: context.pal.muted, fontSize: 13)),
              const SizedBox(height: 20),
              _infoRow(context, context.t('status'), _StatusPill(connected: bulb.connected)),
              _infoRow(context, context.t('address'),
                  Text(widget.device.remoteId.str, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: shadaYellow,
                    foregroundColor: shadaSlate,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _forget();
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(context.t('switch_bulb')),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _infoRow(BuildContext context, String label, Widget value) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: context.pal.track, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Text(label, style: TextStyle(color: context.pal.muted)),
          const SizedBox(width: 12),
          Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: FittedBox(fit: BoxFit.scaleDown, child: value))),
        ]),
      );
}

/// Floating rounded top bar; its shadow glows in the lamp's colour.
class _TopBar extends StatelessWidget {
  final Color glow;
  final List<Widget> children;
  const _TopBar({required this.glow, required this.children});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 6, 6),
        decoration: BoxDecoration(
          color: context.pal.nav,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: glow.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 28, spreadRadius: -4, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: children),
      );
}

/// Pill-shaped tab bar floating above the content.
class FloatingTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const FloatingTabBar({super.key, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.lightbulb_rounded, context.t('light')),
      (Icons.auto_awesome, context.t('scenes')),
      (Icons.schedule_rounded, context.t('schedules')),
    ];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.pal.nav,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          for (final (i, (icon, label)) in items.indexed)
            Expanded(
              flex: i == index ? 3 : 2,
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  height: 52,
                  decoration: BoxDecoration(
                    color: i == index ? shadaYellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, size: 22, color: i == index ? shadaSlate : context.pal.muted),
                    if (i == index) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: shadaSlate, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool connected;
  final VoidCallback? onTap;
  const _StatusPill({required this.connected, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: connected ? const Color(0xFF4ADE80) : shadaYellow),
            ),
            const SizedBox(width: 8),
            Text(context.t(connected ? 'connected' : 'connecting'), style: const TextStyle(fontSize: 12)),
            if (onTap != null) Icon(Icons.expand_more_rounded, size: 16, color: context.pal.muted),
          ]),
        ),
      );
}

void showSettings(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pal.card,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.t('settings'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Text(context.t('theme'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            PillSegments<ThemeMode>(
              expand: true,
              items: [
                (ThemeMode.system, context.t('system'), Icons.brightness_auto_rounded),
                (ThemeMode.light, context.t('light_theme'), Icons.light_mode_rounded),
                (ThemeMode.dark, context.t('dark'), Icons.dark_mode_rounded),
              ],
              value: settings.themeMode,
              onChanged: (v) => settings.set(theme: v),
            ),
            const SizedBox(height: 24),
            Text(context.t('language'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            PillSegments<String>(
              expand: true,
              dense: true,
              items: [
                ('system', context.t('system'), null),
                for (final l in supportedLocales) (l.languageCode, languageNames[l.languageCode]!, null),
              ],
              value: settings.locale?.languageCode ?? 'system',
              onChanged: (v) => v == 'system' ? settings.set(systemLang: true) : settings.set(lang: Locale(v)),
            ),
          ]),
        ),
      ),
    );
