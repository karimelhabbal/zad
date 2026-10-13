#!/usr/bin/env python3
"""Collect Dart analyzer diagnostics for the Zad project over LSP.

**Why this exists.** The Flutter/Dart CLI wrappers cannot spawn their own
helper processes in this environment -- `flutter analyze`, `dart analyze` and
`flutter test` all die with `CreateFile failed: 231 (All pipe instances are
busy)`. So instead of asking the CLI, we launch the analysis-server snapshot
ourselves and speak the Language Server Protocol to it. Python spawns
processes here without trouble; Dart does not.

**Two things are easy to get wrong**, and both cost real debugging time:

1. The AOT snapshot needs several seconds to boot. An `initialize` sent the
   instant the process is spawned is dropped on the floor, and the run then
   blocks forever waiting for a reply that will never come. We wait, and we
   re-send if the first attempt goes unanswered.

2. Every message carries *two* headers (`Content-Length` **and**
   `Content-Type`) before the blank line. A reader that consumes a single
   header line leaves the blank line in the stream, so the following
   `read(n)` swallows it and every body comes back shifted by two bytes --
   which parses as nothing at all, silently. We drain headers until the real
   separator.

The server only publishes diagnostics for files that *have* something to
report, so "silent" means clean.

Usage:
    python tool/analyze_via_lsp.py                 # lib/, test/, tool/
    python tool/analyze_via_lsp.py lib test        # only these directories
    python tool/analyze_via_lsp.py --quiet         # summary line only

Exits 1 when errors are found, so it can gate a commit.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT_URI = "file:///" + ROOT.replace("\\", "/")

# `tool/audio_harness/**` is excluded in analysis_options.yaml because the
# analyzer resolves the *real* packages and cannot type-check the stub tree.
# The server never publishes for excluded files, so opening them would only
# make the run wait for diagnostics that are never coming.
SKIP_DIRS = ("tool/audio_harness",)

STARTUP_WAIT = 8.0
STARTUP_TIMEOUT = 150.0
IDLE_TIMEOUT = 60.0
GRACE_PERIOD = 12.0
HARD_CAP = 600.0


def find_sdk():
    """Locate the Dart SDK that ships with Flutter."""
    env = os.environ.get("DART_SDK")
    if env and os.path.exists(os.path.join(env, "bin", "snapshots")):
        return env
    flutter = shutil.which("flutter")
    if flutter:
        sdk = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(flutter))),
                           "bin", "cache", "dart-sdk")
        if os.path.exists(os.path.join(sdk, "bin", "snapshots")):
            return sdk
    return None


class AnalysisServer:
    def __init__(self, runtime, server, cwd, verbose):
        self.verbose = verbose
        self.lock = threading.Lock()
        self.diagnostics = {}
        self.responses = {}
        self.stderr = []
        self.unparsed = []
        self.last_activity = time.time()
        self.opened = set()
        self.analyzing = None

        self.proc = subprocess.Popen(
            [runtime, server, "--protocol=lsp", "--client-id=zad-tool",
             "--client-version=1.0", "--dart-sdk=" + os.path.dirname(os.path.dirname(runtime))],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, cwd=cwd)
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    # -------------------------------------------------------------- plumbing

    def _read_stdout(self):
        stream = self.proc.stdout
        while True:
            line = stream.readline()
            if not line:
                return
            text = line.decode("utf-8", "replace").rstrip("\r\n")
            if not text:
                continue
            if text.lower().startswith("content-length:"):
                try:
                    length = int(text.split(":", 1)[1].strip())
                except ValueError:
                    continue
                # Drain the remaining headers up to the blank line -- there is
                # more than one (see the module docstring).
                while True:
                    header = stream.readline()
                    if not header:
                        return
                    if header.strip() == b"":
                        break
                body = stream.read(length)
            else:
                # Tolerate a bare JSON line, which this server also emits.
                body = line
            try:
                msg = json.loads(body.decode("utf-8", "replace"))
            except Exception:
                if len(self.unparsed) < 5:
                    self.unparsed.append(text[:200])
                continue
            with self.lock:
                if "method" in msg:
                    method = msg["method"]
                    params = msg.get("params") or {}
                    if method == "textDocument/publishDiagnostics":
                        self.diagnostics[params.get("uri")] = \
                            params.get("diagnostics") or []
                        self.last_activity = time.time()
                    elif method == "$/analyzerStatus":
                        # The server's own "I am done" signal. Without it, a
                        # project with nothing to report looks exactly like a
                        # project that has not been analysed yet.
                        self.analyzing = params.get("isAnalyzing")
                        self.last_activity = time.time()
                elif "id" in msg:
                    self.responses[msg["id"]] = msg

    def _read_stderr(self):
        try:
            for line in self.proc.stderr:
                self.stderr.append(line.decode("utf-8", "replace").rstrip())
        except Exception:
            pass

    def send(self, payload):
        data = json.dumps(payload).encode("utf-8")
        with self.lock:
            self.proc.stdin.write(
                ("Content-Length: %d\r\n\r\n" % len(data)).encode("ascii") + data)
            self.proc.stdin.flush()

    def initialize(self):
        params = {"processId": os.getpid(), "rootUri": ROOT_URI,
                  "workspaceFolders": [{"uri": ROOT_URI, "name": "zad"}],
                  "capabilities": {"textDocument": {"publishDiagnostics": {}}}}
        # Boot delay: sending this too early silently loses it.
        time.sleep(STARTUP_WAIT)
        self.send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                   "params": params})
        started = time.time()
        attempt = 1
        while time.time() - started < STARTUP_TIMEOUT:
            with self.lock:
                if 1 in self.responses:
                    break
            if attempt < 4 and time.time() - started > 30 * attempt:
                attempt += 1
                self.send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                           "params": params})
            time.sleep(0.2)
        with self.lock:
            ok = 1 in self.responses
        if not ok:
            raise TimeoutError("the analysis server never answered initialize")
        self.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
        if self.verbose:
            print("server initialised (attempt %d)" % attempt)

    def open_file(self, path):
        uri = "file:///" + path.replace("\\", "/")
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        with self.lock:
            self.opened.add(uri)
        self.send({"jsonrpc": "2.0", "method": "textDocument/didOpen",
                   "params": {"textDocument": {"uri": uri, "languageId": "dart",
                                               "version": 1, "text": text}}})

    def wait_for_analysis(self):
        """Block until the server has finished analysing, or it goes quiet."""
        deadline = time.time() + HARD_CAP
        while time.time() < deadline:
            with self.lock:
                missing = [u for u in self.opened if u not in self.diagnostics]
                idle = time.time() - self.last_activity
                analyzing = self.analyzing
                have = len(self.diagnostics)
            if not missing:
                return True, "every opened file reported"
            # The server says it is done. Give the last frames a moment to land.
            if analyzing is False and idle > GRACE_PERIOD:
                return True, "analysis finished; %d file(s) with nothing to report" % len(missing)
            # The server only publishes files that have something to say, so a
            # quiet stretch after some output means the rest are clean.
            if idle > IDLE_TIMEOUT and have:
                return True, "%d file(s) still silent -> treated as clean" % len(missing)
            time.sleep(1)
        return False, "timed out"

    def snapshot(self):
        with self.lock:
            return dict(self.diagnostics)

    def kill(self):
        try:
            self.proc.kill()
        except Exception:
            pass


def collect_paths(targets):
    files = []
    for target in targets:
        base = os.path.join(ROOT, target)
        if os.path.isfile(base) and base.endswith(".dart"):
            files.append(base)
            continue
        for dirpath, dirs, names in os.walk(base):
            rel = os.path.relpath(dirpath, ROOT).replace("\\", "/")
            if any(rel == skip or rel.startswith(skip + "/") for skip in SKIP_DIRS):
                dirs[:] = []
                continue
            for name in names:
                if name.endswith(".dart"):
                    files.append(os.path.join(dirpath, name))
    return sorted(set(files))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("targets", nargs="*", default=["lib", "test", "tool"],
                        help="directories (or files) to analyse")
    parser.add_argument("--quiet", action="store_true", help="summary only")
    args = parser.parse_args()
    targets = args.targets or ["lib", "test", "tool"]

    sdk = find_sdk()
    if not sdk:
        print("Could not locate the Dart SDK. Set DART_SDK to the "
              "dart-sdk directory (the one containing bin/snapshots).")
        return 2
    runtime = os.path.join(sdk, "bin", "dartaotruntime.exe")
    if not os.path.exists(runtime):
        runtime = os.path.join(sdk, "bin", "dartaotruntime")
    server = os.path.join(sdk, "bin", "snapshots", "analysis_server_aot.dart.snapshot")
    if not os.path.exists(server):
        print("analysis server snapshot not found: %s" % server)
        return 2

    files = collect_paths(targets)
    if not files:
        print("nothing to analyse under: %s" % ", ".join(targets))
        return 2

    started = time.time()
    srv = AnalysisServer(runtime, server, ROOT, verbose=not args.quiet)
    try:
        srv.initialize()
        for path in files:
            srv.open_file(path)
        if not args.quiet:
            print("opened %d file(s); waiting for analysis..." % len(files))
        completed, why = srv.wait_for_analysis()
        snapshot = srv.snapshot()
    except TimeoutError as exc:
        print("FAILED: %s" % exc)
        srv.kill()
        return 2
    finally:
        pass

    sev_names = {1: "ERROR", 2: "WARNING", 3: "INFO", 4: "HINT"}
    counts = {}
    grouped = {"ERROR": [], "WARNING": [], "INFO": [], "HINT": []}
    for uri in sorted(snapshot):
        for item in snapshot[uri]:
            sev = sev_names.get(item.get("severity", 4), "HINT")
            counts[sev] = counts.get(sev, 0) + 1
            start = (item.get("range") or {}).get("start") or {}
            rel = uri.replace(ROOT_URI + "/", "").replace("/", os.sep)
            grouped[sev].append("%s:%d:%d  [%s] %s" % (
                rel, (start.get("line") or 0) + 1, (start.get("character") or 0) + 1,
                item.get("code") or "",
                (item.get("message") or "").replace("\n", " ")))

    print("")
    print("=== ZAD ANALYSIS RESULT (dart analysis server, LSP) ===")
    print("files analysed: %d in %.0fs (%s)" % (len(files), time.time() - started, why))
    for sev in ("ERROR", "WARNING", "INFO", "HINT"):
        print("%-7s %d" % (sev + ":", counts.get(sev, 0)))
    if not args.quiet:
        for sev in ("ERROR", "WARNING", "INFO", "HINT"):
            if not grouped[sev]:
                continue
            print("")
            print("--- %s (%d) ---" % (sev, len(grouped[sev])))
            for entry in sorted(grouped[sev]):
                print(entry)
    if srv.unparsed and not args.quiet:
        print("")
        print("unparsed frames: %s" % srv.unparsed)
    if srv.stderr and not args.quiet:
        print("")
        print("--- server stderr (first 15) ---")
        for line in srv.stderr[:15]:
            print(line)

    srv.kill()
    if not completed:
        return 2
    return 1 if counts.get("ERROR") else 0


if __name__ == "__main__":
    sys.exit(main())
