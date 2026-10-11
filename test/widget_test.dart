import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bifrost/main.dart';

void main() {
  testWidgets('Bifrost opens on the Nearby screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BifrostApp(enableDiscovery: false)));

    expect(find.text('Bifrost'), findsOneWidget);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('Connect by IP address'), findsOneWidget);
  });
}
