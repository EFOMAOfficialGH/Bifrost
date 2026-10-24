import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations._();

  static final Map<String, String> _arabic = {};
  static final List<_TranslationPattern> _patterns = [];
  static String currentLanguageCode = 'en';

  static Future<void> load() async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/localization/strings.json'),
    ) as Map<String, dynamic>;
    final entries = decoded['strings'] as List<dynamic>;
    _arabic.clear();
    _patterns.clear();
    for (final value in entries) {
      final entry = value as Map<String, dynamic>;
      final english = entry['en'] as String;
      final arabic = entry['ar'] as String;
      if (english.contains('{')) {
        _patterns.add(_TranslationPattern(english, arabic));
      } else {
        _arabic[english] = arabic;
      }
    }
    _patterns.sort((a, b) => b.english.length.compareTo(a.english.length));
  }

  static String translate(BuildContext context, String value) {
    final language = Localizations.localeOf(context).languageCode;
    return translateFor(language, value);
  }

  static String translateCurrent(String value) =>
      translateFor(currentLanguageCode, value);

  static String translateFor(String languageCode, String value) {
    if (languageCode != 'ar') return value;
    // These language names are intentionally invariant in both app locales.
    if (value == 'English' || value == 'العربية') return value;

    final direct = _arabic[value];
    if (direct != null) return direct;

    for (final pattern in _patterns) {
      final match = pattern.regExp.firstMatch(value);
      if (match == null) continue;
      var result = pattern.arabic;
      for (var index = 0; index < pattern.placeholders.length; index++) {
        final name = pattern.placeholders[index];
        var replacement = match.group(index + 1) ?? '';
        if (const {'status', 'direction', 'time', 'size', 'received', 'total', 'details', 'extra', 'speed', 'eta', 'feature'}.contains(name)) {
          replacement = translateFor(languageCode, replacement);
        }
        if (const {'path', 'id', 'address', 'ip'}.contains(name)) {
          replacement = '\u2066$replacement\u2069';
        }
        result = result.replaceAll('{$name}', replacement);
      }
      return _localizeUnits(result);
    }
    return _localizeUnits(value);
  }

  static String _localizeUnits(String value) {
    var result = value;
    const units = <String, String>{
      'GB/s': 'غيغابايت/ث',
      'MB/s': 'ميغابايت/ث',
      'KB/s': 'كيلوبايت/ث',
      'GB': 'غيغابايت',
      'MB': 'ميغابايت',
      'KB': 'كيلوبايت',
      ' B': ' بايت',
    };
    for (final unit in units.entries) {
      result = result.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)\s*' + RegExp.escape(unit.key) + r'\b'),
        (match) => '${match.group(1)} ${unit.value}',
      );
    }
    result = result.replaceAllMapped(
      RegExp(r'(\d+)s\b'),
      (match) => '${match.group(1)} ثانية',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\d+)m\b'),
      (match) => '${match.group(1)} دقيقة',
    );
    return result.replaceAll(' left', ' متبقية');
  }
}

class _TranslationPattern {
  _TranslationPattern(this.english, this.arabic)
      : placeholders = _placeholderPattern.allMatches(english)
            .map((match) => match.group(1)!)
            .toList(growable: false),
        regExp = _buildRegExp(english);

  static final _placeholderPattern = RegExp(r'\{([A-Za-z0-9_]+)\}');

  final String english;
  final String arabic;
  final List<String> placeholders;
  final RegExp regExp;

  static RegExp _buildRegExp(String source) {
    final buffer = StringBuffer('^');
    var cursor = 0;
    for (final match in _placeholderPattern.allMatches(source)) {
      buffer.write(RegExp.escape(source.substring(cursor, match.start)));
      buffer.write(r'([\s\S]*?)');
      cursor = match.end;
    }
    buffer.write(RegExp.escape(source.substring(cursor)));
    final expression = buffer.toString().replaceAll(r'file\(s\)', r'files?');
    buffer.clear();
    buffer.write(expression);
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }
}
