import 'dart:async';
import 'dart:convert';

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
  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(id: json['id'] as String, fileName: json['fileName'] as String, bytes: json['bytes'] as int, direction: json['direction'] as String, status: json['status'] as String, peer: json['peer'] as String, time: DateTime.parse(json['time'] as String), progress: (json['progress'] as num?)?.toDouble() ?? 1);
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

  Future<List<TransferRecord>> history() async {
    final raw = (await _preferences).getStringList('transferHistory') ?? const [];
    return raw.map((item) => TransferRecord.fromJson(jsonDecode(item) as Map<String, dynamic>)).toList(growable: false);
  }

  Future<void> addHistory(TransferRecord record) async {
    final records = (await history()).toList()..insert(0, record);
    final trimmed = records.take(100).map((item) => jsonEncode(item.toJson())).toList(growable: false);
    await (await _preferences).setStringList('transferHistory', trimmed);
  }

  Future<void> clearHistory() async => (await _preferences).remove('transferHistory');

  Future<Set<String>> trustedDevices() async => (await _preferences).getStringList('trustedDevices')?.toSet() ?? <String>{};
  Future<bool> isTrusted(String deviceId) async => (await trustedDevices()).contains(deviceId);
  Future<void> setTrusted(String deviceId, bool trusted) async {
    final devices = await trustedDevices();
    trusted ? devices.add(deviceId) : devices.remove(deviceId);
    await (await _preferences).setStringList('trustedDevices', devices.toList());
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
