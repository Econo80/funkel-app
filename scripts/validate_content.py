#!/usr/bin/env python3
"""Validate Funkel learning content (Content/<lang>/*.json).

Mirrors the schemas in Funkel/Learning/ContentLoading/ContentFiles.swift and the
rules in PLAN.md. Runs anywhere Python 3.8+ is installed:

    python3 scripts/validate_content.py            # validate ./Content
    python3 scripts/validate_content.py path/to/Content

Exit code 0 = valid (warnings allowed), 1 = errors found.
"""
import json
import re
import sys
from pathlib import Path

MIN_AGE, MAX_AGE = 4, 14
PROVIDERS = {"maths", "wordList", "questionBank"}
MATHS_OPERATIONS = {"addition", "subtraction", "multiplication", "division"}
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
PLACEHOLDER = re.compile(r"\{(\w+)\}")

REQUIRED_PHRASES = {
    "maths": [
        "maths.symbol.plus", "maths.symbol.minus", "maths.symbol.times", "maths.symbol.divide",
        "maths.word.plus", "maths.word.minus", "maths.word.times", "maths.word.divide",
        "maths.word.equals", "maths.word.blank",
        "maths.counting", "maths.numberRecognition", "maths.equation", "maths.missingNumber",
        "maths.wordProblem",
    ],
    "wordList": [
        "vocab.pictureToWord", "vocab.wordToPicture", "vocab.meaning", "vocab.spelling",
        "vocab.spelling.spoken", "vocab.opposite", "vocab.synonym",
    ],
    "questionBank": ["sequence.build"],
}


class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def error(self, where, msg):
        self.errors.append(f"ERROR   {where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"warning {where}: {msg}")


def load(path, report):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        report.error(path, "file not found")
    except json.JSONDecodeError as e:
        report.error(path, f"invalid JSON: {e}")
    return None


def check_age(where, item, report):
    min_age = item.get("minAge")
    if not isinstance(min_age, int) or not MIN_AGE <= min_age <= MAX_AGE:
        report.error(where, f"minAge must be an int in {MIN_AGE}…{MAX_AGE}, got {min_age!r}")
        return
    max_age = item.get("maxAge")
    if max_age is not None and (not isinstance(max_age, int) or not min_age <= max_age <= MAX_AGE):
        report.error(where, f"maxAge must be an int in minAge…{MAX_AGE}, got {max_age!r}")


def nonempty_str(value):
    return isinstance(value, str) and value.strip() != ""


def validate_maths(path, data, report):
    for key in ("names", "items", "wordProblems"):
        if not isinstance(data.get(key), list) or not data[key]:
            report.error(path, f"'{key}' must be a non-empty list")
            return
    for i, item in enumerate(data["items"]):
        for key in ("singular", "plural", "emoji"):
            if not nonempty_str(item.get(key)):
                report.error(f"{path} items[{i}]", f"missing '{key}'")
    allowed = {"name", "a", "b", "item", "items"}
    for i, wp in enumerate(data["wordProblems"]):
        where = f"{path} wordProblems[{i}]"
        if wp.get("operation") not in MATHS_OPERATIONS:
            report.error(where, f"operation must be one of {sorted(MATHS_OPERATIONS)}")
        check_age(where, wp, report)
        template = wp.get("template", "")
        used = set(PLACEHOLDER.findall(template))
        if not {"a", "b"} <= used:
            report.error(where, "template must use both {a} and {b}")
        if used - allowed:
            report.error(where, f"unknown placeholders {sorted(used - allowed)}")


def validate_word_list(path, data, report):
    words = data.get("words")
    if not isinstance(words, list) or not words:
        report.error(path, "'words' must be a non-empty list")
        return
    seen = set()
    for i, w in enumerate(words):
        where = f"{path} words[{i}] ({w.get('word', '?')})"
        if not nonempty_str(w.get("word")):
            report.error(where, "missing 'word'")
            continue
        if w["word"] in seen:
            report.error(where, "duplicate word")
        seen.add(w["word"])
        check_age(where, w, report)
        if isinstance(w.get("minAge"), int) and w["minAge"] < 7 and not w.get("emoji"):
            report.warn(where, "words for under-7s should have an 'emoji' for picture matching")
        for key in ("synonyms", "antonyms"):
            if key in w and (not isinstance(w[key], list) or not all(nonempty_str(s) for s in w[key])):
                report.error(where, f"'{key}' must be a list of strings")
            if w["word"] in w.get(key, []):
                report.error(where, f"word appears in its own '{key}'")
    young = [w for w in words if isinstance(w.get("minAge"), int) and w["minAge"] <= 5 and w.get("emoji")]
    if len(young) < 4:
        report.warn(path, f"only {len(young)} picture words for age ≤ 5; picture rounds need at least 4")


def validate_question_bank(path, data, report):
    questions = data.get("questions")
    if not isinstance(questions, list) or not questions:
        report.error(path, "'questions' must be a non-empty list")
        return
    seen = set()
    for i, q in enumerate(questions):
        qid = q.get("id")
        where = f"{path} questions[{i}] ({qid})"
        if not nonempty_str(qid):
            report.error(where, "missing 'id'")
        elif qid in seen:
            report.error(where, "duplicate id")
        seen.add(qid)
        check_age(where, q, report)
        if not nonempty_str(q.get("prompt")):
            report.error(where, "missing 'prompt'")
        if "sentence" in q and "___" not in q["sentence"]:
            report.error(where, "'sentence' must contain the gap marker ___")

        fmt = q.get("format")
        if fmt == "multipleChoice":
            options = q.get("options")
            if not isinstance(options, list) or len(options) < 3:
                report.error(where, "multipleChoice needs at least 3 'options'")
                continue
            if len(set(options)) != len(options):
                report.error(where, "duplicate options")
            if q.get("correct") not in options:
                report.error(where, "'correct' must be one of 'options'")
            max_age = q.get("maxAge", MAX_AGE)
            if len(options) < 4 and isinstance(max_age, int) and max_age >= 8:
                report.warn(where, "children 8+ see 4 options; only 3 provided")
        elif fmt == "buildSequence":
            answer = q.get("answer")
            if not isinstance(answer, list) or len(answer) < 2 or not all(nonempty_str(t) for t in answer):
                report.error(where, "buildSequence needs an 'answer' list of at least 2 tiles")
            if "distractors" in q and not isinstance(q["distractors"], list):
                report.error(where, "'distractors' must be a list")
        else:
            report.error(where, f"unknown format {fmt!r} (multipleChoice | buildSequence)")


VALIDATORS = {"maths": validate_maths, "wordList": validate_word_list, "questionBank": validate_question_bank}


def validate_language(folder, report):
    manifest_path = folder / "manifest.json"
    manifest = load(manifest_path, report)
    if manifest is None:
        return
    for key in ("code", "name", "speechLocale", "subjects"):
        if key not in manifest:
            report.error(manifest_path, f"missing '{key}'")
    if manifest.get("code") != folder.name:
        report.error(manifest_path, f"code {manifest.get('code')!r} must match folder name {folder.name!r}")

    phrasing = load(folder / "strings.json", report) or {}
    ids = set()
    for i, s in enumerate(manifest.get("subjects", [])):
        where = f"{manifest_path} subjects[{i}] ({s.get('id', '?')})"
        for key in ("id", "provider", "file", "title"):
            if not nonempty_str(s.get(key)):
                report.error(where, f"missing '{key}'")
        if s.get("id") in ids:
            report.error(where, "duplicate subject id")
        ids.add(s.get("id"))
        if "color" in s and not HEX.match(str(s["color"])):
            report.error(where, "color must look like #RRGGBB")
        provider = s.get("provider")
        if provider not in PROVIDERS:
            report.warn(where, f"provider {provider!r} unknown to this app version; subject will be hidden")
            continue
        for key in REQUIRED_PHRASES[provider]:
            if key not in phrasing:
                report.error(folder / "strings.json", f"missing phrase '{key}' (needed by {provider})")
        content_path = folder / s.get("file", "")
        data = load(content_path, report)
        if data is not None:
            VALIDATORS[provider](content_path, data, report)


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "Content"
    report = Report()
    languages = sorted(p for p in root.iterdir() if p.is_dir() and (p / "manifest.json").exists())
    if not languages:
        report.error(root, "no language folders with a manifest.json")
    for folder in languages:
        validate_language(folder, report)

    for line in report.warnings + report.errors:
        print(line)
    print(f"\nChecked {len(languages)} language(s): {', '.join(p.name for p in languages)} - "
          f"{len(report.errors)} error(s), {len(report.warnings)} warning(s).")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
