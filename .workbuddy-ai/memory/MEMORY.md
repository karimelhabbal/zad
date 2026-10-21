# Zad — project notes

Curated long-term notes. Append by topic; keep it short.

## Hard rules (never violate, never negotiate)

### A Mushaf page is NEVER cropped
The Mushaf reader must always show the **entire** page. No cropping, no
trimming, no `BoxFit.cover`, no "bleed", no cutting margins — not as a default,
not as an option in a picker. The user rejected this explicitly (2026-10-15):
«لا يجوز اقتطاع أجزاء من الصفحة».

**This does NOT mean the page cannot fill the screen.** "Filling" and
"completeness" only conflict for a *fixed-size* page image. Never tell the user
a screen-filling Mushaf page is impossible — check how the page is drawn first.

### No ads, no analytics, no tracking
Stated as a product promise, repeated in the in-app About screen. Do not add any
dependency that shows ads or collects data.

## The reading layout (current: font-based, 2026-10-17)

The 604 pages are **rendered as text** with `qcf_quran_plus` (QCF page fonts,
one per page). No page image, no SVG, no download. `MushafReaderScreen` wraps
`QuranPageView` (package widget) with `isTajweed`, `isDarkMode`,
`pageBackgroundColor`. The package draws 15 equal-height rows, each a
`FittedBox(BoxFit.contain)` around one line, so a line never stretches or
distorts and the page fills the area it is given. Paper: `0xFFFBF6EE` light /
`0xFF0C1310` dark.

**The page sits inside a hairline frame (2026-10-17).** `_frameInset = 10` of
paper shows outside a 1px `tokens.gold` rule (alpha 0.5 light / 0.38 dark).
The frame is an overlay painted *last*, above the chrome, so the paper-coloured
bar scrims cannot wash it out; the page is inset by the same 10px so the line
always lands in the margin and can never cross Uthmani text. **This is not
cropping** — the page is laid out in the smaller box and still fits whole. Do
not "restore" full-bleed to satisfy the completeness rule; the user asked for
the frame.

**The reader is locked to `portraitUp`.** In landscape `QuranPageView` switches
to a two-page spread and each page is squeezed to half the height, which the
user called ugly («شكلها وحش بتعرض صفحتين»). The lock is set in `initState` and
released in `dispose` (`DeviceOrientation.values`), so the rest of the app is
unaffected.

The package's own two-page threshold is `constraints.maxWidth >= 750`
(`quran_page_view.dart`). `_twoPageMinWidth` mirrors that number, compared
against the **inner** width after the 10px inset. When it is exceeded (a tablet
in portrait) `_PageFramePainter` draws **two** frames 6px apart instead of one,
so the right-hand page — the one read first in an RTL Mushaf — is visibly
separate from the left. If the package ever changes that constant, change it in
both places.

**Superseded (do not restore without being asked):** the SVG page pipeline
(`quran.ws` CDN → `MushafRepository` → `SvgPicture.file` with `contain`,
`edition = 'madani_svg_kfqc'`, 604 files, ~340 MB on disk). `MushafRepository`,
`flutter_svg`, the download/clear-cache UI and `MushafPageTreatment` were all
deleted on 2026-10-17.

## Package facts (verified against source, not guessed)

- `qcf_quran_plus: ^0.1.1`, MIT. Public API: `QuranPageView`,
  `QcfFontLoader`, `QuranTextStyles`, `HighlightVerse`, `WordHighlight`.
- `QuranPageView` params used: `pageController` (0-based), `highlights`
  (required), `isDarkMode` (required), `isTajweed`, `pageBackgroundColor`,
  `enableTwoPageLayout`, `deferNewPages`, `onPageChanged` (1-based page),
  `onLongPress(surah, verse, details)`.
- The package renders `SizedBox.shrink()` until its page data is loaded, and it
  does **not** export `QuranRepository`. `lib/data/services/mushaf_font_service.dart`
  imports `package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart`
  (with `// ignore: implementation_imports`) to call `ensureLoaded(604)`, then
  loads fonts lazily per page via `QcfFontLoader.ensureFontLoaded` /
  `preloadPages`. Do **not** switch to `setupFontsAtStartup`: it registers all
  604 × 5 font variants before the first frame.
- Fonts ship gzipped under `assets/fonts/qcf_tajweed/` (68 MB, all 604
  packaged) and are extracted to `<documents>/qcf_fonts` on first use.

## Prayer times (adhan_dart 2.0.1, since 2026-10-17)

`adhan_dart` returns **UTC** `DateTime`s (`DateTime.utc(...)`), unlike the old
`adhan` 2.0.0+1 package, which returned the device wall clock. `PrayerTimesService`
converts exactly once, with `.toLocal()`, on the way out — every `PrayerSchedule`
time is local. Do not add a second conversion anywhere; and do not add a
time-zone package: `toLocal()` uses the OS tz database, so Egypt's EEST/DST is
handled by the platform and stays correct for any location the user picks.

API differences that bit: presets are factories
(`CalculationMethodParameters.egyptian()`), enums are camelCase
(`moonsightingCommittee`, `turkiye`), `DateComponents` is gone (pass a `DateTime`,
anchored at local noon so a DST step cannot shift the calendar date), and
`Prayer` has no `none` — `nextPrayer` reports `fajrAfter` / `ishaBefore`, whose
times must be read from those fields.

The Egyptian preset carries `methodAdjustments[dhuhr] = 1`; the app cancels it
because the Survey Authority prints the plain transit. `tool/verify_prayer_times.dart`
gates this against the published 8-city table (48 checks, ±1 min) and must stay
green. `tool/print_mansoura_times.dart` prints today's times for eyeballing.

## Recitation audio (since 2026-10-17)

Two CDN shapes, one edition, one verified catalogue:
`audio-surah/128/{id}/{surah}.mp3` (whole surah) and
`audio/128/{id}/{globalAyah}.mp3` (one ayah). `globalAyah` is `1..6236` and is
computed by `QuranData.globalAyahNumber` — never hard-code it: 2:255 is 262,
3:1 is 294, 114:6 is 6236 (6237 answers 403 on the CDN).

`AudioController` owns both scopes (`RecitationScope.surah` / `.ayah`) through a
single private `_load()`; an ayah hands over to the next ayah of its surah
unless `continueThroughSurah: false`. `stop()` pauses but keeps the track;
`dismiss()` returns the player to idle (the now-playing strip's X).

There is **no permanent player bar**: `ListenBar` is one "استماع" button until
something is loaded, then a slim strip that opens `showListenSheet` (scope
switch + ayah list + `RecitationTransport`). `RecitationBar` and
`showRecitationSheet` no longer exist.

`RecitationCache.fileNameFor` uses the last **four** URL segments on purpose —
two would make `audio/…/1.mp3` and `audio-surah/…/1.mp3` share a file name and
serve a whole surah for a single ayah. `AudioDownloadsController` (More →
تحميلات الصوت) manages the same cache the player reads, per reciter.

## Where state lives

- Last page / reading position: `LocalStore.keyReadingPosition`
  (SharedPreferences) via `QuranController.savePosition` — shared with the text
  reader, so both modes resume at the same place.
- Tajweed on/off: `AppSettings.mushafTajweed` (replaced `MushafPageTreatment`).
- Bookmarks: `LocalStore.keyBookmarks`, tinted in-page via `HighlightVerse`.

## Dead ends, recorded so they are not retried

KSU (`quran.ksu.edu.sa` `png_big`) serves only 622×917 scans; QUL/Tarteel is MIT
for code only and its QCF fonts carry the same KFGQPC constraint;
`Kader4658/Quran_Pages` had `license: null`. KFQC's own licence *does* allow use
inside software; only print-for-commercial-sale is reserved.
