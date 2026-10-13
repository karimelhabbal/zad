#!/usr/bin/env python3
"""Run `tool/audio_harness/verify_audio.dart` on the plain Dart VM.

`flutter test` and `dart analyze` cannot run on this host — the Dart SDK fails
to spawn any child process with `ProcessException: All pipe instances are busy`
— so the harness is launched directly, with a hand-built `package_config.json`
that redirects `package:flutter` and `package:audioplayers` to the stand-ins in
`tool/audio_harness/stubs/`.

Usage (from the project root):

    python tool/audio_harness/run.py
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
STUBS = os.path.join(HERE, "stubs")
HARNESS = os.path.join(HERE, "verify_audio.dart")
CONFIG = os.path.join(HERE, "package_config.json")

SDK = os.environ.get(
    "DART_SDK",
    r"D:\flutter\flutter_windows_3.47.1-stable\flutter\bin\cache\dart-sdk",
)
DART = os.path.join(SDK, "bin", "dart.exe")

if not os.path.exists(DART):
    print("Dart SDK not found at %s — set DART_SDK to override." % DART)
    sys.exit(2)

project_config = os.path.join(PROJECT, ".dart_tool", "package_config.json")
if not os.path.exists(project_config):
    print("Run `flutter pub get` first: %s is missing." % project_config)
    sys.exit(2)

with open(project_config, "r", encoding="utf-8") as fh:
    config = json.load(fh)

dart_tool = os.path.join(PROJECT, ".dart_tool")


def absolute(root_uri):
    if root_uri.startswith("file://"):
        return root_uri
    return "file:///" + os.path.normpath(
        os.path.join(dart_tool, root_uri)
    ).replace("\\", "/")


for package in config["packages"]:
    package["rootUri"] = absolute(package["rootUri"])

by_name = {p["name"]: p for p in config["packages"]}


def override(name, path):
    entry = {
        "name": name,
        "rootUri": "file:///" + path.replace("\\", "/"),
        "packageUri": "lib/",
        "languageVersion": "3.5",
    }
    if name in by_name:
        by_name[name].update(entry)
    else:
        config["packages"].append(entry)


override("flutter", os.path.join(STUBS, "flutter"))
override("audioplayers", os.path.join(STUBS, "audioplayers"))

with open(CONFIG, "w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=2)

result = subprocess.run(
    [DART, "--disable-dart-dev", "--packages=" + CONFIG, HARNESS],
    cwd=PROJECT,
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
)
sys.stdout.write(result.stdout)
sys.stderr.write(result.stderr)

failed = "failed: 0" not in result.stdout
sys.exit(1 if (result.returncode != 0 or failed) else 0)
