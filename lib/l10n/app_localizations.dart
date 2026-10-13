import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// Source-based localisation for Zad.
///
/// The Arabic and English text lives in `strings_ar.dart` / `strings_en.dart`
/// as plain source resources — there is no generated artefact to edit, and no
/// code generation step to run.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  static const Locale fallbackLocale = Locale('ar');

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  Map<String, String> get _strings =>
      locale.languageCode == 'en' ? stringsEn : stringsAr;

  bool get isArabic => locale.languageCode != 'en';

  bool get isRtl => isArabic;

  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Looks up [key] and substitutes `{placeholder}` tokens with [args].
  String t(String key, {Map<String, Object?>? args}) {
    var value = _strings[key];
    // Fall back to the reference locale so a missing translation never renders
    // an empty screen.
    value ??= stringsAr[key] ?? key;
    if (args == null || args.isEmpty) return value;
    var out = value;
    for (final entry in args.entries) {
      out = out.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return out;
  }

  /// Maps every ASCII digit in [value] to the locale's digits.
  ///
  /// Arabic uses Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩); English keeps Western
  /// digits. Every number the UI renders must go through this — mixing the two
  /// inside a single string (e.g. an Arabic hour next to a Western minute) is
  /// the bug this exists to prevent.
  String digits(String value) {
    if (!isArabic) return value;
    const western = '0123456789';
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final ch = String.fromCharCode(rune);
      final idx = western.indexOf(ch);
      buffer.write(idx == -1 ? ch : eastern[idx]);
    }
    return buffer.toString();
  }

  /// Formats a number using the locale's digits (Arabic-Indic for `ar`).
  String n(num value) {
    final plain = value is int ? '$value' : _trim(value);
    return digits(plain);
  }

  static String _trim(num value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  /// Formats a duration as `HH:MM:SS`, or `MM:SS` when under an hour.
  ///
  /// Both the hours and the minutes/seconds use the locale's digits.
  String duration(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    final seconds = total.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return digits('${hours.toString().padLeft(2, '0')}:$mm:$ss');
    }
    return digits('$mm:$ss');
  }

  /// Formats a 24h time-of-day as a locale-appropriate `h:mm AM/PM` string.
  ///
  /// The hour and the minute are always rendered with the same digit set.
  String timeOfDay(TimeOfDay time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12
        ? (isArabic ? 'ص' : 'AM')
        : (isArabic ? 'م' : 'PM');
    return '${digits('$hour12')}:${digits(minute)} $suffix';
  }

  /// Convenience wrapper so call sites never have to build a [TimeOfDay].
  String clock(DateTime time) => timeOfDay(TimeOfDay.fromDateTime(time));

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, 'AppLocalizations was not found in the widget tree.');
    return instance!;
  }

  /// Resolves [locale] to a supported locale, preferring the same language.
  static Locale resolve(Locale? locale, Iterable<Locale> supported) {
    if (locale == null) return fallbackLocale;
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
    return fallbackLocale;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  /// Shorthand: `context.tr('nav.home')`.
  String tr(String key, {Map<String, Object?>? args}) =>
      AppLocalizations.of(this).t(key, args: args);

  AppLocalizations get l10n => AppLocalizations.of(this);
}
