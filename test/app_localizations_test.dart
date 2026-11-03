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

  test("Nearby drop and What's New copy translate to Arabic", () {
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Devices running Bifrost on this local network will appear here.',
      ),
      'ستظهر هنا الأجهزة التي تستخدم بايفروست على هذه الشبكة المحلية.',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Release to add files to the transfer list',
      ),
      'أفلِت لإضافة الملفات إلى قائمة النقل',
    );
    expect(AppLocalizations.translateFor('ar', "What's New?"), 'ما الجديد؟');
    expect(
      AppLocalizations.translateFor('ar', 'Highlights for version 0.14.9+47'),
      'أبرز الإضافات في الإصدار 0.14.9+47',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Tap the Bifrost mark in Nearby to cycle themes.',
      ),
      'اضغط على شعار بايفروست في صفحة الأجهزة القريبة للتبديل بين المظاهر.',
    );
    expect(
      AppLocalizations.translateFor('ar', 'Lagacy Theme'),
      'المظهر الكلاسيكي',
    );
    expect(
      AppLocalizations.translateFor('ar', 'Available when Lagacy Theme is on'),
      'متاح عند تفعيل «المظهر الكلاسيكي»',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Turn on for the classic theme style options and the costum color option',
      ),
      'فعّل هذا الخيار لاستخدام خيارات نمط المظهر الكلاسيكي وخيار اللون المخصص.',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Day, Sunset, and Night images now theme the entire Android app, not only startup.',
      ),
      'أصبحت صور النهار والغروب والليل خلفياتٍ لكامل تطبيق أندرويد، وليس لشاشة بدء التشغيل فقط.',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'The updated logo now appears in the Windows app and installer icons.',
      ),
      'يظهر الشعار المحدّث الآن في أيقونة تطبيق ويندوز والمُثبّت.',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Custom Color is disabled unless “Lagacy Theme” is on.',
      ),
      'يكون خيار اللون المخصص معطّلًا ما لم يتم تفعيل «المظهر الكلاسيكي».',
    );
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Turn on “Lagacy Theme” for the classic backgrounds and Custom Color option.',
      ),
      'فعّل «المظهر الكلاسيكي» لاستعادة الخلفيات الكلاسيكية وخيار اللون المخصص.',
    );
  });

  test('English locale remains unchanged', () {
    expect(
      AppLocalizations.translateFor('en', 'Welcome to Bifrost'),
      'Welcome to Bifrost',
    );
  });

  test('background notification tells Arabic users to use Settings', () {
    expect(
      AppLocalizations.translateFor(
        'ar',
        'Background receiving is on. Turn it off in Settings.',
      ),
      'الاستلام في الخلفية مفعّل. يمكنك إيقافه من الإعدادات.',
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
          'App Transfer is intended for personal use with apps you own. APK files only; app data is never copied.',
        ),
        'ميزة نقل التطبيقات مخصّصة للاستخدام الشخصي مع التطبيقات التي تملكها. تُضمَّن ملفات APK فقط؛ ولا تُنسخ بيانات التطبيقات مطلقًا.',
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
      expect(AppLocalizations.translateFor('ar', 'APK'), 'APK فقط');
      expect(AppLocalizations.translateFor('ar', 'APK & OBB'), 'APK و OBB');
      expect(
        AppLocalizations.translateFor(
          'ar',
          'OBB files were found for one or more selected apps. Include them in the app packages?',
        ),
        'عُثر على ملفات OBB لتطبيق واحد أو أكثر من التطبيقات المحددة. هل تريد تضمينها مع حزم التطبيقات؟',
      );
      expect(AppLocalizations.translateFor('ar', '4 columns'), '٤ أعمدة');
      expect(
        AppLocalizations.translateFor('ar', 'Check for OBB data?'),
        'هل تريد التحقق من بيانات OBB؟',
      );
      expect(
        AppLocalizations.translateFor('ar', 'Check for OBB'),
        'تحقّق من OBB',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          'Return from Settings and tap Send selected again to check for OBB files.',
        ),
        'ارجع من الإعدادات واضغط «إرسال المحدد» مجددًا للتحقق من ملفات OBB.',
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
          '1 file added to the transfer queue.',
        ),
        'أُضيف ملف واحد إلى قائمة انتظار النقل.',
      );
      expect(
        AppLocalizations.translateFor(
          'ar',
          '5 files added to the transfer queue.',
        ),
        'أُضيفت 5 ملفات إلى قائمة انتظار النقل.',
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
