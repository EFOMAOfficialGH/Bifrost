import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bifrost/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('darkens Sunset only when requested by the new theme mode', () {
      final classicSunset = AppTheme.forKind(AppThemeKind.sunset);
      final artworkSunset = AppTheme.forKind(
        AppThemeKind.sunset,
        darkenSunset: true,
      );

      expect(classicSunset.colorScheme.brightness, Brightness.light);
      expect(classicSunset.colorScheme.onSurface, Colors.black87);
      expect(artworkSunset.colorScheme.brightness, Brightness.dark);
      expect(artworkSunset.colorScheme.onSurface, Colors.white);
    });
  });

  group('ThemeBackdrop', () {
    testWidgets('uses the selected artwork as its full-screen background', (
      tester,
    ) async {
      const cases = <(AppThemeKind, String)>[
        (AppThemeKind.day, 'assets/splash_day.png'),
        (AppThemeKind.sunset, 'assets/splash_sunset.png'),
        (AppThemeKind.night, 'assets/splash_night.png'),
      ];

      for (final (kind, asset) in cases) {
        await tester.pumpWidget(
          MaterialApp(
            home: ThemeBackdrop(
              kind: kind,
              useArtwork: true,
              child: const SizedBox.expand(),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<AssetImage>());
        expect((image.image as AssetImage).assetName, asset);
      }
    });

    testWidgets('uses supplied landscape artwork for desktop themes', (
      tester,
    ) async {
      const cases = <(AppThemeKind, String)>[
        (AppThemeKind.day, 'assets/splash_day_pc.png'),
        (AppThemeKind.sunset, 'assets/splash_sunset_pc.png'),
        (AppThemeKind.night, 'assets/splash_night_pc.png'),
      ];

      for (final (kind, asset) in cases) {
        await tester.pumpWidget(
          MaterialApp(
            home: ThemeBackdrop(
              kind: kind,
              useArtwork: true,
              useDesktopArtwork: true,
              child: const SizedBox.expand(),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as AssetImage).assetName, asset);
      }
    });

    testWidgets('maps a stale Custom Color to Day artwork in phone mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeBackdrop(
            kind: AppThemeKind.customColor,
            useArtwork: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/splash_day.png');
    });

    testWidgets('maps stale Custom Color to Day artwork in desktop mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeBackdrop(
            kind: AppThemeKind.customColor,
            useArtwork: true,
            useDesktopArtwork: true,
            child: const SizedBox.expand(),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, 'assets/splash_day_pc.png');
    });

    testWidgets('keeps the painter-based background in legacy mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeBackdrop(
            kind: AppThemeKind.night,
            useArtwork: false,
            child: const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
