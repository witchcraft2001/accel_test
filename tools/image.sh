#!/usr/bin/env bash
# FAT12 1.44M floppy image with ACCTEST.EXE for MAME (drive B:).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exe="${1:-$root/build/ACCTEST.EXE}"
img="${2:-$root/build/acctest.img}"
command -v mformat >/dev/null && command -v mcopy >/dev/null || { echo "mtools required" >&2; exit 1; }
[ -f "$exe" ] || "$root/tools/build.sh"
rm -f "$img"
mformat -C -i "$img" -f 1440 ::
mcopy -i "$img" -o "$exe" ::ACCTEST.EXE
echo "Built $img"
