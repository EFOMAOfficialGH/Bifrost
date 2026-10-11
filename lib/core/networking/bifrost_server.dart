import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'checksum.dart';
import 'protocol.dart';

class BifrostServer {
  BifrostServer({required this.saveDirectory, this.deviceName = 'Bifrost Device', this.deviceId = 'local-device'});

  final Directory saveDirectory;
  final String deviceName;
  final String deviceId;
  HttpServer? _server;
  final Map<String, BifrostTransferOffer> _offers = {};

  int get port => _server?.port ?? 0;
  String get address => _server == null ? '' : 'http://${_server!.address.address}:$port';

  Future<void> start({InternetAddress? address, int port = 0, SecurityContext? securityContext}) async {
    await saveDirectory.create(recursive: true);
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    _server = securityContext == null
        ? await HttpServer.bind(bindAddress, port)
        : await HttpServer.bindSecure(bindAddress, port, securityContext);
    unawaited(_serve());
  }

  Future<void> _serve() async {
    await for (final request in _server!) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/bifrost/v1/device') return _json(request, 200, {'protocolVersion': bifrostProtocolVersion, 'deviceId': deviceId, 'name': deviceName, 'deviceType': Platform.isWindows ? 'windows' : 'android', 'port': port});
      if (request.method == 'POST' && path == '/bifrost/v1/offers') return await _offer(request);
      final match = RegExp(r'^/bifrost/v1/transfers/([^/]+)/files/([^/]+)$').firstMatch(path);
      if (request.method == 'PUT' && match != null) return await _receiveFile(request, match.group(1)!, match.group(2)!);
      _json(request, 404, {'error': 'Route not found'});
    } catch (error) {
      _json(request, 400, {'error': 'Request could not be processed'});
    }
  }

  Future<void> _offer(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final offer = BifrostTransferOffer.fromJson(jsonDecode(body) as Map<String, dynamic>);
    _offers[offer.transferId] = offer;
    _json(request, 202, {'transferId': offer.transferId, 'accepted': true});
  }

  Future<void> _receiveFile(HttpRequest request, String transferId, String fileId) async {
    final offer = _offers[transferId];
    final fileOffer = offer?.files.where((file) => file.fileId == fileId).firstOrNull;
    if (fileOffer == null) return _json(request, 404, {'error': 'Transfer or file not found'});
    final temp = File('${saveDirectory.path}/.${fileOffer.fileId}.part');
    final output = temp.openWrite();
    final digestSink = DigestCollector();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var bytes = 0;
    try {
      await for (final chunk in request) {
        bytes += chunk.length;
        hashSink.add(chunk);
        output.add(chunk);
      }
      hashSink.close();
      await output.close();
      final digest = digestSink.value!.toString();
      if (bytes != fileOffer.size || digest != fileOffer.sha256 || request.headers.value('x-bifrost-sha256') != fileOffer.sha256) {
        await temp.delete();
        return _json(request, 422, {'error': 'Checksum mismatch'});
      }
      final destination = _uniqueFile(fileOffer.name);
      await temp.rename(destination.path);
      _json(request, 201, {'received': true, 'sha256': digest, 'path': destination.path});
    } catch (_) {
      await output.close();
      if (await temp.exists()) await temp.delete();
      _json(request, 400, {'error': 'File transfer failed'});
    }
  }

  File _uniqueFile(String requestedName) {
    final safe = requestedName.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_').replaceAll('..', '_');
    var candidate = File('${saveDirectory.path}/$safe');
    var counter = 1;
    while (candidate.existsSync()) {
      final dot = safe.lastIndexOf('.');
      final name = dot > 0 ? safe.substring(0, dot) : safe;
      final extension = dot > 0 ? safe.substring(dot) : '';
      candidate = File('${saveDirectory.path}/$name ($counter)$extension');
      counter++;
    }
    return candidate;
  }

  void _json(HttpRequest request, int status, Object body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }
}
