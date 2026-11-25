#!/usr/bin/env python3
"""Guards the release version so a stale Android `version/code` can never ship again.

Background: v1.1.1 shipped with `version/code=1`, identical to v1.0.0, so the APK could not
install over the previous build. Every release must strictly increase the numeric code.

Two modes:
  * consistency (default) — `project.godot`'s `config/version` matches `export_presets.cfg`'s
    `version/name`, and `version/code` is a positive integer.
  * bump check (`--prev <tag>`) — additionally asserts the current `version/code` is strictly
    greater than the `version/code` at the given previous tag (fetched from git).

Exit code 0 on success, 1 on any failure (CI friendly).
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"
PROJECT = ROOT / "project.godot"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def parse_presets(text: str) -> dict:
    """Parse the small subset of Godot export-preset keys this project uses."""
    values = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith(";"):
            continue
        if "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        value = value.strip()
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
            value = value[1:-1]
        values[key.strip()] = value
    return values


def parse_project_version(text: str):
    """Return the value of `config/version="..."` from project.godot, or None."""
    match = re.search(r'^\s*config/version\s*=\s*"([^"]*)"', text, re.MULTILINE)
    return match.group(1) if match else None


def current_values():
    presets = parse_presets(read_text(PRESETS))
    name = presets.get("version/name", "")
    code_raw = presets.get("version/code", "")
    project_version = parse_project_version(read_text(PROJECT))
    return name, code_raw, project_version


def code_at_tag(tag: str):
    result = subprocess.run(
        ["git", "show", f"{tag}:export_presets.cfg"],
        cwd=ROOT, capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"check_version: cannot read export_presets.cfg at tag {tag}: {result.stderr.strip()}")
        sys.exit(1)
    presets = parse_presets(result.stdout)
    return presets.get("version/code", "")


def fail(message: str) -> None:
    print(f"check_version: FAIL — {message}")
    sys.exit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prev", default=None,
                        help="previous release tag to compare the version code against")
    args = parser.parse_args()

    name, code_raw, project_version = current_values()

    if not name:
        fail("export_presets.cfg has no version/name")
    if not project_version:
        fail("project.godot has no config/version")
    if name != project_version:
        fail(f"version mismatch: project.godot config/version='{project_version}' but "
             f"export_presets.cfg version/name='{name}'")

    if not code_raw.isdigit() or int(code_raw) <= 0:
        fail(f"version/code must be a positive integer, got '{code_raw}'")
    current_code = int(code_raw)

    print(f"check_version: version/name={name} version/code={current_code} "
          f"(project.godot config/version={project_version})")

    if args.prev:
        prev_raw = code_at_tag(args.prev)
        if not prev_raw.isdigit():
            fail(f"previous tag {args.prev} has a non-numeric version/code '{prev_raw}'")
        prev_code = int(prev_raw)
        if current_code <= prev_code:
            fail(f"version/code did not increase: {current_code} <= {prev_code} "
                 f"(previous tag {args.prev}) — Android will refuse to install over it")
        print(f"check_version: version/code {prev_code} -> {current_code} (ok)")

    print("check_version: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
