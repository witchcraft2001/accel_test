#!/bin/sh
# run_mame.sh -- MAME "sprinter" with the DSS system disk (hard1, through a diff) and the
# ACCTEST floppy on B:.
#   run_mame.sh run  IMAGE        interactive window
#   run_mame.sh test IMAGE SYM    types B:\ACCTEST.EXE $ACC_ARGS, waits for the end, collects
#                                 build/mame/report.txt, ACCTEST.LOG and screenshots
# MAME checks the logic only: its accelerator model has no start latency, no parity
# effects and no ALU aliases.  All timing numbers are meaningful on real hardware only.
set -eu
MODE=${1:?usage: run_mame.sh run|test IMAGE [SYM]}
IMAGE=${2:?image}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
abspath() { case $1 in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$PWD" "$1" ;; esac; }
IMAGE=$(abspath "$IMAGE")
MAME_DIR=${MAME_DIR:-/Users/dmitry/dev/zx/sprinter/mame_images/mame_release_v306_25.05.2025}
MAME=${MAME:-$MAME_DIR/mame}
DSS_IMAGE=${DSS_IMAGE:-$MAME_DIR/IMG/sp_hdd_sys_0726.chd}
OUT=${ACC_OUT:-$ROOT/build/mame}
WORK=$OUT/work

COMMON="-skip_gameinfo -bios v3.06 -rompath $MAME_DIR/roms -cfg_directory $WORK/cfg -nvram_directory $WORK/nvram \
 -hard1 $DSS_IMAGE -diff_directory $WORK/diff -beta:wd179x:1 35hd -flop2 $IMAGE"

mkdir -p "$WORK/cfg" "$WORK/nvram"
rm -rf "$WORK/diff"; mkdir -p "$WORK/diff"

case $MODE in
run)
	# shellcheck disable=SC2086
	cd "$MAME_DIR" && exec "$MAME" sprinter $COMMON -window -nofilter -video opengl ${MAME_EXTRA:-}
	;;
test)
	SYM=$(abspath "${3:?symbol file}")
	rm -f "$OUT"/report.txt "$OUT"/*.png "$OUT"/ACCTEST.LOG
	# shellcheck disable=SC2086
	( cd "$MAME_DIR" && ACC_SYM="$SYM" ACC_OUT="$OUT" ACC_ARGS="${ACC_ARGS:-/A /Q /L=B:\\ACCTEST.LOG}" \
	  "$MAME" sprinter $COMMON -video none -sound none -nothrottle -snapshot_directory "$OUT" ${MAME_EXTRA:-} \
	  -autoboot_script "$ROOT/tools/mame_acctest.lua" -seconds_to_run "${SECONDS_TO_RUN:-1800}" ) >"$OUT/mame.log" 2>&1 || true
	rmdir "$OUT/sprinter" 2>/dev/null || true
	mcopy -n -i "$IMAGE" ::ACCTEST.LOG "$OUT/ACCTEST.LOG" 2>/dev/null || echo "(no ACCTEST.LOG on the image)"
	cat "$OUT/report.txt" 2>/dev/null || { echo "no report; see $OUT/mame.log"; exit 1; }
	grep -q '^RESULT: PASS' "$OUT/report.txt" && exit 0
	# Known MAME divergences (the program is right, the emulator is not):
	#  DD 49 / FD 49 / FD 5B -- the Z80 core is built with LOG_UNDOC; illegal_1() re-reads the
	#  opcode through the M1 space for its log message, and that second, unprefixed
	#  fetch of #49 or #5B switches the accelerator on.  A real Z80 has no such extra M1 cycle.
	KNOWN='^  FAIL (DD 49|FD 49|FD 5B) '
	[ -f "$OUT/ACCTEST.LOG" ] || exit 1
	grep -q '^RESULT:' "$OUT/ACCTEST.LOG" || { echo "the log has no RESULT line"; exit 1; }
	if grep '^  FAIL ' "$OUT/ACCTEST.LOG" | grep -E -v "$KNOWN"; then
		echo "RESULT (MAME): FAIL"; exit 1
	fi
	echo "RESULT (MAME): PASS -- only the known MAME divergences failed:"
	grep -E "$KNOWN" "$OUT/ACCTEST.LOG"
	;;
*)
	echo "unknown mode $MODE" >&2; exit 2 ;;
esac
