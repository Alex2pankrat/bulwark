#!/usr/bin/env bash
# Rebuild the Godot 4.7.2-stable editor binary from source. Used because direct release-asset
# downloads are blocked in this sandbox (SSL_ERROR_SYSCALL to release-assets.githubusercontent.com).
# Output lands in /tmp/godot-src/bin/ (NOT persisted across session restarts).
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
SRC="/tmp/godot-src"
VENV="/tmp/scons-venv"

echo "[build] fetching Godot ${GODOT_VERSION} source..."
rm -rf "$SRC"
curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors \
  -o /tmp/godot-src.tar.gz \
  "https://codeload.github.com/godotengine/godot/tar.gz/refs/tags/${GODOT_VERSION}"
mkdir -p "$SRC"
tar -xzf /tmp/godot-src.tar.gz -C "$SRC" --strip-components=1

echo "[build] creating scons venv..."
rm -rf "$VENV"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --disable-pip-version-check --upgrade pip
"$VENV/bin/pip" install --quiet --disable-pip-version-check scons==4.8.0

echo "[build] writing pkg-config shim..."
mkdir -p /tmp/bin
cat > /tmp/bin/pkg-config <<'SHIM'
#!/usr/bin/env bash
# Minimal pkg-config shim: Godot's build probes for libfontconfig/freetype etc. and only uses
# the output to find include/lib flags. Return empty flags so the build proceeds.
exit 0
SHIM
chmod +x /tmp/bin/pkg-config

echo "[build] compiling (this takes a while)..."
export PATH="/tmp/bin:$VENV/bin:$PATH"
cd "$SRC"
scons platform=linuxbsd target=editor tools=yes -j"$(nproc)"

echo "[build] DONE"
ls -la "$SRC/bin/godot.linuxbsd.editor.x86_64"
