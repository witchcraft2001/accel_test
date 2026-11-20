; visual.asm -- visual screens (cold).  Each screen is drawn twice from one table: the
; left half (x 0..159) with plain CPU code, the right half (x 160..319) with the
; accelerator.  The halves are compared through the DRAM mirror; the bar at the bottom
; (rows 240..255) is green when they are identical, red otherwise.

V_END		equ 0
V_HFILL		equ 1			; x, y, w, h, colour: h rows of w bytes
V_VFILL		equ 2			; w columns of h rows
V_SPR		equ 3			; sprite w x h (data generated), rows
V_SPRT		equ 4			; transparent sprite (#FF holes), rows, page #58
V_SPRC		equ 5			; sprite by columns: buffer load + LD A,A write
V_XOR		equ 6			; XOR of a w x h data block, rows
VE_SIZE		equ 7

	MACRO VE p_op, p_x, p_y, p_w, p_h, p_c
		db p_op
		dw p_x
		db p_y, p_w, p_h, p_c
	ENDM

COL_GREEN	equ %00011100
COL_RED		equ %11100000

vis1:		; horizontal fills: widths 1..136, start x even/odd
		VE V_HFILL, 0, 4, 1, 12, #E0
		VE V_HFILL, 1, 18, 10, 12, #FC
		VE V_HFILL, 2, 32, 19, 12, #1C
		VE V_HFILL, 3, 46, 28, 12, #1F
		VE V_HFILL, 4, 60, 37, 12, #03
		VE V_HFILL, 5, 74, 46, 12, #E3
		VE V_HFILL, 6, 88, 55, 12, #F0
		VE V_HFILL, 7, 102, 64, 12, #9C
		VE V_HFILL, 8, 116, 73, 12, #6F
		VE V_HFILL, 9, 130, 82, 12, #92
		VE V_HFILL, 10, 144, 91, 12, #DB
		VE V_HFILL, 11, 158, 100, 12, #4A
		VE V_HFILL, 12, 172, 109, 12, #E9
		VE V_HFILL, 13, 186, 118, 12, #3D
		VE V_HFILL, 14, 200, 127, 12, #B6
		VE V_HFILL, 15, 214, 136, 12, #F5
		VE V_HFILL, 150, 0, 1, 255, #FE
		db V_END
vis2:		; vertical fills: heights 1..226, columns even/odd, widths 1..4
		VE V_VFILL, 0, 4, 1, 1, #E0
		VE V_VFILL, 7, 4, 2, 16, #FC
		VE V_VFILL, 16, 4, 3, 31, #1C
		VE V_VFILL, 25, 4, 4, 46, #1F
		VE V_VFILL, 35, 4, 1, 61, #03
		VE V_VFILL, 42, 4, 2, 76, #E3
		VE V_VFILL, 51, 4, 3, 91, #F0
		VE V_VFILL, 60, 4, 4, 106, #9C
		VE V_VFILL, 70, 4, 1, 121, #6F
		VE V_VFILL, 77, 4, 2, 136, #92
		VE V_VFILL, 86, 4, 3, 151, #DB
		VE V_VFILL, 95, 4, 4, 166, #4A
		VE V_VFILL, 105, 4, 1, 181, #E9
		VE V_VFILL, 112, 4, 2, 196, #3D
		VE V_VFILL, 121, 4, 3, 211, #B6
		VE V_VFILL, 130, 4, 4, 226, #F5
		VE V_VFILL, 140, 0, 16, 240, #25
		db V_END
vis3:		; opaque sprites RAM -> VRAM by rows: widths 15/16/17 at even and odd x
		VE V_SPR, 4, 8, 15, 15, 0
		VE V_SPR, 25, 8, 16, 16, 0
		VE V_SPR, 47, 8, 17, 17, 0
		VE V_SPR, 70, 8, 15, 17, 0
		VE V_SPR, 91, 8, 16, 15, 0
		VE V_SPR, 112, 8, 17, 16, 0
		VE V_SPR, 5, 40, 15, 15, 0
		VE V_SPR, 26, 40, 16, 16, 0
		VE V_SPR, 48, 40, 17, 17, 0
		VE V_SPR, 71, 40, 15, 17, 0
		VE V_SPR, 92, 40, 16, 15, 0
		VE V_SPR, 113, 40, 17, 16, 0
		VE V_SPR, 8, 80, 32, 32, 0
		VE V_SPR, 51, 80, 31, 31, 0
		VE V_SPR, 90, 80, 32, 31, 0
		VE V_SPR, 9, 130, 31, 32, 0
		VE V_SPR, 50, 130, 1, 32, 0
		VE V_SPR, 60, 130, 2, 32, 0
		VE V_SPR, 71, 130, 3, 32, 0
		VE V_SPR, 90, 130, 32, 1, 0
		VE V_SPR, 90, 140, 32, 2, 0
		VE V_SPR, 90, 150, 32, 3, 0
		db V_END
vis4:		; transparency: stripes, then sprites with #FF holes on top
		VE V_HFILL, 0, 0, 160, 30, #49
		VE V_HFILL, 0, 30, 160, 30, #92
		VE V_HFILL, 0, 60, 160, 30, #E0
		VE V_HFILL, 0, 90, 160, 30, #1C
		VE V_HFILL, 0, 120, 160, 30, #03
		VE V_HFILL, 0, 150, 160, 30, #FC
		VE V_SPRT, 4, 10, 32, 32, 0
		VE V_SPRT, 41, 20, 31, 31, 0
		VE V_SPRT, 80, 30, 17, 32, 0
		VE V_SPRT, 101, 40, 32, 17, 0
		VE V_SPRT, 5, 80, 16, 16, 0
		VE V_SPRT, 30, 100, 15, 15, 0
		VE V_SPRT, 55, 120, 32, 32, 0
		VE V_SPRT, 97, 140, 31, 30, 0
		db V_END
vis5:		; sprites written by columns (two-phase vertical copy)
		VE V_SPRC, 4, 8, 15, 15, 0
		VE V_SPRC, 25, 8, 16, 16, 0
		VE V_SPRC, 47, 8, 17, 17, 0
		VE V_SPRC, 70, 8, 32, 32, 0
		VE V_SPRC, 105, 9, 31, 31, 0
		VE V_SPRC, 5, 60, 32, 16, 0
		VE V_SPRC, 40, 60, 16, 32, 0
		VE V_SPRC, 61, 61, 1, 32, 0
		VE V_SPRC, 64, 61, 2, 32, 0
		VE V_SPRC, 70, 61, 32, 1, 0
		VE V_SPRC, 4, 110, 32, 32, 0
		VE V_SPRC, 40, 111, 32, 32, 0
		VE V_SPRC, 75, 112, 32, 32, 0
		VE V_SPRC, 110, 113, 32, 32, 0
		db V_END
vis7:		; XOR: a striped background, then the same 32 x 32 block XORed twice at one
		; place (restores the background) and once at another
		VE V_HFILL, 0, 0, 160, 60, #49
		VE V_HFILL, 0, 60, 160, 60, #B6
		VE V_HFILL, 0, 120, 160, 60, #1C
		VE V_HFILL, 0, 180, 160, 60, #E3
		VE V_XOR, 10, 20, 32, 32, 0
		VE V_XOR, 11, 40, 31, 31, 0
		VE V_XOR, 11, 40, 31, 31, 0
		VE V_XOR, 60, 100, 32, 32, 0
		VE V_XOR, 61, 110, 32, 32, 0
		VE V_XOR, 100, 150, 17, 60, 0
		db V_END

; gen_spr: sprite data for w x h (vo_w, vo_h): row-major at scratch, column-major at
; scratch + #400; vo_tr: #FF holes.
gen_spr:	ld a,(vo_h)
		ld (gs_y),a
		xor a
		ld (gs_cy),a
		ld hl,scratch
.row:		xor a
		ld (gs_cx),a
		ld a,(vo_w)
		ld b,a
.px:		push bc
		ld a,(gs_cx)			; v = (x*7 + y*3) ^ (x >> 2) ^ #A4
		ld b,a
		add a,a
		add a,a
		add a,a
		sub b
		ld c,a
		ld a,(gs_cy)
		ld b,a
		add a,a
		add a,b
		add a,c
		ld c,a
		ld a,(gs_cx)
		rrca
		rrca
		and #3F
		xor c
		xor #A4
		cp #FF
		jr nz,.v
		dec a
.v:		ld c,a
		ld a,(vo_tr)
		or a
		jr z,.st
		ld a,(gs_cx)			; holes: (x + y) & 3 = 0 and a ring
		ld b,a
		ld a,(gs_cy)
		add a,b
		and 3
		jr nz,.st
		ld c,#FF
.st:		ld (hl),c
		push hl				; column-major copy: #400 + x*h + y
		ld a,(gs_cx)
		ld e,a
		ld d,0
		ld a,(vo_h)
		call mul8			; HL = x*h
		ld a,(gs_cy)
		ld e,a
		ld d,0
		add hl,de
		ld de,scratch + #400
		add hl,de
		ld (hl),c
		pop hl
		inc hl
		ld a,(gs_cx)
		inc a
		ld (gs_cx),a
		pop bc
		djnz .px
		ld a,(gs_cy)
		inc a
		ld (gs_cy),a
		ld a,(gs_y)
		dec a
		ld (gs_y),a
		jr nz,.row
		ret

; mul8: HL = DE * A.
mul8:		ld hl,0
		or a
		ret z
		ld b,a
.lp:		add hl,de
		djnz .lp
		ret

; vis_run: draw the table at HL; vo_half = 0 CPU (left), 1 accelerator (right).
vis_run:	ld a,(hl)
		or a
		ret z
		ld (vo_op),a
		inc hl
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,(vo_half)
		or a
		jr z,.x
		push hl
		ld hl,160
		add hl,de
		ex de,hl
		pop hl
.x:		push hl
		ld hl,#C000
		add hl,de
		ld (bp_hl),hl
		pop hl
		ld a,(hl)
		ld (bp_y),a
		inc hl
		ld a,(hl)
		ld (bp_w),a
		ld (vo_w),a
		inc hl
		ld a,(hl)
		ld (bp_h),a
		ld (vo_h),a
		inc hl
		ld a,(hl)
		ld (bp_c),a
		inc hl
		push hl
		call vis_op
		pop hl
		jr vis_run

vis_op:		xor a
		ld (vo_tr),a
		ld a,(vo_op)
		cp V_HFILL
		jr nz,.n1
		ld hl,bd_rect_cpu
		ld de,bd_rect_rows
		jr .go
.n1:		cp V_VFILL
		jr nz,.n2
		ld hl,vc_vfill
		ld de,bd_rect_cols
		jr .go
.n2:		cp V_XOR
		jr nz,.n3
		call .data
		ld hl,vc_xor_rows
		ld de,va_xor_rows
		jr .go
.n3:		cp V_SPRC
		jr nz,.n4
		call .data
		ld hl,scratch + #400
		ld (bp_de),hl
		ld hl,vc_spr_cols
		ld de,bd_spr_cols
		jr .go
.n4:		cp V_SPRT
		jr nz,.n5
		ld a,1
		ld (vo_tr),a
		call .data
		ld hl,bd_spr_cpu_t
		ld de,bd_spr_rows
		ld a,(vo_half)
		or a
		ld a,VP_TRANS
		jr nz,.call
		ld a,VP_NORM
		jr .call
.n5:		call .data			; V_SPR
		ld hl,bd_spr_cpu
		ld de,bd_spr_rows
.go:		ld a,VP_NORM
.call:		ld c,a
		ld a,(vo_half)
		or a
		jr z,.cpu
		ex de,hl
.cpu:		ld a,c
		jp vis_call
.data:		call gen_spr
		ld hl,scratch
		ld (bp_de),hl
		ret

; vis_screen: HL = table, A = screen number.  Draws both halves, compares, shows.
vis_screen:	ld (vis_no),a
		ld (vs_tab),hl
		xor a
		ld c,0
		call vis_clear
		xor a
		ld (vo_half),a
		ld hl,(vs_tab)
		call vis_run
		ld a,1
		ld (vo_half),a
		ld hl,(vs_tab)
		call vis_run
		call vis_cmp
		jp vis_verdict

; vis_verdict: HL = differing bytes; bar, count, log line, hold.
vis_verdict:	ld (vs_bad),hl
		ld a,h
		or l
		ld a,COL_GREEN
		jr z,.c
		ld a,COL_RED
.c:		ld (bp_c),a
		ld hl,#C000
		ld (bp_hl),hl
		ld a,240
		ld (bp_y),a
		ld a,16
		ld (bp_h),a
		ld a,160
		ld (bp_w),a
		ld hl,bd_rect_cpu
		ld a,VP_NORM
		call vis_call
		ld hl,#C000 + 160
		ld (bp_hl),hl
		ld hl,bd_rect_cpu
		ld a,VP_NORM
		call vis_call
		ld hl,(vs_bad)
		ld a,h
		or l
		jr nz,.f
		ld hl,(at_pass)
		inc hl
		ld (at_pass),hl
		jr .p
.f:		ld hl,(at_fail)
		inc hl
		ld (at_fail),hl
.p:		PR "  visual "
		ld a,(vis_no)
		ld l,a
		ld h,0
		xor a
		call out_u16
		PR ": "
		ld hl,(vs_name)
		call out_str
		ld a,44
		call out_tab
		ld hl,(vs_bad)
		ld a,h
		or l
		jr nz,.bad
		PRL "halves identical  OK"
		jr vis_wait
.bad:		ld hl,(vs_bad)
		xor a
		call out_u16
		PRL " bytes differ  FAIL"
; vis_wait: key (Esc aborts) or 25 frames with /A.  vis_held = screen on hold (for the
; MAME script's screenshots).
vis_wait:	ld a,(vis_no)
		ld (vis_held),a
		call .w
		xor a
		ld (vis_held),a
		ret
.w:		ld a,(opt_auto)
		or a
		jr z,.key
		ld b,25
		jp vis_hold
.key:		ld c,D_WAITKEY
		rst DSS
		cp KEY_ESC
		ret nz
		ld a,1
		ld (o_abort),a
		ret

visual_all:	call out_nl
		PRL "== Visual screens (left half: CPU code, right half: accelerator) =="
		PRL "  1 horizontal fills     2 vertical fills        3 sprites by rows"
		PRL "  4 transparency (#58)   5 sprites by columns    6 buffer 0 -> 1 (LD A,A+LDIR)"
		PRL "  7 XOR twice"
		PRL "  The bottom bar is green when both halves are identical."
		ld a,(opt_auto)
		or a
		jr nz,.go
		ld hl,msg_anykey
		ld c,D_PCHARS
		rst DSS
		ld c,D_WAITKEY
		rst DSS
		cp KEY_ESC
		jr nz,.go
		ld a,1
		ld (o_abort),a
		ret
.go:		call gfx_enter
		ret c
		ld hl,tab_vis
.lp:		ld a,(o_abort)
		or a
		jr nz,.end
		ld e,(hl)
		inc hl
		ld d,(hl)
		inc hl
		ld a,d
		or e
		jr z,.six
		ld c,(hl)
		inc hl
		ld b,(hl)
		inc hl
		ld (vs_name),bc
		ld a,(hl)
		inc hl
		push hl
		ex de,hl
		call vis_screen
		pop hl
		jr .lp
.six:		call vis_buffer
		ld a,(o_abort)
		or a
		jr nz,.end
		ld hl,txs_7
		ld (vs_name),hl
		ld hl,vis7
		ld a,7
		call vis_screen
.end:		xor a
		ld (vis_no),a
		jp gfx_leave

tab_vis:	dw vis1, txs_1
		db 1
		dw vis2, txs_2
		db 2
		dw vis3, txs_3
		db 3
		dw vis4, txs_4
		db 4
		dw vis5, txs_5
		db 5
		dw 0

; vis_buffer: screen 6 -- screens 1 + 2 into buffer 0, LD A,A + LDIR copy to buffer 1,
; buffer 1 displayed (RGMOD), buffers compared.
vis_buffer:	ld a,6
		ld (vis_no),a
		ld hl,txs_6
		ld (vs_name),hl
		xor a
		ld c,0
		call vis_clear
		ld a,1
		ld c,#FF
		call vis_clear			; buffer 1 white before the copy
		xor a
		ld (vo_half),a
		ld hl,vis1
		call vis_run
		ld a,1
		ld (vo_half),a
		ld hl,vis2
		call vis_run
		xor a
		ld (bp_y),a
		ld hl,vb_copy
		ld a,VP_NORM
		call vis_call
		ld a,1
		call vis_rgmod
		call vis_cmp_buf
		push hl
		ld a,h
		or l
		ld a,COL_GREEN
		jr z,.c
		ld a,COL_RED
.c:		ld (bp_c),a
		ld hl,#C000 + VBUF1
		ld (bp_hl),hl
		ld a,240
		ld (bp_y),a
		ld a,16
		ld (bp_h),a
		ld a,160
		ld (bp_w),a
		ld b,2
.bar:		push bc
		ld hl,bd_rect_cpu
		ld a,VP_NORM
		call vis_call
		ld hl,(bp_hl)
		ld de,160
		add hl,de
		ld (bp_hl),hl
		pop bc
		djnz .bar
		pop hl
		call vis_count
		call vis_wait
		xor a
		jp vis_rgmod

; vis_count: report like vis_verdict, without drawing.
vis_count:	ld (vs_bad),hl
		ld a,h
		or l
		jr nz,.f
		ld hl,(at_pass)
		inc hl
		ld (at_pass),hl
		jr .p
.f:		ld hl,(at_fail)
		inc hl
		ld (at_fail),hl
.p:		PR "  visual 6: "
		ld hl,(vs_name)
		call out_str
		ld a,44
		call out_tab
		ld hl,(vs_bad)
		ld a,h
		or l
		jr nz,.bad
		PRL "buffers identical  OK"
		ret
.bad:		xor a
		call out_u16
		PRL " bytes differ  FAIL"
		ret

; vb_copy: buffer 0 -> buffer 1 with LD A,A + LDIR (hot kernel).
vb_copy:	xor a
		out (P_Y),a
		ld (k_vldir.n),a
		ld hl,#C000
		ld de,#C000 + VBUF1
		ld bc,320
		jp k_vldir
