#!/usr/bin/env bash
# Builds every distributable into build/ (web also copied to release/web).
#   tools/build.sh [linux|windows|web|android]   (no argument = all four)
# Android needs JAVA_HOME, ANDROID_HOME and a keystore in the environment:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
set -euo pipefail

GODOT="${GODOT:-godot}"
TARGET="${1:-all}"
cd "$(dirname "$0")/.."

mkdir -p build/{linux,windows,web,android} release

build() {  # preset, output, extra-args...
  local preset="$1" out="$2"; shift 2
  echo "== $preset -> $out =="
  "$GODOT" --headless --path . --export-release "$preset" "$out" "$@"
}

if [[ "$TARGET" == all || "$TARGET" == linux ]]; then
  build Linux build/linux/bulwark.x86_64
fi
if [[ "$TARGET" == all || "$TARGET" == windows ]]; then
  build Windows build/windows/bulwark.exe
fi
if [[ "$TARGET" == all || "$TARGET" == web ]]; then
  build Web build/web/index.html
  rm -rf release/web && mkdir -p release/web
  cp build/web/* release/web/
  echo "   web build copied to release/web (serve it with tools/serve_web.py)"
fi
if [[ "$TARGET" == all || "$TARGET" == android ]]; then
  build Android build/android/bulwark.apk
  cp build/android/bulwark.apk release/bulwark-1.0.0-android.apk
  echo "   signed APK copied to release/bulwark-1.0.0-android.apk"
fi

echo "done"
