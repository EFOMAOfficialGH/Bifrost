import 'dart:convert';

import '../localization/app_localizations.dart';

const bifrostDiscoveryPort = 43820;
const _discoverMessage = 'BIFROST_DISCOVER_V1';

class BifrostDevice {
  const BifrostDevice({required this.id, required this.name, required this.type, required this.host, required this.port, this.source = 'udp'});
  final String id;
  final String name;
  final String type;
  final String host;
  final int port;
  final String source;

  Uri get baseUri => Uri.parse('http://$host:$port');
  String get connectionCode => 'bifrost://$host:$port';

  factory BifrostDevice.fromJson(Map<String, dynamic> json, {required String host}) => BifrostDevice(
    id: json['deviceId'] as String? ?? 'unknown', name: json['name'] as String? ?? AppLocalizations.translateCurrent('Bifrost device'), type: json['deviceType'] as String? ?? 'unknown', host: host, port: json['port'] as int? ?? 0, source: json['source'] as String? ?? 'udp');
}

String encodeDiscoveryRequest() => jsonEncode({'message': _discoverMessage});

bool isDiscoveryRequest(Map<String, dynamic> json) => json['message'] == _discoverMessage;

String encodeDiscoveryResponse({required String deviceId, required String name, required String deviceType, required int port}) => jsonEncode({'message': _discoverMessage, 'deviceId': deviceId, 'name': name, 'deviceType': deviceType, 'port': port});
