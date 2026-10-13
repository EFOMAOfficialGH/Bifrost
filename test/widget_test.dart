import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bifrost/main.dart';

void main() {
  testWidgets('Bifrost first-run wizard contains setup controls', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: FirstRunPage(onComplete: () {})));
    await tester.pump();

    expect(find.text('Welcome to Bifrost'), findsOneWidget);
    expect(find.text('Choose device name'), findsOneWidget);
    expect(find.text('Give access / Change save location'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Bifrost shell opens on Nearby', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: BifrostShell(enableDiscovery: false))));
    await tester.pump();

    expect(find.text('Bifrost'), findsOneWidget);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('Connect by IP address'), findsOneWidget);
  });
}
