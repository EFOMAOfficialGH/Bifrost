import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../localization/app_localizations.dart';

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
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_transfers', AppLocalizations.translateCurrent('Bifrost transfers'), description: AppLocalizations.translateCurrent('File transfer progress'), importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_incoming', AppLocalizations.translateCurrent('Incoming transfers'), description: AppLocalizations.translateCurrent('Incoming file transfer requests'), importance: Importance.high, playSound: true));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_background', AppLocalizations.translateCurrent('Background receiving'), description: AppLocalizations.translateCurrent('Keeps Bifrost available while the app is in the background'), importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_updates', AppLocalizations.translateCurrent('Bifrost updates'), description: AppLocalizations.translateCurrent('Bifrost update download progress'), importance: Importance.low, playSound: false));
    _ready = true;
  }

  Future<void> refreshLocalizedChannels() async {
    if (!Platform.isAndroid || !_ready) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_transfers', AppLocalizations.translateCurrent('Bifrost transfers'), description: AppLocalizations.translateCurrent('File transfer progress'), importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_incoming', AppLocalizations.translateCurrent('Incoming transfers'), description: AppLocalizations.translateCurrent('Incoming file transfer requests'), importance: Importance.high, playSound: true));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_background', AppLocalizations.translateCurrent('Background receiving'), description: AppLocalizations.translateCurrent('Keeps Bifrost available while the app is in the background'), importance: Importance.low, playSound: false));
    await android?.createNotificationChannel(AndroidNotificationChannel('bifrost_updates', AppLocalizations.translateCurrent('Bifrost updates'), description: AppLocalizations.translateCurrent('Bifrost update download progress'), importance: Importance.low, playSound: false));
  }

  Future<void> progress({required int id, required String title, required int sent, required int total, double speedBytesPerSecond = 0, int? etaSeconds}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    final percent = total == 0 ? 0 : ((sent * 100) ~/ total).clamp(0, 100);
    final details = speedBytesPerSecond > 0 ? ' • ${_format(speedBytesPerSecond.round())}/s${etaSeconds == null ? '' : ' • ${etaSeconds}s left'}' : '';
    await _plugin.show(id: id, title: AppLocalizations.translateCurrent(title), body: AppLocalizations.translateCurrent('$percent% • ${_format(sent)} of ${_format(total)}$details'), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', AppLocalizations.translateCurrent('Bifrost transfers'), channelDescription: AppLocalizations.translateCurrent('File transfer progress'), ongoing: true, onlyAlertOnce: true, showProgress: true, maxProgress: 100, progress: percent, playSound: false)));
  }

  Future<void> updateProgress({required int received, required int total, double speedBytesPerSecond = 0, int? etaSeconds}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    final percent = total == 0 ? 0 : ((received * 100) ~/ total).clamp(0, 100);
    final details = speedBytesPerSecond > 0 ? ' • ${_format(speedBytesPerSecond.round())}/s${etaSeconds == null ? '' : ' • ${etaSeconds}s left'}' : '';
    await _plugin.show(id: 987655, title: AppLocalizations.translateCurrent('Downloading Bifrost update'), body: AppLocalizations.translateCurrent('$percent% • ${_format(received)} of ${_format(total)}$details'), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_updates', AppLocalizations.translateCurrent('Bifrost updates'), channelDescription: AppLocalizations.translateCurrent('Bifrost update download progress'), ongoing: true, autoCancel: false, onlyAlertOnce: true, showProgress: true, maxProgress: 100, progress: percent, importance: Importance.low, playSound: false)));
  }

  Future<void> updateComplete({required String version}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: 987655, title: AppLocalizations.translateCurrent('Bifrost update downloaded'), body: AppLocalizations.translateCurrent('Version $version is ready to install'), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_updates', AppLocalizations.translateCurrent('Bifrost updates'), channelDescription: AppLocalizations.translateCurrent('Bifrost update download progress'), ongoing: false, autoCancel: true, importance: Importance.defaultImportance, playSound: false)));
  }

  Future<void> clearUpdate() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.cancel(id: 987655);
  }

  Future<void> complete({required int id, required String title, required bool success, String? message}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: id, title: AppLocalizations.translateCurrent(title), body: AppLocalizations.translateCurrent(message ?? (success ? 'Transfer complete' : 'Transfer failed')), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_transfers', AppLocalizations.translateCurrent('Bifrost transfers'), channelDescription: AppLocalizations.translateCurrent('File transfer progress'), ongoing: false, autoCancel: true, importance: Importance.defaultImportance)));
  }

  Future<void> cancel(int id) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> incoming({required int id, required String title, required String body}) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: id, title: AppLocalizations.translateCurrent(title), body: AppLocalizations.translateCurrent(body), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_incoming', AppLocalizations.translateCurrent('Incoming transfers'), channelDescription: AppLocalizations.translateCurrent('Incoming file transfer requests'), importance: Importance.high, priority: Priority.high, autoCancel: true, playSound: true)));
  }

  Future<void> backgroundReady() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await _plugin.show(id: 987654, title: AppLocalizations.translateCurrent('Bifrost is ready'), body: AppLocalizations.translateCurrent('Listening for nearby file transfers • Tap to stop'), notificationDetails: NotificationDetails(android: AndroidNotificationDetails('bifrost_background', AppLocalizations.translateCurrent('Background receiving'), channelDescription: AppLocalizations.translateCurrent('Keeps Bifrost available while the app is in the background'), ongoing: true, autoCancel: false, onlyAlertOnce: true, importance: Importance.low, playSound: false)));
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
