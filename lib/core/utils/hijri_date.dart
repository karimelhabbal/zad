/// Hijri (Islamic) calendar conversion.
///
/// Uses the well-known tabular/Kuwaiti algorithm, which is deterministic and
/// requires no network access or bundled tables. It agrees with the printed
/// Umm al-Qura calendar to within a day in the vast majority of cases; the
/// exact Umm al-Qura table would need the official month-length dataset.
library;

class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;

  /// 1 = Muharram … 12 = Dhu al-Hijjah.
  final int month;
  final int day;

  static const List<String> monthNamesAr = <String>[
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> monthNamesEn = <String>[
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    'Jumada al-Ula',
    'Jumada al-Akhirah',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  String monthName(bool isArabic) {
    final index = (month - 1).clamp(0, 11);
    return isArabic ? monthNamesAr[index] : monthNamesEn[index];
  }

  /// e.g. "١٢ ربيع الأول ١٤٤٧" (Arabic) / "12 Rabi' al-Awwal 1447".
  String format(bool isArabic, String Function(num) numeral) {
    final m = monthName(isArabic);
    return isArabic
        ? '${numeral(day)} $m ${numeral(year)} هـ'
        : '${numeral(day)} $m ${numeral(year)} AH';
  }

  /// Converts a Gregorian [date] to its Hijri equivalent.
  static HijriDate fromGregorian(DateTime date) {
    final jd = _julianDayNumber(date.year, date.month, date.day);
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j =
        ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l =
        l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year: year, month: month.clamp(1, 12), day: day);
  }

  static int _julianDayNumber(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }
}
