"""Build the compact Quran asset used by the Zad app.

Source: Tanzil.net Uthmani text (Hafs 'an Asim), obtained through the
alquran.cloud `quran-uthmani` edition. The `page` / `juz` fields follow the
Madinah Mushaf (604 pages) so the app can drive verified page navigation.
"""
import json
import re
import os

RAW = "quran_raw.json"
OUT = "assets/data/quran.json"

# Strip vowel marks but KEEP maddah (\u0653) and hamza-above/below (\u0654,
# \u0655) so names such as "آل عمران" survive intact.
ARABIC_DIACRITICS = re.compile(
    r"[\u0610-\u061A\u064B-\u0652\u0656-\u065F\u0670\u06D6-\u06ED\u0640]"
)

# Any combining mark, used only for structural comparison.
ANY_MARK = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")

# Skeleton (mark-free) of "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
BISMILLAH_SKELETON = "بسم الله الرحمن الرحيم"


def _skeleton(text: str) -> str:
    return ANY_MARK.sub("", text).replace("\u0671", "\u0627").strip()


def split_bismillah(text: str):
    """Split a leading Basmalah off an ayah.

    Upstream editions differ in diacritic ordering, so the comparison is done
    on the mark-free skeleton. Returns (bismillah, remainder) or (None, text).
    """
    if not _skeleton(text).startswith(BISMILLAH_SKELETON):
        return None, text
    target_len = len(BISMILLAH_SKELETON)
    consumed = 0
    idx = 0
    while idx < len(text) and consumed < target_len:
        if not ANY_MARK.match(text[idx]):
            consumed += 1
        idx += 1
    # Absorb any combining marks that trail the final base letter.
    while idx < len(text) and ANY_MARK.match(text[idx]):
        idx += 1
    return text[:idx].strip(), text[idx:].strip()


def clean_name(name: str) -> str:
    n = name.replace("سُورَةُ", "").replace("سورة", "").strip()
    n = ARABIC_DIACRITICS.sub("", n)
    n = n.replace("ٱ", "ا")
    # Recompose alef + maddah into the canonical precomposed alef-maddah (آ),
    # so "آل عمران" reads correctly rather than "آل عمران".
    n = n.replace("\u0627\u0653", "\u0622")
    return " ".join(n.split())


def main() -> None:
    with open(RAW, encoding="utf-8") as fh:
        data = json.load(fh)

    surahs_out = []
    juz_first_page = {}
    page_starts = {}
    sajda = []
    total_ayahs = 0
    max_page = 0

    for s in data["data"]["surahs"]:
        verses = []
        has_bismillah = False
        for a in s["ayahs"]:
            text = a["text"].replace("\ufeff", "").strip()
            # The upstream edition prefixes the Basmalah to the first ayah of
            # every surah except Al-Fatihah (where it IS ayah 1) and At-Tawbah
            # (which has none). Split it out so the reader can render it as a
            # separate heading line, exactly like the printed Mushaf.
            if a["numberInSurah"] == 1 and s["number"] != 1:
                bism, rest = split_bismillah(text)
                if bism is not None:
                    has_bismillah = True
                    text = rest
            verses.append(
                {"n": a["numberInSurah"], "t": text, "p": a["page"], "j": a["juz"]}
            )
            juz_first_page.setdefault(a["juz"], a["page"])
            page_starts.setdefault(a["page"], []).append(s["number"])
            if a.get("sajda"):
                sajda.append({"s": s["number"], "a": a["numberInSurah"]})
            total_ayahs += 1
            max_page = max(max_page, a["page"])

        surahs_out.append(
            {
                "n": s["number"],
                "name": s["name"],
                "ar": clean_name(s["name"]),
                "en": s["englishName"],
                "tr": s["englishNameTranslation"],
                "type": s["revelationType"],
                "count": len(verses),
                "bismillah": has_bismillah or s["number"] == 1,
                "startPage": verses[0]["p"],
                "startJuz": verses[0]["j"],
                "verses": verses,
            }
        )

    # A page can start more than one surah only in rare cases; keep the first
    # surah number that begins on each page.
    page_to_surah = {int(p): v[0] for p, v in sorted(page_starts.items())}

    meta = {
        "source": "Tanzil.net — Uthmani (Hafs 'an Asim), Madinah Mushaf page order",
        "riwayah": "حفص عن عاصم",
        "totalSurahs": len(surahs_out),
        "totalAyahs": total_ayahs,
        "totalPages": max_page,
        "juzStartPage": {str(k): v for k, v in sorted(juz_first_page.items())},
        "pageToSurah": {str(k): v for k, v in page_to_surah.items()},
        "surahStartPage": {str(s["n"]): s["startPage"] for s in surahs_out},
        "surahStartJuz": {str(s["n"]): s["startJuz"] for s in surahs_out},
        "sajdaAyahs": sajda,
    }

    out = {"meta": meta, "surahs": surahs_out}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))

    print("total ayahs:", total_ayahs)
    print("total pages:", max_page)
    print("juz 1 page:", juz_first_page.get(1), "juz 30 page:", juz_first_page.get(30))
    print("Al-Fatihah page:", surahs_out[0]["startPage"])
    print("Al-Baqarah page:", surahs_out[1]["startPage"])
    print("Al-Kahf page:", surahs_out[17]["startPage"])
    print("An-Nas page:", surahs_out[113]["startPage"])
    print("sajda count:", len(sajda))
    print("asset bytes:", os.path.getsize(OUT))
    print("sample surah 1:", json.dumps(surahs_out[0], ensure_ascii=False)[:300])


if __name__ == "__main__":
    main()
