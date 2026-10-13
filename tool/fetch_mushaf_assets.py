#!/usr/bin/env python3
"""Fetch the 604 Madinah Mushaf page images onto disk.

Two ways to use this:

1. **Bundling the pages into the app.** Pass `--out assets/mushaf` and then add
   the directory to `pubspec.yaml` (the script prints the exact snippet). The
   app then needs no network at all for the Mushaf. Be aware of the size: the
   photographed print is ~135 KB per page, so the full set is roughly 82 MB
   before Flutter's own compression — that is a lot of APK for a feature that
   already downloads on demand and caches. Bundling is the right call only if
   the Mushaf must work on a first launch with no connectivity.

2. **Pre-seeding a server or a mirror.** Pass any `--out` directory.

Pages are fetched from the same two sources the app uses, in the same order:
the photographed Madinah Mushaf print served by the Electronic Mushaf project
at King Saud University, then the jsDelivr mirror of a rendered page set.

Re-running is safe and cheap: a page already on disk that looks like a real
image is skipped, so an interrupted run resumes where it stopped.

    python tool/fetch_mushaf_assets.py --out assets/mushaf
    python tool/fetch_mushaf_assets.py --from 1 --to 20 --out /tmp/probe
    python tool/fetch_mushaf_assets.py --verify-only --out assets/mushaf

Exits 1 if any page is missing or invalid.
"""

import argparse
import concurrent.futures
import os
import struct
import sys
import urllib.error
import urllib.request

TOTAL_PAGES = 604
USER_AGENT = "Zad-Mushaf-Fetcher/1.0 (+https://github.com/)"

PRIMARY = "https://quran.ksu.edu.sa/png_big/{page}.png"
FALLBACK = ("https://cdn.jsdelivr.net/gh/Kader4658/Quran_Pages@main/"
            "page{page:03d}.png")

# A real page is never this small; anything under it is an error document.
MIN_BYTES = 20 * 1024


def dimensions(data):
    """(format, width, height) for a PNG or JPEG byte string, else None."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        if len(data) < 24:
            return None
        width, height = struct.unpack(">II", data[16:24])
        return ("PNG", width, height)
    if data[:2] == b"\xff\xd8":
        i = 2
        while i < len(data) - 9:
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3):
                height, width = struct.unpack(">HH", data[i + 5:i + 9])
                return ("JPEG", width, height)
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    return None


def valid(path):
    """True when `path` already holds a usable page image."""
    try:
        if os.path.getsize(path) < MIN_BYTES:
            return False
        with open(path, "rb") as fh:
            return dimensions(fh.read(4096)) is not None
    except OSError:
        return False


def fetch(page, out_dir, timeout):
    """Download one page. Returns (page, 'skipped'|'primary'|'fallback'|error)."""
    target = os.path.join(out_dir, "%03d.png" % page)
    if valid(target):
        return page, "skipped", None

    last_error = "no source tried"
    for label, template in (("primary", PRIMARY), ("fallback", FALLBACK)):
        url = template.format(page=page)
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = response.read()
            info = dimensions(data[:4096])
            if len(data) < MIN_BYTES or info is None:
                last_error = "%s: not a usable image (%d bytes)" % (label, len(data))
                continue
            tmp = target + ".part"
            with open(tmp, "wb") as fh:
                fh.write(data)
            os.replace(tmp, target)
            return page, label, None
        except urllib.error.HTTPError as exc:
            last_error = "%s: HTTP %s" % (label, exc.code)
        except Exception as exc:  # noqa: BLE001 - report, then try the next source
            last_error = "%s: %s" % (label, exc)
    return page, "failed", last_error


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--out", default="assets/mushaf",
                        help="output directory (default: assets/mushaf)")
    parser.add_argument("--from", dest="first", type=int, default=1)
    parser.add_argument("--to", dest="last", type=int, default=TOTAL_PAGES)
    parser.add_argument("--concurrency", type=int, default=8)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--verify-only", action="store_true",
                        help="do not download; only report what is present")
    args = parser.parse_args()

    first = max(1, args.first)
    last = min(TOTAL_PAGES, args.last)
    if first > last:
        print("empty range: --from %d --to %d" % (first, last))
        return 2

    os.makedirs(args.out, exist_ok=True)
    pages = list(range(first, last + 1))

    counts = {"skipped": 0, "primary": 0, "fallback": 0, "failed": 0}
    failures = []

    if args.verify_only:
        for page in pages:
            target = os.path.join(args.out, "%03d.png" % page)
            if valid(target):
                counts["skipped"] += 1
            else:
                counts["failed"] += 1
                failures.append((page, "missing or invalid"))
    else:
        done = 0
        with concurrent.futures.ThreadPoolExecutor(
                max_workers=max(1, args.concurrency)) as pool:
            futures = [pool.submit(fetch, p, args.out, args.timeout) for p in pages]
            for future in concurrent.futures.as_completed(futures):
                page, status, error = future.result()
                counts[status] = counts.get(status, 0) + 1
                if status == "failed":
                    failures.append((page, error))
                done += 1
                if done % 25 == 0 or done == len(pages):
                    print("  %d/%d pages processed" % (done, len(pages)), flush=True)

    present = sum(1 for p in pages if valid(os.path.join(args.out, "%03d.png" % p)))
    total_bytes = 0
    for page in pages:
        path = os.path.join(args.out, "%03d.png" % page)
        if os.path.exists(path):
            total_bytes += os.path.getsize(path)

    print("")
    print("=== Mushaf pages: %d-%d into %s ===" % (first, last, args.out))
    print("downloaded from the photographed print : %d" % counts["primary"])
    print("downloaded from the fallback mirror    : %d" % counts["fallback"])
    print("already present                        : %d" % counts["skipped"])
    print("failed                                 : %d" % counts["failed"])
    print("usable pages in range                  : %d/%d" % (present, len(pages)))
    print("on disk                                : %.1f MB" % (total_bytes / 1048576))
    if failures:
        print("")
        print("failures:")
        for page, error in failures[:20]:
            print("  page %d: %s" % (page, error))
        if len(failures) > 20:
            print("  ... and %d more" % (len(failures) - 20))

    if present == TOTAL_PAGES and first == 1 and last == TOTAL_PAGES:
        print("")
        print("All %d pages are present. To bundle them, add to pubspec.yaml:"
              % TOTAL_PAGES)
        print("")
        print("  flutter:")
        print("    assets:")
        print("      - %s/" % args.out.rstrip("/"))

    return 0 if present == len(pages) else 1


if __name__ == "__main__":
    sys.exit(main())
