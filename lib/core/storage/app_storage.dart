import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TransferRecord {
  const TransferRecord({required this.id, required this.fileName, required this.bytes, required this.direction, required this.status, required this.peer, required this.time});
  final String id;
  final String fileName;
  final int bytes;
  final String direction;
  final String status;
  final String peer;
  final DateTime time;

  Map<String, dynamic> toJson() => {'id': id, 'fileName': fileName, 'bytes': bytes, 'direction': direction, 'status': status, 'peer': peer, 'time': time.toIso8601String()};
  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(id: json['id'] as String, fileName: json['fileName'] as String, bytes: json['bytes'] as int, direction: json['direction'] as String, status: json['status'] as String, peer: json['peer'] as String, time: DateTime.parse(json['time'] as String));
}

class AppStorage {
  AppStorage._();
  static final instance = AppStorage._();
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async => _prefs ??= await SharedPreferences.getInstance();
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
}
