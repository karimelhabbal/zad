/// Hijri (Islamic) calendar conversion.
///
/// Primary source: the official **Umm al-Qura** month-start table (High
/// Judicial Council of Saudi Arabia) — the same calendar used for the Saudi
/// and Egyptian official Hijri dates. It covers 1438-1472 AH
/// (October 2016 - September 2050), so every realistic device date is served
/// by the real, published calendar rather than an approximation.
///
/// Fallback: an astronomical new-moon calculation (Meeus,
/// *Astronomical Algorithms*) with the Umm al-Qura visibility criterion, for
/// dates outside the table. Month beginnings follow the actual conjunction
/// time instead of a fixed arithmetic cycle, so the result tracks the
/// official calendar to within a day in the vast majority of cases.
///
/// Last resort: the tabular/Kuwaiti algorithm, so the class never throws.
library;

import 'dart:math' as math;

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
  ///
  /// Uses the official Umm al-Qura table when [date] falls inside it, the
  /// astronomical calculation for earlier/later dates, and the tabular
  /// algorithm only if both fail.
  static HijriDate fromGregorian(DateTime date) {
    final jd = _julianDayNumber(date.year, date.month, date.day);
    return _fromUqTable(jd) ?? _fromAstronomy(jd) ?? _tabularFromJdn(jd);
  }

  // ------------------------------------------------ official Umm al-Qura table -

  // Official Umm al-Qura month starts (High Judicial Council of
  // Saudi Arabia) for 1 Muharram 1438 .. 1 Dhu al-Hijjah 1472 AH,
  // stored as Julian Day Numbers. One entry per Hijri month, in
  // order, starting at 1438. Generated from the published tables.
  static const int _uqTableStartYear = 1438;

  static const List<int> _uqMonthStartJdn = <int>[
    2457664, 2457694, 2457723, 2457753, 2457783, 2457813, 2457842, 2457871, 2457901, 2457930, 2457959, 2457989,  // 1438 AH
    2458018, 2458048, 2458077, 2458107, 2458137, 2458167, 2458196, 2458226, 2458256, 2458285, 2458314, 2458343,  // 1439 AH
    2458373, 2458402, 2458432, 2458461, 2458491, 2458521, 2458551, 2458580, 2458610, 2458639, 2458669, 2458698,  // 1440 AH
    2458727, 2458757, 2458786, 2458816, 2458845, 2458875, 2458905, 2458934, 2458964, 2458994, 2459023, 2459053,  // 1441 AH
    2459082, 2459111, 2459141, 2459170, 2459200, 2459229, 2459259, 2459288, 2459318, 2459348, 2459377, 2459407,  // 1442 AH
    2459437, 2459466, 2459495, 2459525, 2459554, 2459584, 2459613, 2459643, 2459672, 2459702, 2459731, 2459761,  // 1443 AH
    2459791, 2459820, 2459850, 2459879, 2459909, 2459939, 2459968, 2459997, 2460027, 2460056, 2460086, 2460115,  // 1444 AH
    2460145, 2460174, 2460204, 2460234, 2460264, 2460293, 2460323, 2460352, 2460381, 2460411, 2460440, 2460469,  // 1445 AH
    2460499, 2460528, 2460558, 2460588, 2460618, 2460647, 2460677, 2460707, 2460736, 2460765, 2460795, 2460824,  // 1446 AH
    2460853, 2460883, 2460912, 2460942, 2460972, 2461002, 2461031, 2461061, 2461090, 2461120, 2461149, 2461179,  // 1447 AH
    2461208, 2461237, 2461267, 2461296, 2461326, 2461356, 2461385, 2461415, 2461445, 2461474, 2461504, 2461533,  // 1448 AH
    2461563, 2461592, 2461621, 2461651, 2461680, 2461710, 2461739, 2461769, 2461799, 2461828, 2461858, 2461888,  // 1449 AH
    2461917, 2461947, 2461976, 2462006, 2462035, 2462064, 2462094, 2462123, 2462153, 2462182, 2462212, 2462242,  // 1450 AH
    2462271, 2462301, 2462331, 2462360, 2462390, 2462419, 2462448, 2462478, 2462507, 2462537, 2462566, 2462596,  // 1451 AH
    2462625, 2462655, 2462685, 2462715, 2462744, 2462774, 2462803, 2462832, 2462862, 2462891, 2462921, 2462950,  // 1452 AH
    2462980, 2463009, 2463039, 2463069, 2463099, 2463128, 2463157, 2463187, 2463216, 2463246, 2463275, 2463305,  // 1453 AH
    2463334, 2463363, 2463393, 2463423, 2463453, 2463482, 2463512, 2463541, 2463571, 2463600, 2463630, 2463659,  // 1454 AH
    2463689, 2463718, 2463747, 2463777, 2463807, 2463836, 2463866, 2463895, 2463925, 2463955, 2463984, 2464014,  // 1455 AH
    2464043, 2464073, 2464102, 2464131, 2464161, 2464190, 2464220, 2464249, 2464279, 2464309, 2464339, 2464368,  // 1456 AH
    2464398, 2464427, 2464457, 2464486, 2464515, 2464545, 2464574, 2464603, 2464633, 2464663, 2464692, 2464722,  // 1457 AH
    2464752, 2464782, 2464811, 2464841, 2464870, 2464899, 2464929, 2464958, 2464987, 2465017, 2465047, 2465076,  // 1458 AH
    2465106, 2465136, 2465166, 2465195, 2465225, 2465254, 2465283, 2465313, 2465342, 2465371, 2465401, 2465431,  // 1459 AH
    2465460, 2465490, 2465520, 2465549, 2465579, 2465608, 2465638, 2465667, 2465697, 2465726, 2465755, 2465785,  // 1460 AH
    2465815, 2465844, 2465874, 2465903, 2465933, 2465963, 2465992, 2466022, 2466051, 2466081, 2466110, 2466140,  // 1461 AH
    2466169, 2466199, 2466228, 2466258, 2466287, 2466317, 2466346, 2466376, 2466405, 2466435, 2466465, 2466494,  // 1462 AH
    2466524, 2466553, 2466583, 2466612, 2466641, 2466671, 2466700, 2466730, 2466760, 2466789, 2466819, 2466849,  // 1463 AH
    2466878, 2466908, 2466937, 2466967, 2466996, 2467025, 2467055, 2467084, 2467114, 2467143, 2467173, 2467203,  // 1464 AH
    2467233, 2467262, 2467292, 2467321, 2467351, 2467380, 2467409, 2467439, 2467468, 2467497, 2467527, 2467557,  // 1465 AH
    2467587, 2467617, 2467646, 2467676, 2467705, 2467735, 2467764, 2467793, 2467823, 2467852, 2467882, 2467911,  // 1466 AH
    2467941, 2467971, 2468000, 2468030, 2468060, 2468089, 2468119, 2468148, 2468177, 2468207, 2468236, 2468266,  // 1467 AH
    2468295, 2468325, 2468354, 2468384, 2468414, 2468443, 2468473, 2468502, 2468532, 2468561, 2468591, 2468620,  // 1468 AH
    2468650, 2468679, 2468708, 2468738, 2468768, 2468797, 2468827, 2468857, 2468886, 2468916, 2468946, 2468975,  // 1469 AH
    2469004, 2469034, 2469063, 2469092, 2469122, 2469152, 2469181, 2469211, 2469240, 2469270, 2469300, 2469330,  // 1470 AH
    2469359, 2469388, 2469418, 2469447, 2469476, 2469506, 2469535, 2469565, 2469595, 2469624, 2469654, 2469684,  // 1471 AH
    2469713, 2469743, 2469772, 2469802, 2469831, 2469861, 2469890, 2469919, 2469949, 2469978, 2470008, 2470038,  // 1472 AH
  ];

  // ---------------------------------------------------- astronomical engine --

  /// Julian Day Number of a known month start, used to anchor the new-moon
  /// index [k] of the fallback calculation.
  ///
  /// 1 Muharram 1446 AH = 7 July 2024 CE (JDN 2460499).
  static const int _anchorJdn = 2460499;
  static const int _anchorYear = 1446;

  /// Cached new-moon index whose month start is [_anchorJdn].
  ///
  /// Computed once by scanning the neighbourhood of the approximate value,
  /// so no magic number has to be hand-tuned.
  static int? _anchorK;

  /// Finds the new-moon index [k] whose month start equals [_anchorJdn].
  static int get _kOfAnchor {
    final cached = _anchorK;
    if (cached != null) return cached;
    var k = ((_anchorJdn - 2451550) / _synodicMonth).floor();
    while (_monthStartForK(k) > _anchorJdn) {
      k--;
    }
    while (_monthStartForK(k + 1) <= _anchorJdn) {
      k++;
    }
    _anchorK = k;
    return k;
  }

  /// Looks [jd] up in the official Umm al-Qura table.
  ///
  /// Returns `null` when [jd] is outside the covered range.
  static HijriDate? _fromUqTable(int jd) {
    final starts = _uqMonthStartJdn;
    if (jd < starts.first || jd > starts.last + 29) return null;

    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (starts[mid] <= jd) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }

    final start = starts[lo];
    final next = lo + 1 < starts.length ? starts[lo + 1] : start + 30;
    final day = jd - start + 1;
    if (day < 1 || day > next - start) return null;
    return HijriDate(
      year: _uqTableStartYear + lo ~/ 12,
      month: lo % 12 + 1,
      day: day,
    );
  }

  /// Astronomical fallback: returns a Umm al-Qura-style [HijriDate] for
  /// [jd], or `null` if [jd] is outside the supported range.
  static HijriDate? _fromAstronomy(int jd) {
    // Find an approximate new-moon index for the given JDN.
    // k is the count of new moons since the reference new moon
    // (J2000.0, JDE 2451550.09766).
    final double kApprox = (jd - 2451550) / _synodicMonth;
    var k = kApprox.floor();

    // Walk backwards until we find the new moon that starts the month
    // containing [jd].
    while (_monthStartForK(k) > jd) {
      k--;
    }
    while (_monthStartForK(k + 1) <= jd) {
      k++;
    }

    final monthStart = _monthStartForK(k);
    final nextStart = _monthStartForK(k + 1);
    final monthLength = nextStart - monthStart;
    final day = jd - monthStart + 1;

    // Map k to a Hijri year/month by counting synodic months from the
    // anchor. The anchor is a known, published month start, so the mapping
    // is exact rather than derived from an assumed epoch offset.
    final monthsSinceAnchor = k - _kOfAnchor;
    final year = _anchorYear + monthsSinceAnchor ~/ 12;
    final month = (monthsSinceAnchor % 12) + 1;

    if (year < 1300 || year > 1600) return null;
    if (day < 1 || day > monthLength) return null;

    return HijriDate(year: year, month: month, day: day);
  }

  /// Mean synodic month in days.
  static const double _synodicMonth = 29.530588861;

  /// Julian Ephemeris Day of the [k]-th new moon since the reference
  /// new moon (J2000.0).  Uses Meeus's simplified formula (error < 1 min).
  static double _newMoonJde(int k) {
    final T = k / 1236.85;
    var jde = 2451550.09766 +
        29.530588861 * k +
        0.00015437 * T * T -
        0.000000150 * T * T * T +
        0.00000000073 * T * T * T * T;

    // Eccentricity of Earth's orbit.
    final E = 1.0 - 0.002516 * T - 0.0000074 * T * T;

    // Solar mean anomaly (degrees).
    final M = _deg(2.5534 + 29.10535669 * k - 0.0000218 * T * T);

    // Lunar mean anomaly (degrees).
    final mPrime = _deg(201.5643 + 385.81693528 * k + 0.0107438 * T * T);

    // Argument of latitude (degrees).
    final F = _deg(160.7108 + 390.67050274 * k - 0.0016341 * T * T);

    // Longitude of ascending node (degrees).
    final omega = _deg(124.7746 - 1.56375588 * k + 0.0020691 * T * T);

    // Corrections (minutes of arc → days).
    var correction = 0.0;

    // Terms from Meeus Table 47.A (simplified — largest terms only).
    correction += -0.40720 * _sin(mPrime);
    correction += 0.17241 * E * _sin(M);
    correction += 0.01608 * _sin(2 * mPrime);
    correction += 0.01039 * _sin(2 * F);
    correction += 0.00739 * E * _sin(mPrime - M);
    correction += -0.00514 * E * _sin(mPrime + M);
    correction += 0.00208 * E * E * _sin(2 * M);
    correction += -0.00111 * _sin(mPrime - 2 * F);
    correction += -0.00057 * _sin(mPrime + 2 * F);
    correction += 0.00056 * E * _sin(2 * mPrime + M);
    correction += -0.00042 * _sin(3 * mPrime);
    correction += 0.00042 * E * _sin(M + 2 * F);
    correction += 0.00038 * E * _sin(M - 2 * F);
    correction += -0.00024 * E * _sin(2 * mPrime - M);
    correction += -0.00017 * _sin(omega);
    correction += -0.00007 * _sin(mPrime + 2 * M);
    correction += 0.00004 * _sin(2 * mPrime - 2 * F);
    correction += 0.00004 * _sin(3 * M);
    correction += 0.00003 * _sin(mPrime + M - 2 * F);
    correction += 0.00003 * _sin(2 * mPrime + 2 * F);
    correction += -0.00003 * _sin(mPrime + M + 2 * F);
    correction += 0.00003 * _sin(mPrime - M + 2 * F);
    correction += -0.00002 * _sin(mPrime - M - 2 * F);
    correction += -0.00002 * _sin(3 * mPrime + M);
    correction += 0.00002 * _sin(4 * mPrime);

    // Meeus's Table 47.A coefficients are already expressed in **days**,
    // so the total is added to the JDE as-is — dividing by 360 here (as a
    // degrees→days conversion) shrinks the periodic terms by two orders of
    // magnitude and leaves the conjunction several hours early.
    jde += correction;

    return jde;
  }

  /// Returns the JDN of the first day of the month that begins with the
  /// [k]-th new moon, using the Umm al-Qura visibility rule.
  ///
  /// Umm al-Qura rule: the month starts on the day after the conjunction
  /// (new moon) if the conjunction occurs before 18:00 UTC; otherwise it
  /// starts two days after. This is a well-known simplification that
  /// matches the official Umm al-Qura tables to within one day.
  static int _monthStartForK(int k) {
    final jde = _newMoonJde(k);
    // JDE → JDN (JDN changes at noon UTC, JDE is TT).
    // For our purposes, adding 0.5 is sufficient.
    final jdConjunction = (jde + 0.5).floor();
    // UTC hour of conjunction.
    final utcFraction = jde - jdConjunction + 0.5;
    final utcHour = (utcFraction * 24.0) % 24.0;
    // If conjunction before 18:00 UTC, month starts next day.
    return utcHour < 18.0 ? jdConjunction + 1 : jdConjunction + 2;
  }

  static double _deg(double d) => d * 0.017453292519943295;
  static double _sin(double rad) => math.sin(rad);


  // ---------------------------------------------------------- tabular fallback

  static HijriDate _tabularFromJdn(int jd) {
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

