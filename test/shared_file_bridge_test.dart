import 'dart:async';

import 'package:bifrost/core/platform/shared_file_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buffers paths until the queue listener is available', () async {
    const channel = MethodChannel('bifrost/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => const <String>[]);

    final bridge = SharedFileBridge.instance;
    bridge.addFiles(const ['/drop/first.txt']);

    final firstReceived = Completer<List<String>>();
    final firstSubscription = bridge.files.listen((paths) {
      if (!firstReceived.isCompleted) firstReceived.complete(paths);
    });
    await bridge.initialize();
    expect(await firstReceived.future, ['/drop/first.txt']);
    await firstSubscription.cancel();

    bridge.addFiles(const ['/drop/second.txt']);
    final secondReceived = Completer<List<String>>();
    final secondSubscription = bridge.files.listen((paths) {
      if (!secondReceived.isCompleted) secondReceived.complete(paths);
    });
    await bridge.initialize();
    expect(await secondReceived.future, ['/drop/second.txt']);
    await secondSubscription.cancel();
  });
}
