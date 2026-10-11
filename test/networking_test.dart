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
