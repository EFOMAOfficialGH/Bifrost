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
    expect(AppLocalizations.translateFor('ar', '5 minutes ago'), 'منذ 5 دقيقة');
  });

  test('Arabic UI uses RTL language and preserves language-choice labels', () {
    expect(AppLocalizations.translateFor('ar', 'English'), 'English');
    expect(AppLocalizations.translateFor('ar', 'العربية'), 'العربية');
    expect(
      AppLocalizations.translateFor('ar', 'Welcome to Bifrost'),
      'مرحبًا بك في بايفروست',
    );
    expect(AppLocalizations.translateFor('ar', 'Bifrost'), 'بايفروست');
    expect(
      AppLocalizations.translateFor('ar', 'Bifrost Device'),
      'جهاز بايفروست',
    );
    expect(
      AppLocalizations.translateFor('ar', 'Bifrost Phone'),
      'هاتف بايفروست',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Keep Bifrost receiving while in background',
      ),
      'يواصل بايفروست العمل فالخلفية',
    );
  });

  test('English locale remains unchanged', () {
    expect(
      AppLocalizations.translateFor('en', 'Welcome to Bifrost'),
      'Welcome to Bifrost',
    );
  });

  test(
    'new startup, app-transfer, and history labels translate placeholders',
    () {
      expect(
        AppLocalizations.translateFor(
          'ar',
          'Version 9.9.9+123 is available. Install now to download and install it, or choose Later to be reminded next launch.',
        ),
        'يتوفر الإصدار 9.9.9+123. اختر «ثبّت الآن» لتنزيله وتثبيته، أو «لاحقًا» ليتم تذكيرك عند تشغيل التطبيق في المرة القادمة.',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Transfer apps'),
        'نقل التطبيقات',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          'App Transfer is intended for personal use with apps you own. Only APKs and optional OBB files are included; app data is never copied.',
        ),
        'ميزة نقل التطبيقات مخصّصة للاستخدام الشخصي مع التطبيقات التي تملكها. تُضمَّن ملفات APK وملفات OBB الاختيارية فقط؛ ولا تُنسخ بيانات التطبيقات مطلقًا.',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Version 2.1 (42) · Size 12 MB'),
        'الإصدار 2.1 (42) · الحجم 12 ميغابايت',
      );
      expect(
        AppLocalizations.translateFor('ar', '2 of 8 transfers'),
        '2 من أصل 8 عملية نقل',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Switch to grid view'),
        'التبديل إلى العرض الشبكي',
      );
      expect(
        AppLocalizations.translateFor('ar', '2 APK splits'),
        '2 من ملفات APK المجزأة',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Send 3 selected'),
        'إرسال 3 من التطبيقات المحددة',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          '1 app added to the transfer queue.',
        ),
        'أُضيف تطبيق واحد إلى قائمة انتظار النقل.',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          '3 apps added to the transfer queue.',
        ),
        'أُضيف 3 من التطبيقات إلى قائمة انتظار النقل.',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          'Version 2.1 (42) · APK size 12 MB',
        ),
        'الإصدار 2.1 (42) · حجم APK ‏12 ميغابايت',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Temporary app package removed'),
        'أُزيلت حزمة التطبيق المؤقتة',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Launch Bifrost at startup'),
        'تشغيل بايفروست عند بدء تشغيل Windows',
      );
    },
  );
}
