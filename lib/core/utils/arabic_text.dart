/// Arabic text normalisation shared by every search surface.
///
/// Arabic users type plain, unvocalised words ("الرحمن") while the Qur'an text
/// and the adhkar are fully vocalised ("ٱلرَّحْمَٰن"), so a literal `contains`
/// finds almost nothing. Normalising both sides makes search work the way a
/// reader expects, without touching the stored text.
///
/// ## The dagger alef
///
/// Uthmani orthography writes some long `ا` sounds as a *superscript* (dagger)
/// alef `U+0670` instead of a full alef:
///
/// | word     | Uthmani text      | reader types |
/// |----------|-------------------|--------------|
/// | الرحمن   | `ٱلرَّحْمَٰنِ`     | `الرحمن`     |
/// | الصراط   | `ٱلصِّرَٰطَ`      | `الصراط`     |
///
/// Neither dropping it nor expanding it handles both cases, so every string is
/// normalised into **both** forms ([ArabicForms]) and a match is accepted when
/// either form matches. That is what [arabicMatches] does, and search must go
/// through it rather than calling [String.contains] on a single normalisation.
library;

/// Combining marks that carry pronunciation but never meaning for a search:
/// harakat, tanween, shadda, sukun, tatweel and the Qur'anic annotation signs.
bool _isIgnorable(int rune) {
  return (rune >= 0x0610 && rune <= 0x061A) || // Arabic signs
      (rune >= 0x064B && rune <= 0x065F) || // harakat, shadda, sukun
      rune == 0x0640 || // tatweel / kashida
      (rune >= 0x06D6 && rune <= 0x06DC) || // small high marks
      (rune >= 0x06DF && rune <= 0x06E4) ||
      (rune >= 0x06E7 && rune <= 0x06E8) ||
      (rune >= 0x06EA && rune <= 0x06ED) ||
      (rune >= 0x08D3 && rune <= 0x08FF); // extended marks
}

/// The Uthmani dagger alef — handled specially, see the library docs.
const int daggerAlef = 0x0670;

/// Collapses the letter variants that readers treat as identical.
int _unify(int rune) {
  switch (rune) {
    case 0x0622: // آ
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0671: // ٱ
    case 0x0627: // ا
      return 0x0627;
    case 0x0649: // ى
    case 0x064A: // ي
      return 0x064A;
    case 0x0626: // ئ
      return 0x064A;
    case 0x0629: // ة
      return 0x0647;
    case 0x0624: // ؤ
      return 0x0648;
    default:
      return rune;
  }
}

/// The two spellings a reader might use for the same passage.
///
/// * [plain] drops the dagger alef — matches what readers type for words like
///   "الرحمن".
/// * [expanded] turns it into a full alef — matches what readers type for words
///   like "الصراط".
///
/// Both also have diacritics removed, letter variants unified, Arabic-Indic
/// digits converted to ASCII, Latin lower-cased and whitespace collapsed.
class ArabicForms {
  const ArabicForms(this.plain, this.expanded);

  final String plain;
  final String expanded;

  bool get isEmpty => plain.isEmpty;

  @override
  String toString() => 'ArabicForms(plain: $plain, expanded: $expanded)';
}

/// Normalises [input] into both searchable spellings in a single pass.
ArabicForms arabicForms(String input) {
  final plain = StringBuffer();
  final expanded = StringBuffer();
  var lastWasSpace = true;

  void write(int rune) {
    plain.writeCharCode(rune);
    expanded.writeCharCode(rune);
    lastWasSpace = false;
  }

  for (final rune in input.runes) {
    if (rune == daggerAlef) {
      // The one character the two forms disagree about.
      expanded.writeCharCode(0x0627);
      lastWasSpace = false;
      continue;
    }
    if (_isIgnorable(rune)) continue;

    final unified = _unify(rune);

    // Arabic-Indic and Extended Arabic-Indic digits become ASCII, so a reader
    // can search "٦٠٤" or "604" interchangeably.
    if (unified >= 0x0660 && unified <= 0x0669) {
      write(0x30 + (unified - 0x0660));
      continue;
    }
    if (unified >= 0x06F0 && unified <= 0x06F9) {
      write(0x30 + (unified - 0x06F0));
      continue;
    }

    if (unified == 0x20 || unified == 0x09 || unified == 0x0A) {
      if (lastWasSpace) continue;
      write(0x20);
      lastWasSpace = true;
      continue;
    }

    write(unified);
  }

  return ArabicForms(_trim(plain), _trim(expanded));
}

String _trim(StringBuffer buffer) {
  var out = buffer.toString();
  if (out.endsWith(' ')) out = out.substring(0, out.length - 1);
  return out.toLowerCase();
}

/// Returns [input] with diacritics removed, letter variants unified and the
/// dagger alef dropped.
///
/// This is the *display-neutral* form used for the "plain" half of a match. To
/// test whether one passage contains another, use [arabicMatches] — a bare
/// `contains` on this value misses Uthmani spellings such as `ٱلصِّرَٰطَ`.
String normalizeArabic(String input) => arabicForms(input).plain;

/// True when [haystack] contains [needle] under either Uthmani spelling of the
/// dagger alef.
///
/// This is the single matching rule every Arabic search in the app must use.
bool arabicMatches(String haystack, String needle) {
  final h = arabicForms(haystack);
  final n = arabicForms(needle);
  if (n.plain.isEmpty) return false;
  return h.plain.contains(n.plain) || h.expanded.contains(n.expanded);
}
