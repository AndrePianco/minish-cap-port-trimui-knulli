#!/usr/bin/env bash
# Assemble the PortMaster zip.
#
#   ./build.sh 2.0.0                                   # fetch tmc_pc + shim, build dist/2.0.0/picori.zip
#   TMC_BINARY=./tmc_pc SDL3SHIM_LIB=./libSDL3.so.0 ./build.sh 2.0.0-dev
#
# tmc_pc comes from a tagged release of the fork, the SDL3-on-SDL2 shim from
# this repo's own releases (built by .github/workflows/release.yml). Neither
# binary is in git.
set -euo pipefail

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "usage: $0 <version>" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$HERE/dist"
CACHE="$HERE/.cache"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

TMC_REPO="lorencouse/tmc"
TMC_TAG="${TMC_TAG:-v0.8.3-sp8}"
TMC_ASSET="tmc-multi-linux-arm64-${TMC_TAG}.tar.gz"
TMC_SHA256="${TMC_SHA256:-b576ff723e224f87f928414c3197365364830a4d44914eba734a598fc3490877}"

SHIM_REPO="lorencouse/muos-rg35xx-sp-picori"
SHIM_TAG="${SDL3SHIM_TAG:-latest}"       # every release of this repo carries the shim
SHIM_ASSET="libSDL3.so.0"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

mkdir -p "$DIST" "$CACHE"

# tmc_pc
if [ -n "${TMC_BINARY:-}" ]; then
  cp "$TMC_BINARY" "$STAGE/tmc_pc"
else
  bin_cache="$CACHE/tmc_pc-$TMC_TAG"
  if [ ! -f "$bin_cache" ]; then
    url="https://github.com/$TMC_REPO/releases/download/$TMC_TAG/$TMC_ASSET"
    echo "==> $url"
    curl -fL --progress-bar -o "$CACHE/$TMC_ASSET" "$url"
    mkdir -p "$CACHE/x" && tar xzf "$CACHE/$TMC_ASSET" -C "$CACHE/x"
    mv "$CACHE/x/tmc_pc" "$bin_cache"
    rm -rf "$CACHE/$TMC_ASSET" "$CACHE/x"
  fi
  cp "$bin_cache" "$STAGE/tmc_pc"
fi
got="$(sha256_of "$STAGE/tmc_pc")"
# The pin belongs to the release download; a local binary is whatever it is.
if [ -z "${TMC_BINARY:-}" ] && [ -n "$TMC_SHA256" ] && [ "$got" != "$TMC_SHA256" ]; then
  echo "!! tmc_pc SHA-256 mismatch: expected $TMC_SHA256, got $got" >&2
  exit 1
fi
echo "==> tmc_pc $got"

# SDL3 shim
if [ -n "${SDL3SHIM_LIB:-}" ]; then
  cp -L "$SDL3SHIM_LIB" "$STAGE/$SHIM_ASSET"
else
  shim_cache="$CACHE/$SHIM_ASSET-$SHIM_TAG"
  if [ ! -f "$shim_cache" ]; then
    if [ "$SHIM_TAG" = latest ]; then url="https://github.com/$SHIM_REPO/releases/latest/download/$SHIM_ASSET"
    else url="https://github.com/$SHIM_REPO/releases/download/$SHIM_TAG/$SHIM_ASSET"; fi
    echo "==> $url"
    curl -fL --progress-bar -o "$shim_cache" "$url"
  fi
  cp "$shim_cache" "$STAGE/$SHIM_ASSET"
fi
echo "==> libSDL3.so.0 $(sha256_of "$STAGE/$SHIM_ASSET")"

# Stage the package
cp -R "$HERE/port/." "$STAGE/"
mkdir -p "$STAGE/picori/libs.aarch64"
mv "$STAGE/tmc_pc" "$STAGE/picori/tmc_pc.aarch64"
mv "$STAGE/$SHIM_ASSET" "$STAGE/picori/libs.aarch64/$SHIM_ASSET"
chmod +x "$STAGE/picori/tmc_pc.aarch64" "$STAGE/Legend of Zelda - The Minish Cap.sh"
printf '%s\n' "$VERSION" > "$STAGE/picori/version.txt"
cp "$STAGE/cover.png" "$STAGE/picori/cover.png"
find "$STAGE" -iname '*.gba' -delete

for f in "Legend of Zelda - The Minish Cap.sh" picori/tmc_pc.aarch64 picori/libs.aarch64/libSDL3.so.0 \
         picori/config.json picori/picori.ini port.json gameinfo.xml README.md screenshot.png cover.png \
         picori/licenses/LICENSE-picori-GPL-3.0.txt picori/licenses/LICENSE-SDL3-zlib.txt; do
  [ -e "$STAGE/$f" ] || { echo "!! missing: $f" >&2; exit 1; }
done

mkdir -p "$DIST/$VERSION"
out="$DIST/$VERSION/picori.zip"
rm -f "$out"
rm -f "$STAGE/testing_thread.txt"
( cd "$STAGE" && zip -q -r -X "$out" . -x '.DS_Store' -x '__MACOSX/*' )
echo "==> $out ($(du -h "$out" | cut -f1), sha256 $(sha256_of "$out"))"
