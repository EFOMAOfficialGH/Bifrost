import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('About and update-check version matches pubspec release version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final appSource = File('lib/main.dart').readAsStringSync();
    final packageVersion = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);
    final appVersion = RegExp(r"const bifrostVersion = '([^']+)';")
        .firstMatch(appSource)
        ?.group(1);

    expect(packageVersion, isNotNull);
    expect(appVersion, packageVersion,
        reason: 'Update bifrostVersion whenever pubspec.yaml version changes.');
  });
}
