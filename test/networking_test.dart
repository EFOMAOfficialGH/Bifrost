import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bifrost/core/networking/bifrost_client.dart';
import 'package:bifrost/core/networking/bifrost_server.dart';
import 'package:bifrost/core/networking/checksum.dart';
import 'package:bifrost/core/networking/protocol.dart';
import 'package:bifrost/core/networking/resumable_session_store.dart';

void main() {
  test('protocol round-trips an offer', () {
    final digest = List<String>.filled(64, 'a').join();
    final offer = BifrostTransferOffer(
      files: [
        BifrostFileOffer(
          fileId: 'f1',
          name: 'photo.jpg',
          size: 4,
          sha256: digest,
        ),
      ],
      transferId: 't1',
    );
    final decoded = BifrostTransferOffer.fromJson({
      'transferId': 't1',
      'files': [offer.files.single.toJson()],
    });
    expect(decoded.totalBytes, 4);
    expect(decoded.files.single.name, 'photo.jpg');
  });

  test('protocol rejects identifiers that could escape the transfer staging directory', () {
    expect(
      () => BifrostTransferOffer.fromJson({
        'transferId': '../../outside',
        'files': [
          {
            'fileId': 'safe',
            'name': 'file.bin',
            'size': 1,
            'sha256': List<String>.filled(64, 'a').join(),
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('streams and verifies a file larger than 200 MiB', () async {
    final root = await Directory.systemTemp.createTemp('bifrost-large-test-');
    const size = 201 * 1024 * 1024 + 17;
    final source = File('${root.path}/large-source.bin');
    final randomAccessFile = await source.open(mode: FileMode.write);
    await randomAccessFile.setPosition(size - 1);
    await randomAccessFile.writeByte(0x5A);
    await randomAccessFile.close();

    final destination = Directory('${root.path}/received');
    final server = BifrostServer(saveDirectory: destination);
    final client = BifrostClient();
    var lastReportedBytes = 0;
    var progressReports = 0;
    try {
      await server.start();
      await client.sendFile(
        server: Uri.parse(server.address),
        file: source,
        remoteName: 'large.bin',
        transferId: 'large-transfer',
        fileId: 'large-file',
        resumeToken: 'abcdef0123456789abcdef0123456789abcdef0123456789',
        useResumable: true,
        onProgress: (sent, total) {
          expect(total, size);
          expect(sent, greaterThanOrEqualTo(lastReportedBytes));
          lastReportedBytes = sent;
          progressReports++;
        },
      );
      final received = File('${destination.path}/large.bin');
      expect(await received.length(), size);
      expect(await sha256File(received), await sha256File(source));
      expect(progressReports, greaterThan(0));
      expect(progressReports, lessThan(200));
      expect(lastReportedBytes, size);
    } finally {
      client.close();
      await server.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('resumes acknowledged chunks after receiver restart without re-sending them', () async {
    final root = await Directory.systemTemp.createTemp('bifrost-resume-test-');
    final destination = Directory('${root.path}/received');
    const chunkSize = defaultResumeChunkSize;
    const size = chunkSize + 31;
    const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
    const senderId = 'sender-device';
    const transferId = 'resumable-transfer';
    const fileId = 'resumable-file';
    final source = File('${root.path}/resume-source.bin');
    final writer = await source.open(mode: FileMode.write);
    await writer.writeFrom(List<int>.filled(chunkSize, 0xC3));
    await writer.writeByte(0x5A);
    await writer.writeFrom(List<int>.filled(30, 0x11));
    await writer.close();

    var initialOfferPrompts = 0;
    var restartedOfferPrompts = 0;
    final firstServer = BifrostServer(
      saveDirectory: destination,
      onOfferWithSender: (offer, deviceId, deviceName) async {
        initialOfferPrompts++;
        return true;
      },
    );
    final rawClient = HttpClient();
    BifrostServer? restartedServer;
    final resumedClient = BifrostClient();
    try {
      await firstServer.start();
      final digest = await sha256File(source);
      final offer = BifrostTransferOffer(
        transferId: transferId,
        files: [
          BifrostFileOffer(
            fileId: fileId,
            name: 'resume.bin',
            size: size,
            sha256: digest,
          ),
        ],
      );
      final offerRequest = await rawClient.postUrl(
        Uri.parse('${firstServer.address}/bifrost/v1/offers'),
      );
      offerRequest.headers.contentType = ContentType.json;
      offerRequest.headers.set('X-Bifrost-Device-Id', senderId);
      offerRequest.write(offer.encode());
      final offerResponse = await offerRequest.close();
      expect(offerResponse.statusCode, 202);
      await offerResponse.drain<void>();
      expect(initialOfferPrompts, 1);

      final basePath = '/bifrost/v2/transfers/$transferId/files/$fileId';
      final beginRequest = await rawClient.postUrl(
        Uri.parse('${firstServer.address}$basePath/begin'),
      );
      beginRequest.headers.contentType = ContentType.json;
      beginRequest.headers.set('X-Bifrost-Resume-Token', token);
      beginRequest.write(jsonEncode({'chunkSize': chunkSize}));
      final beginResponse = await beginRequest.close();
      expect(beginResponse.statusCode, 200);
      await beginResponse.drain<void>();

      final reader = await source.open(mode: FileMode.read);
      final firstChunk = await reader.read(chunkSize);
      await reader.close();
      final chunkRequest = await rawClient.putUrl(
        Uri.parse('${firstServer.address}$basePath/chunks/0'),
      );
      chunkRequest.contentLength = firstChunk.length;
      chunkRequest.headers.set('X-Bifrost-Resume-Token', token);
      chunkRequest.headers.set(
        'X-Bifrost-Chunk-SHA256',
        sha256.convert(firstChunk).toString(),
      );
      chunkRequest.add(firstChunk);
      final chunkResponse = await chunkRequest.close();
      expect(chunkResponse.statusCode, 201);
      await chunkResponse.drain<void>();

      final unauthorized = await rawClient.getUrl(
        Uri.parse('${firstServer.address}$basePath/status'),
      );
      unauthorized.headers.set(
        'X-Bifrost-Resume-Token',
        List<String>.filled(48, '0').join(),
      );
      final unauthorizedResponse = await unauthorized.close();
      expect(unauthorizedResponse.statusCode, 409);
      await unauthorizedResponse.drain<void>();

      await firstServer.close();
      restartedServer = BifrostServer(
        saveDirectory: destination,
        onOfferWithSender: (offer, deviceId, deviceName) async {
          restartedOfferPrompts++;
          return true;
        },
      );
      await restartedServer.start();
      await resumedClient.sendFile(
        server: Uri.parse(restartedServer.address),
        file: source,
        remoteName: 'resume.bin',
        transferId: transferId,
        fileId: fileId,
        senderDeviceId: senderId,
        resumeToken: token,
        useResumable: true,
      );
      final received = File('${destination.path}/resume.bin');
      expect(await received.length(), size);
      expect(await sha256File(received), digest);
      expect(restartedOfferPrompts, 0);
    } finally {
      rawClient.close(force: true);
      resumedClient.close();
      await firstServer.close();
      await restartedServer?.close();
      await root.delete(recursive: true);
    }
  });

  test('server receives a file and verifies its checksum', () async {
    final root = await Directory.systemTemp.createTemp('bifrost-test-');
    final source = File('${root.path}/source.txt')
      ..writeAsStringSync('Bifrost works');
    final destination = Directory('${root.path}/received');
    final server = BifrostServer(saveDirectory: destination);
    final client = BifrostClient();
    await server.start();
    await client.sendFile(
      server: Uri.parse(server.address),
      file: source,
      remoteName: '../safe.txt',
    );
    expect(await File('${destination.path}/__safe.txt').exists(), isTrue);
    expect(
      await File('${destination.path}/__safe.txt').readAsString(),
      'Bifrost works',
    );
    expect(
      await sha256File(File('${destination.path}/__safe.txt')),
      await sha256File(source),
    );
    client.close();
    await server.close();
    await root.delete(recursive: true);
  });
}
