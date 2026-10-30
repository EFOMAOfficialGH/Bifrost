import 'dart:convert';

const bifrostProtocolVersion = 1;

class BifrostFileOffer {
  const BifrostFileOffer({
    required this.fileId,
    required this.name,
    required this.size,
    required this.sha256,
  });
  final String fileId;
  final String name;
  final int size;
  final String sha256;

  Map<String, Object> toJson() => {
    'fileId': fileId,
    'name': name,
    'size': size,
    'sha256': sha256,
  };

  factory BifrostFileOffer.fromJson(Map<String, dynamic> json) =>
      BifrostFileOffer(
        fileId: _identifier(json, 'fileId'),
        name: _string(json, 'name'),
        size: _int(json, 'size'),
        sha256: _digest(json, 'sha256'),
      );
}

class BifrostTransferOffer {
  const BifrostTransferOffer({required this.transferId, required this.files});
  final String transferId;
  final List<BifrostFileOffer> files;
  int get totalBytes => files.fold(0, (sum, file) => sum + file.size);

  Map<String, Object> toJson() => {
    'transferId': transferId,
    'files': files.map((file) => file.toJson()).toList(),
    'totalBytes': totalBytes,
  };
  String encode() => jsonEncode(toJson());

  factory BifrostTransferOffer.fromJson(Map<String, dynamic> json) =>
      BifrostTransferOffer(
        transferId: _identifier(json, 'transferId'),
        files: (_list(json, 'files'))
            .map(
              (item) => BifrostFileOffer.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty)
    throw FormatException('Missing or invalid $key');
  return value;
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0)
    throw FormatException('Missing or invalid $key');
  return value;
}

String _identifier(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value))
    throw FormatException('Missing or invalid $key');
  return value;
}

String _digest(Map<String, dynamic> json, String key) {
  final value = _string(json, key).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value))
    throw FormatException('Missing or invalid $key');
  return value;
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.isEmpty)
    throw FormatException('Missing or invalid $key');
  return value;
}
