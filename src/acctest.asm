; ====================================================================
;   ACCTEST.EXE -- test and benchmark of the Sprinter accelerator (DSS)
; --------------------------------------------------------------------
;   Correctness tests of every accelerator command in linear RAM (even/odd
;   addresses and sizes, 256-byte and 16K window boundaries) and in VRAM,
;   visual screens, micro-benchmarks and a "rows versus columns" study.
;   Output: screen + ACCTEST.LOG.  See README.md.
;
;   Memory map
;     #4000  EXE header (512 bytes)
;     #4200  HOT segment: entry, accelerator kernels, test runner, timer,
;            benchmark bodies, hot BSS.  Always mapped (WIN1).
;     #7C00..#7FFE  stack
;     #8000  COLD segment: UI, test lists, report, numbers, strings.  It is
;            the program's second page in WIN2.  While a test runs (DI),
;            WIN2/WIN3 hold the test arena or VRAM: cold code is never
;            called between map_* and unmap.
; ====================================================================

		DEVICE NOSLOT64K

		INCLUDE "../include/exe_header.inc"
		INCLUDE "../include/hw.inc"

	MACRO PR txt
		call out_inl
		db txt,0
	ENDM
	MACRO PRL txt
		call out_inl
		db txt,10,0
	ENDM

EXE_VERSION	equ 1
HOT_ORG		equ #4200
STACK_TOP	equ #7FFE
HOT_LIMIT	equ #7C00
COLD_ORG	equ #8000
COLD_LIMIT	equ #BC00		; cold BSS follows the cold code up to here

		ORG HOT_ORG - DSS_EXE_HEADER_SIZE
		DSS_EXE_HEADER EXE_VERSION, #0000, HOT_ORG, start, STACK_TOP

; ==================================================================== HOT
		ORG HOT_ORG
start:
		di
		ld sp,STACK_TOP
		ld hl,hot_bss			; IX (command line) survives the LDIR
		ld de,hot_bss + 1
		ld bc,hot_bss_end - hot_bss - 1
		ld (hl),0
		ldir
		ld (cmd_ix),ix
		in a,(P_WIN2)
		ld (exe_p2),a
		in a,(P_WIN3)
		ld (exe_p3),a
		ei
		; the cold segment must be the second page of the EXE in WIN2
		ld hl,cold_magic
		ld de,cold_magic_ref
		ld b,cold_magic_len
.chk:		ld a,(de)
		cp (hl)
		jr nz,.bad
		inc hl
		inc de
		djnz .chk
		jp cold_main
.bad:		ld hl,msg_nocold
		ld c,D_PCHARS
		rst DSS
		ld b,2
		ld c,D_EXIT
		rst DSS
		jr $

msg_nocold:	db 13,10,"ACCTEST: the EXE is not mapped linearly into #8000 (WIN2).",13,10,0
cold_magic_ref:	db "ACCTEST-COLD"
cold_magic_len	equ $ - cold_magic_ref

		INCLUDE "kernels.asm"
		INCLUDE "timer.asm"
		INCLUDE "runner.asm"
		INCLUDE "bench_hot.asm"
		INCLUDE "scen_hot.asm"
		INCLUDE "vis_hot.asm"
		INCLUDE "math.asm"
		INCLUDE "visual.asm"
		INCLUDE "rowscols.asm"
hot_code_end:
		INCLUDE "hot_bss.asm"
hot_end:
		ASSERT hot_end <= HOT_LIMIT
		DISPLAY "hot segment: ", /H, HOT_ORG, "..", /H, hot_end, " (code ends ", /H, hot_code_end, ")"

; ==================================================================== COLD
		ORG COLD_ORG
cold_magic:	db "ACCTEST-COLD"
		INCLUDE "main.asm"
		INCLUDE "out.asm"
		INCLUDE "tests_ram.asm"
		INCLUDE "tests_vram.asm"
		INCLUDE "bench.asm"
		INCLUDE "text.asm"
cold_end:
		INCLUDE "cold_bss.asm"
cold_bss_end:
		ASSERT cold_bss_end <= COLD_LIMIT
		DISPLAY "cold segment: ", /H, COLD_ORG, "..", /H, cold_end, " (bss ends ", /H, cold_bss_end, ")"

		SAVEBIN "ACCTEST.EXE", HOT_ORG - DSS_EXE_HEADER_SIZE, cold_end - (HOT_ORG - DSS_EXE_HEADER_SIZE)
