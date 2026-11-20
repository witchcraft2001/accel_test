; scen_hot.asm -- "rows versus columns" scenarios (hot).  Written the way a game or a
; library would write them (size latched once where it does not change).
; Full-screen scenarios run under sc_measure and call sc_mark every 16 rows/columns,
; so the 74.9 ms counter period is never exceeded even for CPU code at 3.5 MHz.
; Rectangle/sprite bodies run under bm_measure (one rectangle per repetition).
; Environment: DI, WIN2 = arena page 0 (picture/sprite data), WIN3 = VRAM.

; sc_measure: HL = scenario, A = VRAM page -> sc_res (32 bit) = min of two runs.
sc_measure:	ld (sc_fn),hl
		di
		call map_vram_a
		call sc_once
		ld hl,(tm_acc)
		ld (sc_res),hl
		ld hl,(tm_acc + 2)
		ld (sc_res + 2),hl
		call sc_once
		ld hl,(tm_acc + 2)		; keep the smaller of the two
		ld de,(sc_res + 2)
		or a
		sbc hl,de
		jr c,.take
		jr nz,.keep
		ld hl,(tm_acc)
		ld de,(sc_res)
		or a
		sbc hl,de
		jr nc,.keep
.take:		ld hl,(tm_acc)
		ld (sc_res),hl
		ld hl,(tm_acc + 2)
		ld (sc_res + 2),hl
.keep:		call unmap
		ei
		ret

sc_once:	call tm_acc_start
		ld hl,(sc_fn)
		call jp_hl
		jp tm_mark

; sc_mark: tm_mark keeping BC, DE, HL.
sc_mark:	push bc
		push de
		push hl
		call tm_mark
		pop hl
		pop de
		pop bc
		ret

; ---- clear screen (buffer 0) with colour sc_val ----
sc_clr_rows:	ld e,0				; row: 256 + 64 bytes
.row:		ld a,e
		out (P_Y),a
		ld a,(sc_val)
		ld c,a
		ld hl,#C000
		ld d,d
		ld a,0
		ld c,c
		ld (hl),c
		ld b,b
		inc h				; #C100 = x 256
		ld d,d
		ld a,64
		ld c,c
		ld (hl),c
		ld b,b
		inc e
		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

sc_clr_rows2:	ld d,d				; row: 160 + 160 bytes, size latched once
		ld a,160
		ld b,b
		ld a,(sc_val)
		ld c,a
		ld e,0
.row:		ld a,e
		out (P_Y),a
		ld hl,#C000
		ld c,c
		ld (hl),c
		ld b,b
		ld hl,#C000 + 160
		ld c,c
		ld (hl),c
		ld b,b
		inc e
		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

sc_clr_cols:	xor a				; 320 columns x 256 rows (PORT_Y wraps back)
		out (P_Y),a
		ld d,d
		ld a,0
		ld b,b
		ld a,(sc_val)
		ld c,a
		ld hl,#C000
		ld de,320
.col:		ld e,e
		ld (hl),c
		ld b,b
		inc hl
		ld a,l
		and 15
		call z,sc_mark
		dec de
		ld a,d
		or e
		jr nz,.col
		ret

sc_clr_cpu:	ld e,0				; LD (HL),A + LDIR 319 per row
.row:		ld a,e
		out (P_Y),a
		push de
		ld hl,#C000
		ld a,(sc_val)
		ld (hl),a
		ld de,#C001
		ld bc,319
		ldir
		pop de
		inc e
		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

; ---- full-screen picture from RAM: row y uses #8000 + (y & 31) * 320 ----
sc_pic_rows:	ld b,0				; B = row
		ld hl,#8000
.row:		ld a,b
		out (P_Y),a
		ld de,#C000
		ld d,d
		ld a,0
		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		inc h
		inc d
		ld d,d
		ld a,64
		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		ld de,64
		add hl,de			; HL = start + 320
		inc b
		ld a,b
		and 31
		jr nz,.nw
		ld hl,#8000
.nw:		ld a,b
		and 15
		call z,sc_mark
		ld a,b
		or a
		jr nz,.row
		ret

sc_pic_cols:	ld d,d				; column x uses #8000 + (x & 63) * 256, column-major
		ld a,0
		ld b,b
		ld hl,#8000
		ld de,#C000
		ld bc,P_Y			; B = 0: write from row 0
.col:		ld l,l
		ld a,(hl)
		ld b,b
		out (c),b
		ld a,a
		ld (de),a
		ld b,b
		inc h
		ld a,h
		cp #C0
		jr nz,.nw
		ld h,#80
.nw:		inc de
		ld a,e
		and 15
		call z,sc_mark
		ld a,d
		cp #C1
		jr nz,.col
		ld a,e
		cp #40				; x = 320
		jr nz,.col
		ret

sc_pic_cpu:	ld e,0				; LDIR 320 per row
		ld hl,#8000
.row:		ld a,e
		out (P_Y),a
		push de
		ld de,#C000
		ld bc,320
		ldir
		pop de
		inc e
		ld a,e
		and 31
		jr nz,.nw
		ld hl,#8000
.nw:		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

; ---- buffer 0 -> buffer 1 ----
sc_buf_rows:	ld e,0				; 256 + 64 per row, same PORT_Y for both phases
.row:		ld a,e
		out (P_Y),a
		push de
		ld hl,#C000
		ld de,#C000 + VBUF1
		ld d,d
		ld a,0
		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		inc h
		inc d
		ld d,d
		ld a,64
		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		pop de
		inc e
		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

sc_buf_cols:	xor a				; LD A,A + LDIR over 320 columns of 256 rows
		out (P_Y),a
		ld hl,#C000
		ld de,#C000 + VBUF1
		ld bc,320
		ld d,d
		ld a,0
		ld a,a
		ldir
		ld b,b
		ret

sc_buf_cpu:	ld e,0				; LDIR 320 per row (reads the DRAM mirror)
.row:		ld a,e
		out (P_Y),a
		push de
		ld hl,#C000
		ld de,#C000 + VBUF1
		ld bc,320
		ldir
		pop de
		inc e
		ld a,e
		and 15
		call z,sc_mark
		ld a,e
		or a
		jr nz,.row
		ret

; ---------------------------------------------------------------- rect/sprite bodies
; bp_hl = VRAM address (#C000 + x), bp_y = top row, bp_w, bp_h (1..256, 0 = 256),
; bp_c = colour, bp_de = sprite data (arena page 0).

bd_rect_rows:	ld a,(bp_w)			; h rows of a w-byte fill
		ld (.n),a
		ld d,d
		db #3E
.n:		db 0
		ld b,b
		ld a,(bp_c)
		ld c,a
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
		ld e,a
		ld hl,(bp_hl)
.lp:		ld a,e
		out (P_Y),a
		ld c,c
		ld (hl),c
		ld b,b
		inc e
		djnz .lp
		ret

bd_rect_cols:	ld a,(bp_h)			; w columns of an h-row vertical fill
		ld (.n),a
		ld d,d
		db #3E
.n:		db 0
		ld b,b
		ld a,(bp_c)
		ld c,a
		ld a,(bp_w)
		ld b,a
		ld a,(bp_y)
		ld e,a
		ld hl,(bp_hl)
.lp:		ld a,e
		out (P_Y),a
		ld e,e
		ld (hl),c
		ld b,b
		inc hl
		djnz .lp
		ret

bd_rect_cpu:	ld a,(bp_h)			; LD (HL),A + LDIR w-1 per row
		ld b,a
		ld a,(bp_y)
.lp:		out (P_Y),a
		push af
		push bc
		ld hl,(bp_hl)
		ld a,(bp_c)
		ld (hl),a
		ld d,h
		ld e,l
		inc de
		ld bc,(bp_w)
		ld b,0
		dec c
		jr z,.one
		ldir
.one:		pop bc
		pop af
		inc a
		djnz .lp
		ret

bd_spr_rows:	ld a,(bp_w)			; h row copies of w bytes, data row-major
		ld (.n),a
		ld d,d
		db #3E
.n:		db 0
		ld b,b
		ld hl,(bp_de)
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
		ld c,a
.lp:		ld a,c
		out (P_Y),a
		ld de,(bp_hl)
		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		ld de,(bp_w)
		ld d,0
		add hl,de
		inc c
		djnz .lp
		ret

bd_spr_cols:	ld a,(bp_h)			; w columns: h-byte buffer load + vertical write,
		ld (.n),a			; data column-major
		ld d,d
		db #3E
.n:		db 0
		ld b,b
		ld hl,(bp_de)
		ld de,(bp_hl)
		ld a,(bp_w)
		ld (sc_cnt),a
		ld c,P_Y
		ld a,(bp_y)
		ld b,a
.lp:		ld l,l
		ld a,(hl)
		ld b,b
		out (c),b
		ld a,a
		ld (de),a
		ld b,b
		push de
		ld de,(bp_h)
		ld d,0
		ld a,e
		or a
		jr nz,.h
		inc d				; h = 256
.h:		add hl,de
		pop de
		inc de
		ld a,(sc_cnt)
		dec a
		ld (sc_cnt),a
		jr nz,.lp
		ret

bd_spr_cpu:	ld hl,(bp_de)			; LDIR w per row
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
.lp:		out (P_Y),a
		push af
		push bc
		ld de,(bp_hl)
		ld bc,(bp_w)
		ld b,0
		ldir
		pop bc
		pop af
		inc a
		djnz .lp
		ret

bd_spr_cpu_t:	ld hl,(bp_de)			; CPU transparency: skip #FF per byte
		ld a,(bp_h)
		ld b,a
		ld a,(bp_y)
.lp:		out (P_Y),a
		push af
		push bc
		ld de,(bp_hl)
		ld a,(bp_w)
		ld b,a
.px:		ld a,(hl)
		inc a
		jr z,.sk
		dec a
		ld (de),a
.sk:		inc hl
		inc de
		djnz .px
		pop bc
		pop af
		inc a
		djnz .lp
		ret
