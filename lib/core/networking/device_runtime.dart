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

  Future<void> ensureStarted() {
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final configured = await AppStorage.instance.saveDirectoryPath();
    final directory = configured == null ? await Directory.systemTemp.createTemp('bifrost-receive-') : Directory(configured);
    final id = 'device-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    final name = await AppStorage.instance.deviceName();
    await TransferNotifications.instance.initialize();
    final server = BifrostServer(saveDirectory: directory, deviceName: name, deviceId: id, onOffer: BifrostOfferBroker.instance.request, onFileProgress: (file, received, total) {
      TransferNotifications.instance.progress(id: file.fileId.hashCode, title: 'Receiving ${file.name}', sent: received, total: total);
    }, onFileReceived: (file, path) async {
      await AppStorage.instance.addHistory(TransferRecord(id: file.fileId, fileName: file.name, bytes: file.size, direction: 'Received', status: 'Completed', peer: 'Nearby device', time: DateTime.now()));
      await TransferNotifications.instance.complete(id: file.fileId.hashCode, title: 'Received ${file.name}', success: true);
    });
    await server.start(address: InternetAddress.anyIPv4);
    _server = server;
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

  Future<void> updateSaveDirectory(Directory directory) async {
    await AppStorage.instance.setSaveDirectoryPath(directory.path);
    if (_server == null) return;
    await close();
    _starting = _start();
    await _starting;
    _starting = null;
  }
}
