import 'dart:io';

import 'bifrost_server.dart';
import 'offer_broker.dart';
import '../notifications/transfer_notifications.dart';
import '../storage/app_storage.dart';

class BifrostDeviceRuntime {
  BifrostDeviceRuntime._();
  static final instance = BifrostDeviceRuntime._();

  BifrostServer? _server;
  Future<void>? _starting;

  String get deviceId => _server?.deviceId ?? '';
  String get deviceName => _server?.deviceName ?? 'Bifrost Device';
  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  Future<void> ensureStarted() => _starting ??= _start();

  Future<void> _start() async {
    final configured = await AppStorage.instance.saveDirectoryPath();
    final directory = configured == null ? await Directory.systemTemp.createTemp('bifrost-receive-') : Directory(configured);
    final id = await AppStorage.instance.deviceId();
    final name = await AppStorage.instance.deviceName();
    await TransferNotifications.instance.initialize();
    final server = BifrostServer(saveDirectory: directory, deviceName: name, deviceId: id, onOfferWithSender: (offer, senderId, senderName) async {
      if (senderId != null && await AppStorage.instance.isTrusted(senderId)) {
        await AppStorage.instance.touchTrusted(senderId, senderName ?? 'Trusted device');
        return true;
      }
      return BifrostOfferBroker.instance.request(offer, senderId, senderName);
    }, onFileProgress: (file, received, total) {
      if (!AppStorage.instance.activeTransfers.any((item) => item.id == file.fileId)) {
        AppStorage.instance.begin(TransferRecord(id: file.fileId, fileName: file.name, bytes: total, direction: 'Received', status: 'In progress', peer: 'Nearby device', time: DateTime.now(), progress: 0));
      }
      AppStorage.instance.update(file.fileId, received, total);
      TransferNotifications.instance.progress(id: file.fileId.hashCode, title: 'Receiving ${file.name}', sent: received, total: total);
    }, onFileReceived: (file, path) async {
      await AppStorage.instance.finish(TransferRecord(id: file.fileId, fileName: file.name, bytes: file.size, direction: 'Received', status: 'Completed', peer: 'Nearby device', time: DateTime.now()));
      await TransferNotifications.instance.complete(id: file.fileId.hashCode, title: 'Received ${file.name}', success: true);
    });
    await server.start(address: InternetAddress.anyIPv4, port: Platform.isWindows ? 43821 : 0);
    _server = server;
    if (await AppStorage.instance.backgroundActivity()) await TransferNotifications.instance.backgroundReady();
  }

  Future<void> close() async {
    await _server?.close();
    _server = null;
    _starting = null;
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
    }
  }

  Future<void> updateSaveDirectory(Directory directory) async {
    await AppStorage.instance.setSaveDirectoryPath(directory.path);
    if (_server == null) return;
    await close();
    _starting = _start();
    await _starting;
    _starting = null;
  }
}
