; tests_vram.asm -- correctness tests in VRAM, mode 320x256 (cold).  The readback goes
; through page #50 (DRAM mirror).  Rows/columns chosen so that nothing reaches the
; descriptors (#300..) or the palette (#3E0..) of a VRAM row.

nl_vram:	dw 1,2,3,16,17,255,256,0
nl_vcol:	dw 16,17,64,0

; vt_reset: t_reset + VRAM mapping.
vt_reset:	call t_reset
		ld a,MAP_VRAM
		ld (t_map),a
		ret

; cs_vhfill: fill cur_n bytes at x = #40 + cur_p, row 20.
cs_vhfill:	call vt_reset
		ld hl,drv_fill
		ld (t_drv),hl
		ld a,#B1
		ld (t_val),a
		ld hl,(cur_n)
		ld (t_n),hl
		ld a,20
		ld (t_dy),a
		ld a,(cur_p)
		ld l,a
		ld h,#C0
		ld de,#40
		add hl,de
		ld (t_dst),hl
		ld bc,(cur_n)
		ld e,20
		ld d,1
		call sp_vrect
		jp run_case

; cs_vvfill: vertical fill of cur_n rows at x = #50 + cur_p from row 4.
cs_vvfill:	call vt_reset
		ld hl,drv_fill
		ld (t_drv),hl
		ld a,1
		ld (t_dv),a
		ld a,#B2
		ld (t_val),a
		ld hl,(cur_n)
		ld (t_n),hl
		ld a,4
		ld (t_dy),a
		ld a,(cur_p)
		ld l,a
		ld h,#C0
		ld de,#50
		add hl,de
		ld (t_dst),hl
		ld a,(cur_n)
		ld d,a				; 256 -> 0 = all rows
		ld e,4
		ld bc,1
		call sp_vrect
		jp run_case

; cs_vcopy: RAM -> VRAM, src #8100 + sp, dst x = #20 + dp, row 30.
cs_vcopy:	call vt_reset
		ld a,K_COPY
		ld (t_kind),a
		ld hl,drv_copy
		ld (t_drv),hl
		ld hl,(cur_n)
		ld (t_n),hl
		ld a,30
		ld (t_dy),a
		ld a,(cur_p)
		rrca
		rrca
		rrca
		rrca
		and 15
		ld l,a
		ld h,#81
		ld (t_src),hl
		ld de,(cur_n)
		call src_win
		ld a,(cur_p)
		and 15
		ld l,a
		ld h,#C0
		ld de,#20
		add hl,de
		ld (t_dst),hl
		ld bc,(cur_n)
		ld e,30
		ld d,1
		call sp_vrect
		jp run_case

; cs_v2v: two-phase column copy (horizontal load, LD A,A write), 3 columns.
cs_v2v:		call vt_reset
		ld a,K_COPY
		ld (t_kind),a
		ld hl,drv_copy2v
		ld (t_drv),hl
		ld a,1
		ld (t_dv),a
		ld a,3
		ld (t_w),a
		ld hl,(cur_n)
		ld (t_n),hl
		ld (t_sstr),hl			; column-major data
		ld a,140
		ld (t_dy),a
		ld hl,#8800
		ld (t_src),hl
		ld hl,(cur_n)
		ld e,l
		ld d,h
		add hl,hl
		add hl,de			; 3n
		ex de,hl
		ld hl,#8800
		call src_win
		ld a,(cur_p)
		ld l,a
		ld h,#C0
		ld de,#B0
		add hl,de
		ld (t_dst),hl
		ld a,(cur_n)
		ld d,a
		ld e,140
		ld bc,3
		call sp_vrect
		jp run_case

; vtab: table of single VRAM cases (see vcase).  Fields:
;   drv(w) kind tpat vpage dv sv w  dst(w) dy  src(w) sy sstr(w) n(w) name(w)
	MACRO VC p_drv, p_kind, p_tpat, p_vpage, p_dv, p_sv, p_w, p_dst, p_dy, p_src, p_sy, p_sstr, p_n, p_name
		dw p_drv
		db p_kind, p_tpat, p_vpage, p_dv, p_sv, p_w
		dw p_dst
		db p_dy
		dw p_src
		db p_sy
		dw p_sstr, p_n, p_name
	ENDM
VC_SIZE		equ 20

vtab:		VC drv_fill,   K_FILL, 0, VP_NORM, 0, 0, 12, #C043, 100, 0,     0,   0,   37, txv_hrect
		VC drv_fill,   K_FILL, 0, VP_NORM, 1, 0, 1,  #C060, 250, 0,     0,   0,   16, txv_vwrap
		VC drv_fill,   K_FILL, 0, VP_NORM, 1, 0, 5,  #C071, 30,  0,     0,   0,   40, txv_vrect
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 20, #C0A1, 120, #8400, 0,   40,  33, txv_spr
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 1,  #9001, 40,  #C041, 40,  0,   17, txv_v2r
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 1,  #9001, 40,  #C041, 40,  0,  256, txv_v2r
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 8,  #C151, 50,  #C011, 50,  0,  100, txv_buf
		VC drv_copy,   K_COPY, 0, VP_NORM, 1, 1, 1,  #C033, 0,   #C030, 0,   1,  256, txv_vcopy
		VC drv_vldir,  K_COPY, 0, VP_NORM, 1, 1, 4,  #C0C1, 0,   #C038, 0,   1,  256, txv_vldir
		VC drv_copy,   K_COPY, 1, VP_TRANS,0, 0, 4,  #C0E1, 160, #8A00, 0,   64,  64, txv_trans
		VC drv_fill,   K_FILL, 0, VP_NOMIR,0, 0, 1,  #C101, 170, 0,     0,   0,   32, txv_nomir
		VC drv_copy,   K_COPY, 1, VP_TRNOM,0, 0, 1,  #C121, 172, #8B00, 0,   0,   40, txv_trnom
		VC drv_logic,  K_LOGIC,0, VP_NORM, 0, 0, 1,  #C045, 190, #8C00, 0,   0,   33, txv_xor
		VC drv_fill,   K_FILL, 0, VP_NORM, 0, 0, 1,  #BFF8, 180, 0,     180, 0,   16, txv_bfill
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 1,  #BFF8, 184, #9000, 184, 0,   16, txv_bcopy
		VC drv_copy,   K_COPY, 0, VP_NORM, 0, 0, 1,  #9100, 188, #BFF8, 188, 0,   16, txv_bsrc
		dw 0

; vcase: run the table entry at HL; returns HL past it.
vcase:		push hl
		call vt_reset
		pop ix
		ld l,(ix+0)
		ld h,(ix+1)
		ld (t_drv),hl
		ld a,(ix+2)
		ld (t_kind),a
		ld a,(ix+3)
		ld (t_tpat),a
		ld a,(ix+4)
		ld (t_vpage),a
		ld a,(ix+5)
		ld (t_dv),a
		ld a,(ix+6)
		ld (t_sv),a
		ld a,(ix+7)
		ld (t_w),a
		ld l,(ix+8)
		ld h,(ix+9)
		ld (t_dst),hl
		ld a,(ix+10)
		ld (t_dy),a
		ld l,(ix+11)
		ld h,(ix+12)
		ld (t_src),hl
		ld a,(ix+13)
		ld (t_sy),a
		ld l,(ix+14)
		ld h,(ix+15)
		ld (t_sstr),hl
		ld l,(ix+16)
		ld h,(ix+17)
		ld (t_n),hl
		ld l,(ix+18)
		ld h,(ix+19)
		ld (cur_name),hl
		ld a,#B3
		ld (t_val),a
		ld a,OP_XOR_HL
		ld (t_op),a
		ld de,VC_SIZE
		add ix,de
		push ix
		; spans: destination, then source
		ld hl,(t_dst)
		ld de,#C000
		or a
		sbc hl,de
		jr nc,.dv
		; RAM destination (VRAM -> RAM, or crossing into VRAM)
		ld hl,(t_dst)
		ld de,(t_n)
		ld a,h
		cp #BF
		jr nz,.dr
		; crossing: RAM part up to #C000, VRAM part from #C000 in row t_dy
		ld de,#C000
		push hl
		ld bc,-16
		add hl,bc
		ld c,1
		xor a
		call sp_add
		pop hl
		ld de,(t_n)
		add hl,de
		ld de,#C000
		or a
		sbc hl,de			; bytes inside VRAM
		ld b,h
		ld c,l
		ld hl,#C000
		ld a,(t_dy)
		ld e,a
		ld d,1
		call sp_vrect
		jr .src
.dr:		call sp_ram
		jr .src
.dv:		ld hl,(t_dst)
		ld a,(t_dv)
		or a
		jr nz,.dvv
		ld bc,(t_n)
		ld a,(t_dy)
		ld e,a
		ld a,(t_w)
		ld d,a
		call sp_vrect
		jr .src
.dvv:		ld a,(t_w)
		ld c,a
		ld b,0
		ld a,(t_dy)
		ld e,a
		ld a,(t_n)
		ld d,a
		call sp_vrect
.src:		ld a,(t_kind)
		or a
		jr z,.run
		ld hl,(t_src)
		ld de,#C000
		or a
		sbc hl,de
		jr nc,.sv
		; RAM source: window of (w-1)*sstr + n bytes (a crossing source also gets the
		; VRAM part of its row)
		ld hl,(t_n)
		ld a,(t_w)
		dec a
		jr z,.s1
		ld b,a
		ld de,(t_sstr)
.sm:		add hl,de
		djnz .sm
.s1:		ex de,hl
		ld hl,(t_src)
		push hl
		push de
		call src_win
		pop de
		pop hl
		add hl,de
		ld a,h
		cp #C0
		jr c,.run
		ld de,#C000
		or a
		sbc hl,de
		ld b,h
		ld c,l
		ld hl,#C000
		ld a,(t_sy)
		ld e,a
		ld d,1
		call sp_vrect
		jr .run
.sv:		ld hl,(t_src)			; VRAM source (verified unchanged)
		ld a,(t_sv)
		or a
		jr nz,.svv
		ld bc,(t_n)
		ld a,(t_sy)
		ld e,a
		ld a,(t_w)
		ld d,a
		call sp_vrect
		jr .run
.svv:		ld a,(t_w)
		ld c,a
		ld b,0
		ld a,(t_sy)
		ld e,a
		ld a,(t_n)
		ld d,a
		call sp_vrect
.run:		call run_case
		call chk_abort
		pop hl
		ret

; ---------------------------------------------------------------- the VRAM section
tests_vram:	call out_nl
		PRL "== Correctness: VRAM, mode 320x256 (readback through the DRAM mirror) =="
		call gfx_enter
		jr nc,.go
		PRL "  cannot set the graphics mode: VRAM tests skipped"
		ret
.go:		ld hl,nl_vram
		ld (n_list),hl
		ld hl,txg_vhfill
		call grp_begin
		call par1
		ld hl,cs_vhfill
		call iter_np
		call grp_end
		ld hl,txg_vvfill
		call grp_begin
		call par1
		ld hl,cs_vvfill
		call iter_np
		call grp_end
		ld hl,nl_quick
		ld (n_list),hl
		ld hl,txg_vcopy
		call grp_begin
		call par2
		ld hl,cs_vcopy
		call iter_np
		call grp_end
		ld hl,nl_vcol
		ld (n_list),hl
		ld hl,txg_v2v
		call grp_begin
		call par1
		ld hl,cs_v2v
		call iter_np
		call grp_end
		ld hl,txg_vmisc
		call grp_begin
		ld hl,vtab
.vt:		ld a,(hl)
		inc hl
		or (hl)
		dec hl
		jr z,.vte
		call vcase
		jr .vt
.vte:		call grp_end
		call vram_info
		jp gfx_leave

; vram_info: PORT_Y after vertical operations (observation).
vram_info:	xor a
		call vi_probe
		PR "  INFO vertical fill of 16 rows from row 10: written rows "
		call vi_rows
		PR ", PORT_Y after: "
		call vi_mark
		PRL " (model: rows 10..25, PORT_Y 26)"
		ld a,1
		call vi_probe
		PR "  INFO LD A,A copy of 16 rows from row 10: written rows "
		call vi_rows
		PR ", first byte from source row "
		ld a,(vi_fval)
		and #7F
		ld l,a
		ld h,0
		xor a
		call out_u16
		PR ", PORT_Y after: "
		call vi_mark
		call out_nl
		PRL "         model: Y counts on through both phases: rows 26..41, PORT_Y 42"
		ld hl,(at_info)
		inc hl
		inc hl
		ld (at_info),hl
		ret
vi_rows:	ld a,(vi_first)
		call vi_num
		PR ".."
		ld a,(vi_last)
vi_num:		cp #FF
		jr z,.none
		ld l,a
		ld h,0
		xor a
		jp out_u16
.none:		PR "none"
		ret
vi_mark:	ld a,(vi_mrow)
		jr vi_num
