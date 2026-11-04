import 'package:flutter_test/flutter_test.dart';
import 'package:bifrost/core/changelog/app_changelog.dart';

void main() {
  const expectedVersions = <String>[
    '0.15.2+52',
    '0.15.1+51',
    '0.15.0+50',
    '0.14.10+48',
    '0.14.9+47',
    '0.14.8+46',
    '0.14.6+44',
    '0.14.5+43',
    '0.14.4+42',
    '0.14.3+41',
    '0.14.2+40',
    '0.14.1+39',
    '0.14.0+38',
    '0.13.6+37',
    '0.13.5+36',
    '0.13.4+35',
    '0.13.3+34',
    '0.13.2+33',
    '0.13.1+32',
    '0.13.0+31',
    '0.12.7+30',
    '0.12.7+29',
    '0.12.6+28',
    '0.12.5+27',
    '0.12.0+26',
    '0.12.0+25',
    '0.12.0+23',
    '0.11.3+21',
    '0.11.3+20',
    '0.11.3+19',
    '0.11.2+18',
    '0.11.1+17',
    '0.10.3+15',
    '0.10.2+14',
    '0.10.0+12',
    '0.9.0+11',
    '0.8.0+10',
    '0.7.0+9',
    '0.7.0+8',
    '0.6.1+7',
    '0.6.0+6',
    '0.5.0+5',
    '0.4.0+4',
    '0.3.0+3',
    '0.2.0+2',
    '0.1.0+1',
  ];

  test('lists every successful build version newest-first exactly once', () {
    expect(
      appChangelogEntries.map((entry) => entry.version).toList(),
      expectedVersions,
    );
    expect(
      appChangelogEntries.map((entry) => entry.version).toSet().length,
      expectedVersions.length,
    );
  });

  test('every listed build includes status and feature notes', () {
    for (final entry in appChangelogEntries) {
      expect(entry.status, isNotEmpty, reason: entry.version);
      expect(entry.highlights, isNotEmpty, reason: entry.version);
      expect(
        entry.highlights.every((highlight) => highlight.trim().isNotEmpty),
        isTrue,
        reason: entry.version,
      );
    }
  });

  test('identifies partial builds and excludes failed build versions', () {
    expect(
      appChangelogEntries
          .singleWhere((entry) => entry.version == '0.13.3+34')
          .status,
      'Windows-only build (not published)',
    );
    expect(
      appChangelogEntries
          .singleWhere((entry) => entry.version == '0.3.0+3')
          .status,
      'Android-only build (not published)',
    );
    expect(
      appChangelogEntries.any((entry) => entry.version == '0.14.7+45'),
      isFalse,
    );
  });
}
