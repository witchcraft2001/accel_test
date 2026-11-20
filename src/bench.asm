; bench.asm -- micro-benchmarks (cold).
; Every line: the net cost of one operation = (time of R repetitions of the kernel) -
; (time of R repetitions of the same instruction stream with LD B,B in the mode slot,
; i.e. plain single-byte accesses), divided by R.  "cycles" are 7 MHz accelerator
; cycles (142.857 ns; 1 cycle = 3 T at 21 MHz), ns per operation, ns per byte, KB/s.
; CPU baselines subtract the empty loop instead.  "~" marks two runs differing > 1 %.

nb_full:	dw 1,2,3,4,5,6,7,8,15,16,17,31,32,33,63,64,65,127,128,129,255,256,0
nb_quick:	dw 1,2,3,16,17,64,65,255,256,0
nb_vram:	dw 1,2,3,16,17,64,65,255,256,0

; bm_clear: neutral benchmark parameters.
bm_clear:	ld hl,bm_body
		ld de,bm_body + 1
		ld bc,bp_h + 2 - bm_body - 1
		ld (hl),0
		ldir
		xor a
		ld (bm_ptype),a
		ld hl,0
		ld (bm_store),hl
		ret

; bm_patch_n: size operand of every kernel = bm_n.
bm_patch_n:	ld a,(bm_n)
		ld (k_fill.n),a
		ld (k_copy.n),a
		ld (k_logic.n),a
		ld (k_copy2v.n),a
		ret

; bm_go: measure and print one line (name cur_name, size bm_n, parity bm_ptype/bm_par).
bm_go:		ld a,(o_abort)
		or a
		ret nz
		call bm_patch_n
		call bm_measure
		call chk_abort
; bm_print: the line for the last measurement.
bm_print:	ld hl,(bm_real)
		ld de,(bm_null)
		or a
		sbc hl,de
		jr nc,.p
		ld hl,0
.p:		ld (bm_net),hl
		PR "  "
		ld hl,(cur_name)
		call out_str
		ld a,18
		call out_tab
		ld hl,(bm_n)
		ld a,4
		call out_u16
		ld a,' '
		call out_ch
		call bm_partxt
		ld a,28
		call out_tab
		; cycles x100 = net * 800 / R
		ld hl,(bm_net)
		call acc_ld_hl
		ld bc,800
		call mul32x16
		ld bc,(bm_reps)
		call div32x16
		ld hl,(acc32)
		ld (bm_c100),hl
		ld a,2
		ld (o_frac),a
		ld a,9
		call out_fix
		ld hl,(bm_store)		; keep for the summary
		ld a,h
		or l
		jr z,.ns
		ld de,(bm_c100)
		ld (hl),e
		inc hl
		ld (hl),d
		inc hl
		ld (bm_store),hl
.ns:		; ns = net * 8000 / (7 R)
		call bm_ns
		ld a,9
		call out_u32
		; ns/B x10 = ns * 10 / N
		call bm_ns
		ld bc,10
		call mul32x16
		ld bc,(bm_n)
		call div32x16
		ld a,1
		ld (o_frac),a
		ld a,8
		call out_fix
		; KB/s = N * R * 854 / net
		ld hl,(bm_net)
		ld a,h
		or l
		jr nz,.kb
		PR "       -"
		jr .sp
.kb:		ld hl,(bm_n)
		call acc_ld_hl
		ld bc,(bm_reps)
		call mul32x16
		ld bc,854
		call mul32x16
		ld bc,(bm_net)
		call div32x16
		ld a,8
		call out_u32
.sp:		; spread > 1 % of the real time
		ld hl,(bm_spread)
		call acc_ld_hl
		ld bc,100
		call mul32x16
		ld hl,(acc32 + 2)
		ld a,h
		or l
		jr nz,.mark
		ld hl,(acc32)
		ld de,(bm_real)
		or a
		sbc hl,de
		jr c,.nl
		jr z,.nl
.mark:		PR " ~"
.nl:		call out_nl
		; machine-readable line, log only
		ld a,2
		ld (o_mode),a
		PR "R;"
		ld hl,(cur_name)
		call out_str
		PR ";"
		ld hl,(bm_n)
		xor a
		call out_u16
		PR ";"
		call bm_partxt
		PR ";"
		ld hl,(bm_reps)
		xor a
		call out_u16
		PR ";"
		ld hl,(bm_real)
		xor a
		call out_u16
		PR ";"
		ld hl,(bm_null)
		xor a
		call out_u16
		call out_nl
		ld a,3
		ld (o_mode),a
		ret

bm_ns:		ld hl,(bm_net)
		call acc_ld_hl
		ld bc,8000
		call mul32x16
		ld hl,(bm_reps)
		ld b,h
		ld c,l
		add hl,hl
		add hl,hl
		add hl,hl
		or a
		sbc hl,bc			; 7 R
		ld b,h
		ld c,l
		jp div32x16

; bm_partxt: parity text: ptype 1 "a<p>", 2 "s<p>d<q>", 0 nothing.
bm_partxt:	ld a,(bm_ptype)
		or a
		ret z
		cp 1
		jr nz,.two
		ld a,'a'
		call out_ch
		ld a,(bm_par)
		jr .dig
.two:		ld a,'s'
		call out_ch
		ld a,(bm_par)
		rrca
		rrca
		rrca
		rrca
		call .dig
		ld a,'d'
		call out_ch
		ld a,(bm_par)
.dig:		and 15
		add a,'0'
		jp out_ch

bm_header:	PRL "  operation            N addr     cycles       ns    ns/B    KB/s"
		ret

; bm_iter: for every parity code of the list DE and every size of (bm_list): call HL
; (bm_par, bm_n set), which sets the parameters and calls bm_go.
bm_iter:	ld (it_fn),hl
.p:		ld a,(de)
		cp #FF
		ret z
		ld (bm_par),a
		push de
		ld hl,(bm_list)
.n:		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,d
		or e
		jr z,.pn
		ld (bm_n),de
		push hl
		ld hl,(it_fn)
		call jp_hl
		pop hl
		jr .n
.pn:		pop de
		inc de
		jr .p

; low nibble / high nibble of bm_par as offsets
par_lo:		ld a,(bm_par)
		and 15
		ld e,a
		ld d,0
		ret
par_hi:		ld a,(bm_par)
		rrca
		rrca
		rrca
		rrca
		and 15
		ld e,a
		ld d,0
		ret

; ---------------------------------------------------------------- cases
bc_fill:	call bm_keep
		ld a,MAP_ARENA
		ld (bm_map),a
		ld a,1
		ld (bm_ptype),a
		call par_lo
		ld hl,ARENA_F
		add hl,de
		ld (bp_hl),hl
		ld a,#A5
		ld (bp_c),a
		ld hl,bd_fill
		ld (bm_body),hl
		ld hl,k_fill.m
		ld (bm_patch1),hl
		ld a,OP_FILL
		ld (bm_mode1),a
		jp bm_go

bc_copy:	call bm_keep
		ld a,MAP_ARENA
		ld (bm_map),a
		ld a,2
		ld (bm_ptype),a
		call par_hi
		ld hl,ARENA_A
		add hl,de
		ld (bp_hl),hl
		call par_lo
		ld hl,ARENA_B
		add hl,de
		ld (bp_de),hl
		ld hl,bd_copy
		ld (bm_body),hl
		ld hl,k_copy.m
		ld (bm_patch1),hl
		ld a,OP_COPY
		ld (bm_mode1),a
		jp bm_go

bc_xor:		call bm_keep
		ld a,MAP_ARENA
		ld (bm_map),a
		ld a,2
		ld (bm_ptype),a
		call par_hi
		ld hl,ARENA_A
		add hl,de
		ld (bp_de),hl
		call par_lo
		ld hl,ARENA_B
		add hl,de
		ld (bp_hl),hl
		ld a,OP_XOR_HL
		ld (k_logic.op),a
		ld hl,bd_logic
		ld (bm_body),hl
		ld hl,k_logic.m
		ld (bm_patch1),hl
		ld a,OP_COPY
		ld (bm_mode1),a
		jp bm_go

; bm_keep: bm_clear keeping bm_n, bm_par, bm_store, cur_name.
bm_keep:	ld hl,(bm_n)
		push hl
		ld a,(bm_par)
		push af
		ld hl,(bm_store)
		push hl
		call bm_clear
		pop hl
		ld (bm_store),hl
		pop af
		ld (bm_par),a
		pop hl
		ld (bm_n),hl
		ret

; bb_tab: single benchmark lines.  body, patch, mode, map, vpage, hl, de, y, n, name
	MACRO BB p_body, p_patch, p_mode, p_map, p_vpage, p_hl, p_de, p_y, p_n, p_name
		dw p_body, p_patch
		db p_mode, p_map, p_vpage
		dw p_hl, p_de
		db p_y
		dw p_n, p_name
	ENDM
BB_SIZE		equ 16

bb_ram:		BB bd_fill, k_fill.m, OP_FILL, MAP_ARENA, 0, #BFF0, 0, 0, 16, txb_fillnc
		BB bd_fill, k_fill.m, OP_FILL, MAP_ARENA, 0, #BFF8, 0, 0, 16, txb_fillcr
		BB bd_fill, k_fill.m, OP_FILL, MAP_ARENA, 0, #BF80, 0, 0, 256, txb_fillcr
		BB bd_copy, k_copy.m, OP_COPY, MAP_ARENA, 0, #BFF8, #9000, 0, 16, txb_copysc
		BB bd_copy, k_copy.m, OP_COPY, MAP_ARENA, 0, #9000, #BFF8, 0, 16, txb_copydc
		BB bd_copy, k_copy.m, OP_COPY, MAP_ARENA, 0, #BF80, #9000, 0, 256, txb_copysc
		BB bd_copy, k_copy.m, OP_COPY, MAP_ARENA, 0, #9000, #BF80, 0, 256, txb_copydc
		BB bd_copy, k_copy.m, OP_COPY, MAP_ARENA, 0, #90F8, #9208, 0, 16, txb_copy256
		BB bd_cpu_ldir, 0, 0, MAP_ARENA, 0, ARENA_A, ARENA_B, 0, 256, txb_ldir
		BB bd_cpu_ldir, 0, 0, MAP_ARENA, 0, ARENA_A, ARENA_B, 0, 16, txb_ldir
		BB bd_cpu_fill, 0, 0, MAP_ARENA, 0, ARENA_F, 0, 0, 256, txb_cfill
		BB bd_cpu_fill_ldir, 0, 0, MAP_ARENA, 0, ARENA_F, 0, 0, 256, txb_cfldir
		dw 0
bb_vram:	BB bd_cpu_vline, 0, 0, MAP_VRAM, VP_NORM, #C060, 0, 0, 256, txb_cvline
		BB bd_cpu_vline, 0, 0, MAP_VRAM, VP_NORM, #C060, 0, 0, 16, txb_cvline
		BB bd_cpu_ldir, 0, 0, MAP_VRAM, VP_NORM, #8100, #C020, 30, 256, txb_cldirv
		BB bd_cpu_ldir, 0, 0, MAP_VRAM, VP_NORM, #C010, #C150, 30, 256, txb_cldirvv
		BB bd_copy, k_copy.m, OP_COPY, MAP_VRAM, VP_NORM, #BFF8, #C020, 30, 16, txb_r2vcr
		BB bd_fill, k_fill.m, OP_FILL, MAP_VRAM, VP_NORM, #BFF8, 0, 30, 16, txb_fillrv
		dw 0

; bb_run: run the table at HL.
bb_run:		ld a,(hl)
		inc hl
		or (hl)
		dec hl
		ret z
		push hl
		call bm_clear
		pop ix
		ld l,(ix+0)
		ld h,(ix+1)
		ld (bm_body),hl
		ld l,(ix+2)
		ld h,(ix+3)
		ld (bm_patch1),hl
		ld a,(ix+4)
		ld (bm_mode1),a
		ld a,(ix+5)
		ld (bm_map),a
		ld a,(ix+6)
		ld (bm_vpage),a
		ld l,(ix+7)
		ld h,(ix+8)
		ld (bp_hl),hl
		ld l,(ix+9)
		ld h,(ix+10)
		ld (bp_de),hl
		ld a,(ix+11)
		ld (bp_y),a
		ld l,(ix+12)
		ld h,(ix+13)
		ld (bm_n),hl
		ld (bp_n),hl
		ld l,(ix+14)
		ld h,(ix+15)
		ld (cur_name),hl
		ld a,#A5
		ld (bp_c),a
		ld de,BB_SIZE
		add ix,de
		push ix
		call bm_go
		pop hl
		jr bb_run

; VRAM matrices
bv_fill:	call bv_common
		call par_lo
		ld hl,#C040
		add hl,de
		ld (bp_hl),hl
		ld hl,bd_fill
		ld (bm_body),hl
		ld hl,k_fill.m
		ld (bm_patch1),hl
		ld a,OP_FILL
		ld (bm_mode1),a
		jp bm_go
bv_vfill:	call bv_common
		call par_lo
		ld hl,#C050
		add hl,de
		ld (bp_hl),hl
		ld hl,bd_vfill
		ld (bm_body),hl
		ld hl,k_fill.m
		ld (bm_patch1),hl
		ld a,OP_VFILL
		ld (bm_mode1),a
		jp bm_go
bv_copy:	call bv_common
		ld a,2
		ld (bm_ptype),a
		call par_hi
		ld hl,#8100
		add hl,de
		ld (bp_hl),hl
		call par_lo
		ld hl,#C020
		add hl,de
		ld (bp_de),hl
		ld a,30
		ld (bp_y),a
bv_copy_go:	ld hl,bd_copy
		ld (bm_body),hl
		ld hl,k_copy.m
		ld (bm_patch1),hl
		ld a,OP_COPY
		ld (bm_mode1),a
		jp bm_go
bv_v2v:		call bv_common
		ld a,2
		ld (bm_ptype),a
		call par_hi
		ld hl,#C010
		add hl,de
		ld (bp_hl),hl
		call par_lo
		ld hl,#C150
		add hl,de
		ld (bp_de),hl
		jr bv_copy_go
bv_trans:	call bv_common
		ld a,VP_TRNOM
		ld (bm_vpage),a
		ld a,2
		ld (bm_ptype),a
		call par_hi
		ld hl,#8100
		add hl,de
		ld (bp_hl),hl
		call par_lo
		ld hl,#C020
		add hl,de
		ld (bp_de),hl
		jr bv_copy_go
bv_col:		call bv_common
		call par_lo
		ld hl,#8800
		ld (bp_hl),hl
		ld hl,#C0B0
		add hl,de
		ld (bp_de),hl
		ld hl,bd_copy2v
		ld (bm_body),hl
		ld hl,k_copy2v.m1
		ld (bm_patch1),hl
		ld a,OP_COPY
		ld (bm_mode1),a
		ld hl,k_copy2v.m2
		ld (bm_patch2),hl
		ld a,OP_VCOPY
		ld (bm_mode2),a
		jp bm_go
bv_common:	call bm_keep
		ld a,MAP_VRAM
		ld (bm_map),a
		ld a,VP_NORM
		ld (bm_vpage),a
		ld a,1
		ld (bm_ptype),a
		ld a,#B4
		ld (bp_c),a
		ret

; ---------------------------------------------------------------- sections
bench_all:	call out_nl
		PRL "== Benchmarks: accelerator, net cost per operation =="
		PRL "  cycles = 7 MHz cycles (142.9 ns, 3 T at 21 MHz); a = destination addr & 3;"
		PRL "  s/d = source/destination address & 3.  Timer: CTC, 1 count = 8 cycles."
		call bm_header
		ld hl,nb_full
		ld a,(opt_quick)
		or a
		jr z,.l
		ld hl,nb_quick
.l:		ld (bm_list),hl
		ld hl,(bm_list)
		ld (sum_list),hl
		; fill RAM
		ld hl,sum_fill
		ld (bm_store),hl
		ld hl,txb_fill
		ld (cur_name),hl
		call par1
		ld hl,bc_fill
		call bm_iter
		; copy RAM
		ld hl,sum_copy
		ld (bm_store),hl
		ld hl,txb_copy
		ld (cur_name),hl
		call par2
		ld hl,bc_copy
		call bm_iter
		ld hl,0
		ld (bm_store),hl
		; XOR
		ld hl,nb_vram
		ld (bm_list),hl
		ld hl,txb_xor
		ld (cur_name),hl
		ld de,pl_xor
		ld hl,bc_xor
		call bm_iter
		; boundaries and CPU baselines
		ld hl,bb_ram
		call bb_run
		call chk_abort
		ret c
		; VRAM
		call gfx_enter
		jp c,bench_summary
		call out_nl
		PRL "== Benchmarks: VRAM (320x256) =="
		call bm_header
		ld hl,nb_vram
		ld (bm_list),hl
		ld hl,txb_vfill_h
		ld (cur_name),hl
		ld de,pl1
		ld hl,bv_fill
		call bm_iter
		ld hl,txb_r2v
		ld (cur_name),hl
		ld de,pl2
		ld hl,bv_copy
		call bm_iter
		ld hl,txb_v2v
		ld (cur_name),hl
		ld de,pl_xor
		ld hl,bv_v2v
		call bm_iter
		ld hl,txb_trans
		ld (cur_name),hl
		ld de,pl_xor
		ld hl,bv_trans
		call bm_iter
		ld hl,txb_vfill
		ld (cur_name),hl
		ld de,pl1
		ld hl,bv_vfill
		call bm_iter
		ld hl,txb_col
		ld (cur_name),hl
		ld de,pl1
		ld hl,bv_col
		call bm_iter
		ld hl,bb_vram
		call bb_run
		call gfx_leave			; show this table before the next one
		call chk_abort
		jp c,bench_summary
		call gfx_enter
		jp c,bench_summary
		call rows_cols
		call gfx_leave
		jp bench_summary

pl_xor:		db #00,#11,#FF

; ---------------------------------------------------------------- summary
; From the RAM fill/copy tables: slope (cycles per byte between N=16 and N=256),
; fixed cost (cycles at N=16 minus 16 * slope), mean penalty of odd addresses.
bench_summary:	ld a,(o_abort)
		or a
		ret nz
		call out_nl
		PRL "== Summary (RAM, cycles = 7 MHz accelerator cycles, x.xx) =="
		; index of N=16 and N=256 in the list, list length
		ld hl,(sum_list)
		ld bc,0
		ld a,#FF
		ld (sum_i16),a
		ld (sum_i256),a
.f:		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,d
		or e
		jr z,.fe
		ld a,e
		cp 16
		jr nz,.f1
		ld a,d
		or a
		jr nz,.f1
		ld a,c
		ld (sum_i16),a
.f1:		ld a,d
		dec a
		jr nz,.f2
		ld a,e
		or a
		jr nz,.f2
		ld a,c
		ld (sum_i256),a
.f2:		inc c
		jr .f
.fe:		ld a,c
		ld (sum_len),a
		; fill: rows 0 (a0) and 1 (a1)
		PR "  fill: "
		ld hl,sum_fill
		call sum_line
		PR "         odd address: "
		ld hl,sum_fill
		ld a,1
		call sum_row_ptr
		ex de,hl			; DE = row a1
		ld hl,sum_fill
		call sum_pen
		PRL " cycles per operation (mean over N)"
		; copy: rows s0d0, s0d1, s1d0, s1d1
		PR "  copy: "
		ld hl,sum_copy
		call sum_line
		ld a,(opt_four)
		or a
		ld b,1				; s0d1
		ld c,2				; s1d0
		ld d,3				; s1d1
		jr z,.cp
		ld b,1
		ld c,4
		ld d,5
.cp:		push de
		push bc
		PR "         odd destination: "
		pop bc
		push bc
		ld a,b
		call sum_pen_row
		PR ", odd source: "
		pop bc
		push bc
		ld a,c
		call sum_pen_row
		PR ", both: "
		pop bc
		pop de
		ld a,d
		call sum_pen_row
		call out_nl
		PRL "  Base firmware: 1.00 per byte (fill), 2.00 (copy), no odd penalty;"
		PRL "  a 2-byte path: ~0.50 / ~1.00 per byte, plus a cost for odd starts and sizes."
		ret

; sum_row_ptr: HL = HL + A * 2 * sum_len... (A = row index) -> HL = row pointer.
sum_row_ptr:	or a
		ret z
		ld b,a
		ld a,(sum_len)
		ld e,a
		ld d,0
		ex de,hl
		add hl,hl
		ex de,hl			; DE = row bytes
.lp:		add hl,de
		djnz .lp
		ret

; sum_line: row 0 of the table HL: "per byte x.xx, fixed x.xx (from N=16..256)"
sum_line:	ld (sum_row),hl
		ld a,(sum_i16)
		inc a
		jp z,.na
		ld a,(sum_i256)
		inc a
		jp z,.na
		ld a,(sum_i256)
		call sum_get			; HL = c(256)
		push hl
		ld a,(sum_i16)
		call sum_get			; HL = c(16)
		ld (sum_c16),hl
		pop de
		ex de,hl
		or a
		sbc hl,de			; c256 - c16 (x100, both unsigned: the sign
		call sum_signed_c		; is the borrow, not bit 15)
		ld bc,240
		call div32x16
		ld hl,(acc32)
		ld (sum_slope),hl
		PR "per byte "
		ld a,2
		ld (o_frac),a
		xor a
		call out_fix
		; fixed = c16 - 16 * slope
		ld hl,(sum_slope)
		add hl,hl
		add hl,hl
		add hl,hl
		add hl,hl
		ex de,hl
		ld hl,(sum_c16)
		or a
		sbc hl,de
		call sum_signed
		PR ", fixed "
		ld a,2
		ld (o_frac),a
		xor a
		call out_fix
		PRL " per operation (fit N=16..256)"
		ret
.na:		PRL "(needs N=16 and N=256)"
		ret

; sum_get: HL = word A of the row sum_row.
sum_get:	ld hl,(sum_row)
		ld e,a
		ld d,0
		add hl,de
		add hl,de
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		ret

; sum_signed_c: acc32 = |HL|, o_neg = CF (HL is the result of an unsigned SBC).
sum_signed_c:	jr nc,sum_signed.p
		jr sum_signed.n
; sum_signed: acc32 = |HL|, o_neg = sign.
sum_signed:	bit 7,h
		jr z,.p
.n:		ld a,1
		ld (o_neg),a
		ex de,hl
		ld hl,0
		or a
		sbc hl,de
.p:		jp acc_ld_hl

; sum_pen_row: mean(row A - row 0) of sum_copy, printed.
sum_pen_row:	ld hl,sum_copy
		call sum_row_ptr
		ex de,hl
		ld hl,sum_copy
; sum_pen: HL = row 0, DE = row k: print mean (k - 0) over sum_len entries (x.xx).
sum_pen:	ld (sp_r0),hl
		ld (sp_rk),de
		ld hl,0
		ld (sp_sum),hl
		ld a,(sum_len)
		or a
		ret z
		ld b,a
.lp:		push bc
		ld hl,(sp_r0)
		ld c,(hl)
		inc hl
		ld b,(hl)
		inc hl
		ld (sp_r0),hl
		ld hl,(sp_rk)
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld (sp_rk),hl
		ex de,hl
		or a
		sbc hl,bc
		ld de,(sp_sum)
		add hl,de
		ld (sp_sum),hl
		pop bc
		djnz .lp
		ld hl,(sp_sum)
		call sum_signed
		ld a,(sum_len)
		ld c,a
		ld b,0
		call div32x16
		ld a,2
		ld (o_frac),a
		xor a
		jp out_fix
