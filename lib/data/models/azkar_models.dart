/// A short string available in both source locales.
class LocalizedText {
  const LocalizedText({required this.ar, required this.en});

  final String ar;
  final String en;

  String resolve(bool isArabic) => isArabic ? ar : en;

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
    ar: json['ar'] as String? ?? '',
    en: json['en'] as String? ?? json['ar'] as String? ?? '',
  );

  static LocalizedText? tryParse(Object? value) {
    if (value is Map<String, dynamic>) return LocalizedText.fromJson(value);
    if (value is String) return LocalizedText(ar: value, en: value);
    return null;
  }
}

/// Points at a verse range in the bundled, verified Quran text so devotional
/// content (Ayah al-Kursi, Al-Mu'awwidhat, Quranic duas) is never retyped.
class QuranRef {
  const QuranRef({required this.surah, required this.fromAyah, required this.toAyah});

  final int surah;
  final int fromAyah;
  final int toAyah;

  factory QuranRef.fromJson(Map<String, dynamic> json) => QuranRef(
    surah: json['surah'] as int,
    fromAyah: json['ayah'] as int,
    toAyah: (json['toAyah'] as int?) ?? json['ayah'] as int,
  );
}

/// One dhikr inside an adhkar category.
class ZikrItem {
  const ZikrItem({
    required this.id,
    required this.text,
    required this.count,
    this.source,
    this.virtue,
    this.quranRef,
    this.surahName,
  });

  final String id;

  /// Resolved Arabic text (from the asset, or from the Quran dataset when
  /// [quranRef] is set).
  final String text;
  final int count;
  final LocalizedText? source;
  final LocalizedText? virtue;
  final QuranRef? quranRef;

  /// Arabic surah name when this item is Quranic.
  final String? surahName;

  bool get isQuranic => quranRef != null;
}

class ZikrCategory {
  const ZikrCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String id;
  final String icon;
  final LocalizedText title;
  final LocalizedText subtitle;
  final List<ZikrItem> items;

  int get itemCount => items.length;
}

/// A user-created dhikr for the digital tasbeeh.
class CustomDhikr {
  const CustomDhikr({
    required this.id,
    required this.text,
    required this.target,
    required this.createdAt,
  });

  final String id;
  final String text;
  final int target;
  final DateTime createdAt;

  CustomDhikr copyWith({String? text, int? target}) => CustomDhikr(
    id: id,
    text: text ?? this.text,
    target: target ?? this.target,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'target': target,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Returns `null` for malformed / outdated entries instead of throwing, so a
  /// single bad record can never wipe the user's whole list.
  static CustomDhikr? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final text = value['text'];
    final target = value['target'];
    if (id is! String || text is! String || text.trim().isEmpty) return null;
    if (target is! int || target <= 0) return null;
    return CustomDhikr(
      id: id,
      text: text,
      target: target,
      createdAt:
          DateTime.tryParse(value['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// A dhikr currently loaded in the tasbeeh counter (built-in or custom).
class ActiveDhikr {
  const ActiveDhikr({
    required this.id,
    required this.text,
    required this.target,
    required this.isCustom,
    this.label,
  });

  final String id;
  final String text;
  final int target;
  final bool isCustom;

  /// Optional display label for built-in adhkar (e.g. "سبحان الله وبحمده").
  final String? label;

  String get storageId => isCustom ? 'custom:$id' : 'builtin:$id';
}
