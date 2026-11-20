; rowscols.asm -- "rows versus columns" (cold, graphics mode).
; Each line: the same picture drawn by the accelerator row by row, column by column
; (vertical fill / two-phase LD A,A write), and by plain CPU code.  Times in us
; (one operation for full-screen lines, one rectangle otherwise); cols/rows > 1 means
; columns are slower; CPU/rows = acceleration of the row method over the CPU.

; full-screen scenarios: name, rows, columns, CPU (0 = none)
rc_full:	dw txr_clr1, sc_clr_rows, sc_clr_cols, sc_clr_cpu
		dw txr_clr2, sc_clr_rows2, sc_clr_cols, 0
		dw txr_pic, sc_pic_rows, sc_pic_cols, sc_pic_cpu
		dw txr_buf, sc_buf_rows, sc_buf_cols, sc_buf_cpu
		dw 0

; rectangles: w, h
rc_rects:	db 8,200, 200,8, 16,16, 32,32, 64,64, 128,128, 0
; rectangle methods: name, rows body, columns body, CPU body, VRAM page of the
; accelerator bodies
rc_kinds:	dw txr_fill, bd_rect_rows, bd_rect_cols, bd_rect_cpu
		db VP_NORM
		dw txr_spr, bd_spr_rows, bd_spr_cols, bd_spr_cpu
		db VP_NORM
		dw txr_sprt, bd_spr_rows, bd_spr_cols, bd_spr_cpu_t
		db VP_TRNOM
		dw 0

rows_cols:	ld a,(o_abort)
		or a
		ret nz
		call out_nl
		PRL "== Rows versus columns (us; cols/rows > 1: columns slower) =="
		PRL "  scenario                     rows us   cols us cols/rows    CPU us  CPU/rows"
		call arena_pattern
		ld ix,rc_full
.fl:		ld l,(ix+0)
		ld h,(ix+1)
		ld a,h
		or l
		jr z,.rect
		ld (cur_name),hl
		ld a,#25
		ld (sc_val),a
		ld l,(ix+2)
		ld h,(ix+3)
		call rc_full_one
		call rc_set_rows
		ld l,(ix+4)
		ld h,(ix+5)
		call rc_full_one
		call rc_set_cols
		ld l,(ix+6)
		ld h,(ix+7)
		call rc_full_one
		call rc_set_cpu
		push ix
		call rc_line
		pop ix
		ld de,8
		add ix,de
		call chk_abort
		ret c
		jr .fl
.rect:		ld hl,rc_kinds
.kl:		ld a,(hl)
		inc hl
		or (hl)
		ret z
		dec hl
		ld (rc_kind),hl
		ld hl,rc_rects
.rl:		ld a,(hl)
		or a
		jr z,.kn
		ld (bp_w),a
		inc hl
		ld a,(hl)
		ld (bp_h),a
		inc hl
		push hl
		call rc_rect
		pop hl
		call chk_abort
		ret c
		jr .rl
.kn:		ld hl,(rc_kind)
		ld de,9
		add hl,de
		jr .kl

; rc_full_one: time scenario HL (0: none) -> rc_t = us x10 (32 bit), or #FFFFFFFF.
rc_full_one:	push ix
		ld a,h
		or l
		jr z,.none
		ld a,VP_NORM
		call sc_measure
		ld hl,sc_res
		call acc_ld_mem
		ld bc,80
		call mul32x16
		ld bc,7
		call div32x16
		pop ix
		ret
.none:		ld hl,#FFFF
		ld (acc32),hl
		ld (acc32 + 2),hl
		pop ix
		ret
rc_set_rows:	ld hl,rc_rows
		jp acc_st_mem
rc_set_cols:	ld hl,rc_cols
		jp acc_st_mem
rc_set_cpu:	ld hl,rc_cpu
		jp acc_st_mem

; rc_rect: one rectangle size (bp_w, bp_h) for the method at (rc_kind).
rc_rect:	ld hl,(rc_kind)
		ld e,(hl)
		inc hl
		ld d,(hl)
		ld (cur_name),de
		ld hl,#C000 + 32
		ld (bp_hl),hl
		ld hl,#8000
		ld (bp_de),hl
		ld a,20
		ld (bp_y),a
		ld a,#6D
		ld (bp_c),a
		ld b,1
		call rc_rect_one
		call rc_set_rows
		ld b,2
		call rc_rect_one
		call rc_set_cols
		; CPU: skipped for 128 x 128 below 15 MHz (one rectangle would exceed the timer)
		ld a,(bp_w)
		cp 128
		jr nz,.cpu
		ld hl,(env_mhz)
		ld de,1500
		or a
		sbc hl,de
		jr nc,.cpu
		ld hl,#FFFF
		ld (acc32),hl
		ld (acc32 + 2),hl
		jr .cset
.cpu:		ld b,3
		call rc_rect_one
.cset:		call rc_set_cpu
		; name with the size
		ld hl,rc_name
		ld (rc_np),hl
		ld hl,(cur_name)
		call rc_cat
		ld a,' '
		call rc_cc
		ld a,(bp_w)
		call rc_dec
		ld a,'x'
		call rc_cc
		ld a,(bp_h)
		call rc_dec
		xor a
		call rc_cc
		ld hl,rc_name
		ld (cur_name),hl
		jp rc_line

; rc_rect_one: B = method (1 rows, 2 cols, 3 CPU) -> acc32 = us x10 per rectangle.
rc_rect_one:	ld hl,(rc_kind)
		ld e,b
		ld d,0
		add hl,de
		add hl,de			; body pointer at +2*B
		ld e,(hl)
		inc hl
		ld d,(hl)
		push bc
		push de
		ld hl,bm_body			; keep bp_*: clear bm_body..bm_t0 only
		ld de,bm_body + 1
		ld bc,bp_hl - bm_body - 1
		ld (hl),0
		ldir
		pop de
		pop bc
		ld (bm_body),de
		ld a,MAP_VRAM
		ld (bm_map),a
		ld a,VP_NORM
		ld (bm_vpage),a
		ld a,b
		cp 3
		jr z,.pg
		ld hl,(rc_kind)
		ld de,8
		add hl,de
		ld a,(hl)
		ld (bm_vpage),a
.pg:		call bm_measure
		ld hl,(bm_real)
		ld de,(bm_null)
		or a
		sbc hl,de
		jr nc,.p
		ld hl,0
.p:		call acc_ld_hl
		ld bc,80
		call mul32x16
		ld hl,(bm_reps)
		ld b,h
		ld c,l
		add hl,hl
		add hl,hl
		add hl,hl
		or a
		sbc hl,bc
		ld b,h
		ld c,l
		jp div32x16

rc_cat:		ld a,(hl)
		or a
		ret z
		push hl
		call rc_cc
		pop hl
		inc hl
		jr rc_cat
rc_cc:		ld hl,(rc_np)
		ld (hl),a
		inc hl
		ld (rc_np),hl
		ret
rc_dec:		ld b,'0' - 1			; A = 0..255 without leading zeros
		ld c,0
.h:		inc b
		sub 100
		jr nc,.h
		add a,100
		ld e,a
		ld a,b
		cp '0'
		jr z,.t
		call rc_cc
		ld c,1
.t:		ld a,e
		ld b,'0' - 1
.t1:		inc b
		sub 10
		jr nc,.t1
		add a,10
		ld e,a
		ld a,b
		cp '0'
		jr nz,.tp
		ld a,c
		or a
		jr z,.u
		ld a,b
.tp:		call rc_cc
.u:		ld a,e
		add a,'0'
		jp rc_cc

; rc_line: name, rows, cols, cols/rows, CPU, CPU/rows.
rc_line:	PR "  "
		ld hl,(cur_name)
		call out_str
		ld a,28
		call out_tab
		ld hl,rc_rows
		call rc_us
		ld hl,rc_cols
		call rc_us
		ld hl,rc_cols
		call rc_ratio
		ld hl,rc_cpu
		call rc_us
		ld hl,rc_cpu
		call rc_ratio
		call out_nl
		; log: machine-readable
		ld a,2
		ld (o_mode),a
		PR "C;"
		ld hl,(cur_name)
		call out_str
		PR ";"
		ld hl,rc_rows
		call rc_raw
		PR ";"
		ld hl,rc_cols
		call rc_raw
		PR ";"
		ld hl,rc_cpu
		call rc_raw
		call out_nl
		ld a,3
		ld (o_mode),a
		ret

rc_raw:		call acc_ld_mem
		ld a,(acc32 + 3)
		inc a
		ret z
		xor a
		jp out_u32

; rc_us: value at HL (us x10) with one decimal, width 10; "-" if none.
rc_us:		call acc_ld_mem
		ld a,(acc32 + 3)
		inc a
		jr z,.none
		ld a,1
		ld (o_frac),a
		ld a,10
		jp out_fix
.none:		PR "         -"
		ret

; rc_ratio: (HL) / rc_rows with two decimals, width 10.
rc_ratio:	push hl
		call acc_ld_mem
		pop hl
		ld a,(acc32 + 3)
		inc a
		jr z,.none
		ld hl,rc_rows
		ld de,arg32
		ld bc,4
		ldir
		ld a,(arg32 + 3)
		inc a
		jr z,.none
		ld hl,(arg32)
		ld a,h
		or l
		ld hl,(arg32 + 2)
		or h
		or l
		jr z,.none
		ld bc,100
		call mul32x16
		call div32x32
		ld a,2
		ld (o_frac),a
		ld a,10
		jp out_fix
.none:		PR "         -"
		ret
