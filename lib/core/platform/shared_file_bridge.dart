import 'dart:async';

import 'package:flutter/services.dart';

class SharedFileBridge {
  SharedFileBridge._();
  static final instance = SharedFileBridge._();
  static const _channel = MethodChannel('bifrost/share');
  final _files = StreamController<List<String>>.broadcast();
  final _pending = <String>[];
  bool _initialized = false;

  Stream<List<String>> get files => _files.stream;

  void seed(Iterable<String> paths) {
    _pending.addAll(paths.where((path) => path.trim().isNotEmpty));
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedFiles') {
        final paths = (call.arguments as List<dynamic>? ?? const []).whereType<String>().toList(growable: false);
        if (paths.isNotEmpty) _files.add(paths);
      }
    });
    if (_pending.isNotEmpty) {
      _files.add(List<String>.from(_pending));
      _pending.clear();
    }
    try {
      final paths = (await _channel.invokeMethod<List<dynamic>>('getSharedFiles') ?? const []).whereType<String>().toList(growable: false);
      if (paths.isNotEmpty) _files.add(paths);
    } on MissingPluginException {
      // Windows uses command-line arguments instead of the Android channel.
    }
  }

  void dispose() => _files.close();
}
