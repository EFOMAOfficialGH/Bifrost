import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bifrost/core/networking/bifrost_client.dart';
import 'package:bifrost/core/networking/bifrost_server.dart';
import 'package:bifrost/core/networking/checksum.dart';
import 'package:bifrost/core/networking/protocol.dart';

void main() {
  test('protocol round-trips an offer', () {
    const offer = BifrostTransferOffer(files: [BifrostFileOffer(fileId: 'f1', name: 'photo.jpg', size: 4, sha256: 'abcd')], transferId: 't1');
    final decoded = BifrostTransferOffer.fromJson({'transferId': 't1', 'files': [offer.files.single.toJson()]});
    expect(decoded.totalBytes, 4);
    expect(decoded.files.single.name, 'photo.jpg');
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
  });

  test('server receives a file and verifies its checksum', () async {
    final root = await Directory.systemTemp.createTemp('bifrost-test-');
    final source = File('${root.path}/source.txt')..writeAsStringSync('Bifrost works');
    final destination = Directory('${root.path}/received');
    final server = BifrostServer(saveDirectory: destination);
    final client = BifrostClient();
    await server.start();
    await client.sendFile(server: Uri.parse(server.address), file: source, remoteName: '../safe.txt');
    expect(await File('${destination.path}/__safe.txt').exists(), isTrue);
    expect(await File('${destination.path}/__safe.txt').readAsString(), 'Bifrost works');
    expect(await sha256File(File('${destination.path}/__safe.txt')), await sha256File(source));
    client.close();
    await server.close();
    await root.delete(recursive: true);
  });
}
