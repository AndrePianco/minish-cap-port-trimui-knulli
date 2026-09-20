#!/usr/bin/env bash
# stage-portmaster.sh <version> <path-to-PortMaster-New-checkout>
#
# Unpack dist/<version>/picori.zip into <checkout>/ports/picori/ the way the
# PortMaster-New PR wants it, then run their checker. The zip is the source
# of truth: it already carries the binary, the shim and version.txt, and
# leaves testing_thread.txt out.
set -euo pipefail
VERSION="${1:?usage: $0 <version> <PortMaster-New checkout>}"
PM="${2:?usage: $0 <version> <PortMaster-New checkout>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP="$HERE/dist/$VERSION/picori.zip"
[ -f "$ZIP" ] || { echo "no $ZIP, run ./build.sh $VERSION first" >&2; exit 1; }
[ -d "$PM/ports" ] || { echo "$PM does not look like a PortMaster-New checkout" >&2; exit 1; }

DEST="$PM/ports/picori"
rm -rf "$DEST" && mkdir -p "$DEST"
unzip -q "$ZIP" -d "$DEST"
find "$DEST" -name '.DS_Store' -delete
chmod +x "$DEST/Legend of Zelda - The Minish Cap.sh" "$DEST/picori/tmc_pc.aarch64"

# Anything over 90 MB has to be split with their tool; nothing here is, but say so.
find "$DEST" -type f -size +90M -print | sed 's/^/!! over 90 MB, run tools\/build_data.py on: /'

echo "==> staged $DEST"
( cd "$DEST" && find . -type f | sort )
echo
echo "now, in $PM:"
echo "  python3 tools/build_release.py --do-check"
