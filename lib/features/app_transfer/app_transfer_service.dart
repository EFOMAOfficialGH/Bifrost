import 'dart:io';

import 'package:flutter/services.dart';

/// Installed user app metadata exposed by Android's PackageManager.
class TransferableApp {
  const TransferableApp({
    required this.name,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.sizeBytes,
    required this.apkSizeBytes,
    required this.apkPaths,
    required this.apkNames,
    this.iconPng,
  });

  final String name;
  final String packageName;
  final String versionName;
  final int versionCode;
  final int sizeBytes;
  final int apkSizeBytes;
  final List<String> apkPaths;
  final List<String> apkNames;
  final Uint8List? iconPng;

  factory TransferableApp.fromMap(Map<dynamic, dynamic> map) {
    final paths = (map['apkPaths'] as List<dynamic>? ?? const [])
        .cast<String>();
    final names = (map['apkNames'] as List<dynamic>? ?? const [])
        .cast<String>();
    return TransferableApp(
      name: map['name'] as String? ?? 'Unknown app',
      packageName: map['packageName'] as String? ?? '',
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      apkSizeBytes: (map['apkSizeBytes'] as num?)?.toInt() ?? 0,
      apkPaths: paths,
      apkNames: names.isEmpty
          ? paths.indexed
                .map(
                  (entry) => entry.$1 == 0
                      ? 'base.apk'
                      : File(entry.$2).uri.pathSegments.last,
                )
                .toList(growable: false)
          : names,
      iconPng: map['iconPng'] is Uint8List ? map['iconPng'] as Uint8List : null,
    );
  }
}

/// A selected app ready to enter the ordinary Bifrost file-transfer queue.
class AppTransferArtifact {
  const AppTransferArtifact({
    required this.file,
    required this.remoteName,
    required this.isTemporary,
    required this.isArchive,
  });

  final File file;
  final String remoteName;
  final bool isTemporary;
  final bool isArchive;

  factory AppTransferArtifact.fromMap(Map<dynamic, dynamic> map) {
    final path = map['path'] as String?;
    final remoteName = map['remoteName'] as String?;
    if (path == null ||
        path.isEmpty ||
        remoteName == null ||
        remoteName.isEmpty) {
      throw const AppTransferException(
        'Android returned an invalid app-transfer file.',
      );
    }
    return AppTransferArtifact(
      file: File(path),
      remoteName: remoteName,
      isTemporary: map['temporary'] as bool? ?? false,
      isArchive: map['isArchive'] as bool? ?? false,
    );
  }
}

class AppTransferException implements Exception {
  const AppTransferException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Android PackageManager and PackageInstaller operations. Multi-split/OBB
/// packages are streamed natively; a single APK without OBB is sent directly.
class AppTransferService {
  AppTransferService({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static const MethodChannel _defaultChannel = MethodChannel(
    'bifrost/app_transfer',
  );
  final MethodChannel _channel;
  void Function(double progress)? _onProgress;

  Future<Object?> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'packagingProgress') {
      final progress = call.arguments;
      if (progress is num) {
        _onProgress?.call(progress.toDouble().clamp(0, 1).toDouble());
      }
    }
    return null;
  }

  Future<List<TransferableApp>> listInstalledUserApps() async {
    _requireAndroid();
    final rows = await _channel.invokeListMethod<dynamic>(
      'listInstalledUserApps',
    );
    return (rows ?? const [])
        .whereType<Map>()
        .map(TransferableApp.fromMap)
        .toList();
  }

  Future<bool> canInstallUnknownApps() async =>
      await _channel.invokeMethod<bool>('canInstallUnknownApps') ?? false;

  Future<void> requestInstallUnknownApps() =>
      _channel.invokeMethod<void>('requestInstallUnknownApps');

  Future<bool> hasAllFilesAccess() async =>
      await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;

  Future<void> requestAllFilesAccess() =>
      _channel.invokeMethod<void>('requestAllFilesAccess');

  Future<AppTransferArtifact> prepareAppTransfer(
    TransferableApp app, {
    bool includeObb = false,
    void Function(double progress)? onProgress,
  }) async {
    _requireAndroid();
    if (app.apkPaths.isEmpty || app.apkNames.length != app.apkPaths.length) {
      throw const AppTransferException(
        'No valid APK files were found for this app.',
      );
    }
    if (includeObb && !await hasAllFilesAccess()) {
      await requestAllFilesAccess();
      throw const AppTransferException(
        'Grant All files access, return to Bifrost, and tap Send selected again to include optional OBB data.',
        code: 'ALL_FILES_ACCESS_REQUIRED',
      );
    }

    _onProgress = onProgress;
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>(
        'prepareAppTransfer',
        {
          'name': app.name,
          'packageName': app.packageName,
          'versionName': app.versionName,
          'versionCode': app.versionCode,
          'apkPaths': app.apkPaths,
          'apkNames': app.apkNames,
          'includeObb': includeObb,
        },
      );
      if (result == null) {
        throw const AppTransferException(
          'Android could not prepare this app for transfer.',
        );
      }
      onProgress?.call(1);
      return AppTransferArtifact.fromMap(result);
    } on PlatformException catch (error) {
      throw AppTransferException(
        error.message ?? 'Android could not prepare this app for transfer.',
        code: error.code,
      );
    } finally {
      _onProgress = null;
    }
  }

  Future<bool> deleteTemporaryExport(String path) async {
    _requireAndroid();
    try {
      return await _channel.invokeMethod<bool>('deleteTemporaryExport', {
            'path': path,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cleanupTemporaryExports(Iterable<String> retainedPaths) async {
    _requireAndroid();
    await _channel.invokeMethod<void>('cleanupTemporaryExports', {
      'retainedPaths': retainedPaths.toList(growable: false),
    });
  }

  /// Install all APK splits in one PackageInstaller session. OBB files are
  /// copied only after the APK install succeeds; platform errors remain visible.
  Future<void> installXapk(File xapk) async {
    _requireAndroid();
    if (!await xapk.exists()) {
      throw const AppTransferException(
        'The received XAPK file could not be found.',
      );
    }
    if (!await canInstallUnknownApps()) {
      await requestInstallUnknownApps();
      throw const AppTransferException(
        'Enable “Install unknown apps” for Bifrost in Settings, then retry installation.',
        code: 'UNKNOWN_SOURCES_NOT_ALLOWED',
      );
    }
    try {
      await _channel.invokeMethod<void>('installXapk', {'path': xapk.path});
    } on PlatformException catch (error) {
      throw AppTransferException(
        error.message ?? 'Android could not install this app.',
        code: error.code,
      );
    }
  }

  void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw const AppTransferException(
        'App Transfer is available on Android only.',
      );
    }
  }
}
