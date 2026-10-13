"""Builds `lib/data/models/reciter_catalogue.dart` from live CDN evidence.

Why this exists: the previous hand-written catalogue listed only 18 reciters.
That list was *correct* but far from *complete* — the CDN actually serves
surah-level audio for 146 Arabic recitations, and the popular ones users ask
for (e.g. عبد الله المطرود) were missing, so choosing them was impossible.

The script is deliberately evidence-first. For every Arabic edition the
alquran.cloud API advertises it issues a real HTTP Range request against the
exact endpoint the app uses:

    https://cdn.islamic.network/quran/audio-surah/128/{id}/{surah}.mp3

and only keeps editions that answer 200/206 for *every* surah in [SAMPLE]. A
206 also proves the server honours Range requests, which is what makes seeking
work. Anything answering 403 (the `-2` aliases, `ar.husary`, `ar.mahermuaiqly`,
…) is recorded as excluded rather than shipped as a broken option.

Run from the project root (needs network):

    <venv>/Scripts/python.exe tool/build_reciters.py

It rewrites exactly one file and touches nothing else.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "lib", "data", "models", "reciter_catalogue.dart")

EDITIONS_URL = "https://api.alquran.cloud/v1/edition?format=audio"
AUDIO_URL = "https://cdn.islamic.network/quran/audio-surah/128/{id}/{surah}.mp3"

# Surah 1 is the probe; the rest confirm the edition is not partially uploaded.
SAMPLE = [1, 9, 36, 78, 114]

ARABIC = re.compile("[\u0600-\u06FF]")

# Identifiers already curated by hand. When two editions share an Arabic name
# (the CDN carries several aliases for the same reciter) these win, so the
# familiar ids such as `ar.alafasy` survive the de-duplication.
PRIORITY = [
    "ar.alafasy", "ar.abdulbasitmurattal", "ar.abdulbasitmujawwad",
    "ar.muhammadsiddiqalminshawimujawwad", "ar.saudalshuraim",
    "ar.aliabdurrahmanalhuthaify", "ar.abdullahawadaljuhani",
    "ar.yasseraldossari", "ar.faresabbad", "ar.nasseralqatami",
    "ar.muhammadayyub", "ar.ahmedalajmi", "ar.haniarrifai",
    "ar.mohamedtablawi", "ar.mustafaismail", "ar.muhammadalmehysni",
    "ar.mahmoudalialbanna", "ar.abdullahbasfar",
]


# Hand-checked names for reciters users recognise, used in place of the API's
# sometimes terse labels (it ships "Alafasy" and "Abdul Basit").
NAME_OVERRIDES = {
    "ar.alafasy": ("مشاري راشد العفاسي", "Mishary Rashid Alafasy"),
    "ar.abdulbasitmurattal": ("عبد الباسط عبد الصمد (مرتّل)", "Abdul Basit (Murattal)"),
    "ar.abdulbasitmujawwad": ("عبد الباسط عبد الصمد (مجوّد)", "Abdul Basit (Mujawwad)"),
    "ar.muhammadsiddiqalminshawimujawwad": (
        "محمد صديق المنشاوي (مجوّد)", "Muhammad Siddiq al-Minshawi"),
    "ar.saudalshuraim": ("سعود الشريم", "Saud ash-Shuraim"),
    "ar.aliabdurrahmanalhuthaify": (
        "علي بن عبد الرحمن الحذيفي", "Ali Abdur-Rahman al-Huthaify"),
    "ar.abdullahawadaljuhani": ("عبد الله عواد الجهني", "Abdullah Awad al-Juhani"),
    "ar.yasseraldossari": ("ياسر الدوسري", "Yasser ad-Dossari"),
    "ar.faresabbad": ("فارس عباد", "Fares Abbad"),
    "ar.nasseralqatami": ("ناصر القطامي", "Nasser al-Qatami"),
    "ar.muhammadayyub": ("محمد أيوب", "Muhammad Ayyub"),
    "ar.ahmedalajmi": ("أحمد بن علي العجمي", "Ahmed ibn Ali al-Ajamy"),
    "ar.haniarrifai": ("هاني الرفاعي", "Hani ar-Rifai"),
    "ar.mohamedtablawi": ("محمد محمود الطبلاوي", "Mohamed at-Tablawi"),
    "ar.mustafaismail": ("مصطفى إسماعيل", "Mustafa Ismail"),
    "ar.muhammadalmehysni": ("محمد المحيسني", "Muhammad al-Mehysni"),
    "ar.mahmoudalialbanna": ("محمود علي البنّا", "Mahmoud Ali al-Banna"),
    "ar.abdullahbasfar": ("عبد الله بصفر", "Abdullah Basfar"),
    "ar.abdullahalmatrood": ("عبد الله المطرود", "Abdullah al-Matrood"),
}


def http_status(url: str) -> int:
    req = urllib.request.Request(
        url, headers={"Range": "bytes=0-0", "User-Agent": "zad-build/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:  # noqa: BLE001
        return -1


def probe(args):
    rid, surah = args
    return rid, surah, http_status(AUDIO_URL.format(id=rid, surah=surah))


def main() -> int:
    print("fetching edition list ...")
    with urllib.request.urlopen(EDITIONS_URL, timeout=60) as r:
        editions = json.load(r)["data"]
    arabic = [e for e in editions if e.get("language") == "ar"]
    print(f"  {len(arabic)} Arabic editions advertised")

    ids = [e["identifier"] for e in arabic]
    print(f"probing surah {SAMPLE[0]} for all {len(ids)} ...")
    with ThreadPoolExecutor(max_workers=12) as pool:
        first = list(pool.map(lambda i: (i, http_status(AUDIO_URL.format(id=i, surah=SAMPLE[0]))), ids))
    alive = [i for i, st in first if st in (200, 206)]
    excluded_403 = sorted(i for i, st in first if st == 403)
    print(f"  {len(alive)} serve surah {SAMPLE[0]}; {len(excluded_403)} answer 403")

    print(f"confirming survivors across surahs {SAMPLE[1:]} ...")
    jobs = [(i, s) for i in alive for s in SAMPLE[1:]]
    with ThreadPoolExecutor(max_workers=12) as pool:
        rest = list(pool.map(probe, jobs))
    bad = {}
    for rid, surah, st in rest:
        if st not in (200, 206):
            bad.setdefault(rid, []).append(surah)
    solid = [i for i in alive if i not in bad]
    print(f"  {len(solid)} verified on all of {SAMPLE}")

    by_id = {e["identifier"]: e for e in arabic}
    keep = []
    for i in solid:
        e = by_id[i]
        name = e.get("name", "")
        if not ARABIC.search(name) or name == i:
            continue
        if re.search("francais|traduit|translation", i):
            continue
        ar_name, en_name = NAME_OVERRIDES.get(
            i, (name, e.get("englishName") or name))
        keep.append({"id": i, "ar": ar_name, "en": en_name})

    # De-duplicate by Arabic name; PRIORITY ids win, then alphabetical.
    def rank(entry):
        pid = PRIORITY.index(entry["id"]) if entry["id"] in PRIORITY else len(PRIORITY)
        return (pid, entry["id"])

    seen, unique = set(), []
    for entry in sorted(keep, key=rank):
        if entry["ar"] in seen:
            continue
        seen.add(entry["ar"])
        unique.append(entry)
    unique.sort(key=lambda e: rank(e))
    print(f"  {len(unique)} unique reciters after de-duplication")

    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "//",
        "// Produced by `tool/build_reciters.py`, which probes the live CDN with a",
        "// real HTTP Range request against",
        "//   https://cdn.islamic.network/quran/audio-surah/128/{id}/{surah}.mp3",
        f"// for surahs {SAMPLE} and keeps only editions answering 200/206 every time.",
        "// A 206 also proves Range support, which is what makes seeking work.",
        "//",
        f"// {len(unique)} reciters verified. Excluded because the CDN answers 403 for",
        "// surah-level audio (they remain ayah-by-ayah only):",
        "//   " + ", ".join(excluded_403[:24]) + (" …" if len(excluded_403) > 24 else ""),
        "//",
        "// Re-run the generator to refresh this list; never hand-edit it.",
        "",
        "import 'reciter.dart';",
        "",
        "const List<QuranReciter> kVerifiedReciters = <QuranReciter>[",
    ]
    for entry in unique:
        ar = entry["ar"].replace("'", r"\'")
        en = entry["en"].replace("'", r"\'")
        lines.append(
            "  QuranReciter(\n"
            f"    id: '{entry['id']}',\n"
            f"    arabicName: '{ar}',\n"
            f"    englishName: '{en}',\n"
            "  ),"
        )
    lines.append("];")
    lines.append("")

    with open(TARGET, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"wrote {TARGET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
