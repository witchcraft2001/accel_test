#!/usr/bin/env bash
# Build build/ACCTEST.EXE (sjasmplus; SAVEBIN writes the EXE with its DSS header).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v sjasmplus >/dev/null || { echo "sjasmplus not found" >&2; exit 1; }
mkdir -p "$root/build"
cd "$root/build"
sjasmplus --nologo --fullpath --lst=ACCTEST.lst --sym=ACCTEST.sym "$root/src/acctest.asm"
echo "Built $root/build/ACCTEST.EXE ($(wc -c < ACCTEST.EXE) bytes)"
