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
    required this.obbSizeBytes,
    required this.apkPaths,
    required this.hasObb,
    required this.obbAccessRequired,
    this.iconPng,
  });

  final String name;
  final String packageName;
  final String versionName;
  final int versionCode;
  final int sizeBytes;
  final int apkSizeBytes;
  final int obbSizeBytes;
  final List<String> apkPaths;
  final bool hasObb;
  final bool obbAccessRequired;
  final Uint8List? iconPng;

  factory TransferableApp.fromMap(Map<dynamic, dynamic> map) => TransferableApp(
    name: map['name'] as String? ?? 'Unknown app',
    packageName: map['packageName'] as String? ?? '',
    versionName: map['versionName'] as String? ?? '',
    versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
    sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    apkSizeBytes: (map['apkSizeBytes'] as num?)?.toInt() ?? 0,
    obbSizeBytes: (map['obbSizeBytes'] as num?)?.toInt() ?? 0,
    apkPaths: (map['apkPaths'] as List<dynamic>? ?? const []).cast<String>(),
    hasObb: map['hasObb'] as bool? ?? false,
    obbAccessRequired: map['obbAccessRequired'] as bool? ?? false,
    iconPng: map['iconPng'] is Uint8List ? map['iconPng'] as Uint8List : null,
  );
}

class AppTransferException implements Exception {
  const AppTransferException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Android PackageManager and PackageInstaller operations. XAPK I/O is streamed
/// natively so transferring large apps does not require holding entire APKs or
/// OBB archives in Dart memory.
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
      if (progress is num)
        _onProgress?.call(progress.toDouble().clamp(0, 1).toDouble());
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

  /// Create a streamed XAPK containing only base/split APKs and optional OBB.
  Future<File> createXapk(
    TransferableApp app, {
    void Function(double progress)? onProgress,
  }) async {
    _requireAndroid();
    if (app.apkPaths.isEmpty) {
      throw const AppTransferException('No APK files were found for this app.');
    }
    if ((app.hasObb || app.obbAccessRequired) && !await hasAllFilesAccess()) {
      throw const AppTransferException(
        'Android storage access is needed to include this app’s OBB files. Grant All files access and try again.',
        code: 'ALL_FILES_ACCESS_REQUIRED',
      );
    }
    _onProgress = onProgress;
    try {
      final path = await _channel.invokeMethod<String>('createXapk', {
        'name': app.name,
        'packageName': app.packageName,
        'versionName': app.versionName,
        'versionCode': app.versionCode,
        'apkPaths': app.apkPaths,
      });
      if (path == null || path.isEmpty) {
        throw const AppTransferException(
          'Android could not create the XAPK archive.',
        );
      }
      onProgress?.call(1);
      return File(path);
    } on PlatformException catch (error) {
      throw AppTransferException(
        error.message ?? 'Android could not package this app.',
        code: error.code,
      );
    } finally {
      _onProgress = null;
    }
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
