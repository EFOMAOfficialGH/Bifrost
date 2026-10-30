import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'checksum.dart';
import 'protocol.dart';
import 'resumable_session_store.dart';

class TransferCancellation {
  bool isCancelled = false;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  void cancel() {
    if (isCancelled) return;
    isCancelled = true;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

class TransferCancelledException implements Exception {
  const TransferCancelledException();
  @override
  String toString() => 'Transfer cancelled';
}

class BifrostClient {
  BifrostClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();
  final HttpClient _http;

  Future<void> sendFile({
    required Uri server,
    required File file,
    String? remoteName,
    String transferId = 'transfer-1',
    String fileId = 'file-1',
    String? senderDeviceId,
    String? senderDeviceName,
    TransferCancellation? cancellation,
    void Function(int sent, int total)? onProgress,
    FutureOr<void> Function(String sha256, int size)? onPrepared,
    String? precomputedSha256,
    String? resumeToken,
    bool useResumable = false,
    int chunkSize = defaultResumeChunkSize,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(transferId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(fileId)) {
      throw ArgumentError(
        'Transfer and file IDs must contain only letters, digits, underscores, or hyphens',
      );
    }
    final totalBytes = await file.length();
    final digest = (precomputedSha256 ?? await sha256File(file)).toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest))
      throw ArgumentError.value(
        digest,
        'precomputedSha256',
        'Must be a SHA-256 hex digest',
      );
    await onPrepared?.call(digest, totalBytes);
    final offer = BifrostTransferOffer(
      files: [
        BifrostFileOffer(
          fileId: fileId,
          name: remoteName ?? file.uri.pathSegments.last,
          size: totalBytes,
          sha256: digest,
        ),
      ],
      transferId: transferId,
    );
    if (cancellation?.isCancelled ?? false)
      throw const TransferCancelledException();

    final offerRequest = await _http.postUrl(
      server.replace(path: '/bifrost/v1/offers'),
    );
    offerRequest.headers.contentType = ContentType.json;
    if (senderDeviceId != null)
      offerRequest.headers.set('X-Bifrost-Device-Id', senderDeviceId);
    if (senderDeviceName != null)
      offerRequest.headers.set('X-Bifrost-Device-Name', senderDeviceName);
    offerRequest.write(offer.encode());
    final offerResponse = await offerRequest.close();
    final offerBody = await utf8.decoder.bind(offerResponse).join();
    if (offerResponse.statusCode != 202 ||
        (jsonDecode(offerBody) as Map)['accepted'] != true) {
      throw StateError('The receiver declined the transfer');
    }
    if (cancellation?.isCancelled ?? false) {
      await cancelRemote(server: server, transferId: transferId);
      throw const TransferCancelledException();
    }

    if (useResumable && await _supportsChunkedResume(server)) {
      try {
        final token = resumeToken ?? _newResumeToken();
        if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(token))
          throw ArgumentError.value(
            token,
            'resumeToken',
            'Must be a 192-bit lowercase hexadecimal token',
          );
        await _sendResumableFile(
          server: server,
          file: file,
          transferId: transferId,
          fileId: fileId,
          senderDeviceName: senderDeviceName,
          totalBytes: totalBytes,
          chunkSize: chunkSize,
          resumeToken: token,
          cancellation: cancellation,
          onProgress: onProgress,
        );
        return;
      } catch (error) {
        if (error is TransferCancelledException ||
            (cancellation?.isCancelled ?? false)) {
          await cancelRemote(server: server, transferId: transferId);
          throw const TransferCancelledException();
        }
        rethrow;
      }
    }

    await _sendLegacyFile(
      server: server,
      file: file,
      transferId: transferId,
      fileId: fileId,
      remoteName: offer.files.single.name,
      totalBytes: totalBytes,
      digest: digest,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<bool> _supportsChunkedResume(Uri server) async {
    try {
      final request = await _http.getUrl(
        server.replace(path: '/bifrost/v1/device'),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) return false;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final capabilities = json['capabilities'];
      return capabilities is List && capabilities.contains('chunked-resume-v2');
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendResumableFile({
    required Uri server,
    required File file,
    required String transferId,
    required String fileId,
    required int totalBytes,
    required int chunkSize,
    required String resumeToken,
    required TransferCancellation? cancellation,
    required void Function(int sent, int total)? onProgress,
    String? senderDeviceName,
  }) async {
    final basePath = '/bifrost/v2/transfers/$transferId/files/$fileId';
    final begin = await _http.postUrl(server.replace(path: '$basePath/begin'));
    begin.headers.contentType = ContentType.json;
    begin.headers.set('X-Bifrost-Resume-Token', resumeToken);
    if (senderDeviceName != null)
      begin.headers.set('X-Bifrost-Device-Name', senderDeviceName);
    begin.write(jsonEncode({'chunkSize': chunkSize}));
    final beginResponse = await begin.close();
    final beginBody = await utf8.decoder.bind(beginResponse).join();
    if (beginResponse.statusCode != 200)
      throw StateError('Could not resume transfer: $beginBody');
    final status = jsonDecode(beginBody) as Map<String, dynamic>;
    final actualChunkSize = status['chunkSize'] as int;
    final chunkCount = status['chunkCount'] as int;
    if (status['completed'] == true) {
      onProgress?.call(totalBytes, totalBytes);
      return;
    }
    final received = (status['receivedChunks'] as List)
        .map((value) => (value as num).toInt())
        .toSet();
    var sentBytes = 0;
    for (final index in received) {
      sentBytes += (totalBytes - index * actualChunkSize)
          .clamp(0, actualChunkSize)
          .toInt();
    }
    onProgress?.call(sentBytes, totalBytes);
    final handle = await file.open(mode: FileMode.read);
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      for (var index = 0; index < chunkCount; index++) {
        if (received.contains(index)) continue;
        if (cancellation?.isCancelled ?? false)
          throw const TransferCancelledException();
        final offset = index * actualChunkSize;
        final length = (totalBytes - offset).clamp(0, actualChunkSize).toInt();
        await handle.setPosition(offset);
        final bytes = await handle.read(length);
        if (bytes.length != length)
          throw const FileSystemException('Source file changed while sending');
        final chunkDigest = sha256.convert(bytes).toString();
        final request = await _http.putUrl(
          server.replace(path: '$basePath/chunks/$index'),
        );
        request.contentLength = bytes.length;
        request.headers.set('X-Bifrost-Chunk-SHA256', chunkDigest);
        request.headers.set('X-Bifrost-Resume-Token', resumeToken);
        request.add(bytes);
        final response = await request.close();
        final responseBody = await utf8.decoder.bind(response).join();
        if (response.statusCode != 201)
          throw StateError('Receiver rejected a file chunk: $responseBody');
        sentBytes += bytes.length;
        final now = DateTime.now();
        if (sentBytes == totalBytes ||
            now.difference(lastProgressAt) >=
                const Duration(milliseconds: 200)) {
          lastProgressAt = now;
          onProgress?.call(sentBytes, totalBytes);
        }
      }
    } finally {
      await handle.close();
    }
    if (cancellation?.isCancelled ?? false)
      throw const TransferCancelledException();
    if (totalBytes == 0) onProgress?.call(0, 0);
    final finalize = await _http.postUrl(
      server.replace(path: '$basePath/finalize'),
    );
    finalize.headers.set('X-Bifrost-Resume-Token', resumeToken);
    final finalResponse = await finalize.close();
    final finalBody = await utf8.decoder.bind(finalResponse).join();
    if (finalResponse.statusCode != 201)
      throw StateError('Receiver could not finish the file: $finalBody');
    onProgress?.call(totalBytes, totalBytes);
  }

  Future<void> _sendLegacyFile({
    required Uri server,
    required File file,
    required String transferId,
    required String fileId,
    required String remoteName,
    required int totalBytes,
    required String digest,
    required TransferCancellation? cancellation,
    required void Function(int sent, int total)? onProgress,
  }) async {
    final request = await _http.putUrl(
      server.replace(path: '/bifrost/v1/transfers/$transferId/files/$fileId'),
    );
    request.contentLength = totalBytes;
    request.headers.set('X-Bifrost-Filename', remoteName);
    request.headers.set('X-Bifrost-SHA256', digest);
    var sent = 0;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    final stream = file.openRead().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          if (cancellation?.isCancelled ?? false) {
            sink.addError(const TransferCancelledException());
            return;
          }
          sent += chunk.length;
          final now = DateTime.now();
          if (sent == totalBytes ||
              now.difference(lastProgressAt) >=
                  const Duration(milliseconds: 200)) {
            lastProgressAt = now;
            onProgress?.call(sent, totalBytes);
          }
          sink.add(chunk);
        },
      ),
    );
    try {
      await request.addStream(stream);
      if (totalBytes == 0) onProgress?.call(0, 0);
      if (cancellation?.isCancelled ?? false)
        throw const TransferCancelledException();
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      if (response.statusCode != 201)
        throw StateError('Receiver rejected the file: $responseBody');
    } catch (error) {
      request.abort(error);
      if (error is TransferCancelledException ||
          (cancellation?.isCancelled ?? false)) {
        await cancelRemote(server: server, transferId: transferId);
        throw const TransferCancelledException();
      }
      rethrow;
    }
  }

  Future<void> cancelRemote({
    required Uri server,
    required String transferId,
  }) async {
    try {
      final request = await _http.postUrl(
        server.replace(path: '/bifrost/v1/transfers/$transferId/cancel'),
      );
      await request.close();
    } catch (_) {
      // Local cancellation still applies if the other device has disconnected.
    }
  }

  String _newResumeToken() {
    final bytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void close() => _http.close(force: true);
}
