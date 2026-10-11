import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/networking/bifrost_client.dart';
import '../../core/networking/discovery.dart';
import '../../core/networking/discovery_service.dart';
import '../../core/networking/device_runtime.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({this.autoDiscover = true, super.key});
  final bool autoDiscover;
  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final _service = BifrostDiscoveryService();
  List<BifrostDevice> _devices = const [];
  bool _searching = false;
  bool _sending = false;
  String? _transferStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoDiscover) _discover();
  }

  Future<void> _discover() async {
    setState(() { _searching = true; _error = null; });
    try {
      await BifrostDeviceRuntime.instance.ensureStarted();
      final devices = await _service.discover(localDeviceId: BifrostDeviceRuntime.instance.deviceId);
      if (mounted) setState(() { _devices = devices; _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; _error = 'Discovery could not start. You can connect by IP address instead.'; });
    }
  }

  Future<void> _manualConnect() async {
    final result = await showDialog<(String, int)?>(context: context, builder: (_) => const _ManualConnectionDialog());
    if (result == null) return;
    setState(() { _searching = true; _error = null; });
    final devices = await _service.discover(manualHost: result.$1, manualPort: result.$2, localDeviceId: BifrostDeviceRuntime.instance.deviceId);
    if (!mounted) return;
    setState(() { _devices = devices; _searching = false; _error = devices.isEmpty ? 'Could not reach that address. Check the IP, port, and Wi-Fi connection.' : null; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomScrollView(slivers: [
      SliverPadding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), sliver: SliverToBoxAdapter(child: Row(children: [
        const _BifrostMark(), const SizedBox(width: 12), Text('Bifrost', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const Spacer(),
        IconButton(tooltip: 'Troubleshooting', onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TroubleshootingPage())), icon: const Icon(Icons.help_outline)),
      ]))),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Nearby devices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(onPressed: _searching ? null : _discover, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 6),
              Text(_searching ? 'Searching this Wi-Fi network…' : 'Devices running Bifrost on this local network appear here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 20),
              if (_transferStatus != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(_transferStatus!))),
              if (_error != null) Card(color: colors.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.warning_amber, color: colors.onErrorContainer), const SizedBox(width: 12), Expanded(child: Text(_error!, style: TextStyle(color: colors.onErrorContainer)))]))),
              if (_devices.isEmpty && !_searching) Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(Icons.radar, color: colors.primary), const SizedBox(width: 12), const Expanded(child: Text('No nearby devices found yet. Try refresh, manual IP, or check the troubleshooting guide.'))]))),
              for (final device in _devices) Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: () => _selectDevice(device), leading: CircleAvatar(backgroundColor: colors.primaryContainer, child: Icon(device.type == 'windows' ? Icons.computer : Icons.phone_android, color: colors.onPrimaryContainer)), title: Text(device.name), subtitle: Text('${device.host}:${device.port} • ${device.source}'), trailing: IconButton(tooltip: 'Show connection QR', icon: const Icon(Icons.qr_code_2), onPressed: () => _showQr(device)))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _manualConnect, icon: const Icon(Icons.pin_drop_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Connect by IP address')))),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TroubleshootingPage())), icon: const Icon(Icons.build_outlined), label: const Text('Troubleshoot discovery'))),
            ],
          ),
        ),
      ),
    ]);
  }

  void _showQr(BifrostDevice device) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(device.name), content: Column(mainAxisSize: MainAxisSize.min, children: [QrImageView(data: device.connectionCode, size: 220), const SizedBox(height: 12), SelectableText(device.connectionCode, textAlign: TextAlign.center), const SizedBox(height: 8), const Text('Use this code with a future Bifrost scanner, or enter the address manually.', textAlign: TextAlign.center)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));

  Future<void> _selectDevice(BifrostDevice device) async {
    if (_sending) return;
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final files = picked.where((file) => file.path != null).map((file) => File(file.path!)).toList(growable: false);
    if (files.isEmpty) return;
    setState(() { _sending = true; _transferStatus = 'Sending ${files.length} file${files.length == 1 ? '' : 's'} to ${device.name}… Accept or decline on the other device.'; });
    final client = BifrostClient();
    try {
      for (var i = 0; i < files.length; i++) {
        setState(() => _transferStatus = 'Sending file ${i + 1} of ${files.length} to ${device.name}…');
        await client.sendFile(server: device.baseUri, file: files[i], transferId: 'transfer-${DateTime.now().microsecondsSinceEpoch}', fileId: 'file-$i');
      }
      if (mounted) setState(() => _transferStatus = 'Transfer complete: ${files.length} file${files.length == 1 ? '' : 's'} sent.');
    } catch (error) {
      if (mounted) setState(() => _transferStatus = 'Transfer stopped: the other device may have declined, or the connection was lost.');
    } finally {
      client.close();
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ManualConnectionDialog extends StatefulWidget { const _ManualConnectionDialog(); @override State<_ManualConnectionDialog> createState() => _ManualConnectionDialogState(); }
class _ManualConnectionDialogState extends State<_ManualConnectionDialog> {
  final _host = TextEditingController(); final _port = TextEditingController(text: '43821');
  @override void dispose() { _host.dispose(); _port.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Connect by IP'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _host, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'IP address', hintText: '192.168.1.42')), const SizedBox(height: 12), TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final port = int.tryParse(_port.text.trim()); if (_host.text.trim().isNotEmpty && port != null) Navigator.pop(context, (_host.text.trim(), port)); }, child: const Text('Connect'))]);
}

class TroubleshootingPage extends StatelessWidget { const TroubleshootingPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Discovery help')), body: ListView(padding: const EdgeInsets.all(24), children: const [Text('If no devices appear', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 16), _HelpItem(icon: Icons.wifi, title: 'Same local network', text: 'Both devices must be connected to the same Wi-Fi router, or one phone must be connected to the other phone’s hotspot.'), _HelpItem(icon: Icons.router, title: 'Client isolation', text: 'Guest Wi-Fi and some hotspots block devices from talking to each other. Try the main home network or manual IP.'), _HelpItem(icon: Icons.vpn_lock, title: 'VPN', text: 'Temporarily disconnect a VPN. It can send local traffic through a different network.'), _HelpItem(icon: Icons.security, title: 'Windows network profile', text: 'Set the Windows network to Private and allow Bifrost through the Windows Firewall when prompted.'), _HelpItem(icon: Icons.pin, title: 'Manual IP fallback', text: 'Use Connect by IP when automatic discovery is blocked. The receiver shows its IP address in the networking test screen.') ])); }
class _HelpItem extends StatelessWidget { const _HelpItem({required this.icon, required this.title, required this.text}); final IconData icon; final String title; final String text; @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(isThreeLine: true, leading: Icon(icon), title: Text(title), subtitle: Text(text))); }
class _BifrostMark extends StatelessWidget { const _BifrostMark(); @override Widget build(BuildContext context) => Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00C9A7)])), child: const Icon(Icons.architecture, color: Colors.white)); }
