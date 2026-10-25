import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bifrost/core/storage/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generated device name follows locale without changing custom names', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage.instance;

    expect(await storage.deviceName(), 'Bifrost Device');
    await storage.setLanguageChoice('ar');
    expect(await storage.deviceName(), 'جهاز بايفروست');

    await storage.setLanguageChoice('en');
    expect(await storage.deviceName(), 'Bifrost Device');

    await storage.setDeviceName('My transfer device');
    await storage.setLanguageChoice('ar');
    expect(await storage.deviceName(), 'My transfer device');
  });
}
