import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'checksum.dart';
import 'protocol.dart';

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

  Future<void> sendFile({required Uri server, required File file, String? remoteName, String transferId = 'transfer-1', String fileId = 'file-1', String? senderDeviceId, String? senderDeviceName, TransferCancellation? cancellation, void Function(int sent, int total)? onProgress}) async {
    final digest = await sha256File(file);
    final offer = BifrostTransferOffer(files: [BifrostFileOffer(fileId: fileId, name: remoteName ?? file.uri.pathSegments.last, size: await file.length(), sha256: digest)], transferId: transferId);
    final offerRequest = await _http.postUrl(server.replace(path: '/bifrost/v1/offers'));
    offerRequest.headers.contentType = ContentType.json;
    if (senderDeviceId != null) offerRequest.headers.set('X-Bifrost-Device-Id', senderDeviceId);
    if (senderDeviceName != null) offerRequest.headers.set('X-Bifrost-Device-Name', senderDeviceName);
    offerRequest.write(offer.encode());
    final offerResponse = await offerRequest.close();
    final offerBody = await utf8.decoder.bind(offerResponse).join();
    if (offerResponse.statusCode != 202 || (jsonDecode(offerBody) as Map)['accepted'] != true) throw StateError('The receiver declined the transfer');
    if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();

    final request = await _http.putUrl(server.replace(path: '/bifrost/v1/transfers/$transferId/files/$fileId'));
    request.contentLength = offer.files.single.size;
    request.headers.set('X-Bifrost-Filename', offer.files.single.name);
    request.headers.set('X-Bifrost-SHA256', digest);
    var sent = 0;
    final stream = file.openRead().transform(StreamTransformer<List<int>, List<int>>.fromHandlers(handleData: (chunk, sink) {
      if (cancellation?.isCancelled ?? false) {
        sink.addError(const TransferCancelledException());
        return;
      }
      sent += chunk.length;
      onProgress?.call(sent, offer.files.single.size);
      sink.add(chunk);
    }));
    try {
      await request.addStream(stream);
      if (cancellation?.isCancelled ?? false) throw const TransferCancelledException();
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();
      if (response.statusCode != 201) throw StateError('Receiver rejected the file: $responseBody');
    } catch (error) {
      request.abort(error);
      if (error is TransferCancelledException || (cancellation?.isCancelled ?? false)) {
        await cancelRemote(server: server, transferId: transferId);
        throw const TransferCancelledException();
      }
      rethrow;
    }
  }

  Future<void> cancelRemote({required Uri server, required String transferId}) async {
    try {
      final request = await _http.postUrl(server.replace(path: '/bifrost/v1/transfers/$transferId/cancel'));
      await request.close();
    } catch (_) {
      // The local cancellation still applies if the other device has already disconnected.
    }
  }

  void close() => _http.close(force: true);
}
