import 'dart:io';

import 'bifrost_server.dart';

class BifrostDeviceRuntime {
  BifrostDeviceRuntime._();
  static final instance = BifrostDeviceRuntime._();

  BifrostServer? _server;
  Future<void>? _starting;

  String get deviceId => _server?.deviceId ?? '';
  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;

  Future<void> ensureStarted() {
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final directory = await Directory.systemTemp.createTemp('bifrost-receive-');
    final id = 'device-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    final server = BifrostServer(saveDirectory: directory, deviceName: 'Bifrost Device', deviceId: id);
    await server.start(address: InternetAddress.anyIPv4);
    _server = server;
  }

  Future<void> close() async {
    await _server?.close();
    _server = null;
    _starting = null;
  }
}
