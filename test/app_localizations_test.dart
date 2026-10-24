import 'package:flutter_test/flutter_test.dart';

import 'package:bifrost/core/localization/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load();
  });

  test('Arabic translations preserve placeholders and variable names', () {
    expect(
      AppLocalizations.translateFor('ar', 'Sending report.pdf'),
      'جارٍ إرسال report.pdf',
    );
    expect(
      AppLocalizations.translateFor('ar', '5 minutes ago'),
      'منذ 5 دقيقة',
    );
  });

  test('Arabic UI uses RTL language and preserves language-choice labels', () {
    expect(AppLocalizations.translateFor('ar', 'English'), 'English');
    expect(AppLocalizations.translateFor('ar', 'العربية'), 'العربية');
    expect(
      AppLocalizations.translateFor('ar', 'Welcome to Bifrost'),
      'مرحبًا بك في Bifrost',
    );
  });

  test('English locale remains unchanged', () {
    expect(
      AppLocalizations.translateFor('en', 'Welcome to Bifrost'),
      'Welcome to Bifrost',
    );
  });
}
