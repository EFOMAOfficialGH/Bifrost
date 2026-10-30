import '../../core/storage/app_storage.dart';

enum TransferHistoryCategory {
  all,
  images,
  videos,
  audio,
  documents,
  archives,
  apps,
  other,
}

enum TransferHistoryPeriod { all, today, last7Days, last30Days }

const _extensionsByCategory = <TransferHistoryCategory, Set<String>>{
  TransferHistoryCategory.images: {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.heic',
    '.tif',
    '.tiff',
  },
  TransferHistoryCategory.videos: {
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.3gp',
    '.m4v',
  },
  TransferHistoryCategory.audio: {
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.ogg',
    '.aac',
  },
  TransferHistoryCategory.documents: {
    '.pdf',
    '.txt',
    '.rtf',
    '.doc',
    '.docx',
    '.odt',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.csv',
  },
  TransferHistoryCategory.archives: {
    '.zip',
    '.7z',
    '.rar',
    '.tar',
    '.gz',
    '.bz2',
  },
  TransferHistoryCategory.apps: {'.apk', '.xapk', '.exe', '.msi'},
};

List<TransferRecord> filterTransferHistory(
  Iterable<TransferRecord> records, {
  String query = '',
  TransferHistoryCategory category = TransferHistoryCategory.all,
  TransferHistoryPeriod period = TransferHistoryPeriod.all,
  DateTime? now,
}) {
  final needle = query.trim().toLowerCase();
  final current = now ?? DateTime.now();
  return records
      .where((record) {
        if (!_matchesCategory(record.fileName, category) ||
            !_matchesPeriod(record.time, period, current))
          return false;
        if (needle.isEmpty) return true;
        final localTime = record.time.toLocal().toString().toLowerCase();
        final extension = _extensionOf(record.fileName);
        final categoryName = _categoryOf(record.fileName).name;
        return record.fileName.toLowerCase().contains(needle) ||
            record.peer.toLowerCase().contains(needle) ||
            localTime.contains(needle) ||
            extension.contains(needle) ||
            categoryName.contains(needle);
      })
      .toList(growable: false);
}

bool _matchesCategory(String fileName, TransferHistoryCategory selected) =>
    selected == TransferHistoryCategory.all ||
    _categoryOf(fileName) == selected;

bool _matchesPeriod(
  DateTime time,
  TransferHistoryPeriod selected,
  DateTime now,
) {
  if (selected == TransferHistoryPeriod.all) return true;
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  if (selected == TransferHistoryPeriod.today) {
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }
  final days = selected == TransferHistoryPeriod.last7Days ? 7 : 30;
  return !local.isBefore(today.subtract(Duration(days: days - 1)));
}

TransferHistoryCategory _categoryOf(String fileName) {
  final extension = _extensionOf(fileName);
  for (final entry in _extensionsByCategory.entries) {
    if (entry.value.contains(extension)) return entry.key;
  }
  return TransferHistoryCategory.other;
}

String _extensionOf(String fileName) {
  final basename = fileName.split(RegExp(r'[/\\]')).last.toLowerCase();
  final dot = basename.lastIndexOf('.');
  return dot <= 0 ? '' : basename.substring(dot);
}
