import 'dart:async';
import 'dart:io';

import 'bifrost_server.dart';
import 'offer_broker.dart';
import '../localization/app_localizations.dart';
import '../notifications/transfer_notifications.dart';
import '../storage/app_storage.dart';

class BifrostDeviceRuntime {
  BifrostDeviceRuntime._();
  static final instance = BifrostDeviceRuntime._();

  BifrostServer? _server;
  Future<void>? _starting;
  Timer? _networkMonitor;
  String? _networkSignature;

  String get deviceId => _server?.deviceId ?? '';
  String get deviceName =>
      _server?.deviceName ??
      AppLocalizations.translateCurrent('Bifrost Device');
  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  Future<void> ensureStarted() async {
    if (_server != null) return;
    final pending = _starting;
    if (pending != null) {
      await pending;
      return;
    }
    final attempt = _start();
    _starting = attempt;
    try {
      await attempt;
    } finally {
      if (identical(_starting, attempt)) _starting = null;
    }
  }

  Future<void> _start() async {
    final configured = await AppStorage.instance.saveDirectoryPath();
    final preferred = Directory(
      configured ?? AppStorage.instance.defaultSaveDirectory(),
    );
    late Directory directory;
    try {
      await preferred.create(recursive: true);
      directory = preferred;
    } catch (_) {
      directory = await Directory.systemTemp.createTemp('bifrost-receive-');
    }
    final id = await AppStorage.instance.deviceId();
    final name = await AppStorage.instance.deviceName();
    TransferNotifications.instance.onBackgroundNotificationTapped = () =>
        setBackgroundActivity(false);
    await TransferNotifications.instance.initialize();
    late BifrostServer server;
    server = BifrostServer(
      saveDirectory: directory,
      deviceName: name,
      deviceId: id,
      onOfferWithSender: (offer, senderId, senderName) async {
        if (senderId != null && await AppStorage.instance.isTrusted(senderId)) {
          await AppStorage.instance.touchTrusted(
            senderId,
            senderName ?? 'Trusted device',
          );
          return true;
        }
        return BifrostOfferBroker.instance.request(offer, senderId, senderName);
      },
      onFileProgress: (file, received, total, transferId) {
        if (!AppStorage.instance.activeTransfers.any(
          (item) => item.id == file.fileId,
        )) {
          AppStorage.instance.begin(
            TransferRecord(
              id: file.fileId,
              fileName: file.name,
              bytes: total,
              direction: 'Received',
              status: 'In progress',
              peer: 'Nearby device',
              time: DateTime.now(),
              progress: 0,
            ),
          );
          AppStorage.instance.registerCancellation(
            file.fileId,
            () => server.cancelTransfer(transferId),
          );
        }
        AppStorage.instance.update(file.fileId, received, total);
        TransferNotifications.instance.progress(
          id: file.fileId.hashCode,
          title: 'Receiving ${file.name}',
          sent: received,
          total: total,
        );
      },
      onFileReceived: (file, path) async {
        await AppStorage.instance.finish(
          TransferRecord(
            id: file.fileId,
            fileName: file.name,
            bytes: file.size,
            direction: 'Received',
            status: 'Completed',
            peer: 'Nearby device',
            time: DateTime.now(),
            path: path,
          ),
        );
        await TransferNotifications.instance.cancel(file.fileId.hashCode);
        await TransferNotifications.instance.complete(
          id: file.fileId.hashCode,
          title: 'Received ${file.name}',
          success: true,
        );
      },
      onFileCancelled: (file) async {
        await AppStorage.instance.finish(
          TransferRecord(
            id: file.fileId,
            fileName: file.name,
            bytes: file.size,
            direction: 'Received',
            status: 'Cancelled',
            peer: 'Nearby device',
            time: DateTime.now(),
            progress: 0,
          ),
        );
        await TransferNotifications.instance.cancel(file.fileId.hashCode);
      },
    );
    try {
      await server.start(address: InternetAddress.anyIPv4, port: 43821);
    } catch (_) {
      await server.close();
      rethrow;
    }
    _server = server;
    await _startNetworkMonitor(server);
    if (await AppStorage.instance.backgroundActivity())
      await TransferNotifications.instance.backgroundReady();
  }

  Future<void> close() async {
    _networkMonitor?.cancel();
    _networkMonitor = null;
    _networkSignature = null;
    await _server?.close();
    _server = null;
    _starting = null;
  }

  Future<void> _startNetworkMonitor(BifrostServer server) async {
    _networkMonitor?.cancel();
    _networkSignature = await _currentNetworkSignature();
    if (!identical(_server, server)) return;
    _networkMonitor = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshDiscoveryAfterNetworkChange(server));
    });
  }

  Future<String> _currentNetworkSignature() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = <String>[];
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          addresses.add('${interface.name}:${address.address}');
        }
      }
      addresses.sort();
      return addresses.join('|');
    } on SocketException {
      return '';
    }
  }

  Future<void> _refreshDiscoveryAfterNetworkChange(BifrostServer server) async {
    if (!identical(_server, server)) return;
    try {
      final current = await _currentNetworkSignature();
      if (!identical(_server, server) || current == _networkSignature) return;
      await server.refreshDiscovery();
      _networkSignature = current;
    } catch (_) {
      // The next interface check will retry the discovery socket rebind.
    }
  }

  void updateDeviceName(String value) {
    AppStorage.instance.setDeviceName(value);
    _server?.updateDeviceName(value);
  }

  Future<void> setBackgroundActivity(bool enabled) async {
    await AppStorage.instance.setBackgroundActivity(enabled);
    if (enabled) {
      await ensureStarted();
      await TransferNotifications.instance.backgroundReady();
    } else {
      await TransferNotifications.instance.clearBackgroundReady();
      await close();
    }
  }

  Future<void> updateSaveDirectory(Directory directory) async {
    await AppStorage.instance.setSaveDirectoryPath(directory.path);
    if (_server == null) return;
    await close();
    await ensureStarted();
  }
}
