import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TransferNotifications {
  TransferNotifications._();
  static final instance = TransferNotifications._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready || !Platform.isAndroid) return;
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel('bifrost_transfers', 'Bifrost transfers', description: 'File transfer progress', importance: Importance.low, playSound: false));
    _ready = true;
  }

  Future<void> progress({required int id, required String title, required int sent, required int total}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    final percent = total == 0 ? 0 : ((sent * 100) ~/ total).clamp(0, 100);
    await _plugin.show(id, title, '$percent% • ${_format(sent)} of ${_format(total)}', NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', 'Bifrost transfers', channelDescription: 'File transfer progress', ongoing: true, onlyAlertOnce: true, showProgress: true, maxProgress: 100, progress: percent, playSound: false)));
  }

  Future<void> complete({required int id, required String title, required bool success, String? message}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id, title, message ?? (success ? 'Transfer complete' : 'Transfer failed'), NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', 'Bifrost transfers', channelDescription: 'File transfer progress', ongoing: false, autoCancel: true, importance: Importance.defaultImportance)));
  }
}

String _format(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
