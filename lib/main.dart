import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'features/discovery/nearby_page.dart';
import 'features/receive/incoming_offer_listener.dart';
import 'core/networking/device_runtime.dart';
import 'core/networking/bifrost_client.dart';
import 'core/notifications/transfer_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/app_storage.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/localized_text.dart';
import 'core/platform/shared_file_bridge.dart';
import 'core/updates/update_service.dart';

final appThemeProvider = StateProvider<AppThemeKind>((ref) => AppThemeKind.day);
final appLanguageProvider = StateProvider<String>((ref) => 'en');
final deviceNameProvider = StateProvider<String>((ref) => AppLocalizations.translateCurrent('Bifrost Device'));
final customThemeColorProvider = StateProvider<Color>((ref) => const Color(0xFF3154B8));
final textColorProvider = StateProvider<Color?>((ref) => null);
const bifrostVersion = '0.13.5+36';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.load();
  try {
    await BifrostUpdateService.instance.cleanupInstalledUpdates(currentVersion: bifrostVersion);
  } catch (_) {}
  if (Platform.isWindows) SharedFileBridge.instance.seed(args);
  runApp(const ProviderScope(child: BifrostApp()));
}

class BifrostApp extends ConsumerStatefulWidget {
  const BifrostApp({this.enableDiscovery = true, super.key});
  final bool enableDiscovery;

  @override ConsumerState<BifrostApp> createState() => _BifrostAppState();
}

Future<void> _openUpdatePackage(CachedBifrostUpdate update) async {
  if (Platform.isAndroid) {
    await OpenFilex.open(update.file.path, type: 'application/vnd.android.package-archive');
  } else if (Platform.isWindows) {
    await Process.start('cmd.exe', ['/c', 'start', '', update.file.path]);
  }
}

Future<void> _promptToInstallUpdate(BuildContext context, CachedBifrostUpdate update) async {
  if (!context.mounted) return;
  final installNow = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bifrost update downloaded'),
      content: Text('Version ${update.version} is ready to install'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Later')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Install now')),
      ],
    ),
  );
  if (installNow == true) await _openUpdatePackage(update);
}

class _BifrostAppState extends ConsumerState<BifrostApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _readyPromptShownFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TransferNotifications.instance.onUpdateNotificationTapped = _openLatestCachedUpdate;
    _loadAppearance();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForReadyCachedUpdate(delay: const Duration(milliseconds: 1500)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForReadyCachedUpdate();
    }
  }

  Future<void> _openLatestCachedUpdate() async {
    final update = await BifrostUpdateService.instance.latestCachedUpdate(
      currentVersion: bifrostVersion,
      android: Platform.isAndroid,
    );
    if (update != null) {
      _readyPromptShownFor = update.version;
      await _openUpdatePackage(update);
    }
  }

  Future<void> _checkForReadyCachedUpdate({Duration delay = Duration.zero}) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!mounted || !Platform.isAndroid) return;
    final update = await BifrostUpdateService.instance.latestCachedUpdate(
      currentVersion: bifrostVersion,
      android: true,
    );
    if (!mounted) return;
    if (update == null || _readyPromptShownFor == update.version) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _readyPromptShownFor = update.version;
    await _promptToInstallUpdate(context, update);
  }

  @override Widget build(BuildContext context) {
    final enableDiscovery = widget.enableDiscovery;
    final language = ref.watch(appLanguageProvider);
    AppLocalizations.currentLanguageCode = language;
    final kind = ref.watch(appThemeProvider);
    final customColor = ref.watch(customThemeColorProvider);
    final textColor = ref.watch(textColorProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: language == 'ar' ? 'بايفروست' : 'Bifrost',
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: AppTheme.forKind(kind, customColor: customColor, textColor: textColor),
      themeMode: ThemeMode.light,
      builder: (context, child) => ThemeBackdrop(kind: kind, customColor: customColor, child: child ?? const SizedBox.shrink()),
      home: BifrostSplash(child: IncomingOfferListener(child: BifrostGate(enableDiscovery: enableDiscovery))),
    );
  }

  Future<void> _loadAppearance() async {
    final language = await AppStorage.instance.languageChoice();
    final saved = await AppStorage.instance.themeChoice();
    final custom = await AppStorage.instance.customThemeColor();
    final text = await AppStorage.instance.textColor();
    if (!mounted) return;
    AppLocalizations.currentLanguageCode = language;
    ref.read(appLanguageProvider.notifier).state = language;
    final kind = AppThemeKind.values.where((item) => item.name == saved).firstOrNull;
    if (kind != null) ref.read(appThemeProvider.notifier).state = kind;
    final customColor = _parseColor(custom);
    if (customColor != null) ref.read(customThemeColorProvider.notifier).state = customColor;
    ref.read(textColorProvider.notifier).state = _parseColor(text);
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
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Bifrost', style: TextStyle(fontFamily: 'MisticalSpring', fontSize: 64, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Colors.white, shadows: [Shadow(color: const Color(0xFFFFD54F).withAlpha(210), blurRadius: 24), const Shadow(color: Color(0xCCFFB300), blurRadius: 42)])), const SizedBox(height: 8), Text('Your bridge between worlds', style: TextStyle(fontFamily: 'Helvetica', fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: .3, shadows: [Shadow(color: const Color(0xFFFFD54F).withAlpha(210), blurRadius: 12), const Shadow(color: Color(0xCCFFB300), blurRadius: 22)]))])));
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

class FirstRunPage extends ConsumerStatefulWidget {
  const FirstRunPage({required this.onComplete, super.key});
  final VoidCallback onComplete;
  @override ConsumerState<FirstRunPage> createState() => _FirstRunPageState();
}

class _FirstRunPageState extends ConsumerState<FirstRunPage> {
  late final TextEditingController _name;
  late String _path;
  bool _saving = false;
  String _language = 'en';
  @override void initState() { super.initState(); _name = TextEditingController(text: 'Bifrost Device'); _path = AppStorage.instance.defaultSaveDirectory(); AppStorage.instance.languageChoice().then((value) { if (!mounted) return; setState(() { _language = value; if (_name.text == 'Bifrost Device' || _name.text == 'جهاز بايفروست') _name.text = value == 'ar' ? 'جهاز بايفروست' : 'Bifrost Device'; }); AppLocalizations.currentLanguageCode = value; ref.read(appLanguageProvider.notifier).state = value; }); AppStorage.instance.deviceName().then((value) { if (mounted && value != 'Bifrost Device') setState(() => _name.text = value); }); }
  Future<void> _setLanguage(String language) async { setState(() { _language = language; if (_name.text == 'Bifrost Device' || _name.text == 'جهاز بايفروست') _name.text = language == 'ar' ? 'جهاز بايفروست' : 'Bifrost Device'; }); AppLocalizations.currentLanguageCode = language; ref.read(appLanguageProvider.notifier).state = language; await AppStorage.instance.setLanguageChoice(language); await TransferNotifications.instance.refreshLocalizedChannels(); }
  @override void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _chooseLocation() async { final selected = await FilePicker.getDirectoryPath(dialogTitle: AppLocalizations.translate(context, 'Choose Bifrost save location'), initialDirectory: _path); if (selected != null && mounted) setState(() => _path = selected); }
  Future<void> _finish() async { final name = _name.text.trim(); if (name.isEmpty) return; setState(() => _saving = true); try { await Directory(_path).create(recursive: true); await AppStorage.instance.setDeviceName(name); await AppStorage.instance.setSaveDirectoryPath(_path); await AppStorage.instance.setOnboardingComplete(); widget.onComplete(); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bifrost could not access that folder. Choose another location.'))); } if (mounted) setState(() => _saving = false); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(28), children: [const SizedBox(height: 32), Text('Welcome to Bifrost', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), const Text('Set up your device once. You can change these choices later in Settings.'), const SizedBox(height: 24), DropdownButtonFormField<String>(initialValue: _language, decoration: InputDecoration(labelText: AppLocalizations.translate(context, 'Language')), items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'ar', child: Text('العربية'))], onChanged: (value) { if (value != null) _setLanguage(value); }), const SizedBox(height: 24), TextField(controller: _name, decoration: InputDecoration(labelText: AppLocalizations.translate(context, 'Choose device name'), prefixIcon: const Icon(Icons.badge_outlined))), const SizedBox(height: 20), Card(child: ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Save received files to'), subtitle: Text(_path, localized: false, textDirection: TextDirection.ltr), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _chooseLocation)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: _saving ? null : _chooseLocation, icon: const Icon(Icons.folder_open), label: const Text('Give access / Change save location')), const SizedBox(height: 28), FilledButton(onPressed: _saving ? null : _finish, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_saving ? 'Setting up…' : 'Continue')))])));
}

class BifrostShell extends StatefulWidget {
  const BifrostShell({this.enableDiscovery = true, super.key});
  final bool enableDiscovery;

  @override
  State<BifrostShell> createState() => _BifrostShellState();
}

class _BifrostShellState extends State<BifrostShell> {
  int _selectedIndex = 0;
  bool _startupUpdateChecked = false;

  @override
  void initState() {
    super.initState();
    AppStorage.instance.backgroundActivity().then((enabled) {
      if (enabled) BifrostDeviceRuntime.instance.ensureStarted();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdatesAtStartup());
  }

  Future<void> _checkForUpdatesAtStartup() async {
    if (_startupUpdateChecked || !mounted) return;
    _startupUpdateChecked = true;
    if (!await AppStorage.instance.automaticUpdateChecks() || !mounted) return;
    try {
      final release = await BifrostUpdateService.instance.latest(currentVersion: bifrostVersion);
      if (!mounted || release == null) return;
      final cached = await BifrostUpdateService.instance.cachedUpdateForVersion(
        version: release.version,
        android: Platform.isAndroid,
      );
      if (!mounted) return;
      if (cached != null) return;
      final url = Platform.isAndroid ? release.apkUrl : Platform.isWindows ? release.windowsUrl : null;
      if (url == null) return;
      final download = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text('Bifrost ${release.version} is available'), content: Text('A new update is ready. Download size: ${_formatUpdateBytes(Platform.isAndroid ? release.apkSizeBytes : release.windowsSizeBytes)}. You can choose Not now and check again later.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Update'))]));
      if (download == true && mounted) await _downloadStartupUpdate(release, url);
    } catch (_) {
      // Startup checks are silent: network failures must not interrupt app launch.
    }
  }

  Future<void> _downloadStartupUpdate(BifrostRelease release, String url) async {
    var received = 0;
    var total = Platform.isAndroid ? release.apkSizeBytes ?? 0 : release.windowsSizeBytes ?? 0;
    var speed = 0.0;
    var eta = 0;
    var closed = false;
    StateSetter? repaint;
    unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(builder: (_, setState) { repaint = setState; final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : null; return AlertDialog(title: Text('Downloading Bifrost ${release.version}'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [LinearProgressIndicator(value: progress), const SizedBox(height: 12), Text(total > 0 ? '${(progress! * 100).toStringAsFixed(0)}% • ${_formatUpdateBytes(received)} of ${_formatUpdateBytes(total)}' : '${_formatUpdateBytes(received)} downloaded'), if (speed > 0) Text('${_formatSpeed(speed)}/s${eta > 0 ? ' • ${_formatEta(eta)} left' : ''}'), const SizedBox(height: 10), const Text('The download continues while Bifrost is in the background.')]), actions: [TextButton(onPressed: () { BifrostUpdateService.instance.cancelDownload(); Navigator.pop(dialogContext); }, child: const Text('Cancel'))]); })).then((_) => closed = true));
    try {
      final started = DateTime.now();
      final file = await BifrostUpdateService.instance.download(url, version: release.version, onProgress: (done, reportedTotal) { received = done; if (reportedTotal != null) total = reportedTotal; final seconds = DateTime.now().difference(started).inMilliseconds / 1000; speed = received / (seconds < .1 ? .1 : seconds); eta = speed > 0 && total > received ? ((total - received) / speed).ceil() : 0; TransferNotifications.instance.updateProgress(received: received, total: total, speedBytesPerSecond: speed, etaSeconds: eta); repaint?.call(() {}); });
      await TransferNotifications.instance.updateComplete(version: release.version);
      if (!closed && mounted) Navigator.of(context).pop();
      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _promptToInstallUpdate(context, CachedBifrostUpdate(version: release.version, file: file));
      }
    } on UpdateDownloadCancelled {
      await TransferNotifications.instance.clearUpdate();
      if (!closed && mounted) Navigator.of(context).pop();
    } catch (_) {
      await TransferNotifications.instance.clearUpdate();
      if (!closed && mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The update could not be downloaded. You can try again from Settings.')));
    }
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
        destinations: [
          NavigationDestination(icon: Icon(Icons.radar), label: AppLocalizations.translate(context, 'Nearby')),
          NavigationDestination(icon: Icon(Icons.history), label: AppLocalizations.translate(context, 'History')),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: AppLocalizations.translate(context, 'Settings')),
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
                IconButton(tooltip: AppLocalizations.translate(context, 'Help'), onPressed: () => _showComingSoon(context, 'Troubleshooting'), icon: const Icon(Icons.help_outline)),
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

  Future<void> _showDetails(TransferRecord record) async => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(record.fileName, localized: false), content: Text('Status: ${record.status}\nDirection: ${record.direction}\nDevice: ${record.peer}\nSize: ${_historyBytes(record.bytes)}\nTime: ${_historyTime(record.time)}${record.speedBytesPerSecond > 0 ? '\nSpeed: ${_formatSpeed(record.speedBytesPerSecond)}/s' : ''}${record.path == null ? '' : '\nPath: ${record.path}'}'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))]));

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
          Row(children: [Expanded(child: Text('Transfer history', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))), if (_records.isNotEmpty) IconButton(tooltip: AppLocalizations.translate(context, 'Clear history'), onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))]),
          const SizedBox(height: 20),
          for (final record in _active.values) _historyTile(context, record),
          for (final record in _records) Card(child: ListTile(onTap: () => _showRecordActions(record), leading: Icon(record.status == 'Completed' ? Icons.check_circle : Icons.error_outline, color: record.status == 'Completed' ? Colors.green : Theme.of(context).colorScheme.error), title: Text(record.fileName, localized: false), subtitle: Text('${record.direction} • ${record.status} • ${_historyBytes(record.bytes)}\n${record.peer} • ${_historyTime(record.time)}'), trailing: record.path == null ? null : const Icon(Icons.more_vert))),
        ]);

  Widget _historyTile(BuildContext context, TransferRecord record) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.sync, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(record.fileName, localized: false, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${(record.progress * 100).round()}%'),
            ]),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: record.progress),
            const SizedBox(height: 6),
            Text('${record.direction} • ${record.peer}'),
            if (record.speedBytesPerSecond > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_formatSpeed(record.speedBytesPerSecond)}/s${record.etaSeconds == null ? '' : ' • ${_formatEta(record.etaSeconds!)} left'}', style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: OutlinedButton.icon(onPressed: () async {
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
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trusted devices'), actions: [if (_devices.isNotEmpty) IconButton(tooltip: AppLocalizations.translate(context, 'Remove all'), onPressed: _removeAll, icon: const Icon(Icons.delete_sweep_outlined))]), body: _devices.isEmpty ? const EmptyPage(icon: Icons.verified_user_outlined, title: 'No trusted devices', message: 'Trust a device when accepting its first transfer and it will appear here.') : ListView(padding: const EdgeInsets.all(16), children: [for (final device in _devices) Card(child: ListTile(leading: const Icon(Icons.verified_user), title: Text(device.name, localized: false), subtitle: Text('Last seen ${_relative(device.lastSeen)}\n${device.id}'), isThreeLine: true, trailing: IconButton(tooltip: AppLocalizations.translate(context, 'Remove trusted device'), icon: const Icon(Icons.delete_outline), onPressed: () => _remove(device))))]));
}

String _relative(DateTime time) { final difference = DateTime.now().difference(time); if (difference.inMinutes < 1) return 'just now'; if (difference.inHours < 1) return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago'; if (difference.inDays < 1) return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago'; return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago'; }
String _historyTime(DateTime time) { final local = time.toLocal(); final hour = local.hour % 12 == 0 ? 12 : local.hour % 12; final minute = local.minute.toString().padLeft(2, '0'); final period = local.hour >= 12 ? 'PM' : 'AM'; return '$hour:$minute $period'; }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  String? _savePath;
  bool _backgroundActivity = false;
  bool _checkingForUpdates = false;
  bool _updateDownloading = false;
  bool _automaticUpdateChecks = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(deviceNameProvider));
    AppStorage.instance.deviceName().then((name) { if (!mounted) return; _nameController.text = name; ref.read(deviceNameProvider.notifier).state = name; });
    AppStorage.instance.saveDirectoryPath().then((path) { if (mounted) setState(() => _savePath = path); });
    AppStorage.instance.backgroundActivity().then((enabled) { if (mounted) setState(() => _backgroundActivity = enabled); });
    AppStorage.instance.automaticUpdateChecks().then((enabled) { if (mounted) setState(() => _automaticUpdateChecks = enabled); });
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
    final path = await FilePicker.getDirectoryPath(dialogTitle: AppLocalizations.translate(context, 'Choose Bifrost save location'));
    if (path == null) return;
    await BifrostDeviceRuntime.instance.updateSaveDirectory(Directory(path));
    if (mounted) setState(() => _savePath = path);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save location updated.')));
  }

  Future<void> _toggleBackground(bool enabled) async {
    setState(() => _backgroundActivity = enabled);
    await BifrostDeviceRuntime.instance.setBackgroundActivity(enabled);
  }

  Future<void> _chooseLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose language'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'en'), child: Row(children: [if (ref.read(appLanguageProvider) == 'en') const Icon(Icons.check, size: 18), const SizedBox(width: 8), const Text('English')])),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'ar'), child: Row(children: [if (ref.read(appLanguageProvider) == 'ar') const Icon(Icons.check, size: 18), const SizedBox(width: 8), const Text('العربية')])),
        ],
      ),
    );
    if (selected == null) return;
    AppLocalizations.currentLanguageCode = selected;
    ref.read(appLanguageProvider.notifier).state = selected;
    final previousName = _nameController.text.trim();
    await AppStorage.instance.setLanguageChoice(selected);
    if (previousName == 'Bifrost Device' || previousName == 'جهاز بايفروست') {
      final localizedName = await AppStorage.instance.deviceName();
      _nameController.text = localizedName;
      ref.read(deviceNameProvider.notifier).state = localizedName;
      BifrostDeviceRuntime.instance.updateDeviceName(localizedName);
    }
    await TransferNotifications.instance.refreshLocalizedChannels();
  }

  Future<void> _shareBifrost() async {
    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share Bifrost'),
        content: const Text('Choose which Bifrost package to share.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'android'), child: const Text('Android APK')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, 'windows'), child: const Text('Windows installer')),
        ],
      ),
    );
    if (destination == null) return;
    try {
      await const MethodChannel('bifrost/share').invokeMethod<void>(destination == 'windows' ? 'shareBifrostWindows' : 'shareBifrostApk');
    } on PlatformException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share Bifrost: ${error.message ?? 'unknown error'}')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      ListTile(leading: const Icon(Icons.language), title: const Text('Language'), subtitle: Text(ref.watch(appLanguageProvider) == 'ar' ? 'العربية' : 'English'), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _chooseLanguage),
      const SizedBox(height: 8),
      TextField(controller: _nameController, textInputAction: TextInputAction.done, onSubmitted: (_) => _saveName(), decoration: InputDecoration(labelText: AppLocalizations.translate(context, 'Device name'), prefixIcon: const Icon(Icons.badge_outlined), suffixIcon: IconButton(tooltip: AppLocalizations.translate(context, 'Save device name'), onPressed: _saveName, icon: const Icon(Icons.check)))),
      ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Save location'), subtitle: Text(_savePath ?? AppStorage.instance.defaultSaveDirectory(), localized: false, textDirection: TextDirection.ltr), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _chooseSaveLocation),
      SwitchListTile(value: _backgroundActivity, onChanged: _toggleBackground, title: const Text('Background receiving'), subtitle: const Text('Keep Bifrost listening while the app is in the background.'), secondary: const Icon(Icons.notifications_active_outlined)),
      SwitchListTile(value: _automaticUpdateChecks, onChanged: (enabled) async { setState(() => _automaticUpdateChecks = enabled); await AppStorage.instance.setAutomaticUpdateChecks(enabled); }, title: const Text('Automatically check for updates'), subtitle: const Text('Silently check GitHub when Bifrost starts.'), secondary: const Icon(Icons.system_update_alt_outlined)),
      const SizedBox(height: 12),
      ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Trusted devices'), subtitle: const Text('Manage devices that can send without approval.'), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrustedDevicesPage()))),
      ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Theme'), subtitle: Text(ref.watch(appThemeProvider).label), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _chooseTheme),
      ListTile(leading: Icon(Icons.format_color_text, color: ref.watch(textColorProvider) ?? Theme.of(context).colorScheme.onSurface), title: const Text('Text Color'), subtitle: Text(ref.watch(textColorProvider) == null ? 'Automatic for the selected theme' : _colorHex(ref.watch(textColorProvider)!)), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _chooseTextColor),
      ListTile(leading: const Icon(Icons.system_update_outlined), title: const Text('Check for updates'), subtitle: Text(_checkingForUpdates ? 'Checking GitHub Releases…' : _updateDownloading ? 'Downloading update… You can leave Bifrost open in the background.' : 'Download updates without opening GitHub'), trailing: _checkingForUpdates || _updateDownloading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _checkingForUpdates || _updateDownloading ? null : _checkForUpdates),
      const Divider(height: 32),
      ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share Bifrost'), subtitle: Text(Platform.isAndroid ? 'Share the Android APK or Windows installer' : 'Package sharing is available on Android'), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: Platform.isAndroid ? _shareBifrost : null),
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('About Bifrost'), subtitle: const Text('Credits, version, and project information'), trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right), onTap: _showAbout),
    ]);
  }

  Future<void> _chooseTheme() async {
    final selected = await showDialog<AppThemeKind>(context: context, builder: (dialogContext) => SimpleDialog(title: const Text('Choose a theme'), children: [for (final kind in AppThemeKind.values) SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, kind), child: ListTile(leading: Icon(kind == AppThemeKind.day ? Icons.wb_sunny_outlined : kind == AppThemeKind.sunset ? Icons.wb_twilight : Icons.nightlight_outlined), title: Text(kind.label), subtitle: Text(kind.description)))]));
    if (selected == null) return;
    ref.read(appThemeProvider.notifier).state = selected;
    ref.read(textColorProvider.notifier).state = null;
    await AppStorage.instance.setThemeChoice(selected.name);
    await AppStorage.instance.clearTextColor();
    if (selected == AppThemeKind.customColor) await _chooseCustomColor();
  }

  Future<void> _chooseCustomColor() async {
    final result = await _showColorDialog('Choose theme color', ref.read(customThemeColorProvider));
    final selected = result?.color;
    if (selected == null) return;
    ref.read(customThemeColorProvider.notifier).state = selected;
    await AppStorage.instance.setCustomThemeColor(_colorHex(selected));
  }

  Future<void> _chooseTextColor() async {
    final result = await _showColorDialog('Choose text color', ref.read(textColorProvider) ?? Theme.of(context).colorScheme.onSurface, allowAutomatic: true);
    if (result == null) return;
    if (result.automatic) {
      ref.read(textColorProvider.notifier).state = null;
      await AppStorage.instance.clearTextColor();
      return;
    }
    final color = result.color;
    if (color == null) return;
    ref.read(textColorProvider.notifier).state = color;
    await AppStorage.instance.setTextColor(_colorHex(color));
  }

  Future<_ColorDialogResult?> _showColorDialog(String title, Color initial, {bool allowAutomatic = false}) async {
    var selectedColor = initial;
    final result = await showDialog<_ColorDialogResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: selectedColor,
                  onColorChanged: (color) => selectedColor = color,
                  enableAlpha: false,
                  displayThumbColor: true,
                  pickerAreaHeightPercent: .72,
                  paletteType: PaletteType.hsvWithHue,
                ),
                const SizedBox(height: 8),
                const Align(alignment: AlignmentDirectional.centerStart, child: Text('Suggestions')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in const [Color(0xFF102A43), Color(0xFF3154B8), Color(0xFF6E5AE6), Color(0xFF00897B), Color(0xFF2E7D32), Color(0xFF8D6E63), Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFFC62828), Color(0xFFAD1457), Color(0xFF546E7A), Color(0xFFFFFFFF)])
                      GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 20,
                          child: color == Colors.white ? const Icon(Icons.circle_outlined, color: Colors.black54) : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (allowAutomatic) TextButton(onPressed: () => Navigator.pop(dialogContext, const _ColorDialogResult.automatic()), child: const Text('Use theme default')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, _ColorDialogResult.color(selectedColor)), child: const Text('Apply')),
        ],
      ),
    );
    return result;
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingForUpdates = true);
    try {
      final cachedUpdate = await BifrostUpdateService.instance.latestCachedUpdate(
        currentVersion: bifrostVersion,
        android: Platform.isAndroid,
      );
      if (!mounted) return;
      if (cachedUpdate != null) {
        await _openUpdatePackage(cachedUpdate);
        return;
      }
      final release = await BifrostUpdateService.instance.latest(currentVersion: bifrostVersion);
      if (!mounted) return;
      if (release == null) {
        final cached = await BifrostUpdateService.instance.latestCachedUpdate(currentVersion: bifrostVersion, android: Platform.isAndroid);
        if (!mounted) return;
        if (cached != null) {
          await _openUpdatePackage(cached);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are using the latest compatible Bifrost version.')));
        }
      } else {
        final cachedFile = await BifrostUpdateService.instance.cachedUpdateForVersion(version: release.version, android: Platform.isAndroid);
        if (!mounted) return;
        if (cachedFile != null) {
          await _openUpdatePackage(CachedBifrostUpdate(version: release.version, file: cachedFile));
          return;
        }
        final asset = Platform.isAndroid ? release.apkUrl : Platform.isWindows ? release.windowsUrl : null;
        final size = Platform.isAndroid ? release.apkSizeBytes : release.windowsSizeBytes;
        await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text('Bifrost ${release.version} is available'), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(asset == null ? 'A release exists, but it has no installer for this platform.' : 'Download size: ${_formatUpdateBytes(size)}'), if (asset != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('The download can continue while Bifrost is in the background.')), if (release.notes.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 18), child: Text(release.notes))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')), if (asset != null) FilledButton(onPressed: () { Navigator.pop(dialogContext); _downloadAndInstall(release, asset); }, child: const Text('Download and install'))]));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not check GitHub Releases: $error')));
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  Future<void> _downloadAndInstall(BifrostRelease release, String url) async {
    if (!mounted) return;
    setState(() => _updateDownloading = true);
    var received = 0;
    var total = Platform.isAndroid ? release.apkSizeBytes ?? 0 : release.windowsSizeBytes ?? 0;
    var speed = 0.0;
    var etaSeconds = 0;
    var lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
    StateSetter? dialogSetState;
    var dialogOpen = true;
    var userCancelled = false;
    unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
      dialogSetState = setDialogState;
      final percent = total == 0 ? null : (received / total).clamp(0.0, 1.0);
      return AlertDialog(title: Text('Downloading Bifrost ${release.version}'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [LinearProgressIndicator(value: percent), const SizedBox(height: 14), Text(total == 0 ? '${_formatUpdateBytes(received)} downloaded' : '${(percent! * 100).toStringAsFixed(0)}% • ${_formatUpdateBytes(received)} of ${_formatUpdateBytes(total)}'), if (speed > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${_formatSpeed(speed)}/s${etaSeconds > 0 ? ' • ${_formatEta(etaSeconds)} left' : ''}')), const SizedBox(height: 10), const Text('You can leave Bifrost open in the background; progress will remain in the notification.')]), actions: [TextButton(onPressed: () { userCancelled = true; BifrostUpdateService.instance.cancelDownload(); Navigator.pop(dialogContext); }, child: const Text('Cancel'))]);
    })).then((_) => dialogOpen = false));
    try {
      final started = DateTime.now();
      final file = await BifrostUpdateService.instance.download(url, version: release.version, onProgress: (downloaded, reportedTotal) {
        received = downloaded;
        if (reportedTotal != null) total = reportedTotal;
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        speed = received / ((elapsed < 1 ? 1 : elapsed) / 1000);
        etaSeconds = speed > 0 && total > received ? ((total - received) / speed).ceil() : 0;
        TransferNotifications.instance.updateProgress(received: received, total: total, speedBytesPerSecond: speed, etaSeconds: etaSeconds);
        final now = DateTime.now();
        if (dialogSetState != null && now.difference(lastPaint).inMilliseconds >= 120) {
          lastPaint = now;
          dialogSetState!(() {});
        }
      });
      try {
        await TransferNotifications.instance.updateComplete(version: release.version);
      } catch (_) {}
      if (dialogOpen && mounted) Navigator.of(context).pop();
      if (mounted) setState(() => _updateDownloading = false);
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed && mounted) {
        await _showDownloadedUpdateDialog(CachedBifrostUpdate(version: release.version, file: file));
      }
    } on UpdateDownloadCancelled {
      await TransferNotifications.instance.clearUpdate();
      if (dialogOpen && mounted) Navigator.of(context).pop();
      if (!userCancelled && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update download cancelled.')));
    } catch (error) {
      await TransferNotifications.instance.clearUpdate();
      if (dialogOpen && mounted) Navigator.of(context).pop();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update download failed: $error')));
    } finally {
      if (mounted) setState(() => _updateDownloading = false);
    }
  }

  Future<void> _showDownloadedUpdateDialog(CachedBifrostUpdate update) async {
    if (!mounted) return;
    await _promptToInstallUpdate(context, update);
  }

  Future<void> _showAbout() async => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Bifrost', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Programmed by EFOMA', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 18),
          Text('App Version:    $bifrostVersion'),
          SizedBox(height: 14),
          Text('Local-only file sharing for Android and Windows.'),
          SizedBox(height: 8),
          Text('Transfers stay on your local network. No internet account is required.'),
          SizedBox(height: 8),
          Text('Built with Flutter and Dart.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
}

String _historyBytes(int bytes) => bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatUpdateBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'unknown size';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
String _formatSpeed(double bytesPerSecond) => bytesPerSecond < 1024 * 1024 ? '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB' : '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatEta(int seconds) => seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
class _ColorDialogResult {
  const _ColorDialogResult.color(this.color) : automatic = false;
  const _ColorDialogResult.automatic() : color = null, automatic = true;
  final Color? color;
  final bool automatic;
}

Color? _parseColor(String? value) { if (value == null) return null; var hex = value.trim().replaceFirst('#', ''); if (hex.length == 6) hex = 'FF$hex'; if (hex.length != 8) return null; final parsed = int.tryParse(hex, radix: 16); return parsed == null ? null : Color(parsed); }
String _colorHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

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
