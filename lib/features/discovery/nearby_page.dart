import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/networking/bifrost_client.dart';
import '../../core/networking/discovery.dart';
import '../../core/networking/discovery_service.dart';
import '../../core/networking/device_runtime.dart';
import '../../core/notifications/transfer_notifications.dart';
import '../../core/platform/shared_file_bridge.dart';
import '../../core/storage/app_storage.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({this.autoDiscover = true, super.key});
  final bool autoDiscover;
  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final _service = BifrostDiscoveryService();
  List<BifrostDevice> _devices = const [];
  List<File> _queuedFiles = const [];
  bool _searching = false;
  bool _sending = false;
  bool _dragging = false;
  double _progress = 0;
  String? _transferStatus;
  String? _error;
  TransferCancellation? _cancellation;
  final _queueStatuses = <String, String>{};
  StreamSubscription<List<String>>? _sharedFilesSubscription;

  @override
  void initState() {
    super.initState();
    _sharedFilesSubscription = SharedFileBridge.instance.files.listen(_queueSharedFiles);
    unawaited(SharedFileBridge.instance.initialize());
    if (widget.autoDiscover) _discover();
  }

  void _queueSharedFiles(List<String> paths) {
    _queueDropped(paths.map(File.new).where((file) => file.existsSync()).toList(growable: false));
    if (mounted && paths.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${paths.length} file${paths.length == 1 ? '' : 's'} added from Android Share')));
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

  Future<List<File>> _pickFiles() async {
    final picked = await FilePicker.pickFiles();
    return picked.where((file) => file.path != null).map((file) => File(file.path!)).toList(growable: false);
  }

  void _queueDropped(List<File> files) {
    if (files.isEmpty || _sending) return;
    setState(() { _queuedFiles = [..._queuedFiles, ...files]; for (final file in files) { _queueStatuses[file.path] = 'Queued'; } _transferStatus = '${_queuedFiles.length} file${_queuedFiles.length == 1 ? '' : 's'} ready. Select a device to send.'; });
  }

  @override
  void dispose() { _sharedFilesSubscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) => setState(() { _dragging = false; _queueDropped(detail.files.map((file) => File(file.path)).toList(growable: false)); }),
      child: CustomScrollView(slivers: [
        SliverPadding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), sliver: SliverToBoxAdapter(child: Row(children: [const _BifrostMark(), const SizedBox(width: 12), Text('Bifrost', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)), const Spacer(), IconButton(tooltip: 'Troubleshooting', onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TroubleshootingPage())), icon: const Icon(Icons.help_outline))]))),
        SliverPadding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Nearby devices', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))), IconButton(onPressed: _searching ? null : _discover, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
          const SizedBox(height: 6),
          Text(_searching ? 'Searching this Wi-Fi network…' : 'Devices running Bifrost on this local network appear here.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          AnimatedContainer(duration: const Duration(milliseconds: 180), width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: _dragging ? colors.primaryContainer : colors.surfaceContainerHighest, border: Border.all(color: _dragging ? colors.primary : colors.outlineVariant, width: _dragging ? 2 : 1)), child: Row(children: [Icon(Icons.file_upload_outlined, color: _dragging ? colors.primary : colors.onSurfaceVariant), const SizedBox(width: 12), Expanded(child: Text(_dragging ? 'Drop files here' : 'On Windows, drop files here to queue them. On phone, use the button below.')), TextButton(onPressed: _sending ? null : () async { final files = await _pickFiles(); _queueDropped(files); }, child: const Text('Choose'))])),
          if (_queuedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(child: Column(children: [for (final file in _queuedFiles) ListTile(dense: true, leading: Icon(_queueStatuses[file.path] == 'Completed' ? Icons.check_circle : _queueStatuses[file.path] == 'Failed' ? Icons.error_outline : Icons.insert_drive_file_outlined), title: Text(file.uri.pathSegments.last), subtitle: Text('${_formatBytes(file.lengthSync())} • ${_queueStatuses[file.path] ?? 'Queued'}'), trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Remove', onPressed: _sending ? null : () => setState(() { _queuedFiles = _queuedFiles.where((item) => item.path != file.path).toList(); _queueStatuses.remove(file.path); }))), ListTile(leading: const Icon(Icons.clear_all), title: const Text('Clear queued files'), onTap: _sending ? null : () => setState(() { _queuedFiles = const []; _queueStatuses.clear(); }) )])),
          ],
          const SizedBox(height: 20),
          if (_transferStatus != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_transferStatus!), if (_sending) ...[const SizedBox(height: 10), LinearProgressIndicator(value: _progress), const SizedBox(height: 10), OutlinedButton.icon(onPressed: _cancelTransfer, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel transfer'))]]))),
          if (_error != null) Card(color: colors.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.warning_amber, color: colors.onErrorContainer), const SizedBox(width: 12), Expanded(child: Text(_error!, style: TextStyle(color: colors.onErrorContainer)))]))),
          if (_devices.isEmpty && !_searching) Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(Icons.radar, color: colors.primary), const SizedBox(width: 12), const Expanded(child: Text('No nearby devices found yet. Try refresh, manual IP, or check the troubleshooting guide.'))]))),
          for (final device in _devices) Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(onTap: () => _selectDevice(device), leading: CircleAvatar(backgroundColor: colors.primaryContainer, child: Icon(device.type == 'windows' ? Icons.computer : Icons.phone_android, color: colors.onPrimaryContainer)), title: Text(device.name), subtitle: Text('${device.host}:${device.port} • ${device.source}'), trailing: IconButton(tooltip: 'Show connection QR', icon: const Icon(Icons.qr_code_2), onPressed: () => _showQr(device)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _manualConnect, icon: const Icon(Icons.pin_drop_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('Connect by IP address'))),),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TroubleshootingPage())), icon: const Icon(Icons.build_outlined), label: const Text('Troubleshoot discovery'))),
        ]))),
      ]),
    );
  }

  void _showQr(BifrostDevice device) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(device.name), content: Column(mainAxisSize: MainAxisSize.min, children: [QrImageView(data: device.connectionCode, size: 220), const SizedBox(height: 12), SelectableText(device.connectionCode, textAlign: TextAlign.center), const SizedBox(height: 8), const Text('Use this code with a future Bifrost scanner, or enter the address manually.', textAlign: TextAlign.center)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));

  Future<void> _selectDevice(BifrostDevice device) async {
    if (_sending) return;
    var files = _queuedFiles;
    if (files.isEmpty) files = await _pickFiles();
    if (files.isEmpty) return;
    setState(() { _queuedFiles = files; });
    await _sendFiles(device, files);
  }

  Future<void> _sendFiles(BifrostDevice device, List<File> files) async {
    setState(() { _sending = true; _progress = 0; _transferStatus = 'Starting transfer to ${device.name}…'; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer started to ${device.name}')));
    final client = BifrostClient();
    final cancellation = TransferCancellation();
    _cancellation = cancellation;
    var completedCount = 0;
    var failedCount = 0;
    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final size = await file.length();
        if (mounted) setState(() => _queueStatuses[file.path] = 'Sending');
        final activityId = 'send-${DateTime.now().microsecondsSinceEpoch}';
        AppStorage.instance.begin(TransferRecord(id: activityId, fileName: file.uri.pathSegments.last, bytes: size, direction: 'Sent', status: 'In progress', peer: device.name, time: DateTime.now(), progress: 0, peerHost: device.host, peerPort: device.port));
        AppStorage.instance.registerCancellation(activityId, () async => cancellation.cancel());
        final notificationId = activityId.hashCode;
        try {
          Object? lastError;
          for (var attempt = 1; attempt <= 3; attempt++) {
            try {
              await client.sendFile(server: device.baseUri, file: file, transferId: 'transfer-${DateTime.now().microsecondsSinceEpoch}', fileId: 'file-${DateTime.now().microsecondsSinceEpoch}', senderDeviceId: BifrostDeviceRuntime.instance.deviceId, senderDeviceName: BifrostDeviceRuntime.instance.deviceName, cancellation: cancellation, onProgress: (sent, total) {
                AppStorage.instance.update(activityId, sent, total);
                final current = AppStorage.instance.activeTransfers.where((item) => item.id == activityId).firstOrNull;
                if (mounted) setState(() { _progress = total == 0 ? 1 : sent / total; final speed = current?.speedBytesPerSecond ?? 0; final eta = current?.etaSeconds; _transferStatus = 'Sending ${file.uri.pathSegments.last}: ${total == 0 ? 100 : (sent * 100 ~/ total)}%${speed > 0 ? ' • ${_formatSpeed(speed)}/s' : ''}${eta != null ? ' • ${_formatEta(eta)} left' : ''}'; });
                TransferNotifications.instance.progress(id: notificationId, title: 'Sending ${file.uri.pathSegments.last}', sent: sent, total: total, speedBytesPerSecond: current?.speedBytesPerSecond ?? 0, etaSeconds: current?.etaSeconds);
              });
              lastError = null;
              break;
            } catch (error) {
              lastError = error;
              if (cancellation.isCancelled || !_isRetryable(error) || attempt == 3) rethrow;
              if (mounted) setState(() => _transferStatus = 'Connection interrupted. Retrying ${file.uri.pathSegments.last} (${attempt + 1}/3)…');
              await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
          if (lastError != null) throw lastError;
          await AppStorage.instance.finish(TransferRecord(id: activityId, fileName: file.uri.pathSegments.last, bytes: size, direction: 'Sent', status: 'Completed', peer: device.name, time: DateTime.now(), path: file.path, peerHost: device.host, peerPort: device.port));
          completedCount++;
          if (mounted) setState(() => _queueStatuses[file.path] = 'Completed');
          await TransferNotifications.instance.cancel(notificationId);
          await TransferNotifications.instance.complete(id: notificationId, title: 'Sent ${file.uri.pathSegments.last}', success: true);
        } catch (error) {
          final cancelled = error is TransferCancelledException || cancellation.isCancelled;
          await AppStorage.instance.finish(TransferRecord(id: activityId, fileName: file.uri.pathSegments.last, bytes: size, direction: 'Sent', status: cancelled ? 'Cancelled' : 'Failed', peer: device.name, time: DateTime.now(), progress: _progress, path: file.path, peerHost: device.host, peerPort: device.port));
          if (mounted) setState(() => _queueStatuses[file.path] = cancelled ? 'Cancelled' : 'Failed');
          await TransferNotifications.instance.cancel(notificationId);
          if (cancelled) rethrow;
          failedCount++;
        }
      }
      if (mounted) setState(() { if (failedCount == 0) { _queuedFiles = const []; _queueStatuses.clear(); } _transferStatus = failedCount == 0 ? 'Transfer complete: $completedCount file${completedCount == 1 ? '' : 's'} sent.' : 'Batch finished: $completedCount completed, $failedCount failed. Failed files remain queued.'; });
    } catch (error) {
      if (mounted) setState(() => _transferStatus = error is TransferCancelledException ? 'Transfer cancelled.' : 'Transfer stopped: the other device may have declined, or the connection was lost.');
    } finally {
      cancellation.dispose();
      client.close();
      _cancellation = null;
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelTransfer() {
    _cancellation?.cancel();
    if (mounted) setState(() => _transferStatus = 'Cancelling transfer…');
  }
}

String _formatBytes(int bytes) => bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatSpeed(double bytesPerSecond) => _formatBytes(bytesPerSecond.round());
String _formatEta(int seconds) => seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
bool _isRetryable(Object error) => error is SocketException || error is HttpException || error is TimeoutException;

class _ManualConnectionDialog extends StatefulWidget { const _ManualConnectionDialog(); @override State<_ManualConnectionDialog> createState() => _ManualConnectionDialogState(); }
class _ManualConnectionDialogState extends State<_ManualConnectionDialog> { final _host = TextEditingController(); final _port = TextEditingController(text: '43821'); @override void dispose() { _host.dispose(); _port.dispose(); super.dispose(); } @override Widget build(BuildContext context) => AlertDialog(title: const Text('Connect by IP'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _host, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'IP address', hintText: '192.168.1.42')), const SizedBox(height: 12), TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { final port = int.tryParse(_port.text.trim()); if (_host.text.trim().isNotEmpty && port != null) Navigator.pop(context, (_host.text.trim(), port)); }, child: const Text('Connect'))]); }
class TroubleshootingPage extends StatelessWidget { const TroubleshootingPage({super.key}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Discovery help')), body: ListView(padding: const EdgeInsets.all(24), children: const [Text('If no devices appear', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 16), _HelpItem(icon: Icons.wifi, title: 'Same local network', text: 'Both devices must be connected to the same Wi-Fi router, or one phone must be connected to the other phone’s hotspot.'), _HelpItem(icon: Icons.router, title: 'Client isolation', text: 'Guest Wi-Fi and some hotspots block devices from talking to each other. Try the main home network or manual IP.'), _HelpItem(icon: Icons.vpn_lock, title: 'VPN', text: 'Temporarily disconnect a VPN. It can send local traffic through a different network.'), _HelpItem(icon: Icons.security, title: 'Windows network profile', text: 'Set the Windows network to Private and allow Bifrost through the Windows Firewall when prompted.'), _HelpItem(icon: Icons.pin, title: 'Manual IP fallback', text: 'Use Connect by IP when automatic discovery is blocked. The receiver shows its IP address in the networking test screen.') ])); }
class _HelpItem extends StatelessWidget { const _HelpItem({required this.icon, required this.title, required this.text}); final IconData icon; final String title; final String text; @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(isThreeLine: true, leading: Icon(icon), title: Text(title), subtitle: Text(text))); }
class _BifrostMark extends StatelessWidget { const _BifrostMark(); @override Widget build(BuildContext context) => Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF00C9A7)])), child: const Icon(Icons.architecture, color: Colors.white)); }
