import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bifrost/core/localization/app_localizations.dart';
import 'package:bifrost/core/localization/localized_text.dart' as app_text;
import 'package:bifrost/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Bifrost first-run wizard contains setup controls', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: FirstRunPage(onComplete: _noop)),
    ));
    await tester.pump();

    expect(find.text('Welcome to Bifrost'), findsOneWidget);
    expect(find.text('Choose device name'), findsOneWidget);
    expect(find.text('Give access / Change save location'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('Arabic locale translates app text and lays out RTL', (WidgetTester tester) async {
    await AppLocalizations.load();
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: app_text.Text('Welcome to Bifrost')),
      ),
    );
    await tester.pump();

    expect(find.text('مرحبًا بك في Bifrost'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(app_text.Text))),
      TextDirection.rtl,
    );
  });

  testWidgets('Bifrost shell opens on Nearby', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: BifrostShell(enableDiscovery: false)),
    ));
    await tester.pump();

    expect(find.text('Bifrost'), findsOneWidget);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('Connect by IP address'), findsOneWidget);
  });
}

void _noop() {}
