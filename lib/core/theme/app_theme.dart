import 'package:flutter/material.dart';

enum AppThemeKind { day, sunset, night }

extension AppThemeKindLabel on AppThemeKind {
  String get label => switch (this) {
        AppThemeKind.day => 'Day',
        AppThemeKind.sunset => 'Sunset',
        AppThemeKind.night => 'Night',
      };

  String get description => switch (this) {
        AppThemeKind.day => 'Blue sky, clouds, and warm sunlight',
        AppThemeKind.sunset => 'Amber sky, clouds, and a setting sun',
        AppThemeKind.night => 'Deep blue night with stars',
      };
}

abstract final class AppTheme {
  static const _seed = Color(0xFF6E5AE6);

  static ThemeData forKind(AppThemeKind kind) {
    final brightness = kind == AppThemeKind.night ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness).copyWith(tertiary: const Color(0xFF00BFA5));
    final panel = (brightness == Brightness.dark ? Colors.black : Colors.white).withAlpha(190);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      cardTheme: CardThemeData(color: panel, margin: EdgeInsets.zero, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant.withAlpha(150))),),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: panel, labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    );
  }
}

class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop({required this.kind, required this.child, super.key});
  final AppThemeKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [Positioned.fill(child: CustomPaint(painter: _SkyPainter(kind))), Positioned.fill(child: child)]);
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.kind);
  final AppThemeKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = switch (kind) {
      AppThemeKind.day => const [Color(0xFF74C9F4), Color(0xFFDDF5FF)],
      AppThemeKind.sunset => const [Color(0xFFFF7B54), Color(0xFFFFD18A)],
      AppThemeKind.night => const [Color(0xFF050A2E), Color(0xFF142C63)],
    };
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect));

    if (kind == AppThemeKind.night) {
      final starPaint = Paint()..color = Colors.white.withAlpha(190);
      for (var index = 0; index < 42; index++) {
        final x = ((index * 83) % 100) / 100 * size.width;
        final y = (20 + ((index * 47) % 48)) / 100 * size.height;
        final radius = index % 7 == 0 ? 1.8 : 0.9;
        canvas.drawCircle(Offset(x, y), radius, starPaint);
      }
      final moon = Paint()..color = const Color(0xFFFFF1B8).withAlpha(220);
      canvas.drawCircle(Offset(size.width * .78, size.height * .18), 34, moon);
      canvas.drawCircle(Offset(size.width * .80, size.height * .16), 34, Paint()..color = colors.first);
    } else {
      final sunPaint = Paint()..color = (kind == AppThemeKind.sunset ? const Color(0xFFFFE06B) : const Color(0xFFFFF2A6)).withAlpha(230);
      final sunCenter = Offset(size.width * (kind == AppThemeKind.sunset ? .78 : .18), size.height * (kind == AppThemeKind.sunset ? .70 : .18));
      canvas.drawCircle(sunCenter, kind == AppThemeKind.sunset ? 62 : 48, sunPaint);
      _cloud(canvas, Offset(size.width * .18, size.height * .32), 1.0, Colors.white.withAlpha(kind == AppThemeKind.sunset ? 110 : 175));
      _cloud(canvas, Offset(size.width * .68, size.height * .38), .78, Colors.white.withAlpha(kind == AppThemeKind.sunset ? 95 : 155));
    }

    final horizon = size.height * .74;
    final land = Paint()..color = (kind == AppThemeKind.night ? const Color(0xFF02071C) : kind == AppThemeKind.sunset ? const Color(0xFF8C3D4A) : const Color(0xFF2B7D73)).withAlpha(180);
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

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.kind != kind;
}
