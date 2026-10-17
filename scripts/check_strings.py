#!/usr/bin/env python3
"""Check that every UI string key used in Swift exists in Localizable.xcstrings.

A missing key shows up on screen as the raw key (e.g. "home.subtitle"), so this
runs in CI. Keys are recognised by their prefix; interpolations become format
specifiers the way SwiftUI builds LocalizedStringKey ("home.greeting \\(name)"
→ "home.greeting %@", Ints → "%lld").

    python3 scripts/check_strings.py
"""
import json
import os
import pathlib
import re
import sys

# Relative to the working directory: absolute paths can exceed Windows'
# 260-character limit in deeply nested folders.
ROOT = pathlib.Path(os.path.relpath(pathlib.Path(__file__).absolute().parent.parent))
CATALOG = ROOT / "Funkel/Resources/Localizable.xcstrings"
PREFIXES = "app|content|profiles?|editor|home|round|feedback|summary|color|gate|grownups|play|game|garden|sudoku|numberHouse"
LITERAL = re.compile(r'"((?:' + PREFIXES + r')\.[^"]*)"')
INTERPOLATION = re.compile(r"\\\(([^)]*\)?)\)")
# Interpolated values that are strings; everything else is assumed to be an Int.
STRING_HINTS = ("name", "answer", "title", "text")


def specifier(expr: str) -> str:
    return "%@" if any(h in expr.lower() for h in STRING_HINTS) else "%lld"


def main() -> int:
    catalog = set(json.loads(CATALOG.read_text(encoding="utf-8"))["strings"])
    used = {}
    # Both apps share the catalog: Swift (iOS) and TypeScript (web). The web
    # app passes catalog keys verbatim, e.g. t("home.greeting %@", name).
    sources = list((ROOT / "Funkel").rglob("*.swift"))
    sources += [p for p in (ROOT / "web" / "src").rglob("*.ts*")] if (ROOT / "web" / "src").exists() else []
    for path in sources:
        for match in LITERAL.finditer(path.read_text(encoding="utf-8")):
            key = INTERPOLATION.sub(lambda m: specifier(m.group(1)), match.group(1))
            if key.endswith("."):
                continue  # prefix of a runtime-built key, e.g. "color." + name
            used.setdefault(key, path.relative_to(ROOT))

    # Keys built at runtime, e.g. LocalizedStringKey("color." + key).
    dynamic = {k for k in catalog if k.startswith(("color.", "garden.item.", "editor.games.difficulty.", "game.balloons.color.", "game.balloons.name."))}

    missing = sorted(set(used) - catalog)
    unused = sorted(catalog - set(used) - dynamic)
    for key in missing:
        print(f"ERROR   missing in catalog: {key!r} (used in {used[key]})")
    for key in unused:
        print(f"warning unused catalog key: {key!r}")
    print(f"\n{len(used)} key(s) used, {len(catalog)} in catalog - {len(missing)} missing, {len(unused)} unused.")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
