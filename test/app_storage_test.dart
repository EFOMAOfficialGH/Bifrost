import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bifrost/core/storage/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('background receiving defaults on and favorite state stays separate from trust', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = AppStorage.instance;

    expect(await storage.backgroundActivity(), isTrue);
    await storage.setBackgroundActivity(false);
    expect(await storage.backgroundActivity(), isFalse);
    await storage.setBackgroundActivity(true);
    expect(await storage.backgroundActivity(), isTrue);
    expect(await storage.startWithWindows(), isTrue);
    await storage.setStartWithWindows(false);
    expect(await storage.startWithWindows(), isFalse);

    await storage.setFavoriteDevice('family-device', true);
    expect(await storage.isFavoriteDevice('family-device'), isTrue);
    expect(await storage.isTrusted('family-device'), isFalse);

    await storage.setTrusted('family-device', true, name: 'Family phone');
    await storage.setFavoriteDevice('family-device', false);
    expect(await storage.isFavoriteDevice('family-device'), isFalse);
    expect(await storage.isTrusted('family-device'), isTrue);

    final token = storage.newResumeToken();
    expect(token, matches(RegExp(r'^[a-f0-9]{48}$')));
    final interrupted = TransferRecord(
      id: 'history-1',
      fileName: 'large.zip',
      bytes: 1024,
      direction: 'Sent',
      status: 'In progress',
      peer: 'Family phone',
      time: DateTime.utc(2026),
      path: '/tmp/large.zip',
      peerHost: '192.168.1.2',
      peerPort: 43821,
      peerDeviceId: 'family-device',
      transferId: 'transfer-1',
      fileId: 'file-1',
      sha256: List<String>.filled(64, 'a').join(),
      resumeToken: token,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('transferHistory', [
      jsonEncode(interrupted.toJson()),
    ]);
    final recovered = (await storage.history()).single;
    expect(recovered.status, 'Interrupted');
    expect(recovered.transferId, 'transfer-1');
    expect(recovered.fileId, 'file-1');
    expect(recovered.resumeToken, token);
  });
}
