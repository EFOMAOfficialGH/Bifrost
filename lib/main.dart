import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/send/network_test_page.dart';
import 'core/theme/app_theme.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BifrostApp()));
}

class BifrostApp extends ConsumerWidget {
  const BifrostApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Bifrost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const BifrostShell(),
    );
  }
}

class BifrostShell extends StatefulWidget {
  const BifrostShell({super.key});

  @override
  State<BifrostShell> createState() => _BifrostShellState();
}

class _BifrostShellState extends State<BifrostShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    HistoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyPage(icon: Icons.history, title: 'Transfer history', message: 'Completed transfers will appear here.');
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      const ListTile(leading: Icon(Icons.badge_outlined), title: Text('Device name'), subtitle: Text('Bifrost Phone')),
      const ListTile(leading: Icon(Icons.folder_outlined), title: Text('Save location'), subtitle: Text('Configured in a later milestone')),
      ListTile(leading: const Icon(Icons.lan_outlined), title: const Text('Networking test'), subtitle: const Text('Milestone 2 local receiver'), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NetworkTestPage()))),
      SwitchListTile(value: mode == ThemeMode.dark, onChanged: (value) => ref.read(themeModeProvider.notifier).state = value ? ThemeMode.dark : ThemeMode.light, title: const Text('Dark theme'), secondary: const Icon(Icons.dark_mode_outlined)),
      const Divider(height: 32),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('About Bifrost'), subtitle: Text('Milestone 1 • Local-only file sharing')),
    ]);
  }
}

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
