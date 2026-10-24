import 'package:flutter/material.dart' as material;

import 'app_localizations.dart';

/// A source-compatible Text wrapper that reads the active locale from context.
/// Keeping localization at the widget boundary also makes all existing UI text
/// react immediately when the locale changes.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.localized = true,
  });

  final String data;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;
  final bool localized;

  @override
  material.Widget build(material.BuildContext context) => material.Text(
        localized ? AppLocalizations.translate(context, data) : data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

/// Selectable localized body copy; use the framework's SelectableText directly
/// for opaque data such as connection codes.
class LocalizedSelectableText extends material.StatelessWidget {
  const LocalizedSelectableText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  final String data;
  final material.TextStyle? style;
  final material.TextAlign? textAlign;
  final int? maxLines;

  @override
  material.Widget build(material.BuildContext context) =>
      material.SelectableText(
        AppLocalizations.translate(context, data),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
}
