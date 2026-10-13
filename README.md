# زاد — Zad

رفيق الروح والمسير: القرآن الكريم، الأذكار، السبحة الذكية، مواقيت الصلاة والقبلة.

A Flutter (Android) Islamic companion app built on the approved **"Sanctuary
Elegance"** design system: deep emerald `#134E3A`, muted artisan gold `#C99E5C`,
warm ivory surface `#FBF9F4`.

---

## Features

| Area | What is implemented |
| --- | --- |
| **Home** | Greeting, Hijri date, live next-prayer countdown with day progress, six prayer milestones, daily *wird* card bound to the saved reading position, quick access grid, verse of the day — every value read from real state. |
| **Quran** | Two display modes. **Text mode**: continuous classical script with ornate ayah markers, per-ayah tap actions (bookmark / copy / share / open in Mushaf), surah & ayah pickers, font scaling. **Mushaf mode**: the authentic 604-page Madinah Mushaf — *photographs of the printed pages*, served by the Electronic Mushaf project at King Saud University, which describes them as «نسخة حقيقية مصوّرة من صفحات مصحف المدينة المنورة». Page/surah/juz navigation, download-and-cache, offline support, and three page treatments (**as printed / dimmed / inverted**) so white paper stops glaring in dark mode. |
| **Quran audio** | One surah per file, streamed from the alquran.cloud CDN (`audio-surah/128/{reciter}/{surah}.mp3`), 144 verified reciters with a searchable picker. Transport bar with play/pause, ±10 s skip, scrubber, real duration, 0.75×–2× speed, retry and a cancel-able prepare. Selecting a reciter re-streams the current surah from the new edition. Only a *definitive* 404/403 from the reachability check blocks playback — an inconclusive one (offline, CORS, captive portal) never does, because the platform player, not the Dart HTTP client, decides whether audio plays. |
| **Azkar** | 8 categories, 71 items with documented repetition counts and cited sources. Quranic adhkar are resolved from the verified Quran asset rather than retyped. Per-dhikr progress that survives restarts. |
| **Tasbeeh** | Large one-handed counter, 33 / 100 / ∞ targets, per-dhikr counters that never interfere, full custom-dhikr CRUD with validation, daily and all-time statistics. |
| **Prayer times** | Real astronomical calculation via the pure-Dart `adhan` library — no static timetable, no paid service. 12 calculation methods, Hanafi/standard Asr, high-latitude rules, device location with graceful fallback to a manual city. **Defaults to the Egyptian General Authority of Survey calendar** — the one Al-Azhar and the Ministry of Awqaf publish — and reproduces its published table to within a minute across eight cities, Alexandria to Aswan (`tool/verify_prayer_times.dart`). |
| **Qibla** | Geographic great-circle bearing to the Kaaba plus the device magnetometer. Calibration guidance, accuracy buckets, and an explicit no-sensor fallback that still shows the numeric bearing. Never a decorative compass. |
| **Settings** | Arabic/English, light/dark/system, Quran display mode and font size, calculation method, Asr madhab, high-latitude rule, notification preferences, location mode, offline page management, data reset. |

---

## Architecture

```
lib/
  app.dart                 MultiProvider wiring + MaterialApp
  main.dart                Bootstrap (edge-to-edge, LocalStore)
  core/
    theme/                 app_colors (ZadTokens), app_typography, app_theme
    utils/hijri_date.dart  Tabular (Kuwaiti) Hijri conversion
  data/
    models/                quran / azkar / settings models
    repositories/          LocalStore, quran, azkar, tasbeeh, mushaf, settings
    services/              location, prayer_times, qibla
  l10n/                    source-based strings_ar / strings_en + delegate
  state/                   ChangeNotifier controllers (one per feature)
  features/                splash, shell, home, quran, azkar, tasbeeh,
                           prayer, qibla, settings, more
  widgets/                 ZadLogo/Khatam, shared cards, app bar, states
```

- **State**: `provider` — one `ChangeNotifier` per feature, composed in `app.dart`.
- **Persistence**: `shared_preferences` only, through the single `LocalStore`
  façade with versioned keys (`zad.settings.v1`, `zad.quran.position.v1`, …).
  No Firebase, no backend, no account.
- **Localisation**: plain `Map<String, String>` resources in
  `lib/l10n/strings_ar.dart` / `strings_en.dart`. There is **no ARB codegen** —
  edit those two files directly. Both files must keep identical key sets.

---

## Data sources and attribution

| Content | Source | Status |
| --- | --- | --- |
| Quran text | [Tanzil.net](https://tanzil.net) Uthmani, Hafs 'an Asim, fetched from `api.alquran.cloud/v1/quran/quran-uthmani` | ✅ Verified — 114 surahs, 6236 ayahs, 604 pages, 15 sajdah |
| Mushaf page images | 604-page Madinah Mushaf PNGs from the GitHub mirror `Kader4658/Quran_Pages` via jsDelivr; pages 595–596 fall back to `Zohanur2026/zohanur-mushaf-pages-hafs` | ⚠️ Real printed-page images, but **third-party mirrors** — licensing not formally cleared. See "Known limitations". |
| Adhkar / duas | Compiled from the Qur'an and the hadith collections (Bukhari, Muslim, Abu Dawud, At-Tirmidhi, An-Nasa'i, Ibn Majah, Ahmad), each item citing its reference | ✅ Cited per item |
| Fonts | Amiri, Noto Naskh Arabic, IBM Plex Sans, Noto Serif (all SIL OFL, via `google/fonts`) | ✅ OFL |
| Prayer times | `adhan` ^2.0.0 — pure Dart, offline | ✅ No paid service |
| City lookup | Open-Meteo geocoding API | ✅ Free, no key |

The Quran asset is regenerated with `tool/build_quran_asset.py` from a raw
`quran_raw.json` download. Surah names are normalised to canonical Arabic
orthography (e.g. `آل عمران` uses precomposed U+0622, not alef + combining maddah).

---

## Verification

Run from the project root in Android Studio's terminal (PowerShell or Git Bash).

```powershell
flutter pub get
flutter analyze --no-pub
flutter test
flutter build apk --debug
```

### When the Dart toolchain cannot spawn processes

On this machine `flutter test`, `flutter analyze` and `dart analyze` all fail with

```
ProcessException: All pipe instances are busy (at ../../runtime/bin/process_win.cc:744)
```

The Dart SDK cannot create the pipes it uses to spawn helpers, so no child process
can start. This is host-level (identical with the sandbox disabled and with a plain
`Process.start` from Dart) and unrelated to the project. Three harnesses exist to
keep verification possible in that state:

```powershell
# Real analyzer diagnostics (drives the Dart analysis server over LSP)
python tool/analyze_via_lsp.py

# Executes the real AudioController against a stubbed platform player
python tool/audio_harness/run.py

# Checks the real PrayerTimesService against the published Egyptian table
dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/verify_prayer_times.dart
```

The prayer check works because `PrayerTimesService` and the models it needs are
pure Dart — no Flutter import — so the Dart VM runs them directly. It compares
**UTC instants**, never local wall-clock time, so it does not depend on the
timezone of the machine running it.

To pre-fetch the Mushaf pages for bundling as assets (see the size warning in the
script):

```powershell
python tool/fetch_mushaf_assets.py --out assets/mushaf
```

`tool/analyze_via_lsp.py` launches the analysis-server snapshot itself and speaks
LSP to it. Two details are load-bearing, and both cost real debugging time when they
are wrong: the server needs a few seconds to boot, so an `initialize` sent the
instant it is spawned is silently dropped; and every message carries **two** headers
(`Content-Length` *and* `Content-Type`) before the blank line, so a reader that
consumes a single header line shifts every body by two bytes and parses nothing.
The server only publishes diagnostics for files that have something to report, so a
silent file means a clean file. Exits 1 on errors, so it can gate a commit.

`tool/audio_harness/` compiles and runs the genuine `lib/state/audio_controller.dart`
(including the real `AudioPlayersRecitationPlayer` adapter and the real
`probeAudioUrl`, which uses the genuine `package:http`) on the plain Dart VM, by
resolving `package:flutter` / `package:audioplayers` to the minimal stand-ins in
`tool/audio_harness/stubs/`. It is a substitute for
`flutter test test/audio_controller_test.dart`, **not** a replacement: it cannot
exercise widgets, platform channels or the real plugin. Keep both suites in sync.

Expected results as of the last run on this machine:

| Command | Result |
| --- | --- |
| `python tool/analyze_via_lsp.py` | **68 files, 0 errors, 0 warnings, 0 infos** — real analyzer diagnostics over LSP |
| `flutter analyze --no-pub` | **No issues found** — last full run before the toolchain broke |
| `flutter test` | **103 passed, 0 failed** — last full run; the audio suite has since grown to 42 cases and new prayer-time and settings-migration cases were added, none of which any runner has executed (see above). `tool/analyze_via_lsp.py` type-checks them even though it cannot run them |
| `python tool/audio_harness/run.py` | **37 passed, 0 failed** — the audio controller, executed for real |
| `dart --disable-dart-dev --packages=.dart_tool/package_config.json tool/verify_prayer_times.dart` | **48 checks, 0 failures** — computed times against the published Egyptian table, worst delta 1 minute |
| `python tool/check_dart_balance.py` | **72/72 files balanced** |
| `flutter build bundle` | **Succeeded** — full Dart kernel compiled, assets + fonts bundled |
| `flutter build apk --debug` | See below |

> **Gradle note.** `android/gradle.properties` requests an 8 GB Gradle daemon
> heap. On a machine with less free RAM the daemon is killed mid-build and you
> see *"Gradle build daemon disappeared unexpectedly"*. If that happens, lower
> the heap, e.g. `org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=1024m`.

### Checks that need a real device or emulator

These cannot be verified by the analyzer or the unit tests:

1. **Location permission flow** — grant, deny, and "deny forever"; confirm the
   manual-city fallback appears in each case.
2. **Qibla sensor** — the magnetometer reading, calibration prompt and accuracy
   buckets only work on physical hardware. Also confirm the no-sensor fallback
   on an emulator.
3. **Mushaf page download** — first run downloads from King Saud University;
   verify progress, cancel, and that cached pages render offline. Then check all
   three **page appearance** options in dark mode: *as printed* should glare,
   *dimmed* should be readable, *night (inverted)* should give light ink on a
   true black page. Confirm swipe, centre-tap and pinch-zoom still work under
   each.
4. **RTL / text scaling** — set the system language to Arabic and the font size
   to the largest step; check forms, dialogs and the reading views.
5. **Theme switch** — light/dark and system-follow, then restart to confirm the
   choice persists.
6. **Reading position and bookmarks** — read a few ayahs, kill the app, reopen;
   then switch text ⇄ Mushaf mode and confirm the position is preserved.
7. **Tasbeeh persistence** — count, create/edit/delete a custom dhikr, restart.
8. **Recitation playback** — press play on a surah and confirm audio starts and
   the spinner clears; pause/resume, ±10 s, the scrubber on a long surah
   (Al-Baqarah), speed changes mid-stream, and switching reciter while playing.
   Also confirm that a slow prepare can be cancelled by tapping the spinner, and
   that playback pauses when the app is backgrounded.
9. **Prayer times** — compare the displayed times against the General Authority
   of Survey table for today for your governorate. They should agree to the
   minute on Fajr, sunrise, Asr, Maghrib and Isha, and to within a minute or two
   on Dhuhr. Also check that an upgrade from an older build switches the method
   from Umm al-Qura to the Egyptian authority (Settings → calculation method).

---

## Known limitations

- **Mushaf licensing (improved, still not settled).** Pages are now served by
  the Electronic Mushaf project at King Saud University, which states on its own
  site that they are «نسخة حقيقية مصوّرة من صفحات مصحف المدينة المنورة» — a real
  photographic copy of the Madinah Mushaf pages. That replaced the previous
  third-party GitHub mirrors, which on inspection turned out **not to be the
  printed page at all**: the old files were a text render, wrong aspect ratio
  (0.62 against the printed 0.68), with most of each page left blank. So the
  images are now genuinely the printed pages, and the host is an academic
  institution rather than an anonymous mirror. What is still missing is an
  explicit written licence — the site publishes no terms of use that could be
  found. Before a store release, either obtain written permission from King Saud
  University, or take the assets from the King Fahd Glorious Quran Printing
  Complex, which prints and distributes the Madinah Mushaf itself.
- The jsDelivr mirror is retained only as a fallback for when the university host
  is unreachable. It serves the old rendered pages, so a page fetched through it
  will not match the photographed ones around it.
- Notification preferences are stored and respected as settings, but no local
  notification scheduling is wired up yet.
- Hijri dates use the tabular (Kuwaiti) algorithm, so they may differ by ±1 day
  from local moon sighting.
