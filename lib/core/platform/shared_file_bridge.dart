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

  void addFiles(Iterable<String> paths) {
    final files = paths
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    _publishOrBuffer(files);
  }

  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'sharedFiles') {
          final paths = (call.arguments as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false);
          _publishOrBuffer(paths);
        }
      });
    }
    _flushPending();
    if (_fetchedSharedFiles) return;
    _fetchedSharedFiles = true;
    try {
      final paths =
          (await _channel.invokeMethod<List<dynamic>>('getSharedFiles') ??
                  const [])
              .whereType<String>()
              .toList(growable: false);
      _publishOrBuffer(paths);
    } on MissingPluginException {
      // Windows uses command-line arguments instead of the Android channel.
    }
  }

  bool _fetchedSharedFiles = false;

  void _publishOrBuffer(List<String> paths) {
    if (paths.isEmpty) return;
    if (_files.hasListener) {
      _files.add(paths);
    } else {
      _pending.addAll(paths);
    }
  }

  void _flushPending() {
    if (!_files.hasListener || _pending.isEmpty) return;
    final pending = List<String>.from(_pending);
    _pending.clear();
    _files.add(pending);
  }

  void dispose() => _files.close();
}
