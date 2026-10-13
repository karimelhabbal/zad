import '../../core/utils/arabic_text.dart';
import 'reciter_catalogue.dart';

/// A Qur'an recitation edition available for streaming.
///
/// Every entry in [QuranReciters.all] was verified against the live CDN — see
/// `reciter_catalogue.dart` (generated) for the exact check that was run.
class QuranReciter {
  const QuranReciter({
    required this.id,
    required this.arabicName,
    required this.englishName,
  });

  /// The edition identifier used in the CDN path, e.g. `ar.alafasy`.
  final String id;

  final String arabicName;
  final String englishName;

  String nameFor({required bool isArabic}) =>
      isArabic ? arabicName : englishName;

  /// Bitrate of the hosted files. The CDN serves 128 kbps MP3 for every
  /// edition in [QuranReciters.all].
  static const int bitrate = 128;

  /// Streams a whole surah as a single MP3 file.
  ///
  /// Surah-level (rather than verse-by-verse) playback is what the design's
  /// player bar implies: pick a surah, press play, and get real duration and
  /// seeking from one continuous file.
  String surahAudioUrl(int surahNumber) =>
      'https://cdn.islamic.network/quran/audio-surah/'
      '$bitrate/$id/$surahNumber.mp3';

  @override
  bool operator ==(Object other) =>
      other is QuranReciter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuranReciter($id)';
}

/// The curated reciter catalogue.
///
/// **Source of truth.** All audio is served by the alquran.cloud CDN
/// (`cdn.islamic.network`), the same provider the app already uses for the
/// Qur'an text. Files are 128 kbps MP3 and the CDN supports HTTP Range
/// requests, so the player can seek.
///
/// **Availability.** [all] is *generated*, not hand-written, by
/// `tool/build_reciters.py`. That script asks the alquran.cloud API which
/// Arabic editions exist, then issues a real Range request against
/// `audio-surah/128/{id}/{surah}.mp3` for surahs 1, 9, 36, 78 and 114, keeping
/// only editions that answer 200/206 every single time. A 206 also proves Range
/// support, which is what makes the scrubber's seeking work.
///
/// **What was deliberately excluded.** The API advertises 176 Arabic editions,
/// but 28 answer `403 Forbidden` for surah-level audio and remain
/// ayah-by-ayah only. These include several very well-known identifiers —
/// `ar.husary`, `ar.mahermuaiqly`, `ar.minshawi`, `ar.abdurrahmaansudais`,
/// `ar.hudhaify`, `ar.muhammadayyoub`, `ar.ahmedajamy`, `ar.shaatree` — plus
/// the `-2` and `-surah` aliases. They are intentionally absent rather than
/// offered as broken options. [isVerified] encodes this contract, and the
/// generated file lists the excluded ids.
class QuranReciters {
  const QuranReciters._();

  /// Every reciter verified to serve surah-level audio. Generated — see the
  /// library documentation on `reciter_catalogue.dart`.
  static const List<QuranReciter> all = kVerifiedReciters;

  /// Identifier of [defaultReciter] as a compile-time constant, so it can be
  /// used as a default value in const constructors.
  static const String defaultReciterId = 'ar.alafasy';

  /// Used only if [defaultReciterId] is ever missing from the catalogue, which
  /// would mean the generator produced a broken list.
  static const QuranReciter _fallback = QuranReciter(
    id: defaultReciterId,
    arabicName: 'مشاري راشد العفاسي',
    englishName: 'Mishary Rashid Alafasy',
  );

  /// The reciter used when nothing has been chosen yet.
  ///
  /// Resolved through [byId] rather than being a second hard-coded literal, so
  /// it can never drift from the generated catalogue.
  static final QuranReciter defaultReciter = byId(defaultReciterId);

  /// True when [id] is part of the verified catalogue.
  static bool isVerified(String? id) =>
      id != null && all.any((r) => r.id == id);

  /// Resolves a stored identifier, falling back to [_fallback].
  static QuranReciter byId(String? id) {
    if (id != null) {
      for (final reciter in all) {
        if (reciter.id == id) return reciter;
      }
    }
    return _fallback;
  }

  /// Filters the catalogue by a free-text query, for the picker's search box.
  ///
  /// Arabic queries go through the same normalisation as Qur'an search, so a
  /// name typed without harakat still matches; Latin queries match the English
  /// name or the raw identifier.
  static List<QuranReciter> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return all;
    final latin = trimmed.toLowerCase();
    return all
        .where(
          (reciter) =>
              arabicMatches(reciter.arabicName, trimmed) ||
              reciter.englishName.toLowerCase().contains(latin) ||
              reciter.id.toLowerCase().contains(latin),
        )
        .toList(growable: false);
  }
}
