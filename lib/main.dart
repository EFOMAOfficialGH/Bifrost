import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'features/send/network_test_page.dart';
import 'features/discovery/nearby_page.dart';
import 'features/receive/incoming_offer_listener.dart';
import 'core/networking/device_runtime.dart';
import 'core/networking/bifrost_client.dart';
import 'core/notifications/transfer_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/app_storage.dart';
import 'core/platform/shared_file_bridge.dart';

final appThemeProvider = StateProvider<AppThemeKind>((ref) => AppThemeKind.day);
final deviceNameProvider = StateProvider<String>((ref) => 'Bifrost Device');

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) SharedFileBridge.instance.seed(args);
  runApp(const ProviderScope(child: BifrostApp()));
}

class BifrostApp extends ConsumerStatefulWidget {
  const BifrostApp({this.enableDiscovery = true, super.key});
  final bool enableDiscovery;

  @override ConsumerState<BifrostApp> createState() => _BifrostAppState();
}

class _BifrostAppState extends ConsumerState<BifrostApp> {
  @override void initState() { super.initState(); AppStorage.instance.themeChoice().then((saved) { final kind = AppThemeKind.values.where((item) => item.name == saved).firstOrNull; if (mounted && kind != null) ref.read(appThemeProvider.notifier).state = kind; }); }

  @override
  Widget build(BuildContext context) {
    final enableDiscovery = widget.enableDiscovery;
    final kind = ref.watch(appThemeProvider);
    return MaterialApp(
      title: 'Bifrost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forKind(kind),
      themeMode: ThemeMode.light,
      builder: (context, child) => ThemeBackdrop(kind: kind, child: child ?? const SizedBox.shrink()),
      home: BifrostSplash(child: IncomingOfferListener(child: BifrostGate(enableDiscovery: enableDiscovery))),
    );
  }
}

class BifrostSplash extends StatefulWidget {
  const BifrostSplash({required this.child, super.key});
  final Widget child;
  @override State<BifrostSplash> createState() => _BifrostSplashState();
}

class _BifrostSplashState extends State<BifrostSplash> {
  bool _showApp = false;
  @override void initState() { super.initState(); Future<void>.delayed(const Duration(milliseconds: 1200), () { if (mounted) setState(() => _showApp = true); }); }
  @override Widget build(BuildContext context) => AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _showApp ? widget.child : const _SplashArtwork(key: ValueKey('splash')));
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({super.key});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Bifrost', style: TextStyle(fontFamily: 'MisticalSpring', fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Colors.white, shadows: [Shadow(color: Colors.white.withAlpha(180), blurRadius: 24), const Shadow(color: Color(0xAA8A7CFF), blurRadius: 42)])), const SizedBox(height: 8), const Text("You're bridge between worlds", style: TextStyle(fontFamily: 'Helvetica', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: .3))])));
}

class BifrostGate extends StatefulWidget {
  const BifrostGate({required this.enableDiscovery, super.key});
  final bool enableDiscovery;
  @override State<BifrostGate> createState() => _BifrostGateState();
}

class _BifrostGateState extends State<BifrostGate> {
  bool? _complete;
  @override void initState() { super.initState(); AppStorage.instance.onboardingComplete().then((value) { if (mounted) setState(() => _complete = value); }); }
  @override Widget build(BuildContext context) {
    if (_complete == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _complete! ? BifrostShell(enableDiscovery: widget.enableDiscovery) : FirstRunPage(onComplete: () => setState(() => _complete = true));
  }
}

class FirstRunPage extends StatefulWidget {
  const FirstRunPage({required this.onComplete, super.key});
  final VoidCallback onComplete;
  @override State<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends State<FirstRunPage> {
  late final TextEditingController _name;
  late String _path;
  bool _saving = false;
  @override void initState() { super.initState(); _name = TextEditingController(text: 'Bifrost Device'); _path = AppStorage.instance.defaultSaveDirectory(); AppStorage.instance.deviceName().then((value) { if (mounted && value != 'Bifrost Device') setState(() => _name.text = value); }); }
  @override void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _chooseLocation() async { final selected = await FilePicker.getDirectoryPath(dialogTitle: 'Choose Bifrost save location', initialDirectory: _path); if (selected != null && mounted) setState(() => _path = selected); }
  Future<void> _finish() async { final name = _name.text.trim(); if (name.isEmpty) return; setState(() => _saving = true); try { await Directory(_path).create(recursive: true); await AppStorage.instance.setDeviceName(name); await AppStorage.instance.setSaveDirectoryPath(_path); await AppStorage.instance.setOnboardingComplete(); widget.onComplete(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bifrost could not access that folder. Choose another location.'))); } if (mounted) setState(() => _saving = false); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(28), children: [const SizedBox(height: 48), const BifrostMark(size: 64), const SizedBox(height: 24), Text('Welcome to Bifrost', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), const Text('Set up your device once. You can change these choices later in Settings.'), const SizedBox(height: 32), TextField(controller: _name, decoration: const InputDecoration(labelText: 'Choose device name', prefixIcon: Icon(Icons.badge_outlined))), const SizedBox(height: 20), Card(child: ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Save received files to'), subtitle: Text(_path), trailing: const Icon(Icons.chevron_right), onTap: _chooseLocation)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _saving ? null : _chooseLocation, icon: const Icon(Icons.folder_open), label: const Text('Give access / Change save location')), const SizedBox(height: 28), FilledButton(onPressed: _saving ? null : _finish, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_saving ? 'Setting up…' : 'Continue')))])));
}

class BifrostShell extends StatefulWidget {
  const BifrostShell({this.enableDiscovery = true, super.key});
  final bool enableDiscovery;

  @override
  State<BifrostShell> createState() => _BifrostShellState();
}

class _BifrostShellState extends State<BifrostShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    AppStorage.instance.backgroundActivity().then((enabled) {
      if (enabled) BifrostDeviceRuntime.instance.ensureStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pages = <Widget>[
      NearbyPage(autoDiscover: widget.enableDiscovery),
      const HistoryPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _selectedIndex, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Nearby'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
        backgroundColor: colors.surface,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const BifrostMark(size: 42),
                const SizedBox(width: 12),
                Text('Bifrost', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(tooltip: 'Help', onPressed: () => _showComingSoon(context, 'Troubleshooting'), icon: const Icon(Icons.help_outline)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nearby devices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Devices on your local Wi-Fi will appear here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 28),
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(colors: [colors.primary.withValues(alpha: .18), colors.tertiary.withValues(alpha: .12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.primary.withValues(alpha: .18), width: 1))),
                      Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.primary.withValues(alpha: .28), width: 1))),
                      Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.wifi_tethering, size: 36, color: colors.primary), const SizedBox(height: 10), Text('Looking nearby…', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text('Discovery arrives in Milestone 3', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))]),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: colors.primaryContainer, child: Icon(Icons.phone_android, color: colors.onPrimaryContainer)),
                    title: const Text('This device'),
                    subtitle: const Text('Ready to receive • Bifrost Phone'),
                    trailing: Icon(Icons.check_circle, color: colors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _showComingSoon(context, 'File picker'), icon: const Icon(Icons.upload_file), label: const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('Send files')))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TransferRecord> _records = const [];
  final _active = <String, TransferRecord>{};
  StreamSubscription<TransferRecord>? _activitySubscription;
  @override void initState() { super.initState(); _load(); _activitySubscription = AppStorage.instance.activities.listen((record) { if (!mounted) return; setState(() { if (record.status == 'In progress') { _active[record.id] = record; } else { _active.remove(record.id); _records = [record, ..._records.where((item) => item.id != record.id)]; } }); }); }
  Future<void> _load() async { final records = await AppStorage.instance.history(); if (mounted) setState(() => _records = records); }
  @override void dispose() { _activitySubscription?.cancel(); super.dispose(); }
  Future<void> _clear() async { await AppStorage.instance.clearHistory(); if (mounted) setState(() => _records = const []); }

  Future<void> _showDetails(TransferRecord record) async => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(record.fileName), content: Text('Status: ${record.status}\nDirection: ${record.direction}\nDevice: ${record.peer}\nSize: ${_historyBytes(record.bytes)}\nTime: ${record.time.toLocal()}${record.speedBytesPerSecond > 0 ? '\nSpeed: ${_formatSpeed(record.speedBytesPerSecond)}/s' : ''}${record.path == null ? '' : '\nPath: ${record.path}'}'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))]));

  Future<void> _retryRecord(TransferRecord record) async {
    if (record.path == null || record.peerHost == null || record.peerPort == null) return;
    final file = File(record.path!);
    if (!file.existsSync()) return;
    final cancellation = TransferCancellation();
    final client = BifrostClient();
    final notificationId = record.id.hashCode;
    final size = await file.length();
    AppStorage.instance.begin(TransferRecord(id: record.id, fileName: record.fileName, bytes: size, direction: 'Sent', status: 'In progress', peer: record.peer, time: DateTime.now(), progress: 0, path: record.path, peerHost: record.peerHost, peerPort: record.peerPort));
    AppStorage.instance.registerCancellation(record.id, () async => cancellation.cancel());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retrying ${record.fileName}…')));
    try {
      await client.sendFile(server: Uri.parse('http://${record.peerHost}:${record.peerPort}'), file: file, transferId: 'transfer-${DateTime.now().microsecondsSinceEpoch}', fileId: 'file-${DateTime.now().microsecondsSinceEpoch}', senderDeviceId: BifrostDeviceRuntime.instance.deviceId, senderDeviceName: BifrostDeviceRuntime.instance.deviceName, cancellation: cancellation, onProgress: (sent, total) { AppStorage.instance.update(record.id, sent, total); final current = AppStorage.instance.activeTransfers.where((item) => item.id == record.id).firstOrNull; TransferNotifications.instance.progress(id: notificationId, title: 'Retrying ${record.fileName}', sent: sent, total: total, speedBytesPerSecond: current?.speedBytesPerSecond ?? 0, etaSeconds: current?.etaSeconds); });
      await AppStorage.instance.finish(TransferRecord(id: record.id, fileName: record.fileName, bytes: size, direction: 'Sent', status: 'Completed', peer: record.peer, time: DateTime.now(), path: record.path, peerHost: record.peerHost, peerPort: record.peerPort));
      await TransferNotifications.instance.cancel(notificationId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retry completed successfully.')));
    } catch (error) {
      final cancelled = error is TransferCancelledException || cancellation.isCancelled;
      await AppStorage.instance.finish(TransferRecord(id: record.id, fileName: record.fileName, bytes: size, direction: 'Sent', status: cancelled ? 'Cancelled' : 'Failed', peer: record.peer, time: DateTime.now(), path: record.path, peerHost: record.peerHost, peerPort: record.peerPort));
      await TransferNotifications.instance.cancel(notificationId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cancelled ? 'Retry cancelled.' : 'Retry failed: ${error.toString()}')));
    } finally {
      cancellation.dispose();
      client.close();
      await _load();
    }
  }

  Future<void> _showRecordActions(TransferRecord record) async {
    final path = record.path;
    final exists = path != null && File(path).existsSync();
    final isApk = path != null && path.toLowerCase().endsWith('.apk');
    final action = await showModalBottomSheet<String>(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('Transfer details'), onTap: () => Navigator.pop(sheetContext, 'details')),
      if (exists) ListTile(leading: Icon(isApk ? Icons.install_mobile : Icons.open_in_new), title: Text(isApk ? 'Install APK' : 'Open'), onTap: () => Navigator.pop(sheetContext, 'open')),
      if (exists && Platform.isWindows) ListTile(leading: const Icon(Icons.folder_open), title: const Text('Open File Location'), onTap: () => Navigator.pop(sheetContext, 'location')),
      if (exists && record.status == 'Failed' && record.direction == 'Sent' && record.peerHost != null) ListTile(leading: const Icon(Icons.refresh), title: const Text('Retry transfer'), onTap: () => Navigator.pop(sheetContext, 'retry')),
      if (!exists) const ListTile(leading: Icon(Icons.warning_amber), title: Text('File is no longer available'), subtitle: Text('The saved file may have been moved or deleted.')),
      ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete from History'), onTap: () => Navigator.pop(sheetContext, 'delete')),
    ])));
    if (!mounted || action == null) return;
    if (action == 'details') {
      await _showDetails(record);
    } else if (action == 'retry') {
      await _retryRecord(record);
    } else if (action == 'open') {
      final result = await OpenFilex.open(path!, type: isApk ? 'application/vnd.android.package-archive' : null);
      if (mounted && result.type != ResultType.done) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } else if (action == 'location' && Platform.isWindows) {
      final windowsPath = record.path!.replaceAll('/', '\\');
      final parent = File(windowsPath).parent.path;
      await Process.run('explorer.exe', ['/select,$windowsPath']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opened file location: $parent')));
    } else if (action == 'delete') {
      await AppStorage.instance.deleteHistory(record.id);
      if (mounted) setState(() => _records = _records.where((item) => item.id != record.id).toList(growable: false));
    }
  }
  @override
  Widget build(BuildContext context) => _records.isEmpty && _active.isEmpty
      ? const EmptyPage(icon: Icons.history, title: 'Transfer history', message: 'Completed transfers will appear here.')
      : ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [Expanded(child: Text('Transfer history', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))), if (_records.isNotEmpty) IconButton(tooltip: 'Clear history', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))]),
          const SizedBox(height: 20),
          for (final record in _active.values) _historyTile(context, record),
          for (final record in _records) Card(child: ListTile(onTap: () => _showRecordActions(record), leading: Icon(record.status == 'Completed' ? Icons.check_circle : Icons.error_outline, color: record.status == 'Completed' ? Colors.green : Theme.of(context).colorScheme.error), title: Text(record.fileName), subtitle: Text('${record.direction} • ${record.status} • ${_historyBytes(record.bytes)}\n${record.peer} • ${record.time.toLocal()}'), trailing: record.path == null ? null : const Icon(Icons.more_vert))),
        ]);

  Widget _historyTile(BuildContext context, TransferRecord record) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.sync, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(record.fileName, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${(record.progress * 100).round()}%'),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: record.progress),
            const SizedBox(height: 6),
            Text('${record.direction} • ${record.peer}'),
            if (record.speedBytesPerSecond > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_formatSpeed(record.speedBytesPerSecond)}/s${record.etaSeconds == null ? '' : ' • ${_formatEta(record.etaSeconds!)} left'}', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () async {
              await AppStorage.instance.cancelTransfer(record.id);
            }, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel'))),
          ]),
        ),
      );
}

class TrustedDevicesPage extends StatefulWidget {
  const TrustedDevicesPage({super.key});
  @override State<TrustedDevicesPage> createState() => _TrustedDevicesPageState();
}

class _TrustedDevicesPageState extends State<TrustedDevicesPage> {
  List<TrustedDevice> _devices = const [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final devices = await AppStorage.instance.trustedDevices(); if (mounted) setState(() => _devices = devices); }
  Future<void> _remove(TrustedDevice device) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Remove trusted device?'), content: Text('${device.name} will need approval next time it sends a file.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove'))])) ?? false;
    if (!confirmed) return;
    await AppStorage.instance.setTrusted(device.id, false);
    if (mounted) setState(() => _devices = _devices.where((item) => item.id != device.id).toList(growable: false));
  }
  Future<void> _removeAll() async { for (final device in _devices) { await AppStorage.instance.setTrusted(device.id, false); } if (mounted) setState(() => _devices = const []); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trusted devices'), actions: [if (_devices.isNotEmpty) IconButton(tooltip: 'Remove all', onPressed: _removeAll, icon: const Icon(Icons.delete_sweep_outlined))]), body: _devices.isEmpty ? const EmptyPage(icon: Icons.verified_user_outlined, title: 'No trusted devices', message: 'Trust a device when accepting its first transfer and it will appear here.') : ListView(padding: const EdgeInsets.all(16), children: [for (final device in _devices) Card(child: ListTile(leading: const Icon(Icons.verified_user), title: Text(device.name), subtitle: Text('Last seen ${_relative(device.lastSeen)}\n${device.id}'), isThreeLine: true, trailing: IconButton(tooltip: 'Remove trusted device', icon: const Icon(Icons.delete_outline), onPressed: () => _remove(device))))]));
}

String _relative(DateTime time) { final difference = DateTime.now().difference(time); if (difference.inMinutes < 1) return 'just now'; if (difference.inHours < 1) return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago'; if (difference.inDays < 1) return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago'; return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago'; }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  String? _savePath;
  bool _backgroundActivity = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(deviceNameProvider));
    AppStorage.instance.deviceName().then((name) { if (!mounted) return; _nameController.text = name; ref.read(deviceNameProvider.notifier).state = name; });
    AppStorage.instance.saveDirectoryPath().then((path) { if (mounted) setState(() => _savePath = path); });
    AppStorage.instance.backgroundActivity().then((enabled) { if (mounted) setState(() => _backgroundActivity = enabled); });
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ref.read(deviceNameProvider.notifier).state = name;
    BifrostDeviceRuntime.instance.updateDeviceName(name);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device name updated.')));
  }

  Future<void> _chooseSaveLocation() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Choose Bifrost save location');
    if (path == null) return;
    await BifrostDeviceRuntime.instance.updateSaveDirectory(Directory(path));
    if (mounted) setState(() => _savePath = path);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save location updated.')));
  }

  Future<void> _toggleBackground(bool enabled) async {
    setState(() => _backgroundActivity = enabled);
    await BifrostDeviceRuntime.instance.setBackgroundActivity(enabled);
  }


  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      TextField(controller: _nameController, textInputAction: TextInputAction.done, onSubmitted: (_) => _saveName(), decoration: InputDecoration(labelText: 'Device name', prefixIcon: const Icon(Icons.badge_outlined), suffixIcon: IconButton(tooltip: 'Save device name', onPressed: _saveName, icon: const Icon(Icons.check)))),
      ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Save location'), subtitle: Text(_savePath ?? AppStorage.instance.defaultSaveDirectory()), trailing: const Icon(Icons.chevron_right), onTap: _chooseSaveLocation),
      ListTile(leading: const Icon(Icons.lan_outlined), title: const Text('Networking test'), subtitle: const Text('Milestone 2 local receiver'), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NetworkTestPage()))),
      SwitchListTile(value: _backgroundActivity, onChanged: _toggleBackground, title: const Text('Background receiving'), subtitle: const Text('Keep Bifrost listening while the app is in the background.'), secondary: const Icon(Icons.notifications_active_outlined)),
      const SizedBox(height: 12),
      ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Trusted devices'), subtitle: const Text('Manage devices that can send without approval.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrustedDevicesPage()))),
      ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Theme'), subtitle: Text(ref.watch(appThemeProvider).label), trailing: const Icon(Icons.chevron_right), onTap: _chooseTheme),
      const Divider(height: 32),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('About Bifrost'), subtitle: Text('Milestone 1 • Local-only file sharing')),
    ]);
  }

  Future<void> _chooseTheme() async {
    final selected = await showDialog<AppThemeKind>(context: context, builder: (dialogContext) => SimpleDialog(title: const Text('Choose a theme'), children: [for (final kind in AppThemeKind.values) SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, kind), child: ListTile(leading: Icon(kind == AppThemeKind.day ? Icons.wb_sunny_outlined : kind == AppThemeKind.sunset ? Icons.wb_twilight : Icons.nightlight_outlined), title: Text(kind.label), subtitle: Text(kind.description)))]));
    if (selected == null) return;
    ref.read(appThemeProvider.notifier).state = selected;
    await AppStorage.instance.setThemeChoice(selected.name);
  }
}

String _historyBytes(int bytes) => bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatSpeed(double bytesPerSecond) => bytesPerSecond < 1024 * 1024 ? '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB' : '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatEta(int seconds) => seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';

class EmptyPage extends StatelessWidget {
  const EmptyPage({required this.icon, required this.title, required this.message, super.key});
  final IconData icon; final String title; final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 20), Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)])));
}

class BifrostMark extends StatelessWidget {
  const BifrostMark({this.size = 48, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(borderRadius: BorderRadius.circular(size * .28), gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00C9A7)], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Icon(Icons.architecture, color: Colors.white, size: size * .58));
}

void _showComingSoon(BuildContext context, String feature) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is planned for a later milestone.')));
