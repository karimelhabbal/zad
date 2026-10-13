"""Delimiter-balance check for Dart sources.

A stand-in for the syntax half of `dart analyze`, which cannot run in this
sandbox (the tool cannot spawn the analysis server). It strips comments and
string literals and then checks that every bracket, brace and paren is matched —
enough to catch a botched large edit, which is the realistic risk when the
analyzer is unavailable.

Usage:  python tool/check_dart_balance.py [paths...]
"""

from __future__ import annotations

import os
import sys

PAIRS = {")": "(", "]": "[", "}": "{"}
OPENERS = set("([{")


def check(path: str) -> list[str]:
    source = open(path, encoding="utf-8").read()
    errors: list[str] = []
    stack: list[tuple[str, int]] = []
    line = 1
    i = 0
    n = len(source)

    while i < n:
        ch = source[i]

        if ch == "\n":
            line += 1
            i += 1
            continue

        # Line comment
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                i += 1
            continue

        # Block comment (Dart block comments nest)
        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            depth = 1
            i += 2
            while i < n and depth:
                if source[i] == "\n":
                    line += 1
                elif source[i] == "/" and i + 1 < n and source[i + 1] == "*":
                    depth += 1
                    i += 1
                elif source[i] == "*" and i + 1 < n and source[i + 1] == "/":
                    depth -= 1
                    i += 1
                i += 1
            continue

        # String literals: ''' """ ' "
        if ch in "'\"":
            quote = ch * 3 if source.startswith(ch * 3, i) else ch
            start_line = line
            i += len(quote)
            while i < n:
                if source[i] == "\\":
                    if source[i : i + 1] == "\\" and i + 1 < n and source[i + 1] == "\n":
                        line += 1
                    i += 2
                    continue
                if source[i] == "\n":
                    line += 1
                    if len(quote) == 1:
                        break  # unterminated single-line string
                if source.startswith(quote, i):
                    i += len(quote)
                    break
                # Interpolation can contain braces — skip them wholesale.
                if source[i] == "$" and i + 1 < n and source[i + 1] == "{":
                    depth = 1
                    i += 2
                    while i < n and depth:
                        if source[i] == "\n":
                            line += 1
                        elif source[i] == "{":
                            depth += 1
                        elif source[i] == "}":
                            depth -= 1
                        i += 1
                    continue
                i += 1
            else:
                errors.append(f"line {start_line}: unterminated string literal")
            continue

        if ch in OPENERS:
            stack.append((ch, line))
            i += 1
            continue

        if ch in PAIRS:
            if not stack:
                errors.append(f"line {line}: unmatched closing '{ch}'")
            elif stack[-1][0] != PAIRS[ch]:
                opened, opened_line = stack[-1]
                errors.append(
                    f"line {line}: '{ch}' closes '{opened}' opened on line {opened_line}"
                )
                stack.pop()
            else:
                stack.pop()
            i += 1
            continue

        i += 1

    for opener, opened_line in stack:
        errors.append(f"line {opened_line}: unclosed '{opener}'")
    return errors


def main(argv: list[str]) -> int:
    targets = argv[1:]
    if not targets:
        targets = []
        for root in ("lib", "test", "tool"):
            for dirpath, _dirnames, filenames in os.walk(root):
                for name in sorted(filenames):
                    if name.endswith(".dart"):
                        targets.append(os.path.join(dirpath, name))

    failed = 0
    for path in sorted(targets):
        problems = check(path)
        if problems:
            failed += 1
            print(f"BAD  {path}")
            for problem in problems:
                print(f"       {problem}")
        else:
            print(f"OK   {path}")
    print(f"\n{len(targets) - failed}/{len(targets)} files balanced")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
