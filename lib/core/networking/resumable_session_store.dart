import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'checksum.dart';
import 'protocol.dart';

const defaultResumeChunkSize = 4 * 1024 * 1024;
const minResumeChunkSize = 64 * 1024;
const maxResumeChunkSize = 16 * 1024 * 1024;

class ResumeStatus {
  const ResumeStatus({
    required this.chunkSize,
    required this.chunkCount,
    required this.receivedChunks,
    required this.completed,
    this.path,
  });

  final int chunkSize;
  final int chunkCount;
  final List<int> receivedChunks;
  final bool completed;
  final String? path;

  List<int> get missingChunks => [
    for (var index = 0; index < chunkCount; index++)
      if (!receivedChunks.contains(index)) index,
  ];

  Map<String, Object?> toJson() => {
    'chunkSize': chunkSize,
    'chunkCount': chunkCount,
    'receivedChunks': receivedChunks,
    'missingChunks': missingChunks,
    'completed': completed,
    if (path != null) 'path': path,
  };
}

class ResumeFinalizeResult {
  const ResumeFinalizeResult({
    required this.path,
    required this.sha256,
    required this.newlyCompleted,
  });

  final String path;
  final String sha256;
  final bool newlyCompleted;
}

/// File-backed resume journal. A chunk is flushed before its manifest entry is
/// committed. If the app stops between those writes, the sender safely retries
/// that chunk; it never assumes unrecorded bytes are complete.
class ResumableSessionStore {
  ResumableSessionStore(this.saveDirectory);

  final Directory saveDirectory;
  final Map<String, Future<void>> _locks = {};
  static const _retention = Duration(days: 30);

  Directory _root() => Directory(
    '${saveDirectory.path}${Platform.pathSeparator}.bifrost-resume',
  );

  Directory _sessionDirectory(String transferId, String fileId) => Directory(
    '${_root().path}${Platform.pathSeparator}$transferId${Platform.pathSeparator}$fileId',
  );

  File _partFile(String transferId, String fileId) => File(
    '${_sessionDirectory(transferId, fileId).path}${Platform.pathSeparator}data.part',
  );

  Directory _chunksDirectory(String transferId, String fileId) => Directory(
    '${_sessionDirectory(transferId, fileId).path}${Platform.pathSeparator}chunks',
  );

  File _chunkFile(String transferId, String fileId, int index) => File(
    '${_chunksDirectory(transferId, fileId).path}${Platform.pathSeparator}$index.part',
  );

  Future<bool> matchesExisting(
    BifrostTransferOffer offer,
    String? senderDeviceId,
  ) async {
    for (final file in offer.files) {
      final manifest = await _readManifest(offer.transferId, file.fileId);
      if (manifest == null ||
          manifest['status'] == 'cancelled' ||
          manifest['transferId'] != offer.transferId ||
          manifest['fileId'] != file.fileId ||
          manifest['name'] != file.name ||
          manifest['size'] != file.size ||
          manifest['sha256'] != file.sha256 ||
          manifest['senderDeviceId'] != senderDeviceId) {
        return false;
      }
    }
    return offer.files.isNotEmpty;
  }

  Future<ResumeStatus> begin({
    required String transferId,
    required BifrostFileOffer file,
    required String? senderDeviceId,
    required String? senderDeviceName,
    required String resumeToken,
    int chunkSize = defaultResumeChunkSize,
  }) => _withLock('$transferId/${file.fileId}', () async {
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(resumeToken))
      throw StateError('Invalid resume token');
    final safeChunkSize = chunkSize
        .clamp(minResumeChunkSize, maxResumeChunkSize)
        .toInt();
    final directory = _sessionDirectory(transferId, file.fileId);
    await directory.create(recursive: true);
    var manifest = await _readManifest(transferId, file.fileId);
    if (manifest != null) {
      _validateManifest(
        manifest,
        transferId,
        file,
        senderDeviceId,
        resumeToken,
      );
      if (manifest['status'] == 'cancelled')
        throw StateError('This transfer was cancelled');
      await _refreshReceivedChunks(transferId, file.fileId, manifest);
      manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _writeManifest(directory, manifest);
      return _statusFrom(manifest);
    }
    final chunkCount = file.size == 0
        ? 0
        : (file.size + safeChunkSize - 1) ~/ safeChunkSize;
    await _chunksDirectory(transferId, file.fileId).create(recursive: true);
    manifest = {
      'revision': 0,
      'transferId': transferId,
      'fileId': file.fileId,
      'name': file.name,
      'size': file.size,
      'sha256': file.sha256,
      'chunkSize': safeChunkSize,
      'chunkCount': chunkCount,
      'senderDeviceId': senderDeviceId,
      'senderDeviceName': senderDeviceName,
      'resumeToken': resumeToken,
      'receivedChunks': <String, String>{},
      'status': 'receiving',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writeManifest(directory, manifest);
    return _statusFrom(manifest);
  });

  Future<ResumeStatus> status(
    String transferId,
    String fileId, {
    required String resumeToken,
  }) => _withLock('$transferId/$fileId', () async {
    final manifest = await _readManifest(transferId, fileId);
    if (manifest == null) throw StateError('Resume session not found');
    _validateToken(manifest, resumeToken);
    return _statusFrom(manifest);
  });

  Future<int> receiveChunk({
    required String transferId,
    required String fileId,
    required String resumeToken,
    required int index,
    required List<int> bytes,
    required String declaredSha256,
  }) => _withLock('$transferId/$fileId', () async {
    final manifest = await _readManifest(transferId, fileId);
    if (manifest == null) throw StateError('Resume session not found');
    _validateToken(manifest, resumeToken);
    if (manifest['status'] != 'receiving')
      throw StateError('Resume session is not accepting chunks');
    final chunkSize = manifest['chunkSize'] as int;
    final chunkCount = manifest['chunkCount'] as int;
    final size = manifest['size'] as int;
    if (index < 0 || index >= chunkCount)
      throw StateError('Chunk index is outside the file');
    final expectedLength = (size - index * chunkSize)
        .clamp(0, chunkSize)
        .toInt();
    if (bytes.length != expectedLength)
      throw StateError('Chunk length does not match the file');
    final actualDigest = sha256.convert(bytes).toString();
    if (actualDigest != declaredSha256.toLowerCase())
      throw StateError('Chunk checksum mismatch');

    final chunkDirectory = _chunksDirectory(transferId, fileId);
    await chunkDirectory.create(recursive: true);
    await _chunkFile(
      transferId,
      fileId,
      index,
    ).writeAsBytes(bytes, flush: true);
    final chunks = Map<String, String>.from(manifest['receivedChunks'] as Map);
    chunks['$index'] = actualDigest;
    manifest['receivedChunks'] = chunks;
    manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _writeManifest(_sessionDirectory(transferId, fileId), manifest);
    return _receivedBytes(manifest);
  });

  Future<ResumeFinalizeResult> finalize({
    required String transferId,
    required String fileId,
    required String resumeToken,
  }) => _withLock('$transferId/$fileId', () async {
    final manifest = await _readManifest(transferId, fileId);
    if (manifest == null) throw StateError('Resume session not found');
    _validateToken(manifest, resumeToken);
    if (manifest['status'] == 'completed') {
      final path = manifest['finalPath'] as String?;
      if (path == null) throw StateError('Completed file path is missing');
      return ResumeFinalizeResult(
        path: path,
        sha256: manifest['sha256'] as String,
        newlyCompleted: false,
      );
    }
    if (manifest['status'] != 'receiving' &&
        manifest['status'] != 'finalizing') {
      throw StateError('Resume session cannot be finalized');
    }
    await _refreshReceivedChunks(transferId, fileId, manifest);
    final expectedChunks = manifest['chunkCount'] as int;
    final received = Map<String, String>.from(
      manifest['receivedChunks'] as Map,
    );
    final missing = [
      for (var index = 0; index < expectedChunks; index++)
        if (!received.containsKey('$index')) index,
    ];
    if (missing.isNotEmpty)
      throw StateError('Chunks are missing: ${missing.join(',')}');

    final part = _partFile(transferId, fileId);
    final size = manifest['size'] as int;
    final directory = _sessionDirectory(transferId, fileId);
    var finalPath = manifest['finalPath'] as String?;
    if (manifest['status'] == 'finalizing' &&
        finalPath != null &&
        await File(finalPath).exists()) {
      if (await File(finalPath).length() == size &&
          await sha256File(File(finalPath)) == manifest['sha256']) {
        manifest['status'] = 'completed';
        manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        await _writeManifest(directory, manifest);
        final chunks = _chunksDirectory(transferId, fileId);
        if (await chunks.exists()) await chunks.delete(recursive: true);
        return ResumeFinalizeResult(
          path: finalPath,
          sha256: manifest['sha256'] as String,
          newlyCompleted: true,
        );
      }
      await File(finalPath).delete();
    }
    if (finalPath == null) {
      finalPath = _uniqueDestination(manifest['name'] as String).path;
      manifest['status'] = 'finalizing';
      manifest['finalPath'] = finalPath;
      manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _writeManifest(directory, manifest);
    }
    final output = await part.open(mode: FileMode.write);
    try {
      for (var index = 0; index < expectedChunks; index++) {
        final chunk = _chunkFile(transferId, fileId, index);
        final expectedLength = (size - index * (manifest['chunkSize'] as int))
            .clamp(0, manifest['chunkSize'] as int)
            .toInt();
        if (!await chunk.exists() || await chunk.length() != expectedLength) {
          throw StateError(
            'A saved file chunk is missing or has an invalid size',
          );
        }
        final chunkDigest = await sha256File(chunk);
        if (chunkDigest != received['$index']) {
          throw StateError('A saved file chunk failed its checksum');
        }
        await for (final bytes in chunk.openRead()) {
          await output.writeFrom(bytes);
        }
      }
      await output.flush();
    } finally {
      await output.close();
    }
    if (await part.length() != size)
      throw StateError('File size does not match');
    final digest = await sha256File(part);
    if (digest != manifest['sha256'])
      throw StateError('File checksum mismatch');
    await part.rename(finalPath);
    manifest['status'] = 'completed';
    manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _writeManifest(directory, manifest);
    final chunks = _chunksDirectory(transferId, fileId);
    if (await chunks.exists()) await chunks.delete(recursive: true);
    return ResumeFinalizeResult(
      path: finalPath,
      sha256: digest,
      newlyCompleted: true,
    );
  });

  Future<void> deleteTransfer(String transferId) async {
    final transferDirectory = Directory(
      '${_root().path}${Platform.pathSeparator}$transferId',
    );
    if (!await transferDirectory.exists()) return;
    await for (final entity in transferDirectory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final fileId = entity.path.split(Platform.pathSeparator).last;
      await _withLock('$transferId/$fileId', () async {
        if (await entity.exists()) await entity.delete(recursive: true);
      });
    }
    if (await transferDirectory.exists())
      await transferDirectory.delete(recursive: true);
  }

  Future<void> cleanupExpired() async {
    final root = _root();
    if (!await root.exists()) return;
    final now = DateTime.now();
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final stat = await entity.stat();
      if (now.difference(stat.modified) <= _retention) continue;
      await entity.delete(recursive: true);
    }
  }

  ResumeStatus _statusFrom(Map<String, dynamic> manifest) {
    final received =
        (manifest['receivedChunks'] as Map).keys
            .map((key) => int.parse(key.toString()))
            .toList()
          ..sort();
    return ResumeStatus(
      chunkSize: manifest['chunkSize'] as int,
      chunkCount: manifest['chunkCount'] as int,
      receivedChunks: received,
      completed: manifest['status'] == 'completed',
      path: manifest['finalPath'] as String?,
    );
  }

  int _receivedBytes(Map<String, dynamic> manifest) {
    final size = manifest['size'] as int;
    final chunkSize = manifest['chunkSize'] as int;
    final chunks = (manifest['receivedChunks'] as Map).keys
        .map((key) => int.parse(key.toString()))
        .toSet();
    var bytes = 0;
    for (final index in chunks) {
      bytes += (size - index * chunkSize).clamp(0, chunkSize).toInt();
    }
    return bytes;
  }

  Future<void> _refreshReceivedChunks(
    String transferId,
    String fileId,
    Map<String, dynamic> manifest,
  ) async {
    if (manifest['status'] == 'completed') return;
    final chunks = Map<String, String>.from(manifest['receivedChunks'] as Map);
    var changed = false;
    final size = manifest['size'] as int;
    final chunkSize = manifest['chunkSize'] as int;
    final chunkCount = manifest['chunkCount'] as int;
    for (final key in chunks.keys.toList()) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= chunkCount) {
        chunks.remove(key);
        changed = true;
        continue;
      }
      final file = _chunkFile(transferId, fileId, index);
      final expectedLength = (size - index * chunkSize)
          .clamp(0, chunkSize)
          .toInt();
      if (!await file.exists() || await file.length() != expectedLength) {
        chunks.remove(key);
        changed = true;
        continue;
      }
      if (await sha256File(file) != chunks[key]) {
        chunks.remove(key);
        changed = true;
      }
    }
    if (changed) {
      manifest['receivedChunks'] = chunks;
      manifest['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _writeManifest(_sessionDirectory(transferId, fileId), manifest);
    }
  }

  void _validateManifest(
    Map<String, dynamic> manifest,
    String transferId,
    BifrostFileOffer file,
    String? senderDeviceId,
    String resumeToken,
  ) {
    if (manifest['transferId'] != transferId ||
        manifest['fileId'] != file.fileId ||
        manifest['name'] != file.name ||
        manifest['size'] != file.size ||
        manifest['sha256'] != file.sha256 ||
        manifest['senderDeviceId'] != senderDeviceId ||
        manifest['resumeToken'] != resumeToken) {
      throw StateError('Resume request does not match the saved transfer');
    }
  }

  void _validateToken(Map<String, dynamic> manifest, String resumeToken) {
    if (resumeToken.isEmpty || manifest['resumeToken'] != resumeToken)
      throw StateError('Invalid resume token');
  }

  Future<T> _withLock<T>(String key, Future<T> Function() operation) async {
    final previous = _locks[key];
    final gate = Completer<void>();
    _locks[key] = gate.future;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      if (identical(_locks[key], gate.future)) _locks.remove(key);
      gate.complete();
    }
  }

  File _uniqueDestination(String requestedName) {
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

  Future<Map<String, dynamic>?> _readManifest(
    String transferId,
    String fileId,
  ) async {
    final directory = _sessionDirectory(transferId, fileId);
    final manifests = <Map<String, dynamic>>[];
    for (final name in const ['manifest-a.json', 'manifest-b.json']) {
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      if (!await file.exists()) continue;
      try {
        manifests.add(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      } catch (_) {
        // The other alternating slot may still contain the last valid commit.
      }
    }
    if (manifests.isEmpty) return null;
    manifests.sort(
      (a, b) =>
          (b['revision'] as int? ?? 0).compareTo(a['revision'] as int? ?? 0),
    );
    return manifests.first;
  }

  Future<void> _writeManifest(
    Directory directory,
    Map<String, dynamic> manifest,
  ) async {
    final revision = (manifest['revision'] as int? ?? 0) + 1;
    manifest['revision'] = revision;
    final slot = revision.isEven ? 'a' : 'b';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}manifest-$slot.json',
    );
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(manifest), flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }
}
