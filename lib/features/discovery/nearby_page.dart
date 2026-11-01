import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import '../../core/localization/localized_text.dart';
import '../../core/localization/app_localizations.dart';

import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/networking/bifrost_client.dart';
import '../../core/networking/discovery.dart';
import '../../core/networking/discovery_service.dart';
import '../../core/networking/device_runtime.dart';
import '../../core/notifications/transfer_notifications.dart';
import '../../core/platform/shared_file_bridge.dart';
import '../../core/storage/app_storage.dart';
import '../send/network_test_page.dart';
import '../app_transfer/app_transfer_picker.dart';
import '../app_transfer/app_transfer_service.dart';
import 'transfer_queue_dialog.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({
    this.autoDiscover = true,
    this.filePickerRequest = 0,
    super.key,
  });
  final bool autoDiscover;
  final int filePickerRequest;
  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final _service = BifrostDiscoveryService();
  List<BifrostDevice> _devices = const [];
  Set<String> _favoriteDeviceIds = const {};
  List<File> _queuedFiles = const [];
  bool _searching = false;
  bool _sending = false;
  int _sentCount = 0;
  double _progress = 0;
  String? _transferStatus;
  String? _error;
  TransferCancellation? _cancellation;
  final _queueStatuses = <String, String>{};
  final _queuedRemoteNames = <String, String>{};
  final _temporaryAppPackagePaths = <String>{};
  final _appTransferService = AppTransferService();
  StreamSubscription<List<String>>? _sharedFilesSubscription;
  Timer? _discoveryTimer;

  @override
  void initState() {
    super.initState();
    _sharedFilesSubscription = SharedFileBridge.instance.files.listen(
      _queueSharedFiles,
    );
    unawaited(SharedFileBridge.instance.initialize());
    if (widget.autoDiscover) {
      _discover();
      _discoveryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted && !_searching && !_sending) _discover();
      });
    }
  }

  void _queueSharedFiles(List<String> paths) {
    unawaited(_queueDroppedPaths(paths));
  }

  @override
  void didUpdateWidget(covariant NearbyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePickerRequest != widget.filePickerRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickAndQueue();
      });
    }
  }

  Future<void> _pickAndQueue() async {
    try {
      final files = await _pickFiles();
      if (mounted) _queueDropped(files);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file picker.')),
        );
    }
  }

  Future<void> _chooseInstalledApp() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AppTransferPicker(
          onAppsReady: (artifacts) async {
            final queued = _queueDropped(
              artifacts.map((artifact) => artifact.file).toList(),
            );
            final queuedPaths = queued.map((file) => file.path).toSet();
            for (final artifact in artifacts) {
              if (queuedPaths.contains(artifact.file.path)) {
                _queuedRemoteNames[artifact.file.path] = artifact.remoteName;
                if (artifact.isTemporary) {
                  _temporaryAppPackagePaths.add(artifact.file.path);
                }
              } else if (artifact.isTemporary) {
                await _appTransferService.deleteTemporaryExport(
                  artifact.file.path,
                );
              }
            }
            if (queued.isEmpty)
              throw StateError(
                'The selected apps could not be added to the transfer queue.',
              );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    queued.length == 1
                        ? '1 app added to the transfer queue.'
                        : '${queued.length} apps added to the transfer queue.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _discover() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      await BifrostDeviceRuntime.instance.ensureStarted();
      final devices = await _service.discover(
        localDeviceId: BifrostDeviceRuntime.instance.deviceId,
      );
      final favorites = await AppStorage.instance.favoriteDeviceIds();
      if (mounted)
        setState(() {
          _favoriteDeviceIds = favorites;
          _devices = _sortDevices(devices);
          _searching = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _searching = false;
          _error = 'Discovery could not start. You can connect by IP address instead.';
        });
    }
  }

  Future<void> _manualConnect() async {
    final result = await showDialog<(String, int)?>(
      context: context,
      builder: (_) => const _ManualConnectionDialog(),
    );
    if (result == null) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    final devices = await _service.discover(
      manualHost: result.$1,
      manualPort: result.$2,
      localDeviceId: BifrostDeviceRuntime.instance.deviceId,
    );
    final favorites = await AppStorage.instance.favoriteDeviceIds();
    if (!mounted) return;
    setState(() {
      _favoriteDeviceIds = favorites;
      _devices = _sortDevices(devices);
      _searching = false;
      _error = devices.isEmpty
          ? 'Could not reach that address. Check the IP, port, and Wi-Fi connection.'
          : null;
    });
  }

  List<BifrostDevice> _sortDevices(List<BifrostDevice> devices) {
    final sorted = List<BifrostDevice>.of(devices);
    sorted.sort((a, b) {
      final favoriteOrder = (_favoriteDeviceIds.contains(b.id) ? 1 : 0)
          .compareTo(_favoriteDeviceIds.contains(a.id) ? 1 : 0);
      return favoriteOrder != 0
          ? favoriteOrder
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  Future<void> _toggleFavorite(BifrostDevice device) async {
    final favorite = !_favoriteDeviceIds.contains(device.id);
    await AppStorage.instance.setFavoriteDevice(device.id, favorite);
    if (!mounted) return;
    setState(() {
      _favoriteDeviceIds = {..._favoriteDeviceIds, if (favorite) device.id};
      if (!favorite) _favoriteDeviceIds.remove(device.id);
      _devices = _sortDevices(_devices);
    });
  }

  Future<List<File>> _pickFiles() async {
    final picked = await FilePicker.pickFiles();
    return picked
        .where((file) => file.path != null)
        .map((file) => File(file.path!))
        .toList(growable: false);
  }

  Future<void> _queueDroppedPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final files = <File>[];
    var skipped = 0;
    for (final path in paths) {
      try {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type == FileSystemEntityType.file) {
          files.add(File(path));
        } else if (type == FileSystemEntityType.directory) {
          await for (final entity in Directory(
            path,
          ).list(recursive: true, followLinks: false)) {
            if (entity is File) files.add(entity);
          }
        } else {
          skipped++;
        }
      } on FileSystemException {
        skipped++;
      }
    }
    if (!mounted) return;
    final added = _queueDropped(files);
    if (added.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files were found in the dropped item.'),
        ),
      );
    } else if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some dropped items could not be read.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added.length == 1
                ? '1 file added to the transfer queue.'
                : '${added.length} files added to the transfer queue.',
          ),
        ),
      );
    }
  }

  List<File> _queueDropped(List<File> files) {
    if (files.isEmpty) return const [];
    final paths = _queuedFiles.map((file) => file.path).toSet();
    final valid = <File>[];
    for (final file in files) {
      try {
        if (FileSystemEntity.typeSync(file.path, followLinks: false) ==
                FileSystemEntityType.file &&
            paths.add(file.path)) {
          valid.add(file);
        }
      } on FileSystemException {
        // Ignore dropped items that disappeared or cannot be read.
      }
    }
    if (valid.isEmpty) return const [];
    setState(() {
      _queuedFiles = [..._queuedFiles, ...valid];
      for (final file in valid) {
        _queueStatuses[file.path] = 'Queued';
      }
      _transferStatus =
          '${_queuedFiles.length} file${_queuedFiles.length == 1 ? '' : 's'} ready. Select a device to send.';
    });
    return valid;
  }

  Future<void> _showQueue() async {
    final updated = await showDialog<List<File>>(
      context: context,
      builder: (_) => TransferQueueDialog(
        files: _queuedFiles,
        statuses: Map<String, String>.of(_queueStatuses),
        sending: _sending,
        displayNames: Map<String, String>.of(_queuedRemoteNames),
      ),
    );
    if (!mounted || updated == null) return;
    final retained = updated.map((file) => file.path).toSet();
    final removed = _queuedFiles.where((file) => !retained.contains(file.path));
    for (final file in removed) {
      if (_temporaryAppPackagePaths.remove(file.path)) {
        await _appTransferService.deleteTemporaryExport(file.path);
      }
      _queuedRemoteNames.remove(file.path);
    }
    setState(() {
      _queuedFiles = updated;
      _queueStatuses.removeWhere((path, _) => !retained.contains(path));
    });
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _sharedFilesSubscription?.cancel();
    super.dispose();
  }

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
                  const _BifrostMark(),
                  const SizedBox(width: 12),
                  Text(
                    'Bifrost',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: AppLocalizations.translate(
                      context,
                      'Troubleshooting',
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TroubleshootingPage(),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline),
                  ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nearby devices',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: _searching ? null : _discover,
                        tooltip: AppLocalizations.translate(context, 'Refresh'),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _searching ? 'Searching this Wi-Fi network…' : 'Devices running Bifrost on this local network appear here.',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colors.surfaceContainerHighest,
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.file_upload_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            Platform.isWindows
                                ? 'Drop files here or press "Choose" to start sending files'
                                : 'Press "Choose" to start sending files',
                          ),
                        ),
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () async {
                                  final files = await _pickFiles();
                                  _queueDropped(files);
                                },
                          child: const Text('Choose'),
                        ),
                      ],
                    ),
                  ),
                  if (Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _sending ? null : _chooseInstalledApp,
                          icon: const Icon(Icons.android),
                          label: const Text('Transfer an installed app'),
                        ),
                      ),
                    ),
                  if (_queuedFiles.isNotEmpty || _sentCount > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        onTap: _showQueue,
                        leading: const Icon(Icons.queue_outlined),
                        title: Text(
                          'Queue: ${_queuedFiles.length} • Sent: $_sentCount',
                        ),
                        subtitle: const Text(
                          'Tap to view, remove, or reorder files.',
                        ),
                        trailing: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_transferStatus != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_transferStatus!),
                            if (_sending) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: _progress),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _cancelTransfer,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel transfer'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  if (_error != null)
                    Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: colors.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_devices.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(Icons.radar, color: colors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _searching
                                    ? 'No nearby devices found yet. Searching again automatically…'
                                    : 'No nearby devices found yet. Try refresh, manual IP, or check the troubleshooting guide.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (final device in _devices)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _selectDevice(device),
                        leading: CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            device.type == 'windows'
                                ? Icons.computer
                                : Icons.phone_android,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(device.name, localized: false),
                        subtitle: Text(
                          '${device.host}:${device.port} • ${device.source}',
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppLocalizations.translate(
                                context,
                                _favoriteDeviceIds.contains(device.id)
                                    ? 'Remove favorite device'
                                    : 'Add favorite device',
                              ),
                              icon: Icon(
                                _favoriteDeviceIds.contains(device.id)
                                    ? Icons.star
                                    : Icons.star_border,
                              ),
                              onPressed: () => _toggleFavorite(device),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.translate(
                                context,
                                'Show connection QR',
                              ),
                              icon: const Icon(Icons.qr_code_2),
                              onPressed: () => _showQr(device),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _manualConnect,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 13),
                        child: Text('Connect by IP address'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
    );
  }

  void _showQr(BifrostDevice device) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(device.name, localized: false),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: device.connectionCode, size: 220),
          const SizedBox(height: 12),
          SelectableText(
            device.connectionCode,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this code with a future Bifrost scanner, or enter the address manually.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _selectDevice(BifrostDevice device) async {
    if (_sending) return;
    var files = _queuedFiles;
    if (files.isEmpty) {
      final picked = await _pickFiles();
      if (picked.isEmpty || !mounted) return;
      files = _queueDropped(picked);
    }
    if (files.isEmpty) return;
    await _sendFiles(device, files);
  }

  Future<void> _sendFiles(BifrostDevice device, List<File> files) async {
    setState(() {
      _sending = true;
      _progress = 0;
      _transferStatus = 'Starting transfer to ${device.name}…';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transfer started to ${device.name}')),
    );
    final client = BifrostClient();
    final cancellation = TransferCancellation();
    _cancellation = cancellation;
    var completedCount = 0;
    var failedCount = 0;
    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final fileName =
            _queuedRemoteNames[file.path] ??
            (file.uri.pathSegments.isEmpty
                ? file.path
                : file.uri.pathSegments.last);
        final generatedAppPackage = _temporaryAppPackagePaths.contains(
          file.path,
        );
        final size = await file.length();
        if (mounted) setState(() => _queueStatuses[file.path] = 'Sending');
        final activityId = 'send-${DateTime.now().microsecondsSinceEpoch}';
        final transferId = 'transfer-${DateTime.now().microsecondsSinceEpoch}';
        final fileId = 'file-${DateTime.now().microsecondsSinceEpoch}';
        final resumeToken = AppStorage.instance.newResumeToken();
        var fileDigest = '';
        await AppStorage.instance.beginPersistent(
          TransferRecord(
            id: activityId,
            fileName: fileName,
            bytes: size,
            direction: 'Sent',
            status: 'In progress',
            peer: device.name,
            time: DateTime.now(),
            progress: 0,
            path: file.path,
            generatedAppPackage: generatedAppPackage,
            peerHost: device.host,
            peerPort: device.port,
            peerDeviceId: device.id,
            transferId: transferId,
            fileId: fileId,
            resumeToken: resumeToken,
          ),
        );
        AppStorage.instance.registerCancellation(
          activityId,
          () async => cancellation.cancel(),
        );
        final notificationId = activityId.hashCode;
        try {
          Object? lastError;
          for (var attempt = 1; attempt <= 3; attempt++) {
            try {
              await client.sendFile(
                server: device.baseUri,
                file: file,
                remoteName: fileName,
                transferId: transferId,
                fileId: fileId,
                resumeToken: resumeToken,
                senderDeviceId: BifrostDeviceRuntime.instance.deviceId,
                senderDeviceName: BifrostDeviceRuntime.instance.deviceName,
                cancellation: cancellation,
                useResumable: true,
                onPrepared: (hash, bytes) async {
                  fileDigest = hash;
                  await AppStorage.instance.updateResumeMetadata(
                    activityId,
                    sha256: hash,
                    bytes: bytes,
                  );
                },
                onProgress: (sent, total) {
                  AppStorage.instance.update(activityId, sent, total);
                  final current = AppStorage.instance.activeTransfers
                      .where((item) => item.id == activityId)
                      .firstOrNull;
                  if (mounted)
                    setState(() {
                      _progress = total == 0 ? 1 : sent / total;
                      final speed = current?.speedBytesPerSecond ?? 0;
                      final eta = current?.etaSeconds;
                      _transferStatus =
                          'Sending $fileName: ${total == 0 ? 100 : (sent * 100 ~/ total)}%${speed > 0 ? ' • ${_formatSpeed(speed)}/s' : ''}${eta != null ? ' • ${_formatEta(eta)} left' : ''} • ${_formatBytes(total)}';
                    });
                  TransferNotifications.instance.progress(
                    id: notificationId,
                    title: 'Sending $fileName',
                    sent: sent,
                    total: total,
                    speedBytesPerSecond: current?.speedBytesPerSecond ?? 0,
                    etaSeconds: current?.etaSeconds,
                  );
                },
              );
              lastError = null;
              break;
            } catch (error) {
              lastError = error;
              if (cancellation.isCancelled ||
                  !_isRetryable(error) ||
                  attempt == 3)
                rethrow;
              if (mounted)
                setState(
                  () => _transferStatus =
                      'Connection interrupted. Retrying $fileName (${attempt + 1}/3)…',
                );
              await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
          if (lastError != null) throw lastError;
          final removedTemporaryPackage =
              generatedAppPackage &&
              await _appTransferService.deleteTemporaryExport(file.path);
          await AppStorage.instance.finish(
            TransferRecord(
              id: activityId,
              fileName: fileName,
              bytes: size,
              direction: 'Sent',
              status: 'Completed',
              peer: device.name,
              time: DateTime.now(),
              path: removedTemporaryPackage ? null : file.path,
              generatedAppPackage: generatedAppPackage,
              peerHost: device.host,
              peerPort: device.port,
              peerDeviceId: device.id,
              transferId: transferId,
              fileId: fileId,
              sha256: fileDigest,
              resumeToken: resumeToken,
            ),
          );
          completedCount++;
          if (mounted)
            setState(() {
              _queueStatuses.remove(file.path);
              _queuedRemoteNames.remove(file.path);
              _temporaryAppPackagePaths.remove(file.path);
              _queuedFiles = _queuedFiles
                  .where((item) => item.path != file.path)
                  .toList(growable: false);
              _sentCount++;
            });
          await TransferNotifications.instance.cancel(notificationId);
          await TransferNotifications.instance.complete(
            id: notificationId,
            title: 'Sent $fileName',
            success: true,
          );
        } catch (error) {
          final cancelled =
              error is TransferCancelledException || cancellation.isCancelled;
          await AppStorage.instance.finish(
            TransferRecord(
              id: activityId,
              fileName: fileName,
              bytes: size,
              direction: 'Sent',
              status: cancelled ? 'Cancelled' : 'Failed',
              peer: device.name,
              time: DateTime.now(),
              progress: _progress,
              path: file.path,
              generatedAppPackage: generatedAppPackage,
              peerHost: device.host,
              peerPort: device.port,
              peerDeviceId: device.id,
              transferId: transferId,
              fileId: fileId,
              sha256: fileDigest.isEmpty ? null : fileDigest,
              resumeToken: resumeToken,
            ),
          );
          if (mounted)
            setState(
              () => _queueStatuses[file.path] = cancelled
                  ? 'Cancelled'
                  : 'Failed',
            );
          await TransferNotifications.instance.cancel(notificationId);
          if (cancelled) rethrow;
          failedCount++;
        }
      }
      if (mounted)
        setState(() {
          _transferStatus = failedCount == 0
              ? 'Transfer complete: $completedCount file${completedCount == 1 ? '' : 's'} sent.'
              : 'Batch finished: $completedCount completed, $failedCount failed. Failed files remain queued.';
        });
    } catch (error) {
      if (mounted)
        setState(
          () => _transferStatus = error is TransferCancelledException
              ? 'Transfer cancelled.'
              : 'Transfer stopped: the other device may have declined, or the connection was lost.',
        );
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

String _formatBytes(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String _formatSpeed(double bytesPerSecond) =>
    _formatBytes(bytesPerSecond.round());
String _formatEta(int seconds) =>
    seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
bool _isRetryable(Object error) =>
    error is SocketException ||
    error is HttpException ||
    error is TimeoutException;

class _ManualConnectionDialog extends StatefulWidget {
  const _ManualConnectionDialog();
  @override
  State<_ManualConnectionDialog> createState() =>
      _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<_ManualConnectionDialog> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '43821');
  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect by IP'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _host,
          autofocus: true,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: AppLocalizations.translate(context, 'IP address'),
            hintText: '192.168.1.42',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _port,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.translate(context, 'Port'),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final port = int.tryParse(_port.text.trim());
          if (_host.text.trim().isNotEmpty && port != null)
            Navigator.pop(context, (_host.text.trim(), port));
        },
        child: const Text('Connect'),
      ),
    ],
  );
}

class TroubleshootingPage extends StatelessWidget {
  const TroubleshootingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Troubleshooting')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NetworkTestPage()),
          ),
          icon: const Icon(Icons.network_check),
          label: const Text('Run connection diagnostics'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Using Bifrost',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const _HelpItem(
          icon: Icons.send,
          title: 'Send a file',
          text: 'Open Nearby, choose a device, then pick files or drag them into the Windows window. The other device can accept or reject the transfer.',
        ),
        const _HelpItem(
          icon: Icons.share,
          title: 'Use Android Share',
          text: 'From Gallery or Files, tap Share and choose Bifrost. The selected files will appear in the Nearby queue.',
        ),
        const _HelpItem(
          icon: Icons.folder_open,
          title: 'Where files are saved',
          text: 'Received files go to Download/Bifrost by default. Change this in Settings → Save location.',
        ),
        const _HelpItem(
          icon: Icons.verified_user,
          title: 'Trusted devices',
          text: 'Trust a device when accepting a transfer to allow future transfers without asking. Remove it later from Settings → Trusted devices.',
        ),
        const SizedBox(height: 20),
        const Text(
          'If something fails',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const _HelpItem(
          icon: Icons.wifi,
          title: 'Same local network',
          text: 'Both devices must be connected to the same Wi-Fi router, or one phone must be connected to the other phone’s hotspot.',
        ),
        const _HelpItem(
          icon: Icons.router,
          title: 'Client isolation',
          text: 'Guest Wi-Fi and some hotspots block devices from talking to each other. Try the main home network or manual IP.',
        ),
        const _HelpItem(
          icon: Icons.vpn_lock,
          title: 'VPN',
          text: 'Temporarily disconnect a VPN. It can send local traffic through a different network.',
        ),
        const _HelpItem(
          icon: Icons.security,
          title: 'Windows network profile',
          text: 'Set the Windows network to Private and allow Bifrost through the Windows Firewall when prompted.',
        ),
        const _HelpItem(
          icon: Icons.pin,
          title: 'Manual IP fallback',
          text: 'Use Connect by IP when automatic discovery is blocked. Check the receiver address on Connection diagnostics.',
        ),
        const _HelpItem(
          icon: Icons.refresh,
          title: 'Retry failed transfers',
          text: 'Open History, select a failed sent file, and choose Retry transfer. Files that were moved or deleted can be removed from History.',
        ),
      ],
    ),
  );
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      isThreeLine: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(text),
    ),
  );
}

class _BifrostMark extends StatelessWidget {
  const _BifrostMark();
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      'assets/icon.png',
      width: 42,
      height: 42,
      fit: BoxFit.cover,
    ),
  );
}
