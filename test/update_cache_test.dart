import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bifrost/core/updates/update_service.dart';

void main() {
  late Directory supportDirectory;
  late BifrostUpdateService service;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp('bifrost-update-cache-test-');
    service = BifrostUpdateService.forTesting(() async => supportDirectory);
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('finds the newest compatible cached APK by version', () async {
    final cache = Directory('${supportDirectory.path}${Platform.pathSeparator}bifrost-updates');
    await cache.create(recursive: true);
    final older = File('${cache.path}${Platform.pathSeparator}bifrost-update-0.13.2+33.apk');
    final latest = File('${cache.path}${Platform.pathSeparator}bifrost-update-0.13.3+34.apk');
    await older.writeAsBytes([1, 2, 3]);
    await latest.writeAsBytes([4, 5, 6]);

    final cached = await service.latestCachedUpdate(currentVersion: '0.13.1+32', android: true);

    expect(cached?.version, '0.13.3+34');
    expect(cached?.file.path, latest.path);
    expect(await service.cachedUpdateForVersion(version: '0.13.2+33', android: true), isNotNull);
  });

  test('removes installed packages but keeps newer cached updates', () async {
    final cache = Directory('${supportDirectory.path}${Platform.pathSeparator}bifrost-updates');
    await cache.create(recursive: true);
    final installed = File('${cache.path}${Platform.pathSeparator}bifrost-update-0.13.2+33.apk');
    final newer = File('${cache.path}${Platform.pathSeparator}bifrost-update-0.13.3+34.apk');
    final partial = File('${cache.path}${Platform.pathSeparator}bifrost-update-0.13.4+35.apk.part');
    await installed.writeAsBytes([1]);
    await newer.writeAsBytes([2]);
    await partial.writeAsBytes([3]);

    await service.cleanupInstalledUpdates(currentVersion: '0.13.2+33');

    expect(await installed.exists(), isFalse);
    expect(await newer.exists(), isTrue);
    expect(await partial.exists(), isFalse);
  });
}
