import 'dart:typed_data';

import 'package:bifrost/features/app_transfer/app_transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TransferableApp parses PackageManager app metadata', () {
    final icon = Uint8List.fromList([1, 2, 3]);
    final app = TransferableApp.fromMap({
      'name': 'Example',
      'packageName': 'org.example.app',
      'versionName': '2.1',
      'versionCode': 42,
      'sizeBytes': 1200,
      'apkSizeBytes': 1000,
      'obbSizeBytes': 200,
      'apkPaths': ['/data/app/base.apk', '/data/app/split_config.apk'],
      'hasObb': false,
      'obbAccessRequired': true,
      'iconPng': icon,
    });

    expect(app.name, 'Example');
    expect(app.packageName, 'org.example.app');
    expect(app.versionName, '2.1');
    expect(app.versionCode, 42);
    expect(app.sizeBytes, 1200);
    expect(app.apkPaths, hasLength(2));
    expect(app.hasObb, isFalse);
    expect(app.obbAccessRequired, isTrue);
    expect(app.iconPng, icon);
  });
}
