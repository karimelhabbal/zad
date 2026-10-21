#!/usr/bin/env python3
"""Fetch official Umm al-Qura month start dates (Aladhan HJCoSA method) and
emit a compact Dart table for lib/core/utils/hijri_date.dart."""
import json
import time
import urllib.request
import sys

START_YEAR = 1438
END_YEAR = 1472

def jdn(y, m, d):
    a = (14 - m) // 12
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    return d + (153 * mm + 2) // 5 + 365 * yy + yy // 4 - yy // 100 + yy // 400 - 32045

def fetch(h_year, h_month):
    url = f"https://api.aladhan.com/v1/hToG/01-{h_month:02d}-{h_year}"
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                data = json.load(r)
            g = data["data"]["gregorian"]["date"]  # DD-MM-YYYY
            dd, mm, yy = (int(x) for x in g.split("-"))
            return jdn(yy, mm, dd)
        except Exception as e:  # noqa
            print(f"retry {h_year}-{h_month}: {e}", file=sys.stderr)
            time.sleep(2)
    raise SystemExit(f"failed {h_year}-{h_month}")

month_starts = []
for y in range(START_YEAR, END_YEAR + 1):
    for m in range(1, 13):
        month_starts.append(fetch(y, m))
        if m == 12 or m == 6:
            print(f"{y}-{m}: {month_starts[-1]}", file=sys.stderr)

# sanity: strictly increasing, gaps 29/30
bad = []
prev = None
for i, ms in enumerate(month_starts):
    if prev is not None and ms - prev not in (29, 30):
        bad.append((i, prev, ms, ms - prev))
    prev = ms
if bad:
    print("BAD GAPS:", bad, file=sys.stderr)

print(f"total {len(month_starts)} entries, {START_YEAR}..{END_YEAR}", file=sys.stderr)

lines = []
lines.append("  // Official Umm al-Qura month starts (High Judicial Council of")
lines.append("  // Saudi Arabia) for 1 Muharram %d .. 1 Dhu al-Hijjah %d AH," % (START_YEAR, END_YEAR))
lines.append("  // stored as Julian Day Numbers. One entry per Hijri month, in")
lines.append("  // order, starting at %d. Generated from the published tables." % START_YEAR)
lines.append("  static const int _uqTableStartYear = %d;" % START_YEAR)
lines.append("")
lines.append("  static const List<int> _uqMonthStartJdn = <int>[")
for i in range(0, len(month_starts), 12):
    chunk = month_starts[i:i + 12]
    year = START_YEAR + i // 12
    comment = "%d AH" % year
    lines.append("    %s,  // %s" % (", ".join(str(v) for v in chunk), comment))
lines.append("  ];")
print("\n".join(lines))
