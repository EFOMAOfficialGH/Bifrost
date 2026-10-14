import 'dart:convert';
import 'dart:io';

class BifrostRelease {
  const BifrostRelease({required this.tag, required this.name, required this.notes, required this.publishedAt, required this.apkUrl, required this.apkSizeBytes, required this.windowsUrl, required this.windowsSizeBytes});
  final String tag;
  final String name;
  final String notes;
  final DateTime publishedAt;
  final String? apkUrl;
  final int? apkSizeBytes;
  final String? windowsUrl;
  final int? windowsSizeBytes;

  String get version => tag.replaceFirst(RegExp(r'^v'), '');
}

class BifrostUpdateService {
  BifrostUpdateService._();
  static final instance = BifrostUpdateService._();
  static const _releasesUrl = 'https://api.github.com/repos/EFOMAOfficialGH/Bifrost/releases?per_page=20';
  HttpClientRequest? _activeRequest;
  bool _cancelRequested = false;

  Future<BifrostRelease?> latest({required String currentVersion}) async {
    final client = HttpClient()..userAgent = 'Bifrost-Updater';
    try {
      final request = await client.getUrl(Uri.parse(_releasesUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) throw HttpException('GitHub returned HTTP ${response.statusCode}');
      final decoded = jsonDecode(await response.transform(utf8.decoder).join()) as List<dynamic>;
      final releases = decoded.whereType<Map<String, dynamic>>().where((json) => json['draft'] != true).map(_releaseFromJson).whereType<BifrostRelease>().where((release) => _compareVersions(release.version, currentVersion) > 0).toList();
      releases.sort((a, b) => _compareVersions(b.version, a.version));
      return releases.isEmpty ? null : releases.first;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(String url, {required void Function(int received, int? total) onProgress}) async {
    if (_activeRequest != null) throw StateError('Another update download is already running');
    final client = HttpClient()..userAgent = 'Bifrost-Updater';
    File? target;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      _activeRequest = request;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) throw HttpException('Download failed with HTTP ${response.statusCode}');
      final fileName = Uri.parse(url).pathSegments.last.split('?').first;
      target = File('${Directory.systemTemp.path}${Platform.pathSeparator}bifrost-update-$fileName');
      sink = target.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (_cancelRequested) throw const UpdateDownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, response.contentLength > 0 ? response.contentLength : null);
      }
      await sink.close();
      sink = null;
      return target;
    } on UpdateDownloadCancelled {
      await sink?.close();
      if (target != null && await target.exists()) await target.delete();
      rethrow;
    } finally {
      await sink?.close();
      _activeRequest = null;
      _cancelRequested = false;
      client.close(force: true);
    }
  }

  void cancelDownload() {
    _cancelRequested = true;
    _activeRequest?.abort();
  }

  BifrostRelease? _releaseFromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    final published = DateTime.tryParse(json['published_at'] as String? ?? '');
    if (tag == null || published == null) return null;
    final assets = (json['assets'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>();
    String? apk;
    int? apkSize;
    String? windows;
    int? windowsSize;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'] as String?;
      final size = (asset['size'] as num?)?.toInt();
      if (url == null) continue;
      if (name.endsWith('.apk') && apk == null) { apk = url; apkSize = size; }
      if (name.endsWith('.exe') && name.contains('windows') && windows == null) { windows = url; windowsSize = size; }
    }
    if (apk == null && windows == null) return null;
    return BifrostRelease(tag: tag, name: json['name'] as String? ?? tag, notes: json['body'] as String? ?? '', publishedAt: published, apkUrl: apk, apkSizeBytes: apkSize, windowsUrl: windows, windowsSizeBytes: windowsSize);
  }
}

class UpdateDownloadCancelled implements Exception {
  const UpdateDownloadCancelled();
}

int _compareVersions(String left, String right) {
  final a = _versionParts(left);
  final b = _versionParts(right);
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return a[index].compareTo(b[index]);
  }
  return 0;
}

List<int> _versionParts(String value) {
  final clean = value.trim().replaceFirst(RegExp(r'^v'), '');
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?').firstMatch(clean);
  if (match == null) return const [0, 0, 0, 0];
  return [for (var index = 1; index <= 4; index++) int.tryParse(match.group(index) ?? '') ?? 0];
}
