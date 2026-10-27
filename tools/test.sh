#!/usr/bin/env bash
# Runs every automated check. Exits non-zero on the first failure.
#   GODOT=/path/to/godot tools/test.sh
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

echo "== import (ensures .import files are up to date) =="
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== unit tests =="
"$GODOT" --headless --path . res://tests/test_core.tscn

echo "== level smoke test =="
"$GODOT" --headless --path . res://tests/smoke_level.tscn

for d in 0 1 2; do
  echo "== autoplay, difficulty $d =="
  # --fixed-fps keeps the balance numbers comparable between runs and between machines.
  "$GODOT" --headless --fixed-fps 480 --path . res://tests/autoplay.tscn -- --difficulty="$d"
done

echo "all checks passed"
