import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'features/send/network_test_page.dart';
import 'features/discovery/nearby_page.dart';
import 'features/receive/incoming_offer_listener.dart';
import 'core/networking/device_runtime.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/app_storage.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final deviceNameProvider = StateProvider<String>((ref) => 'Bifrost Device');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BifrostApp()));
}

class BifrostApp extends ConsumerWidget {
  const BifrostApp({this.enableDiscovery = true, super.key});
  final bool enableDiscovery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Bifrost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: IncomingOfferListener(child: BifrostShell(enableDiscovery: enableDiscovery)),
    );
  }
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pages = <Widget>[
      NearbyPage(autoDiscover: widget.enableDiscovery),
      const HistoryPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
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
  @override
  Widget build(BuildContext context) => _records.isEmpty && _active.isEmpty
      ? const EmptyPage(icon: Icons.history, title: 'Transfer history', message: 'Completed transfers will appear here.')
      : ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [Expanded(child: Text('Transfer history', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))), if (_records.isNotEmpty) IconButton(tooltip: 'Clear history', onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))]),
          const SizedBox(height: 20),
          for (final record in _active.values) _historyTile(context, record),
          for (final record in _records) Card(child: ListTile(leading: Icon(record.status == 'Completed' ? Icons.check_circle : Icons.error_outline, color: record.status == 'Completed' ? Colors.green : Theme.of(context).colorScheme.error), title: Text(record.fileName), subtitle: Text('${record.direction} • ${record.status} • ${_historyBytes(record.bytes)}\n${record.peer} • ${record.time.toLocal()}'))),
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
          ]),
        ),
      );
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  String? _savePath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(deviceNameProvider));
    AppStorage.instance.deviceName().then((name) { if (!mounted) return; _nameController.text = name; ref.read(deviceNameProvider.notifier).state = name; });
    AppStorage.instance.saveDirectoryPath().then((path) { if (mounted) setState(() => _savePath = path); });
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

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      TextField(controller: _nameController, textInputAction: TextInputAction.done, onSubmitted: (_) => _saveName(), decoration: InputDecoration(labelText: 'Device name', prefixIcon: const Icon(Icons.badge_outlined), suffixIcon: IconButton(tooltip: 'Save device name', onPressed: _saveName, icon: const Icon(Icons.check)))),
      ListTile(leading: const Icon(Icons.folder_outlined), title: const Text('Save location'), subtitle: Text(_savePath ?? 'Temporary folder'), trailing: const Icon(Icons.chevron_right), onTap: _chooseSaveLocation),
      ListTile(leading: const Icon(Icons.lan_outlined), title: const Text('Networking test'), subtitle: const Text('Milestone 2 local receiver'), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NetworkTestPage()))),
      SwitchListTile(value: mode == ThemeMode.dark, onChanged: (value) => ref.read(themeModeProvider.notifier).state = value ? ThemeMode.dark : ThemeMode.light, title: const Text('Dark theme'), secondary: const Icon(Icons.dark_mode_outlined)),
      const Divider(height: 32),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('About Bifrost'), subtitle: Text('Milestone 1 • Local-only file sharing')),
    ]);
  }
}

String _historyBytes(int bytes) => bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

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
