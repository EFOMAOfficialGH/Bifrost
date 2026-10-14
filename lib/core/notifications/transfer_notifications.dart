import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TransferNotifications {
  TransferNotifications._();
  static final instance = TransferNotifications._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> Function()? onBackgroundNotificationTapped;

  Future<void> initialize() async {
    if (_ready || !Platform.isAndroid) return;
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: (response) async {
      if (response.id == 987654) await onBackgroundNotificationTapped?.call();
    });
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel('bifrost_transfers', 'Bifrost transfers', description: 'File transfer progress', importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(const AndroidNotificationChannel('bifrost_incoming', 'Incoming transfers', description: 'Incoming file transfer requests', importance: Importance.high, playSound: true));
    await android?.createNotificationChannel(const AndroidNotificationChannel('bifrost_background', 'Background receiving', description: 'Keeps Bifrost available while the app is in the background', importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(const AndroidNotificationChannel('bifrost_updates', 'Bifrost updates', description: 'Bifrost update download progress', importance: Importance.low, playSound: false));
    _ready = true;
  }

  Future<void> progress({required int id, required String title, required int sent, required int total, double speedBytesPerSecond = 0, int? etaSeconds}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    final percent = total == 0 ? 0 : ((sent * 100) ~/ total).clamp(0, 100);
    final details = speedBytesPerSecond > 0 ? ' • ${_format(speedBytesPerSecond.round())}/s${etaSeconds == null ? '' : ' • ${etaSeconds}s left'}' : '';
    await _plugin.show(id: id, title: title, body: '$percent% • ${_format(sent)} of ${_format(total)}$details', notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', 'Bifrost transfers', channelDescription: 'File transfer progress', ongoing: true, onlyAlertOnce: true, showProgress: true, maxProgress: 100, progress: percent, playSound: false)));
  }

  Future<void> updateProgress({required int received, required int total, double speedBytesPerSecond = 0, int? etaSeconds}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    final percent = total == 0 ? 0 : ((received * 100) ~/ total).clamp(0, 100);
    final details = speedBytesPerSecond > 0 ? ' • ${_format(speedBytesPerSecond.round())}/s${etaSeconds == null ? '' : ' • ${etaSeconds}s left'}' : '';
    await _plugin.show(id: 987655, title: 'Downloading Bifrost update', body: '$percent% • ${_format(received)} of ${_format(total)}$details', notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_updates', 'Bifrost updates', channelDescription: 'Bifrost update download progress', ongoing: true, autoCancel: false, onlyAlertOnce: true, showProgress: true, maxProgress: 100, progress: percent, importance: Importance.low, playSound: false)));
  }

  Future<void> updateComplete({required String version}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: 987655, title: 'Bifrost update downloaded', body: 'Version $version is ready to install', notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('bifrost_updates', 'Bifrost updates', channelDescription: 'Bifrost update download progress', ongoing: false, autoCancel: true, importance: Importance.defaultImportance, playSound: false)));
  }

  Future<void> clearUpdate() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.cancel(id: 987655);
  }

  Future<void> complete({required int id, required String title, required bool success, String? message}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: id, title: title, body: message ?? (success ? 'Transfer complete' : 'Transfer failed'), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', 'Bifrost transfers', channelDescription: 'File transfer progress', ongoing: false, autoCancel: true, importance: Importance.defaultImportance)));
  }

  Future<void> cancel(int id) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> incoming({required int id, required String title, required String body}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: id, title: title, body: body, notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('bifrost_incoming', 'Incoming transfers', channelDescription: 'Incoming file transfer requests', importance: Importance.high, priority: Priority.high, autoCancel: true, playSound: true)));
  }

  Future<void> backgroundReady() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: 987654, title: 'Bifrost is ready', body: 'Listening for nearby file transfers • Tap to stop', notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('bifrost_background', 'Background receiving', channelDescription: 'Keeps Bifrost available while the app is in the background', ongoing: true, autoCancel: false, onlyAlertOnce: true, importance: Importance.low, playSound: false)));
  }

  Future<void> clearBackgroundReady() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.cancel(id: 987654);
  }
}

String _format(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
