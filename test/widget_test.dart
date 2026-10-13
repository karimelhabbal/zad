import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zad/app.dart';
import 'package:zad/core/theme/app_theme.dart';
import 'package:zad/data/repositories/local_store.dart';
import 'package:zad/features/splash/splash_screen.dart';
import 'package:zad/l10n/app_localizations.dart';
import 'package:zad/widgets/common.dart';

/// Startup smoke tests: the theme, the shared widgets and the first frame of
/// the real app.
///
/// The bundled JSON assets are verified from disk in `quran_asset_test.dart`
/// and `azkar_asset_test.dart`; the full bootstrap (which decodes those assets
/// on a background isolate) is exercised on a device or emulator instead, see
/// the README.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the design-system card renders in both themes', (tester) async {
    for (final theme in <ThemeData>[ZadTheme.light(), ZadTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: ZadCard(child: Text('زاد'))),
        ),
      );
      expect(find.text('زاد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty states render their copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: const Scaffold(
          body: EmptyView(title: 'لا توجد بيانات', body: 'حاول لاحقًا'),
        ),
      ),
    );
    // The localisation delegates resolve asynchronously, so settle once before
    // asserting.
    await tester.pumpAndSettle();

    expect(find.text('لا توجد بيانات'), findsOneWidget);
    expect(find.text('حاول لاحقًا'), findsOneWidget);
  });

  testWidgets('error states expose a retry affordance', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ZadTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: ErrorView(
            title: 'تعذّر التحميل',
            body: 'تحقق من الاتصال',
            onRetry: () => retried++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذّر التحميل'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('the app renders its splash screen on the first frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LocalStore.overrideInstance(null);
    final store = await LocalStore.instance();

    await tester.pumpWidget(ZadApp(store: store));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tear the tree down again so the splash's pending bootstrap work does not
    // leak into the following tests.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
