import 'dart:convert';
import 'dart:io';

import 'checksum.dart';
import 'protocol.dart';

class BifrostClient {
  BifrostClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();
  final HttpClient _http;

  Future<void> sendFile({required Uri server, required File file, String? remoteName, String transferId = 'transfer-1', String fileId = 'file-1'}) async {
    final digest = await sha256File(file);
    final offer = BifrostTransferOffer(files: [BifrostFileOffer(fileId: fileId, name: remoteName ?? file.uri.pathSegments.last, size: await file.length(), sha256: digest)], transferId: transferId);
    final offerRequest = await _http.postUrl(server.replace(path: '/bifrost/v1/offers'));
    offerRequest.headers.contentType = ContentType.json;
    offerRequest.write(offer.encode());
    final offerResponse = await offerRequest.close();
    final offerBody = await utf8.decoder.bind(offerResponse).join();
    if (offerResponse.statusCode != 202 || (jsonDecode(offerBody) as Map)['accepted'] != true) throw StateError('The receiver declined the transfer');

    final request = await _http.putUrl(server.replace(path: '/bifrost/v1/transfers/$transferId/files/$fileId'));
    request.contentLength = offer.files.single.size;
    request.headers.set('X-Bifrost-Filename', offer.files.single.name);
    request.headers.set('X-Bifrost-SHA256', digest);
    await request.addStream(file.openRead());
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode != 201) throw StateError('Receiver rejected the file: $responseBody');
  }

  void close() => _http.close(force: true);
}
