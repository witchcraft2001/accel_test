; vis_hot.asm -- primitives of the visual screens (hot).  Each one maps VRAM into WIN3
; for its own duration (DI), WIN2 stays the cold page; sprite data lives in WIN1.
; Parameters: bp_hl = #C000 + x, bp_y, bp_w, bp_h, bp_c, bp_de = data (WIN1).

; vis_call: HL = body, A = VRAM page.
vis_call:	di
		out (P_WIN3),a
		call jp_hl
		call unmap
		ei
		ret

; vc_vfill: CPU column fill, w columns x h rows.
vc_vfill:	ld a,(bp_w)
		ld b,a
		ld hl,(bp_hl)
.col:		push bc
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
		ld e,a
		ld a,(bp_c)
		ld d,a
		ld c,P_Y
.row:		out (c),e
		ld (hl),d
		inc e
		djnz .row
		pop bc
		inc hl
		djnz .col
		ret

; vc_spr_cols: CPU version of bd_spr_cols (column-major data, opaque).
vc_spr_cols:	ld hl,(bp_de)
		ld de,(bp_hl)
		ld a,(bp_w)
		ld b,a
.col:		push bc
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
		ld c,a
.row:		ld a,c
		out (P_Y),a
		ld a,(hl)
		ld (de),a
		inc hl
		inc c
		djnz .row
		pop bc
		inc de
		djnz .col
		ret

; va_xor_rows: h rows, each (dest) = (dest) XOR data row (w bytes, row-major).
va_xor_rows:	ld a,(bp_w)
		ld (k_logic.n),a
		ld a,OP_COPY
		ld (k_logic.m),a
		ld a,OP_XOR_HL
		ld (k_logic.op),a
		ld de,(bp_de)
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
.lp:		out (P_Y),a
		push af
		push bc
		push de
		ld hl,(bp_hl)
		call k_logic
		pop hl
		ld de,(bp_w)
		ld d,0
		add hl,de
		ex de,hl
		pop bc
		pop af
		inc a
		djnz .lp
		ret

vc_xor_rows:	ld hl,(bp_de)
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
.lp:		out (P_Y),a
		push af
		push bc
		ld de,(bp_hl)
		ld a,(bp_w)
		ld b,a
.px:		ld a,(de)
		xor (hl)
		ld (de),a
		inc hl
		inc de
		djnz .px
		pop bc
		pop af
		inc a
		djnz .lp
		ret

; vis_cmp: HL = number of bytes in rows 0..VIS_ROWS-1 where x differs from x + 160.
VIS_ROWS	equ 240
vis_cmp:	di
		ld a,VP_NORM
		out (P_WIN3),a
		ld de,0
		ld c,0
.row:		ld a,c
		out (P_Y),a
		ld hl,#C000
		ld b,160
.px:		ld a,(hl)
		push hl
		push bc
		ld bc,160
		add hl,bc
		cp (hl)
		pop bc
		pop hl
		jr z,.eq
		inc de
.eq:		inc hl
		djnz .px
		inc c
		ld a,c
		cp VIS_ROWS
		jr nz,.row
		call unmap
		ei
		ex de,hl
		ret

; vis_cmp_buf: HL = bytes where buffer 0 differs from buffer 1 (rows 0..VIS_ROWS-1).
vis_cmp_buf:	di
		ld a,VP_NORM
		out (P_WIN3),a
		ld de,0
		ld c,0
.row:		ld a,c
		out (P_Y),a
		ld hl,#C000
		exx
		ld hl,#C000 + VBUF1
		ld bc,320
		exx
.px:		ld a,(hl)
		exx
		cp (hl)
		jr z,.eq
		exx
		inc de
		exx
.eq:		inc hl
		dec bc
		ld a,b
		or c
		exx
		inc hl
		jr nz,.px
		inc c
		ld a,c
		cp VIS_ROWS
		jr nz,.row
		call unmap
		ei
		ex de,hl
		ret

; vis_clear: CPU clear of rows 0..255 of buffer A (0/1) with colour C.
vis_clear:	ld hl,#C000
		or a
		jr z,.b0
		ld hl,#C000 + VBUF1
.b0:		ld (bp_hl),hl
		ld a,c
		ld (bp_c),a
		ld a,64				; 320 = 5 x 64
		ld (bp_w),a
		xor a
		ld (bp_y),a
		ld (bp_h),a			; 256 rows
		ld b,5
.lp:		push bc
		ld hl,bd_rect_cpu
		ld a,VP_NORM
		call vis_call
		ld hl,(bp_hl)
		ld de,64
		add hl,de
		ld (bp_hl),hl
		pop bc
		djnz .lp
		ret

; vis_palette: RGB 3-3-2 palette for both palette pages (direct register writes).
vis_palette:	di
		ld a,VP_NORM
		out (P_WIN3),a
		ld c,0
.lp:		ld a,c
		out (P_Y),a
		and #E0				; R = bits 7..5
		ld b,a
		rrca
		rrca
		rrca
		or b
		ld b,a
		rrca
		rrca
		rrca
		and #03
		or b
		ld (#C3E0),a
		ld (#C3E4),a
		ld a,c				; G = bits 4..2
		add a,a
		add a,a
		add a,a
		and #E0
		ld b,a
		rrca
		rrca
		rrca
		or b
		ld b,a
		rrca
		rrca
		rrca
		and #03
		or b
		ld (#C3E1),a
		ld (#C3E5),a
		ld a,c				; B = bits 1..0
		and 3
		ld b,a
		rlca
		rlca
		or b
		ld b,a
		rlca
		rlca
		rlca
		rlca
		or b
		ld (#C3E2),a
		ld (#C3E6),a
		inc c
		jr nz,.lp
		call unmap
		ei
		ret

; vis_rgmod: RGMOD = A.
vis_rgmod:	out (P_RGMOD),a
		ret

; vis_hold: wait B frames (interrupts on).
vis_hold:	ei
.lp:		halt
		djnz .lp
		ret

; vi_probe: A = 0 vertical fill, 1 LD A,A copy; 16 rows from row 10.  Columns #210
; (source, row | #80), #212 (destination), #215 (marker written at the PORT_Y left by
; the operation).  Out: vi_first/vi_last = rows of #212 that changed, vi_fval = value
; in vi_first, vi_mrow = row of the marker (#FF = none).
vi_probe:	ld (vi_kind),a
		di
		ld a,VP_NORM
		out (P_WIN3),a
		ld c,0
.cl:		ld a,c
		out (P_Y),a
		or #80
		ld (#C210),a
		xor a
		ld (#C212),a
		ld (#C215),a
		inc c
		jr nz,.cl
		ld a,10
		out (P_Y),a
		ld a,16
		ld (k_fill.n),a
		ld (k_copy.n),a
		ld a,(vi_kind)
		or a
		jr nz,.cp
		ld a,OP_VFILL
		ld (k_fill.m),a
		ld hl,#C212
		ld c,#E1
		call k_fill
		jr .mk
.cp:		ld a,OP_VCOPY
		ld (k_copy.m),a
		ld hl,#C210
		ld de,#C212
		call k_copy
.mk:		ld a,#EE
		ld (#C215),a
		ld a,#FF
		ld (vi_mrow),a
		ld (vi_first),a
		ld (vi_last),a
		ld c,0
.sc:		ld a,c
		out (P_Y),a
		ld a,(#C215)
		cp #EE
		jr nz,.s1
		ld a,c
		ld (vi_mrow),a
.s1:		ld a,(#C212)
		or a
		jr z,.s2
		ld b,a
		ld a,c
		ld (vi_last),a
		ld a,(vi_first)
		inc a
		jr nz,.s2
		ld a,c
		ld (vi_first),a
		ld a,b
		ld (vi_fval),a
.s2:		inc c
		jr nz,.sc
		call unmap
		ei
		ret

; arena_pattern: arena page 0 = picture data (via WIN3, restored).
arena_pattern:	di
		ld a,(arena_p0)
		out (P_WIN3),a
		ld hl,#C000
.lp:		ld a,l
		xor h
		add a,a
		xor l
		ld (hl),a
		inc hl
		ld a,h
		or a
		jr nz,.lp
		call unmap
		ei
		ret
