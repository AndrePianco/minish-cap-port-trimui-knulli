#!/usr/bin/env bash
# grab-screen.sh <outfile.png> [adb-transport-id]
#
# Capture what the SP's panel is showing, over adb. Used to produce
# screenshot.png without a capture card.
#
# /dev/fb0 is 640x960 virtual (two 640x480 pages), 32bpp BGRA, stride 2560.
# Which page is live moves, so read the current y-offset from `pan` first.
# `adb exec-out` is not supported by muOS's adb daemon -- dd to device tmpfs
# and pull.
set -uo pipefail
out="${1:?usage: grab-screen.sh <outfile.png> [adb-serial]}"

# Find the muOS device by asking each attached one who it is. Transport ids
# and serials both change across replugs; "muOS" in `uname` does not.
SER="${2:-${ADB_SERIAL:-}}"
if [ -z "$SER" ]; then
  for s in $(adb devices | awk 'NR>1 && $2=="device"{print $1}'); do
    if adb -s "$s" shell 'uname -a' 2>/dev/null | grep -qi muos; then SER="$s"; break; fi
  done
fi
if [ -z "$SER" ]; then
  echo "no muOS device found on adb (is the SP plugged in and USB Function set to ADB?)" >&2
  exit 1
fi
S="$(mktemp -d)"; trap 'rm -rf "$S"' EXIT
yoff=$(adb -s "$SER" shell 'cat /sys/class/graphics/fb0/pan' 2>/dev/null | tr -d '\r' | cut -d, -f2)
adb -s "$SER" shell "dd if=/dev/fb0 of=/tmp/fb.raw bs=2560 skip=${yoff:-0} count=480 2>/dev/null"
adb -s "$SER" pull -a /tmp/fb.raw "$S/fb.raw" >/dev/null 2>&1
if [ ! -s "$S/fb.raw" ]; then
  echo "framebuffer capture failed (empty read from /dev/fb0)" >&2
  exit 1
fi
python3 - "$S/fb.raw" "$out" <<'PY'
import zlib,struct,sys
W,H=640,480
d=open(sys.argv[1],'rb').read()
rows=[b'\x00'+bytes(b for i in range(0,2560,4) for b in (d[y*2560+i+2],d[y*2560+i+1],d[y*2560+i])) for y in range(H)]
raw=b''.join(rows)
def chunk(t,data):
    c=t+data; return struct.pack('>I',len(data))+c+struct.pack('>I',zlib.crc32(c)&0xffffffff)
open(sys.argv[2],'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
PY
adb -s "$SER" shell 'rm -f /tmp/fb.raw' 2>/dev/null
echo "$out  (device $SER, pan y=$yoff)"
