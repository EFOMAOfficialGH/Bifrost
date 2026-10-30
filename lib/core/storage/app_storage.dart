import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.fileName,
    required this.bytes,
    required this.direction,
    required this.status,
    required this.peer,
    required this.time,
    this.progress = 1,
    this.path,
    this.speedBytesPerSecond = 0,
    this.etaSeconds,
    this.peerHost,
    this.peerPort,
    this.peerDeviceId,
    this.transferId,
    this.fileId,
    this.sha256,
    this.resumeToken,
    this.generatedAppPackage = false,
  });
  final String id;
  final String fileName;
  final int bytes;
  final String direction;
  final String status;
  final String peer;
  final DateTime time;
  final double progress;
  final String? path;
  final double speedBytesPerSecond;
  final int? etaSeconds;
  final String? peerHost;
  final int? peerPort;
  final String? peerDeviceId;
  final String? transferId;
  final String? fileId;
  final String? sha256;
  final String? resumeToken;
  final bool generatedAppPackage;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'bytes': bytes,
    'direction': direction,
    'status': status,
    'peer': peer,
    'time': time.toIso8601String(),
    'progress': progress,
    'path': path,
    'speedBytesPerSecond': speedBytesPerSecond,
    'etaSeconds': etaSeconds,
    'peerHost': peerHost,
    'peerPort': peerPort,
    'peerDeviceId': peerDeviceId,
    'transferId': transferId,
    'fileId': fileId,
    'sha256': sha256,
    'resumeToken': resumeToken,
    'generatedAppPackage': generatedAppPackage,
  };
  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
    id: json['id'] as String,
    fileName: json['fileName'] as String,
    bytes: (json['bytes'] as num).toInt(),
    direction: json['direction'] as String,
    status: json['status'] as String,
    peer: json['peer'] as String,
    time: DateTime.parse(json['time'] as String),
    progress: (json['progress'] as num?)?.toDouble() ?? 1,
    path: json['path'] as String?,
    speedBytesPerSecond: (json['speedBytesPerSecond'] as num?)?.toDouble() ?? 0,
    etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
    peerHost: json['peerHost'] as String?,
    peerPort: (json['peerPort'] as num?)?.toInt(),
    peerDeviceId: json['peerDeviceId'] as String?,
    transferId: json['transferId'] as String?,
    fileId: json['fileId'] as String?,
    sha256: json['sha256'] as String?,
    resumeToken: json['resumeToken'] as String?,
    generatedAppPackage: json['generatedAppPackage'] as bool? ?? false,
  );

  TransferRecord copyWith({String? status, double? progress}) => TransferRecord(
    id: id,
    fileName: fileName,
    bytes: bytes,
    direction: direction,
    status: status ?? this.status,
    peer: peer,
    time: time,
    progress: progress ?? this.progress,
    path: path,
    speedBytesPerSecond: speedBytesPerSecond,
    etaSeconds: etaSeconds,
    peerHost: peerHost,
    peerPort: peerPort,
    peerDeviceId: peerDeviceId,
    transferId: transferId,
    fileId: fileId,
    sha256: sha256,
    resumeToken: resumeToken,
    generatedAppPackage: generatedAppPackage,
  );
}

class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.name,
    required this.lastSeen,
  });
  final String id;
  final String name;
  final DateTime lastSeen;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lastSeen': lastSeen.toIso8601String(),
  };
  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Unknown device',
    lastSeen:
        DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
  );
}

class AppStorage {
  AppStorage._();
  static final instance = AppStorage._();
  SharedPreferences? _prefs;
  final _activity = StreamController<TransferRecord>.broadcast();
  final _active = <String, TransferRecord>{};
  final _cancellers = <String, Future<void> Function()>{};

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();
  Stream<TransferRecord> get activities => _activity.stream;
  List<TransferRecord> get activeTransfers =>
      _active.values.toList(growable: false);

  Future<String?> saveDirectoryPath() async =>
      (await _preferences).getString('saveDirectoryPath');
  Future<void> setSaveDirectoryPath(String path) async =>
      (await _preferences).setString('saveDirectoryPath', path);
  Future<String> languageChoice() async =>
      (await _preferences).getString('languageChoice') == 'ar' ? 'ar' : 'en';
  Future<void> setLanguageChoice(String language) async {
    final prefs = await _preferences;
    final normalized = language == 'ar' ? 'ar' : 'en';
    await prefs.setString('languageChoice', normalized);
    final currentName = prefs.getString('deviceName');
    if (currentName == null ||
        currentName == 'Bifrost Device' ||
        currentName == 'جهاز بايفروست') {
      await prefs.setString(
        'deviceName',
        normalized == 'ar' ? 'جهاز بايفروست' : 'Bifrost Device',
      );
    }
  }

  Future<String> deviceName() async {
    final prefs = await _preferences;
    final currentName = prefs.getString('deviceName');
    if (currentName == null ||
        currentName == 'Bifrost Device' ||
        currentName == 'جهاز بايفروست') {
      return prefs.getString('languageChoice') == 'ar'
          ? 'جهاز بايفروست'
          : 'Bifrost Device';
    }
    return currentName;
  }

  Future<void> setDeviceName(String name) async =>
      (await _preferences).setString('deviceName', name);
  Future<bool> backgroundActivity() async =>
      (await _preferences).getBool('backgroundActivity') ?? true;
  Future<void> setBackgroundActivity(bool enabled) async =>
      (await _preferences).setBool('backgroundActivity', enabled);
  Future<bool> startWithWindows() async =>
      (await _preferences).getBool('startWithWindows') ?? true;
  Future<void> setStartWithWindows(bool enabled) async =>
      (await _preferences).setBool('startWithWindows', enabled);
  Future<bool> automaticUpdateChecks() async =>
      (await _preferences).getBool('automaticUpdateChecks') ?? true;
  Future<void> setAutomaticUpdateChecks(bool enabled) async =>
      (await _preferences).setBool('automaticUpdateChecks', enabled);
  Future<String> themeChoice() async =>
      (await _preferences).getString('themeChoice') ?? 'day';
  Future<void> setThemeChoice(String choice) async =>
      (await _preferences).setString('themeChoice', choice);
  Future<String?> customThemeColor() async =>
      (await _preferences).getString('customThemeColor');
  Future<void> setCustomThemeColor(String value) async =>
      (await _preferences).setString('customThemeColor', value);
  Future<String?> textColor() async =>
      (await _preferences).getString('textColor');
  Future<void> setTextColor(String value) async =>
      (await _preferences).setString('textColor', value);
  Future<void> clearTextColor() async =>
      (await _preferences).remove('textColor');
  Future<bool> onboardingComplete() async {
    final prefs = await _preferences;
    if (prefs.getBool('onboardingComplete') == true) return true;
    // Existing installations that already chose a save folder should not be interrupted.
    // Older installs with only a device name still need the new folder setup.
    if (prefs.containsKey('saveDirectoryPath')) {
      await prefs.setBool('onboardingComplete', true);
      return true;
    }
    return false;
  }

  Future<void> setOnboardingComplete() async =>
      (await _preferences).setBool('onboardingComplete', true);

  String defaultSaveDirectory() {
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null)
        return '$profile${Platform.pathSeparator}Downloads${Platform.pathSeparator}Bifrost';
    }
    if (Platform.isAndroid) return '/storage/emulated/0/Download/Bifrost';
    final home = Platform.environment['HOME'];
    if (home != null)
      return '$home${Platform.pathSeparator}Downloads${Platform.pathSeparator}Bifrost';
    return '${Directory.systemTemp.path}${Platform.pathSeparator}Bifrost';
  }

  Future<String> deviceId() async {
    final prefs = await _preferences;
    final existing = prefs.getString('deviceId');
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id =
        'device-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString('deviceId', id);
    return id;
  }

  String newResumeToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<TransferRecord>> history() async {
    final raw =
        (await _preferences).getStringList('transferHistory') ?? const [];
    final records = raw.map(
      (item) =>
          TransferRecord.fromJson(jsonDecode(item) as Map<String, dynamic>),
    );
    return records
        .map(
          (record) =>
              record.status == 'In progress' && !_active.containsKey(record.id)
              ? record.copyWith(status: 'Interrupted')
              : record,
        )
        .toList(growable: false);
  }

  Future<void> addHistory(TransferRecord record) async {
    final records =
        (await history()).where((item) => item.id != record.id).toList()
          ..insert(0, record);
    final trimmed = records
        .take(100)
        .map((item) => jsonEncode(item.toJson()))
        .toList(growable: false);
    await (await _preferences).setStringList('transferHistory', trimmed);
  }

  Future<void> clearHistory() async =>
      (await _preferences).remove('transferHistory');

  Future<void> deleteHistory(String id) async {
    final records = (await history())
        .where((record) => record.id != id)
        .map((record) => jsonEncode(record.toJson()))
        .toList(growable: false);
    await (await _preferences).setStringList('transferHistory', records);
  }

  Future<List<TrustedDevice>> trustedDevices() async {
    final prefs = await _preferences;
    final structured = prefs.getStringList('trustedDeviceRecords');
    if (structured != null)
      return structured
          .map(
            (item) => TrustedDevice.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);
    final legacy = prefs.getStringList('trustedDevices') ?? const [];
    return legacy
        .map(
          (id) => TrustedDevice(
            id: id,
            name: 'Trusted device',
            lastSeen: DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> isTrusted(String deviceId) async =>
      (await trustedDevices()).any((device) => device.id == deviceId);

  Future<void> setTrusted(
    String deviceId,
    bool trusted, {
    String name = 'Trusted device',
  }) async {
    final prefs = await _preferences;
    final devices = (await trustedDevices())
        .where((device) => device.id != deviceId)
        .toList();
    if (trusted)
      devices.add(
        TrustedDevice(id: deviceId, name: name, lastSeen: DateTime.now()),
      );
    await prefs.setStringList(
      'trustedDeviceRecords',
      devices.map((device) => jsonEncode(device.toJson())).toList(),
    );
    await prefs.remove('trustedDevices');
  }

  Future<Set<String>> favoriteDeviceIds() async =>
      ((await _preferences).getStringList('favoriteDeviceIds') ??
              const <String>[])
          .toSet();

  Future<bool> isFavoriteDevice(String deviceId) async =>
      (await favoriteDeviceIds()).contains(deviceId);

  Future<void> setFavoriteDevice(String deviceId, bool favorite) async {
    if (deviceId.trim().isEmpty) return;
    final prefs = await _preferences;
    final ids = (prefs.getStringList('favoriteDeviceIds') ?? const <String>[])
        .toSet();
    if (favorite) {
      ids.add(deviceId);
    } else {
      ids.remove(deviceId);
    }
    await prefs.setStringList('favoriteDeviceIds', ids.toList(growable: false));
  }

  Future<void> touchTrusted(String deviceId, String name) async {
    final devices = await trustedDevices();
    if (!devices.any((device) => device.id == deviceId)) return;
    await setTrusted(deviceId, true, name: name);
  }

  void begin(TransferRecord record) {
    _active[record.id] = record;
    _activity.add(record);
  }

  Future<void> beginPersistent(TransferRecord record) async {
    begin(record);
    await addHistory(record);
  }

  Future<void> updateResumeMetadata(
    String id, {
    required String sha256,
    required int bytes,
  }) async {
    final current = _active[id];
    if (current == null) return;
    final updated = TransferRecord(
      id: current.id,
      fileName: current.fileName,
      bytes: bytes,
      direction: current.direction,
      status: current.status,
      peer: current.peer,
      time: current.time,
      progress: current.progress,
      path: current.path,
      speedBytesPerSecond: current.speedBytesPerSecond,
      etaSeconds: current.etaSeconds,
      peerHost: current.peerHost,
      peerPort: current.peerPort,
      peerDeviceId: current.peerDeviceId,
      transferId: current.transferId,
      fileId: current.fileId,
      sha256: sha256,
      resumeToken: current.resumeToken,
      generatedAppPackage: current.generatedAppPackage,
    );
    _active[id] = updated;
    _activity.add(updated);
    await addHistory(updated);
  }

  void registerCancellation(String id, Future<void> Function() cancel) =>
      _cancellers[id] = cancel;

  Future<void> cancelTransfer(String id) async {
    final cancel = _cancellers[id];
    if (cancel != null) await cancel();
  }

  void update(String id, int sent, int total) {
    final current = _active[id];
    if (current == null) return;
    final progress = total == 0 ? 1.0 : (sent / total).clamp(0.0, 1.0);
    final elapsed =
        DateTime.now().difference(current.time).inMilliseconds / 1000;
    final speed = elapsed <= 0 ? 0.0 : sent / elapsed;
    final eta = speed <= 0
        ? null
        : ((total - sent) / speed).ceil().clamp(0, 864000);
    final next = TransferRecord(
      id: current.id,
      fileName: current.fileName,
      bytes: total,
      direction: current.direction,
      status: 'In progress',
      peer: current.peer,
      time: current.time,
      progress: progress,
      speedBytesPerSecond: speed,
      etaSeconds: eta,
      peerHost: current.peerHost,
      peerPort: current.peerPort,
      peerDeviceId: current.peerDeviceId,
      transferId: current.transferId,
      fileId: current.fileId,
      sha256: current.sha256,
      resumeToken: current.resumeToken,
      path: current.path,
      generatedAppPackage: current.generatedAppPackage,
    );
    _active[id] = next;
    _activity.add(next);
  }

  Future<void> finish(TransferRecord record) async {
    _active.remove(record.id);
    _cancellers.remove(record.id);
    _activity.add(record);
    await addHistory(record);
  }
}
