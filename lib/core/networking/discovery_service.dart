import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'discovery.dart';

class BifrostDiscoveryService {
  Future<List<BifrostDevice>> discover({Duration timeout = const Duration(seconds: 3), String? manualHost, int? manualPort, String? localDeviceId}) async {
    if (manualHost != null) return _manual(manualHost, manualPort ?? 43821);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final devices = <String, BifrostDevice>{};
    final request = utf8.encode(encodeDiscoveryRequest());
    final broadcasts = await _broadcastAddresses();
    final multicast = InternetAddress('224.0.0.251');
    for (var attempt = 0; attempt < 3; attempt++) {
      for (final broadcast in broadcasts) {
        socket.send(request, broadcast, bifrostDiscoveryPort);
      }
      socket.send(request, multicast, bifrostDiscoveryPort);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final deadline = DateTime.now().add(timeout);
    try {
      await for (final event in socket.timeout(timeout)) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram;
          while ((datagram = socket.receive()) != null) {
            final packet = datagram!;
            try {
              final json = jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
              if (json['message'] == 'BIFROST_DISCOVER_V1' && json['port'] is int) {
                final device = BifrostDevice.fromJson(json, host: packet.address.address);
                if (device.port > 0 && device.id != localDeviceId) devices[device.id] = device;
              }
            } catch (_) {}
          }
        }
        if (DateTime.now().isAfter(deadline)) break;
      }
    } on TimeoutException {
      // A quiet network is a valid result; the UI will offer manual connection.
    } finally {
      socket.close();
    }
    return devices.values.toList(growable: false);
  }

  Future<List<InternetAddress>> _broadcastAddresses() async {
    final addresses = <String, InternetAddress>{'255.255.255.255': InternetAddress('255.255.255.255')};
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false, includeLinkLocal: false);
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final raw = address.rawAddress;
          if (raw.length != 4) continue;
          final directed = InternetAddress('${raw[0]}.${raw[1]}.${raw[2]}.255');
          addresses[directed.address] = directed;
        }
      }
    } on SocketException {
      // The global broadcast remains available as a fallback.
    }
    return addresses.values.toList(growable: false);
  }

  Future<List<BifrostDevice>> _manual(String host, int port) async {
    final client = HttpClient();
    try {
      final response = await client.getUrl(Uri.parse('http://$host:$port/bifrost/v1/device')).then((request) => request.close()).timeout(const Duration(seconds: 3));
      final json = jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      if (response.statusCode != 200) return const [];
      return [BifrostDevice.fromJson(json, host: host)];
    } catch (_) {
      return const [];
    } finally {
      client.close(force: true);
    }
  }
}

class BifrostDiscoveryResponder {
  BifrostDiscoveryResponder({required this.deviceId, required this.name, required this.deviceType, required this.httpPort});
  final String deviceId;
  String name;
  final String deviceType;
  final int httpPort;
  RawDatagramSocket? _socket;

  void updateName(String value) => name = value;

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, bifrostDiscoveryPort, reuseAddress: true);
      _socket!.broadcastEnabled = true;
      _socket!.joinMulticast(InternetAddress('224.0.0.251'));
      _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = _socket!.receive()) != null) {
          try {
            final json = jsonDecode(utf8.decode(packet!.data)) as Map<String, dynamic>;
            if (isDiscoveryRequest(json)) {
              final response = utf8.encode(encodeDiscoveryResponse(deviceId: deviceId, name: name, deviceType: deviceType, port: httpPort));
              _socket!.send(response, packet.address, packet.port);
            }
          } catch (_) {}
        }
      });
    } on SocketException {
      // Discovery is optional. The HTTP server and manual IP fallback still work.
    }
  }

  void close() => _socket?.close();
}
