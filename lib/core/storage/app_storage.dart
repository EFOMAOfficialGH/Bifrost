import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class TransferRecord {
  const TransferRecord({required this.id, required this.fileName, required this.bytes, required this.direction, required this.status, required this.peer, required this.time, this.progress = 1});
  final String id;
  final String fileName;
  final int bytes;
  final String direction;
  final String status;
  final String peer;
  final DateTime time;
  final double progress;

  Map<String, dynamic> toJson() => {'id': id, 'fileName': fileName, 'bytes': bytes, 'direction': direction, 'status': status, 'peer': peer, 'time': time.toIso8601String(), 'progress': progress};
  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(id: json['id'] as String, fileName: json['fileName'] as String, bytes: (json['bytes'] as num).toInt(), direction: json['direction'] as String, status: json['status'] as String, peer: json['peer'] as String, time: DateTime.parse(json['time'] as String), progress: (json['progress'] as num?)?.toDouble() ?? 1);
}

class TrustedDevice {
  const TrustedDevice({required this.id, required this.name, required this.lastSeen});
  final String id;
  final String name;
  final DateTime lastSeen;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'lastSeen': lastSeen.toIso8601String()};
  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(id: json['id'] as String, name: json['name'] as String? ?? 'Unknown device', lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now());
}

class AppStorage {
  AppStorage._();
  static final instance = AppStorage._();
  SharedPreferences? _prefs;
  final _activity = StreamController<TransferRecord>.broadcast();
  final _active = <String, TransferRecord>{};

  Future<SharedPreferences> get _preferences async => _prefs ??= await SharedPreferences.getInstance();
  Stream<TransferRecord> get activities => _activity.stream;
  List<TransferRecord> get activeTransfers => _active.values.toList(growable: false);

  Future<String?> saveDirectoryPath() async => (await _preferences).getString('saveDirectoryPath');
  Future<void> setSaveDirectoryPath(String path) async => (await _preferences).setString('saveDirectoryPath', path);
  Future<String> deviceName() async => (await _preferences).getString('deviceName') ?? 'Bifrost Device';
  Future<void> setDeviceName(String name) async => (await _preferences).setString('deviceName', name);
  Future<bool> backgroundActivity() async => (await _preferences).getBool('backgroundActivity') ?? false;
  Future<void> setBackgroundActivity(bool enabled) async => (await _preferences).setBool('backgroundActivity', enabled);

  Future<String> deviceId() async {
    final prefs = await _preferences;
    final existing = prefs.getString('deviceId');
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = 'device-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString('deviceId', id);
    return id;
  }

  Future<List<TransferRecord>> history() async {
    final raw = (await _preferences).getStringList('transferHistory') ?? const [];
    return raw.map((item) => TransferRecord.fromJson(jsonDecode(item) as Map<String, dynamic>)).toList(growable: false);
  }

  Future<void> addHistory(TransferRecord record) async {
    final records = (await history()).where((item) => item.id != record.id).toList()..insert(0, record);
    final trimmed = records.take(100).map((item) => jsonEncode(item.toJson())).toList(growable: false);
    await (await _preferences).setStringList('transferHistory', trimmed);
  }

  Future<void> clearHistory() async => (await _preferences).remove('transferHistory');

  Future<List<TrustedDevice>> trustedDevices() async {
    final prefs = await _preferences;
    final structured = prefs.getStringList('trustedDeviceRecords');
    if (structured != null) return structured.map((item) => TrustedDevice.fromJson(jsonDecode(item) as Map<String, dynamic>)).toList(growable: false);
    final legacy = prefs.getStringList('trustedDevices') ?? const [];
    return legacy.map((id) => TrustedDevice(id: id, name: 'Trusted device', lastSeen: DateTime.now())).toList(growable: false);
  }

  Future<bool> isTrusted(String deviceId) async => (await trustedDevices()).any((device) => device.id == deviceId);

  Future<void> setTrusted(String deviceId, bool trusted, {String name = 'Trusted device'}) async {
    final prefs = await _preferences;
    final devices = (await trustedDevices()).where((device) => device.id != deviceId).toList();
    if (trusted) devices.add(TrustedDevice(id: deviceId, name: name, lastSeen: DateTime.now()));
    await prefs.setStringList('trustedDeviceRecords', devices.map((device) => jsonEncode(device.toJson())).toList());
    await prefs.remove('trustedDevices');
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

  void update(String id, int sent, int total) {
    final current = _active[id];
    if (current == null) return;
    final progress = total == 0 ? 1.0 : (sent / total).clamp(0.0, 1.0);
    final next = TransferRecord(id: current.id, fileName: current.fileName, bytes: total, direction: current.direction, status: 'In progress', peer: current.peer, time: current.time, progress: progress);
    _active[id] = next;
    _activity.add(next);
  }

  Future<void> finish(TransferRecord record) async {
    _active.remove(record.id);
    _activity.add(record);
    await addHistory(record);
  }
}
