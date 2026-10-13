import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/azkar_repository.dart';
import 'data/repositories/local_store.dart';
import 'data/repositories/mushaf_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/tasbeeh_repository.dart';
import 'l10n/app_localizations.dart';
import 'state/audio_controller.dart';
import 'state/azkar_controller.dart';
import 'state/prayer_controller.dart';
import 'state/qibla_controller.dart';
import 'state/quran_controller.dart';
import 'state/settings_controller.dart';
import 'state/tasbeeh_controller.dart';
import 'features/splash/splash_screen.dart';

/// Root widget: wires the controllers, the theme and the localisation.
class ZadApp extends StatelessWidget {
  const ZadApp({super.key, required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<LocalStore>.value(value: store),
        Provider<MushafRepository>(
          create: (_) => MushafRepository(),
          dispose: (_, repo) => repo.dispose(),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(store),
        ),
        ChangeNotifierProvider<QuranController>(
          create: (_) => QuranController(QuranRepository(store)),
        ),
        // Owns the recitation player; created once and torn down with the app.
        ChangeNotifierProvider<AudioController>(
          create: (_) => AudioController(),
        ),
        ChangeNotifierProvider<AzkarController>(
          create: (_) => AzkarController(AzkarRepository(store)),
        ),
        ChangeNotifierProvider<TasbeehController>(
          create: (_) => TasbeehController(TasbeehRepository(store)),
        ),
        ChangeNotifierProvider<PrayerController>(
          create: (ctx) =>
              PrayerController(settings: ctx.read<SettingsController>()),
        ),
        ChangeNotifierProvider<QiblaController>(
          create: (ctx) => QiblaController(prayer: ctx.read<PrayerController>()),
        ),
      ],
      child: const _ZadMaterialApp(),
    );
  }
}

class _ZadMaterialApp extends StatelessWidget {
  const _ZadMaterialApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final isArabic = settings.isArabic;

    return MaterialApp(
      title: isArabic ? 'زاد' : 'Zad',
      debugShowCheckedModeBanner: false,
      theme: ZadTheme.light(isArabic: isArabic),
      darkTheme: ZadTheme.dark(isArabic: isArabic),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: AppLocalizations.resolve,
      builder: (context, child) {
        // Keep text scaling within a readable range so the devotional layouts
        // never break, while still respecting the user's accessibility setting.
        final media = MediaQuery.of(context);
        final scale = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.35,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return MediaQuery(
          data: media.copyWith(textScaler: scale),
          // Both system bars are transparent so the app's own surfaces show
          // through (Android 15+ enforces edge-to-edge for targetSdk 35+, so
          // opting out is not an option). Their *icon* colours therefore have
          // to follow the theme, or the bar icons vanish against the surface.
          // `AppBar` refines the status-bar half per screen; this covers the
          // navigation bar, which no widget sets on its own.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              // No grey scrim behind the transparent bar (API 29–34; ignored
              // from API 35, where the platform decides).
              systemNavigationBarContrastEnforced: false,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
