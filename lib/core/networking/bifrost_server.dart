import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../localization/app_localizations.dart';
import 'checksum.dart';
import 'discovery_service.dart';
import 'protocol.dart';
import 'resumable_session_store.dart';

class BifrostServer {
  BifrostServer({
    required this.saveDirectory,
    String? deviceName,
    this.deviceId = 'local-device',
    this.onOffer,
    this.onOfferWithSender,
    this.onFileProgress,
    this.onFileReceived,
    this.onFileCancelled,
  }) : deviceName =
           deviceName ?? AppLocalizations.translateCurrent('Bifrost Device'),
       _resumeStore = ResumableSessionStore(saveDirectory);

  final Directory saveDirectory;
  String deviceName;
  final String deviceId;
  final Future<bool> Function(BifrostTransferOffer offer)? onOffer;
  final Future<bool> Function(
    BifrostTransferOffer offer,
    String? senderDeviceId,
    String? senderDeviceName,
  )?
  onOfferWithSender;
  final void Function(
    BifrostFileOffer file,
    int received,
    int total,
    String transferId,
  )?
  onFileProgress;
  final Future<void> Function(BifrostFileOffer file, String path)?
  onFileReceived;
  final Future<void> Function(BifrostFileOffer file)? onFileCancelled;

  final ResumableSessionStore _resumeStore;
  HttpServer? _server;
  BifrostDiscoveryResponder? _discovery;
  final Map<String, BifrostTransferOffer> _offers = {};
  final Map<String, String?> _acceptedSenderIds = {};
  final Set<String> _cancelled = {};

  int get port => _server?.port ?? 0;
  String get address =>
      _server == null ? '' : 'http://${_server!.address.address}:$port';

  void updateDeviceName(String value) {
    deviceName = value.trim().isEmpty
        ? AppLocalizations.translateCurrent('Bifrost Device')
        : value.trim();
    _discovery?.updateName(deviceName);
  }

  Future<void> refreshDiscovery() async {
    final server = _server;
    if (server == null) return;
    _discovery?.close();
    final discovery = BifrostDiscoveryResponder(
      deviceId: deviceId,
      name: deviceName,
      deviceType: Platform.isWindows ? 'windows' : 'android',
      httpPort: server.port,
    );
    _discovery = discovery;
    await discovery.start();
  }

  Future<void> start({
    InternetAddress? address,
    int port = 0,
    SecurityContext? securityContext,
  }) async {
    await saveDirectory.create(recursive: true);
    await _resumeStore.cleanupExpired();
    await _cleanupLegacyPartials();
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    _server = securityContext == null
        ? await HttpServer.bind(bindAddress, port)
        : await HttpServer.bindSecure(bindAddress, port, securityContext);
    _discovery = BifrostDiscoveryResponder(
      deviceId: deviceId,
      name: deviceName,
      deviceType: Platform.isWindows ? 'windows' : 'android',
      httpPort: this.port,
    );
    await _discovery!.start();
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
      if (request.method == 'GET' && path == '/bifrost/v1/device') {
        return _json(request, 200, {
          'protocolVersion': bifrostProtocolVersion,
          'deviceId': deviceId,
          'name': deviceName,
          'deviceType': Platform.isWindows ? 'windows' : 'android',
          'port': port,
          'capabilities': const ['chunked-resume-v2'],
        });
      }
      if (request.method == 'POST' && path == '/bifrost/v1/offers')
        return await _offer(request);
      final cancelMatch = RegExp(
        r'^/bifrost/v1/transfers/([A-Za-z0-9_-]{1,128})/cancel$',
      ).firstMatch(path);
      if (request.method == 'POST' && cancelMatch != null) {
        await cancelTransfer(cancelMatch.group(1)!);
        return _json(request, 200, {'cancelled': true});
      }
      final resumeMatch = RegExp(
        r'^/bifrost/v2/transfers/([A-Za-z0-9_-]{1,128})/files/([A-Za-z0-9_-]{1,128})/(begin|status|finalize|chunks/(\d+))$',
      ).firstMatch(path);
      if (resumeMatch != null)
        return await _handleResumeRoute(request, resumeMatch);
      final match = RegExp(
        r'^/bifrost/v1/transfers/([A-Za-z0-9_-]{1,128})/files/([A-Za-z0-9_-]{1,128})$',
      ).firstMatch(path);
      if (request.method == 'PUT' && match != null)
        return await _receiveFile(request, match.group(1)!, match.group(2)!);
      _json(request, 404, {'error': 'Route not found'});
    } catch (_) {
      _json(request, 400, {'error': 'Request could not be processed'});
    }
  }

  Future<void> _handleResumeRoute(
    HttpRequest request,
    RegExpMatch match,
  ) async {
    final transferId = match.group(1)!;
    final fileId = match.group(2)!;
    final action = match.group(3)!;
    try {
      if (request.method == 'POST' && action == 'begin') {
        final offer = _offers[transferId];
        final file = offer?.files
            .where((item) => item.fileId == fileId)
            .firstOrNull;
        if (file == null || _cancelled.contains(transferId))
          return _json(request, 409, {'error': 'Transfer was not accepted'});
        final body = await utf8.decoder.bind(request).join();
        final requestedChunkSize = body.isEmpty
            ? defaultResumeChunkSize
            : ((jsonDecode(body) as Map)['chunkSize'] as int? ??
                  defaultResumeChunkSize);
        final status = await _resumeStore.begin(
          transferId: transferId,
          file: file,
          senderDeviceId: _acceptedSenderIds[transferId],
          senderDeviceName: request.headers.value('x-bifrost-device-name'),
          resumeToken: request.headers.value('x-bifrost-resume-token') ?? '',
          chunkSize: requestedChunkSize,
        );
        return _json(request, 200, status.toJson());
      }
      if (request.method == 'GET' && action == 'status') {
        final status = await _resumeStore.status(
          transferId,
          fileId,
          resumeToken: request.headers.value('x-bifrost-resume-token') ?? '',
        );
        return _json(request, 200, status.toJson());
      }
      if (request.method == 'PUT' && action.startsWith('chunks/')) {
        final index = int.tryParse(match.group(4) ?? '');
        if (index == null)
          return _json(request, 400, {'error': 'Invalid chunk index'});
        final resumeToken =
            request.headers.value('x-bifrost-resume-token') ?? '';
        final status = await _resumeStore.status(
          transferId,
          fileId,
          resumeToken: resumeToken,
        );
        if (index < 0 || index >= status.chunkCount)
          return _json(request, 400, {
            'error': 'Chunk index is outside the file',
          });
        final file = _offers[transferId]?.files
            .where((item) => item.fileId == fileId)
            .firstOrNull;
        if (file == null)
          return _json(request, 409, {'error': 'Transfer offer is missing'});
        final exactLength = (file.size - index * status.chunkSize)
            .clamp(0, status.chunkSize)
            .toInt();
        if (request.contentLength != exactLength)
          return _json(request, 422, {'error': 'Invalid chunk length'});
        final builder = BytesBuilder(copy: false);
        var count = 0;
        await for (final bytes in request) {
          count += bytes.length;
          if (count > exactLength)
            return _json(request, 422, {'error': 'Chunk is too large'});
          builder.add(bytes);
        }
        if (count != exactLength)
          return _json(request, 422, {'error': 'Chunk is incomplete'});
        final digest = request.headers.value('x-bifrost-chunk-sha256');
        if (digest == null)
          return _json(request, 422, {'error': 'Chunk checksum is missing'});
        final received = await _resumeStore.receiveChunk(
          transferId: transferId,
          fileId: fileId,
          resumeToken: resumeToken,
          index: index,
          bytes: builder.takeBytes(),
          declaredSha256: digest,
        );
        onFileProgress?.call(file, received, file.size, transferId);
        return _json(request, 201, {
          'received': true,
          'bytesReceived': received,
        });
      }
      if (request.method == 'POST' && action == 'finalize') {
        final result = await _resumeStore.finalize(
          transferId: transferId,
          fileId: fileId,
          resumeToken: request.headers.value('x-bifrost-resume-token') ?? '',
        );
        final file = _offers[transferId]?.files
            .where((item) => item.fileId == fileId)
            .firstOrNull;
        if (result.newlyCompleted && file != null) {
          try {
            await onFileReceived?.call(file, result.path);
          } catch (_) {
            // The durable file is already complete; a history/notification error must not undo it.
          }
        }
        _offers.remove(transferId);
        _acceptedSenderIds.remove(transferId);
        return _json(request, 201, {
          'received': true,
          'sha256': result.sha256,
          'path': result.path,
        });
      }
      _json(request, 404, {'error': 'Route not found'});
    } catch (error) {
      _json(request, 409, {'error': error.toString()});
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    _cancelled.add(transferId);
    final offer = _offers.remove(transferId);
    _acceptedSenderIds.remove(transferId);
    await _resumeStore.deleteTransfer(transferId);
    for (final file in offer?.files ?? const <BifrostFileOffer>[]) {
      await onFileCancelled?.call(file);
    }
  }

  Future<void> _offer(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final offer = BifrostTransferOffer.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
    final senderDeviceId = request.headers.value('x-bifrost-device-id');
    final senderDeviceName = request.headers.value('x-bifrost-device-name');
    final resumedAcceptedOffer = await _resumeStore.matchesExisting(
      offer,
      senderDeviceId,
    );
    final accepted =
        resumedAcceptedOffer ||
        await (onOfferWithSender?.call(
              offer,
              senderDeviceId,
              senderDeviceName,
            ) ??
            onOffer?.call(offer) ??
            Future<bool>.value(true));
    if (!accepted)
      return _json(request, 409, {
        'transferId': offer.transferId,
        'accepted': false,
      });
    _cancelled.remove(offer.transferId);
    _offers[offer.transferId] = offer;
    _acceptedSenderIds[offer.transferId] = senderDeviceId;
    _json(request, 202, {
      'transferId': offer.transferId,
      'accepted': true,
      'resumed': resumedAcceptedOffer,
    });
  }

  Future<void> _receiveFile(
    HttpRequest request,
    String transferId,
    String fileId,
  ) async {
    final offer = _offers[transferId];
    final fileOffer = offer?.files
        .where((file) => file.fileId == fileId)
        .firstOrNull;
    if (fileOffer == null || _cancelled.contains(transferId))
      return _json(request, 409, {'error': 'Transfer cancelled'});
    final temp = File(
      '${saveDirectory.path}${Platform.pathSeparator}.${fileOffer.fileId}.part',
    );
    final output = temp.openWrite();
    final digestSink = DigestCollector();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var bytes = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    void reportProgress({bool force = false}) {
      final now = DateTime.now();
      if (!force &&
          now.difference(lastProgressAt) < const Duration(milliseconds: 200))
        return;
      lastProgressAt = now;
      onFileProgress?.call(fileOffer, bytes, fileOffer.size, transferId);
    }

    try {
      await for (final chunk in request) {
        if (_cancelled.contains(transferId)) throw const _ServerCancelled();
        bytes += chunk.length;
        hashSink.add(chunk);
        output.add(chunk);
        reportProgress();
      }
      reportProgress(force: true);
      hashSink.close();
      await output.close();
      if (_cancelled.contains(transferId)) throw const _ServerCancelled();
      final digest = digestSink.value!.toString();
      if (bytes != fileOffer.size ||
          digest != fileOffer.sha256 ||
          request.headers.value('x-bifrost-sha256') != fileOffer.sha256) {
        await temp.delete();
        return _json(request, 422, {'error': 'Checksum mismatch'});
      }
      final destination = _uniqueFile(fileOffer.name);
      await temp.rename(destination.path);
      await onFileReceived?.call(fileOffer, destination.path);
      _offers.remove(transferId);
      _acceptedSenderIds.remove(transferId);
      _json(request, 201, {
        'received': true,
        'sha256': digest,
        'path': destination.path,
      });
    } catch (_) {
      await output.close();
      if (await temp.exists()) await temp.delete();
      _json(request, 409, {'error': 'Transfer cancelled or failed'});
    }
  }

  File _uniqueFile(String requestedName) {
    final safe = requestedName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_')
        .replaceAll('..', '_');
    final base = safe.isEmpty ? 'file' : safe;
    var candidate = File('${saveDirectory.path}${Platform.pathSeparator}$base');
    var counter = 1;
    while (candidate.existsSync()) {
      final dot = base.lastIndexOf('.');
      final name = dot > 0 ? base.substring(0, dot) : base;
      final extension = dot > 0 ? base.substring(dot) : '';
      candidate = File(
        '${saveDirectory.path}${Platform.pathSeparator}$name ($counter)$extension',
      );
      counter++;
    }
    return candidate;
  }

  Future<void> _cleanupLegacyPartials() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final entity in saveDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!RegExp(r'^\.[A-Za-z0-9_-]{1,128}\.part$').hasMatch(name)) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff))
          await entity.delete();
      } on FileSystemException {
        // A busy or protected partial can be cleaned on a later launch.
      }
    }
  }

  void _json(HttpRequest request, int status, Object body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    request.response.close();
  }

  Future<void> close() async {
    _discovery?.close();
    _discovery = null;
    await _server?.close(force: true);
    _server = null;
  }
}

class _ServerCancelled implements Exception {
  const _ServerCancelled();
}
