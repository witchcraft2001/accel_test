; tests_ram.asm -- correctness tests in linear RAM (cold) + helpers shared with VRAM.

ARENA_A		equ #8800		; source area (arena page 0)
ARENA_B		equ #9800		; destination area (arena page 0)
ARENA_F		equ #9100		; fill area

; ---------------------------------------------------------------- helpers
; t_reset: empty descriptor, one repetition, arena mapping, plain VRAM page.
t_reset:	ld hl,t_blk
		ld de,t_blk + 1
		ld bc,t_blk_end - t_blk - 1
		ld (hl),0
		ldir
		ld a,1
		ld (t_w),a
		ld a,VP_NORM
		ld (t_vpage),a
		ld a,MAP_ARENA
		ld (t_map),a
		ret

; sp_add: add span (A = y, C = rows, HL = lo, DE = hi).
sp_add:		push hl
		push de
		push af
		ld a,(t_nsp)
		cp MAX_SPANS
		jr nc,.full
		ld l,a
		inc a
		ld (t_nsp),a
		ld h,0
		ld d,h
		ld e,l
		add hl,hl
		add hl,de
		add hl,hl			; *6
		ld de,t_spans
		add hl,de
		pop af
		ld (hl),a
		inc hl
		ld (hl),c
		inc hl
		pop de
		ex (sp),hl			; HL = lo, (sp) = pointer
		ex de,hl			; DE = lo, HL = hi
		ex (sp),hl			; HL = pointer, (sp) = hi
		ld (hl),e
		inc hl
		ld (hl),d
		inc hl
		pop de
		ld (hl),e
		inc hl
		ld (hl),d
		ret
.full:		pop af
		pop de
		pop hl
		ret

; sp_ram: RAM span [HL - 16, HL + DE + 16).
sp_ram:		push hl
		add hl,de
		ld de,16
		add hl,de
		ex de,hl			; DE = hi
		pop hl
		push de
		ld de,-16
		add hl,de			; HL = lo
		pop de
		xor a
		ld c,1
		jp sp_add

; src_win: source window [HL - 16, HL + DE + 16) (background bgS) + its span.
src_win:	push hl
		push de
		ld bc,-16
		add hl,bc
		ld (t_slo),hl
		ex de,hl
		ld bc,32
		add hl,bc
		ld (t_slen),hl
		pop de
		pop hl
		jr sp_ram

; sp_vrect: VRAM span around a rectangle.  HL = #C000 + x, E = top row, BC = width
; (bytes), D = rows (0 = 256).  Margins: 4 bytes, 2 rows; x clamped to #000..#27F.
sp_vrect:	ld (sv_lo),hl
		ld (sv_y),de			; sv_y = top, sv_y + 1 = rows
		add hl,bc
		ld bc,4
		add hl,bc
		ld bc,#C280
		or a
		sbc hl,bc
		jr c,.h1
		ld hl,0
.h1:		add hl,bc
		ld (sv_hi),hl
		ld hl,(sv_lo)
		ld bc,-4
		add hl,bc
		ld a,h
		cp #C0
		jr nc,.l1
		ld hl,#C000
.l1:		ld (sv_lo),hl
		ld a,(sv_y + 1)
		or a
		jr z,.all
		cp 252
		jr nc,.all
		add a,4
		ld c,a
		ld a,(sv_y)
		sub 2
		jr .add
.all:		ld c,0
		xor a
.add:		ld hl,(sv_lo)
		ld de,(sv_hi)
		jp sp_add

; ---------------------------------------------------------------- running and reporting
; grp_begin: HL = group name.
grp_begin:	ld (grp_name),hl
		ld (cur_name),hl
		ld hl,0
		ld (grp_pass),hl
		ld (grp_fail),hl
		ret

; grp_end: "  name ........ passed/total OK|FAIL".
grp_end:	ld hl,(grp_pass)
		ld de,(grp_fail)
		ld a,h
		or l
		or d
		or e
		ret z				; nothing ran (aborted)
		PR "  "
		ld hl,(grp_name)
		call out_str
		ld a,44
		call out_tab
		ld hl,(grp_pass)
		ld a,4
		call out_u16
		PR " /"
		ld hl,(grp_pass)
		ld de,(grp_fail)
		add hl,de
		ld a,4
		call out_u16
		ld hl,(grp_fail)
		ld a,h
		or l
		jr nz,.f
		PRL "  OK"
		ret
.f:		PRL "  FAIL"
		ret

; run_case: run the current descriptor and count/report the result.
run_case:	ld a,(o_abort)
		or a
		ret nz
		call t_run
		push af
		ld a,(t_info)
		or a
		jr nz,.info
		pop af
		jr nz,.fail
		ld hl,(at_pass)
		inc hl
		ld (at_pass),hl
		ld hl,(grp_pass)
		inc hl
		ld (grp_pass),hl
		ret
.fail:		ld hl,(at_fail)
		inc hl
		ld (at_fail),hl
		ld hl,(grp_fail)
		inc hl
		ld (grp_fail),hl
		PR "  FAIL "
		call case_desc
		jp case_bad
.info:		pop af
		ld hl,(at_info)
		inc hl
		ld (at_info),hl
		push af
		PR "  INFO "
		call case_desc
		pop af
		jp nz,case_bad
		PRL ": as modelled"
		ret

; case_desc: name n=.. dst=.. src=.. [y=..]
case_desc:	ld hl,(cur_name)
		call out_str
		PR " n="
		ld hl,(t_n)
		xor a
		call out_u16
		ld a,(t_w)
		cp 1
		jr z,.w1
		PR " w="
		ld a,(t_w)
		ld l,a
		ld h,0
		xor a
		call out_u16
.w1:		PR " dst="
		ld hl,(t_dst)
		call out_hex16
		ld a,(t_kind)
		or a
		jr z,.ns
		PR " src="
		ld hl,(t_src)
		call out_hex16
.ns:		ld a,(t_map)
		cp MAP_VRAM
		ret nz
		PR " y="
		ld a,(t_dy)
		ld l,a
		ld h,0
		xor a
		jp out_u16

; case_bad: ": N bad, first #addr [y] exp #xx got #xx"
case_bad:	PR ": "
		ld hl,(r_bad)
		xor a
		call out_u16
		PR " bad, first "
		ld hl,(r_addr)
		call out_hex16
		ld a,(t_map)
		cp MAP_VRAM
		jr nz,.ny
		ld hl,(r_addr)
		ld a,h
		cp #C0
		jr c,.ny
		PR " y="
		ld a,(r_y)
		ld l,a
		ld h,0
		xor a
		call out_u16
.ny:		PR " exp "
		ld a,(r_exp)
		call out_hexb
		PR " got "
		ld a,(r_got)
		call out_hexb
		jp out_nl

; iter_np: call HL for every parity code of the list at DE (#FF-terminated) and every
; size of (n_list) (0-terminated words).  cur_p, cur_n are set for the callee.
iter_np:	ld (it_fn),hl
.p:		ld a,(de)
		cp #FF
		ret z
		ld (cur_p),a
		push de
		ld hl,(n_list)
.n:		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,d
		or e
		jr z,.pn
		ld (cur_n),de
		push hl
		ld hl,(it_fn)
		call jp_hl
		call chk_abort
		pop hl
		jr .n
.pn:		pop de
		inc de
		jr .p

; set_lists: n_list = full or quick list, parity lists by /4.
set_nlist:	ld hl,nl_full
		ld a,(opt_quick)
		or a
		jr z,.s
		ld hl,nl_quick
.s:		ld (n_list),hl
		ret

par1:		ld de,pl1
		ld a,(opt_four)
		or a
		ret z
		ld de,pl1x
		ret
par2:		ld de,pl2
		ld a,(opt_four)
		or a
		ret z
		ld de,pl2x
		ret

nl_full:	dw 1,2,3,4,5,15,16,17,127,128,129,255,256,0
nl_quick:	dw 1,2,3,16,17,255,256,0
nl_logic:	dw 1,2,3,16,17,255,256,0
pl1:		db 0,1,#FF
pl1x:		db 0,1,2,3,#FF
pl2:		db #00,#01,#10,#11,#FF
pl2x:		db #00,#01,#02,#03,#10,#11,#12,#13,#20,#21,#22,#23,#30,#31,#32,#33,#FF

; ---------------------------------------------------------------- cases
; cs_fill: fill cur_n bytes at ARENA_F + cur_p.
cs_fill:	call t_reset
		ld hl,drv_fill
		ld (t_drv),hl
		ld a,#A5
		ld (t_val),a
		ld hl,(cur_n)
		ld (t_n),hl
		ld a,(cur_p)
		ld l,a
		ld h,0
		ld de,ARENA_F
		add hl,de
		ld (t_dst),hl
		ld de,(cur_n)
		call sp_ram
		jp run_case

; cs_copy_setup: src = ARENA_A + (cur_p >> 4), dst = ARENA_B + (cur_p & 15).
cs_copy_setup:	call t_reset
		ld hl,(cur_n)
		ld (t_n),hl
		ld a,K_COPY
		ld (t_kind),a
		ld a,(cur_p)
		rrca
		rrca
		rrca
		rrca
		and 15
		ld l,a
		ld h,0
		ld de,ARENA_A
		add hl,de
		ld (t_src),hl
		ld de,(cur_n)
		call src_win
		ld a,(cur_p)
		and 15
		ld l,a
		ld h,0
		ld de,ARENA_B
		add hl,de
		ld (t_dst),hl
		ld de,(cur_n)
		jp sp_ram

cs_copy:	call cs_copy_setup
		ld hl,drv_copy
		ld (t_drv),hl
		jp run_case

cs_logic:	call cs_copy_setup
		ld a,K_LOGIC
		ld (t_kind),a
		ld a,(cur_op)
		ld (t_op),a
		ld hl,drv_logic
		ld (t_drv),hl
		jp run_case

cs_xor2:	call cs_copy_setup
		ld a,K_NONE
		ld (t_kind),a
		ld a,OP_XOR_HL
		ld (t_op),a
		ld hl,drv_xor2
		ld (t_drv),hl
		jp run_case

; tab_case: run the table at HL: kind, dst (w), src (w), n (w); kind #FF ends.
tab_case:	ld a,(hl)
		cp #FF
		ret z
		push hl
		call t_reset
		pop hl
		ld a,(hl)
		ld (t_kind),a
		inc hl
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld (t_dst),de
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld (t_src),de
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld (t_n),de
		push hl
		ld a,#A5
		ld (t_val),a
		ld hl,drv_fill
		ld a,(t_kind)
		or a
		jr z,.f
		ld hl,(t_src)
		ld de,(t_n)
		call src_win
		ld hl,drv_copy
.f:		ld (t_drv),hl
		ld hl,(t_dst)
		ld de,(t_n)
		call sp_ram
		call run_case
		call chk_abort
		pop hl
		jr tab_case

	MACRO TC p_kind, p_dst, p_src, p_n
		db p_kind
		dw p_dst, p_src, p_n
	ENDM

tab_bound:	; 256-byte and window (#BFFF/#C000) boundaries
		TC K_FILL, #90FF, 0, 2
		TC K_FILL, #90FE, 0, 3
		TC K_FILL, #9080, 0, 256
		TC K_FILL, #9081, 0, 256
		TC K_FILL, #BFFF, 0, 2
		TC K_FILL, #BFFE, 0, 2
		TC K_FILL, #BFFE, 0, 3
		TC K_FILL, #BFF0, 0, 16
		TC K_FILL, #BFF1, 0, 16
		TC K_FILL, #BF80, 0, 256
		TC K_FILL, #BF81, 0, 255
		TC K_FILL, #BF7F, 0, 256
		TC K_COPY, #9208, #90F8, 16
		TC K_COPY, #9209, #90F9, 255
		TC K_COPY, #9000, #BFF8, 16
		TC K_COPY, #9001, #BF81, 255
		TC K_COPY, #9000, #BF7F, 256
		TC K_COPY, #BFF8, #9000, 16
		TC K_COPY, #BF81, #9001, 255
		TC K_COPY, #BF80, #9000, 256
		TC K_COPY, #BFF8, #BFF0, 16
		db #FF

tab_overlap:	; the whole block is read before it is written: memmove semantics
		TC K_COPY, #9001, #9000, 64
		TC K_COPY, #9002, #9000, 64
		TC K_COPY, #9000, #9001, 64
		TC K_COPY, #9000, #9002, 64
		TC K_COPY, #9000, #9000, 64
		TC K_COPY, #9040, #9000, 128
		TC K_COPY, #9000, #9041, 128
		db #FF

; ---------------------------------------------------------------- the RAM section
tests_ram:	call out_nl
		PRL "== Correctness: linear RAM (arena pages in WIN2/WIN3) =="
		call set_nlist
		ld hl,txg_fill
		call grp_begin
		call par1
		ld hl,cs_fill
		call iter_np
		call grp_end
		ld hl,txg_copy
		call grp_begin
		call par2
		ld hl,cs_copy
		call iter_np
		call grp_end
		ld hl,txg_bound
		call grp_begin
		ld hl,tab_bound
		call tab_case
		call grp_end
		ld hl,txg_overlap
		call grp_begin
		ld hl,tab_overlap
		call tab_case
		call grp_end
		call tests_count
		ld hl,nl_logic
		ld (n_list),hl
		ld a,OP_XOR_HL
		ld hl,txg_xor
		call logic_grp
		ld a,OP_OR_HL
		ld hl,txg_or
		call logic_grp
		ld a,OP_AND_HL
		ld hl,txg_and
		call logic_grp
		ld hl,txg_xor2
		call grp_begin
		ld de,pl2
		ld hl,cs_xor2
		call iter_np
		call grp_end
		call tests_vram_in_ram
		call tests_decoder
		call tests_info
		ret

logic_grp:	ld (cur_op),a
		call grp_begin
		call par2
		ld hl,cs_logic
		call iter_np
		jp grp_end

; size handling: 0 = 256 is in the matrices; here: the size persists, one load
; written three times.
tests_count:	ld hl,txg_count
		call grp_begin
		ld hl,txc_persist
		ld (cur_name),hl
		ld de,17
		call .persist
		ld de,256
		call .persist
		ld hl,txc_rw3
		ld (cur_name),hl
		call t_reset
		ld a,K_COPY
		ld (t_kind),a
		ld hl,drv_rw3
		ld (t_drv),hl
		ld hl,33
		ld (t_n),hl
		ld a,3
		ld (t_w),a
		ld hl,#100
		ld (t_dstr),hl
		ld hl,ARENA_A + 1
		ld (t_src),hl
		ld de,33
		call src_win
		ld hl,ARENA_B
		ld (t_dst),hl
		ld b,3
.w:		push bc
		push hl
		ld de,33
		call sp_ram
		pop hl
		inc h
		pop bc
		djnz .w
		call run_case
		jp grp_end
.persist:	push de
		call t_reset
		pop de
		ld (t_n),de
		ld hl,drv_persist
		ld (t_drv),hl
		ld a,#A5
		ld (t_val),a
		ld hl,ARENA_F + 1
		ld (t_dst),hl
		call sp_ram
		jp run_case

; vertical modes on plain RAM: the address does not move, one byte changes.
tests_vram_in_ram:
		ld hl,txg_vert
		call grp_begin
		ld hl,txc_vfill
		ld (cur_name),hl
		call t_reset
		ld hl,drv_fill
		ld (t_drv),hl
		ld a,1
		ld (t_dv),a
		ld a,#A5
		ld (t_val),a
		ld hl,16
		ld (t_n),hl
		ld hl,ARENA_F + 1
		ld (t_dst),hl
		ld de,16
		call sp_ram
		call run_case
		ld hl,txc_vcopy
		ld (cur_name),hl
		call t_reset
		ld a,K_COPY
		ld (t_kind),a
		ld hl,drv_copy
		ld (t_drv),hl
		ld a,1
		ld (t_dv),a
		ld (t_sv),a
		ld hl,16
		ld (t_n),hl
		ld hl,ARENA_A + 1
		ld (t_src),hl
		ld de,16
		call src_win
		ld hl,ARENA_B + 1
		ld (t_dst),hl
		ld de,16
		call sp_ram
		call run_case
		jp grp_end

; decoder: prefixed and operand copies of the mode opcodes, HALT (WIN1 scratch).
SCR_D		equ scratch + #100
SCR_S		equ scratch + #300

tests_decoder:	ld hl,txg_dec
		call grp_begin
		ld hl,tab_dec
.lp:		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,d
		or e
		jp z,grp_end
		ld (t_aux2_tmp),de		; probe
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld (cur_name),de
		ld a,(hl)			; expected size
		inc hl
		ld c,(hl)			; kind
		inc hl
		push hl
		push af
		push bc
		call t_reset
		pop bc
		pop af
		ld l,a
		ld h,0
		ld (t_n),hl
		ld a,c
		ld (t_kind),a
		xor a
		ld (t_map),a
		ld a,16
		ld (t_aux),a
		ld hl,(t_aux2_tmp)
		ld (t_aux2),hl
		ld hl,drv_probe
		ld (t_drv),hl
		ld a,#C3
		ld (t_val),a
		ld hl,SCR_S
		ld (t_src),hl
		ld a,(t_kind)
		or a
		jr z,.nf
		ld de,(t_n)
		call src_win
.nf:		ld hl,SCR_D
		ld (t_dst),hl
		ld de,16
		call sp_ram
		call run_case
		pop hl
		jr .lp

tab_dec:	dw kd_dd49, txd_dd49
		db 1, K_FILL
		dw kd_fd49, txd_fd49
		db 1, K_FILL
		dw kd_cb49, txd_cb49
		db 1, K_FILL
		dw kd_op49, txd_op49
		db 1, K_FILL
		dw kd_fd6d, txd_fd6d
		db 1, K_COPY
		dw kd_ed52, txd_ed52
		db 16, K_FILL
		dw kd_halt, txd_halt
		db 1, K_FILL
		dw 0

; observations (not counted as pass/fail): WIN1 scratch, results dumped.
tests_info:	call out_nl
		PRL "== Observations (behaviour outside the documented protocol) =="
		ld hl,txg_info
		call grp_begin
		; buffer kept across LD B,B + EI + HALT (the DSS ISR runs in between)
		ld hl,txi_keep
		ld (cur_name),hl
		call info_copy_setup
		ld hl,drv_bufkeep
		ld (t_drv),hl
		ld a,40
		call info_n
		call run_case
		; LD H,H at an even and an odd address
		ld a,(opt_noh)
		or a
		jr nz,.noh
		ld hl,SCR_D
		call info_dbl
		ld hl,SCR_D + 1
		call info_dbl
.noh:		; ALU (HL) opcodes other than XOR/OR/AND in the logic slot
		ld hl,tab_alias
.al:		ld a,(hl)
		or a
		jr z,.ald
		inc hl
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		push hl
		ld (cur_name),de
		push af
		call info_copy_setup
		pop af
		ld (t_op),a
		ld a,K_COPY			; modelled as a copy; the dump tells the truth
		ld (t_kind),a
		ld hl,drv_logic
		ld (t_drv),hl
		ld a,16
		call info_n
		call run_case
		call info_alias
		pop hl
		jr .al
.ald:		; read N, write M
		ld hl,txi_rd16
		ld (cur_name),hl
		call info_copy_setup
		ld hl,drv_rdwr
		ld (t_drv),hl
		ld a,8
		ld (t_aux),a
		ld a,16
		call info_n
		call run_case
		ld b,12
		call info_src_idx
		ld hl,txi_rd8
		ld (cur_name),hl
		call info_copy_setup
		ld hl,drv_rdwr
		ld (t_drv),hl
		ld a,16
		ld (t_aux),a
		ld a,8
		call info_n
		call run_case
		ld b,20
		call info_src_idx
		; size latched from a memory read: LD D,D + LD A,(DE) with (DE) = 5
		ld hl,txi_cntmem
		ld (cur_name),hl
		call t_reset
		ld a,1
		ld (t_info),a
		xor a
		ld (t_map),a
		ld hl,drv_cntmem
		ld (t_drv),hl
		ld a,5
		ld (t_aux),a
		ld hl,5
		ld (t_n),hl
		ld a,#C3
		ld (t_val),a
		ld hl,SCR_S
		ld (t_src),hl
		ld hl,SCR_D
		ld (t_dst),hl
		ld de,16
		call sp_ram
		call run_case
		jp grp_end

; info_copy_setup: info copy SCR_S -> SCR_D in WIN1 (size set by info_n).
info_copy_setup:
		call t_reset
		ld a,1
		ld (t_info),a
		xor a
		ld (t_map),a
		ld a,K_COPY
		ld (t_kind),a
		ld hl,SCR_S
		ld (t_src),hl
		ld hl,SCR_D
		ld (t_dst),hl
		ret
; info_n: size A; windows of 32 bytes around source and destination.
info_n:		ld l,a
		ld h,0
		ld (t_n),hl
		ld hl,SCR_S
		ld de,32
		call src_win
		ld hl,SCR_D
		ld de,32
		jp sp_ram

; info_dbl: LD H,H + one write of #C3 at HL; dump HL-2..HL+2.
info_dbl:	push hl
		call t_reset
		pop hl
		ld (t_dst),hl
		ld a,1
		ld (t_info),a
		ld (t_n),a
		xor a
		ld (t_map),a
		ld a,#C3
		ld (t_val),a
		ld hl,txi_dbl
		ld (cur_name),hl
		ld hl,drv_dbl
		ld (t_drv),hl
		ld hl,(t_dst)
		ld de,4
		call sp_ram
		call run_case
		PR "         bytes dst-2..dst+2:"
		ld hl,(t_dst)
		dec hl
		dec hl
		ld b,5
.d:		push bc
		push hl
		ld a,' '
		call out_ch
		pop hl
		push hl
		ld a,(hl)
		call out_hex8
		pop hl
		inc hl
		pop bc
		djnz .d
		jp out_nl

; info_alias: classify each destination byte: = src AND/XOR/OR dst, src, unchanged.
info_alias:	PR "         result:"
		ld hl,SCR_D
		ld b,8
.lp:		push bc
		push hl
		ld a,' '
		call out_ch
		pop hl
		push hl
		call init_at			; d0
		ld (al_d0),a
		ld de,SCR_S - SCR_D
		add hl,de
		call init_at			; s0
		ld (al_s0),a
		pop hl
		push hl
		ld c,(hl)			; result
		ld a,(al_s0)
		ld b,a
		ld a,(al_d0)
		and b
		cp c
		ld a,'&'
		jr z,.p
		ld a,(al_d0)
		xor b
		cp c
		ld a,'^'
		jr z,.p
		ld a,(al_d0)
		or b
		cp c
		ld a,'|'
		jr z,.p
		ld a,b
		cp c
		ld a,'s'
		jr z,.p
		ld a,(al_d0)
		cp c
		ld a,'d'
		jr z,.p
		ld a,'?'
.p:		call out_ch
		pop hl
		inc hl
		pop bc
		djnz .lp
		PRL "   (& and, ^ xor, | or, s copy, d unchanged)"
		ret

tab_alias:	db #86
		dw txa_add
		db #8E
		dw txa_adc
		db #96
		dw txa_sub
		db #9E
		dw txa_sbc
		db #BE
		dw txa_cp
		db 0

; info_src_idx: B bytes of SCR_D as source indices (s0..s39), '.' = unchanged.
info_src_idx:	PR "         dst = src["
		ld hl,SCR_D
.lp:		push bc
		push hl
		ld c,(hl)
		push bc
		call init_at			; unchanged?
		pop bc
		cp c
		jr z,.dot
		; find k in 0..39 with init(SCR_S + k) = C
		ld hl,SCR_S
		ld b,40
		ld e,0
.f:		push bc
		push de
		call init_at
		pop de
		pop bc
		cp c
		jr z,.got
		inc hl
		inc e
		djnz .f
		ld a,'?'
		call out_ch
		jr .nx
.got:		ld l,e
		ld h,0
		xor a
		call out_u16
		jr .nx
.dot:		ld a,'.'
		call out_ch
.nx:		ld a,' '
		call out_ch
		pop hl
		inc hl
		pop bc
		djnz .lp
		PRL "]"
		ret
