import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest digest) => value = digest;

  @override
  void close() {}
}

Future<String> sha256File(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

class StreamingSha256Sink implements StreamConsumer<List<int>> {
  StreamingSha256Sink(this._output);

  final IOSink _output;
  final DigestCollector _digestSink = DigestCollector();
  late final ByteConversionSink _hashSink = sha256.startChunkedConversion(_digestSink);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _hashSink.add(chunk);
      _output.add(chunk);
    }
  }

  @override
  Future<void> close() async {
    _hashSink.close();
    await _output.close();
  }

  String get digest => _digestSink.value!.toString();
}
