import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bifrost/core/networking/discovery.dart';

void main() {
  test('discovery packets round-trip', () {
    final request = jsonDecode(encodeDiscoveryRequest()) as Map<String, dynamic>;
    expect(isDiscoveryRequest(request), isTrue);
    final response = jsonDecode(encodeDiscoveryResponse(deviceId: 'abc', name: 'Phone', deviceType: 'android', port: 1234)) as Map<String, dynamic>;
    final device = BifrostDevice.fromJson(response, host: '192.168.1.5');
    expect(device.connectionCode, 'bifrost://192.168.1.5:1234');
    expect(device.type, 'android');
  });
}
