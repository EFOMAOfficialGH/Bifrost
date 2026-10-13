import 'dart:async';

import 'package:flutter/material.dart';

enum AppThemeKind { day, sunset, night, deviceTime, customColor }

extension AppThemeKindLabel on AppThemeKind {
  String get label => switch (this) {
        AppThemeKind.day => 'Day',
        AppThemeKind.sunset => 'Sunset',
        AppThemeKind.night => 'Night',
        AppThemeKind.deviceTime => 'Use Device Time',
        AppThemeKind.customColor => 'Custom Color',
      };

  String get description => switch (this) {
        AppThemeKind.day => 'Blue sky, clouds, and warm sunlight',
        AppThemeKind.sunset => 'Amber sky, clouds, and a setting sun',
        AppThemeKind.night => 'Deep blue night with stars',
        AppThemeKind.deviceTime => 'Automatically changes with the clock',
        AppThemeKind.customColor => 'Choose a coordinated color atmosphere',
      };
}

AppThemeKind resolvedThemeKind(AppThemeKind kind, [DateTime? now]) {
  if (kind != AppThemeKind.deviceTime) return kind;
  final hour = (now ?? DateTime.now()).hour;
  if (hour >= 7 && hour < 17) return AppThemeKind.day;
  if (hour >= 17 && hour < 21) return AppThemeKind.sunset;
  return AppThemeKind.night;
}

abstract final class AppTheme {
  static const _seed = Color(0xFF6E5AE6);

  static ThemeData forKind(AppThemeKind kind, {Color? customColor, Color? textColor}) {
    final visualKind = resolvedThemeKind(kind);
    final seed = kind == AppThemeKind.customColor && customColor != null ? customColor : _seed;
    final brightness = visualKind == AppThemeKind.night || (kind == AppThemeKind.customColor && customColor != null && HSLColor.fromColor(customColor).lightness < .38) ? Brightness.dark : Brightness.light;
    final preferredText = textColor ?? (brightness == Brightness.dark ? Colors.white : Colors.black87);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(tertiary: const Color(0xFF00BFA5), onSurface: preferredText, onSurfaceVariant: preferredText.withAlpha(190));
    final panel = (brightness == Brightness.dark ? Colors.black : Colors.white).withAlpha(190);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      textTheme: ThemeData(brightness: brightness).textTheme.apply(bodyColor: preferredText, displayColor: preferredText),
      cardTheme: CardThemeData(color: panel, margin: EdgeInsets.zero, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant.withAlpha(150))),),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: panel, labelTextStyle: WidgetStateProperty.all(TextStyle(fontWeight: FontWeight.w600, color: preferredText))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    );
  }
}

class ThemeBackdrop extends StatefulWidget {
  const ThemeBackdrop({required this.kind, required this.child, this.customColor, super.key});
  final AppThemeKind kind;
  final Color? customColor;
  final Widget child;
  @override State<ThemeBackdrop> createState() => _ThemeBackdropState();
}

class _ThemeBackdropState extends State<ThemeBackdrop> {
  Timer? _clock;
  @override void initState() { super.initState(); _clock = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted && widget.kind == AppThemeKind.deviceTime) setState(() {}); }); }
  @override void didUpdateWidget(covariant ThemeBackdrop oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.kind != widget.kind || oldWidget.customColor != widget.customColor) setState(() {}); }
  @override void dispose() { _clock?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Stack(children: [Positioned.fill(child: CustomPaint(painter: _SkyPainter(widget.kind, widget.customColor))), Positioned.fill(child: widget.child)]);
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.kind, this.customColor);
  final AppThemeKind kind;
  final Color? customColor;

  @override
  void paint(Canvas canvas, Size size) {
    final visualKind = resolvedThemeKind(kind);
    final custom = kind == AppThemeKind.customColor && customColor != null;
    final base = customColor ?? const Color(0xFF3154B8);
    final colors = custom
        ? [base, _shift(base, .28)]
        : switch (visualKind) {
            AppThemeKind.day => const [Color(0xFF74C9F4), Color(0xFFDDF5FF)],
            AppThemeKind.sunset => const [Color(0xFFFF7B54), Color(0xFFFFD18A)],
            AppThemeKind.night => const [Color(0xFF050A2E), Color(0xFF142C63)],
            _ => const [Color(0xFF74C9F4), Color(0xFFDDF5FF)],
          };
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect));

    if (custom) {
      final glow = Paint()..color = _shift(base, .42).withAlpha(120);
      canvas.drawCircle(Offset(size.width * .18, size.height * .24), size.width * .18, glow);
      canvas.drawCircle(Offset(size.width * .82, size.height * .58), size.width * .26, Paint()..color = _shift(base, -.18).withAlpha(100));
    } else if (visualKind == AppThemeKind.night) {
      final starPaint = Paint()..color = Colors.white.withAlpha(190);
      for (var index = 0; index < 42; index++) {
        final x = ((index * 83) % 100) / 100 * size.width;
        final y = (20 + ((index * 47) % 48)) / 100 * size.height;
        canvas.drawCircle(Offset(x, y), index % 7 == 0 ? 1.8 : .9, starPaint);
      }
      final moon = Paint()..color = const Color(0xFFFFF1B8).withAlpha(220);
      canvas.drawCircle(Offset(size.width * .78, size.height * .18), 34, moon);
      canvas.drawCircle(Offset(size.width * .80, size.height * .16), 34, Paint()..color = colors.first);
    } else {
      final sunset = visualKind == AppThemeKind.sunset;
      final sunPaint = Paint()..color = (sunset ? const Color(0xFFFFE06B) : const Color(0xFFFFF2A6)).withAlpha(230);
      final sunCenter = Offset(size.width * (sunset ? .78 : .18), size.height * (sunset ? .70 : .18));
      canvas.drawCircle(sunCenter, sunset ? 62 : 48, sunPaint);
      _cloud(canvas, Offset(size.width * .18, size.height * .32), 1.0, Colors.white.withAlpha(sunset ? 110 : 175));
      _cloud(canvas, Offset(size.width * .68, size.height * .38), .78, Colors.white.withAlpha(sunset ? 95 : 155));
    }

    final horizon = size.height * .74;
    final land = Paint()..color = (custom ? _shift(base, -.25) : visualKind == AppThemeKind.night ? const Color(0xFF02071C) : visualKind == AppThemeKind.sunset ? const Color(0xFF8C3D4A) : const Color(0xFF2B7D73)).withAlpha(180);
    final path = Path()..moveTo(0, horizon + 32)..quadraticBezierTo(size.width * .18, horizon - 25, size.width * .36, horizon + 12)..quadraticBezierTo(size.width * .58, horizon - 42, size.width, horizon + 8)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(path, land);
  }

  void _cloud(Canvas canvas, Offset center, double scale, Color color) {
    final paint = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: center.translate(-38 * scale, 8 * scale), width: 82 * scale, height: 34 * scale), paint);
    canvas.drawCircle(center.translate(-24 * scale, -7 * scale), 22 * scale, paint);
    canvas.drawCircle(center.translate(4 * scale, -16 * scale), 29 * scale, paint);
    canvas.drawCircle(center.translate(34 * scale, 5 * scale), 20 * scale, paint);
  }

  @override bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.customColor != customColor;
}

Color _shift(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
