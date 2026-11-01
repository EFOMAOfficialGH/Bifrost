import 'package:bifrost/features/app_transfer/app_transfer_picker.dart';
import 'package:bifrost/features/app_transfer/app_transfer_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

class _PickerService extends AppTransferService {
  _PickerService() : super(channel: const MethodChannel('picker-test'));

  @override
  Future<List<TransferableApp>> listInstalledUserApps() async => const [
    TransferableApp(
      name: 'Widget App',
      packageName: 'org.example.widget',
      versionName: '1.0',
      versionCode: 1,
      sizeBytes: 100,
      apkSizeBytes: 100,
      apkPaths: ['/example/base.apk'],
      apkNames: ['base.apk'],
    ),
  ];

  @override
  Future<bool> hasAllFilesAccess() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preparing selected app closes picker and retains parent route', (
    tester,
  ) async {
    var preparedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => AppTransferPicker(
                      service: _PickerService(),
                      onAppsReady: (artifacts) async {
                        preparedCount = artifacts.length;
                      },
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Transfer apps'), findsOneWidget);

    await tester.tap(find.text('Widget App'));
    await tester.pump();
    await tester.tap(find.text('Send 1 selected'));
    await tester.pumpAndSettle();

    expect(preparedCount, 1);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Transfer apps'), findsNothing);
  });

  testWidgets('grid menu provides current, three, and four column choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppTransferPicker(
          service: _PickerService(),
          onAppsReady: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('Auto columns (current)'), findsOneWidget);
    expect(find.text('3 columns'), findsOneWidget);
    expect(find.text('4 columns'), findsOneWidget);

    await tester.tap(find.text('3 columns'));
    await tester.pumpAndSettle();
    expect(find.text('Widget App'), findsOneWidget);
  });
}
