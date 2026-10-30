import 'dart:io';

import '../storage/app_storage.dart';

class WindowsStartupService {
  WindowsStartupService._();
  static final instance = WindowsStartupService._();

  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'Bifrost';

  Future<void> syncFromPreferences() async {
    if (!Platform.isWindows) return;
    await setEnabled(
      await AppStorage.instance.startWithWindows(),
      persist: false,
    );
  }

  Future<void> setEnabled(bool enabled, {bool persist = true}) async {
    if (persist) await AppStorage.instance.setStartWithWindows(enabled);
    if (!Platform.isWindows) return;
    if (enabled) {
      final result = await Process.run('reg.exe', [
        'add',
        _runKey,
        '/v',
        _valueName,
        '/t',
        'REG_SZ',
        '/d',
        '"${Platform.resolvedExecutable}" --minimized-to-tray',
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'reg.exe',
          const [],
          '${result.stderr}'.trim(),
          result.exitCode,
        );
      }
      return;
    }

    final query = await Process.run('reg.exe', [
      'query',
      _runKey,
      '/v',
      _valueName,
    ]);
    if (query.exitCode == 0) {
      final result = await Process.run('reg.exe', [
        'delete',
        _runKey,
        '/v',
        _valueName,
        '/f',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'reg.exe',
          const [],
          '${result.stderr}'.trim(),
          result.exitCode,
        );
      }
    } else {
      final output = '${query.stdout}\n${query.stderr}'.toLowerCase();
      if (!output.contains('unable to find') &&
          !output.contains('cannot find')) {
        throw ProcessException(
          'reg.exe',
          const [],
          output.trim(),
          query.exitCode,
        );
      }
    }
  }
}
