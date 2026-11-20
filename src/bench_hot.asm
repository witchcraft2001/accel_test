; bench_hot.asm -- micro-benchmark framework (hot).
;
; bm_measure: one configuration.  Inputs: bm_body (routine run per repetition, reads
; bp_* itself), bm_map (MAP_*), bm_vpage (VRAM page for MAP_VRAM), bm_patch1/bm_mode1
; and bm_patch2/bm_mode2 (mode bytes; patch = 0: unused).  The null run uses the same
; body with OP_OFF in the mode bytes, or bd_nop when bm_patch1 = 0 (CPU baselines).
; Outputs: bm_reps, bm_real, bm_null (counts for bm_reps repetitions, minimum of two
; runs each), bm_spread (counts between the two real runs).
BM_TARGET	equ 12000		; counts per run (~13.7 ms)
BM_MAXREPS	equ 4096

bm_measure:	di
		call bm_map_pages
		call bm_set_real
		ld hl,1
		ld (bm_reps),hl
		call bm_run			; calibration: one repetition
		ld a,h
		or l
		jr nz,.t
		inc hl
.t:		; reps = largest power of 2 <= BM_TARGET / t, at most BM_MAXREPS
		ld de,BM_MAXREPS
.rc:		push hl
		push de
		call mul16			; HL*DE -> DEHL
		ld a,d
		or e
		jr nz,.big
		ld de,BM_TARGET + 1
		or a
		sbc hl,de
		jr c,.ok
.big:		pop de
		pop hl
		srl d
		rr e
		ld a,d
		or e
		jr nz,.rc
		ld de,1
		push hl
		push de
.ok:		pop de
		pop hl
		ld (bm_reps),de
		call bm_run
		ld (bm_real),hl
		call bm_run
		ld de,(bm_real)
		call min_spread
		ld (bm_real),hl
		ld (bm_spread),de
		call bm_set_null
		call bm_run
		ld (bm_null),hl
		call bm_run
		ld de,(bm_null)
		call min_spread
		ld (bm_null),hl
		call bm_set_real
		call unmap
		ei
		ret

; min_spread: HL = min(HL, DE), DE = |HL - DE|.
min_spread:	push hl
		or a
		sbc hl,de
		jr nc,.de_min
		; HL < DE
		ex de,hl			; DE = HL - DE (negative)
		ld hl,0
		or a
		sbc hl,de
		ex de,hl			; DE = |diff|
		pop hl
		ret
.de_min:	ex de,hl			; HL = old DE, DE = diff
		pop af				; drop
		ret

; mul16: DEHL = HL * DE (unsigned).  Clobbers AF, BC.
mul16:		ld b,h
		ld c,l
		ld hl,0
		ld a,16
.lp:		add hl,hl
		rl e
		rl d
		jr nc,.n
		add hl,bc
		jr nc,.n
		inc de
.n:		dec a
		jr nz,.lp
		ret

bm_map_pages:	ld a,(bm_map)
		or a
		ret z
		cp MAP_VRAM
		jr z,.v
		jp map_arena
.v:		ld a,(bm_vpage)
		jp map_vram_a

bm_set_real:	ld hl,(bm_patch1)
		ld a,h
		or l
		jr z,.cpu
		ld a,(bm_mode1)
		ld (hl),a
		ld hl,(bm_patch2)
		ld a,h
		or l
		ret z
		ld a,(bm_mode2)
		ld (hl),a
		ret
.cpu:		ld hl,(bm_body)
		ld (bm_cur),hl
		ret

bm_set_null:	ld hl,(bm_patch1)
		ld a,h
		or l
		jr z,.cpu
		ld (hl),OP_OFF
		ld hl,(bm_patch2)
		ld a,h
		or l
		ret z
		ld (hl),OP_OFF
		ret
.cpu:		ld hl,bd_nop
		ld (bm_cur),hl
		ret

; bm_run: HL = counts for bm_reps calls of the body.
bm_run:		ld hl,(bm_patch1)		; accelerator bodies always run bm_body
		ld a,h
		or l
		jr z,.c
		ld hl,(bm_body)
		ld (bm_cur),hl
.c:		call tm_now
		ld (bm_t0),hl
		ld bc,(bm_reps)
.lp:		push bc
		ld hl,.ret
		push hl
		ld hl,(bm_cur)
		jp (hl)
.ret:		pop bc
		dec bc
		ld a,b
		or c
		jr nz,.lp
		call tm_now
		ld de,(bm_t0)
		or a
		sbc hl,de
		ret

; ---------------------------------------------------------------- bodies
bd_nop:		ret

bd_fill:	ld hl,(bp_hl)
		ld a,(bp_c)
		ld c,a
		jp k_fill

bd_vfill:	ld a,(bp_y)
		out (P_Y),a
		ld hl,(bp_hl)
		ld a,(bp_c)
		ld c,a
		jp k_fill

bd_copy:	ld a,(bp_y)
		out (P_Y),a
		ld hl,(bp_hl)
		ld de,(bp_de)
		jp k_copy

bd_logic:	ld hl,(bp_hl)			; destination
		ld de,(bp_de)			; source
		jp k_logic

bd_copy2v:	ld hl,(bp_hl)
		ld de,(bp_de)
		ld a,(bp_y)
		ld b,a
		ld c,P_Y
		jp k_copy2v

; CPU baselines (bp_n bytes, 1..256 for the loops)
bd_cpu_ldir:	ld a,(bp_y)
		out (P_Y),a
		ld hl,(bp_hl)
		ld de,(bp_de)
		ld bc,(bp_n)
		ldir
		ret

bd_cpu_fill:	ld hl,(bp_hl)			; LD (HL),A / INC HL / DJNZ
		ld a,(bp_n)
		ld b,a
		ld a,(bp_c)
.lp:		ld (hl),a
		inc hl
		djnz .lp
		ret

bd_cpu_fill_ldir:			; LD (HL),A + LDIR (bp_n >= 2)
		ld hl,(bp_hl)
		ld a,(bp_c)
		ld (hl),a
		ld d,h
		ld e,l
		inc de
		ld bc,(bp_n)
		dec bc
		ldir
		ret

bd_cpu_vline:	ld hl,(bp_hl)			; one byte per row: OUT (#89) + LD (HL),A
		ld a,(bp_n)
		ld b,a
		ld a,(bp_y)
		ld e,a
		ld a,(bp_c)
		ld d,a
		ld c,P_Y
.lp:		out (c),e
		ld (hl),d
		inc e
		djnz .lp
		ret
