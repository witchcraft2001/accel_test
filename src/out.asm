; out.asm -- console + log output (cold).
;
; Text is collected per line in lb_buf.  At the end of a line it goes to the screen
; (DSS PChars, unless o_gfx: the DSS console shares VRAM with the graphics mode) and to
; the log page (arena page 2 in WIN3, written under DI).  The log page is written to
; the file by log_flush (text mode only).  Lines produced in graphics mode are shown
; afterwards by gfx_leave (backlog from o_blk).
LB_MAX		equ 160
LOG_MAX		equ #3E00		; flush threshold inside the 16K log page
PAGE_LINES	equ 28

; out_inl: print the ASCIIZ string that follows the CALL.
out_inl:	ex (sp),hl
		call out_str
		inc hl
		ex (sp),hl
		ret

; out_str: HL = ASCIIZ (10 = end of line).  On return HL points at the terminator.
out_str:	ld a,(hl)
		or a
		ret z
		push hl
		call out_ch
		pop hl
		inc hl
		jr out_str

; out_ch: A = character, 10 = end of line.  Clobbers AF, BC, DE, HL.
out_ch:		cp 10
		jr z,out_nl
		ld c,a
		ld a,(lb_len)
		cp LB_MAX
		ret nc
		ld e,a
		ld d,0
		ld hl,lb_buf
		add hl,de
		ld (hl),c
		inc a
		ld (lb_len),a
		ret

; out_sp: A spaces.
out_sp:		or a
		ret z
		ld b,a
.lp:		push bc
		ld a,' '
		call out_ch
		pop bc
		djnz .lp
		ret

; out_tab: pad with spaces up to column A.
out_tab:	ld b,a
		ld a,(lb_len)
		cp b
		ret nc
		ld c,a
		ld a,b
		sub c
		jr out_sp

; out_nl: end the line.
out_nl:		ld a,(lb_len)
		ld e,a
		ld d,0
		ld hl,lb_buf
		add hl,de
		ld (hl),13
		inc hl
		ld (hl),10
		inc hl
		ld (hl),0
		inc a
		inc a
		ld (lb_len),a
		ld a,(o_mode)
		bit 1,a
		call nz,log_line
		ld a,(o_mode)
		bit 0,a
		jr z,.done
		ld a,(o_gfx)
		or a
		jr nz,.done
		ld hl,lb_buf
		call scr_line
.done:		xor a
		ld (lb_len),a
		ret

; scr_line: print the ASCIIZ line at HL on the screen, page every PAGE_LINES lines.
scr_line:	ld c,D_PCHARS
		rst DSS
		ld hl,o_lines
		inc (hl)
		ld a,(hl)
		cp PAGE_LINES
		ret c
		ld (hl),0
; page_wait: "more" prompt unless /A.  Esc sets o_abort.
page_wait:	ld a,(opt_auto)
		or a
		ret nz
		ld hl,msg_more
		ld c,D_PCHARS
		rst DSS
		ld c,D_WAITKEY
		rst DSS
		cp KEY_ESC
		jr nz,.k
		ld a,1
		ld (o_abort),a
.k:		ld hl,msg_unmore
		ld c,D_PCHARS
		rst DSS
		xor a
		ld (o_lines),a
		ret

; log_line: append lb_buf (lb_len bytes) to the log page.
log_line:	ld a,(log_ok)
		or a
		ret z
		ld hl,(log_pos)
		ld de,LOG_MAX
		or a
		sbc hl,de
		jr c,.room
		ld a,(o_gfx)			; full: flush; in graphics mode the screen
		ld (o_lost),a			; backlog then starts after this point
		call log_flush
.room:		ld de,(log_pos)
		ld hl,#C000
		add hl,de
		ex de,hl			; DE = position in WIN3
		ld a,(lb_len)
		ld c,a
		ld b,0
		push bc
		ld hl,lb_buf
		di
		ld a,(arena_p2)
		out (P_WIN3),a
		ldir
		ld a,(exe_p3)
		out (P_WIN3),a
		ei
		pop bc
		ld hl,(log_pos)
		add hl,bc
		ld (log_pos),hl
		ret

; log_fetch: copy C bytes (1..255) of the log page from offset HL to stage.
log_fetch:	ld de,#C000
		add hl,de
		ld de,stage
		ld b,0
		di
		ld a,(arena_p2)
		out (P_WIN3),a
		ldir
		ld a,(exe_p3)
		out (P_WIN3),a
		ei
		ret

; log_flush: write the log page to the file and empty it (text mode only).
log_flush:	ld a,(log_ok)
		or a
		ret z
		ld hl,0
		ld (o_fpos),hl
.lp:		ld hl,(log_pos)
		ld de,(o_fpos)
		or a
		sbc hl,de
		jr z,.end
		ld a,h
		or a
		ld a,l
		jr z,.n
		ld a,255
.n:		ld c,a
		ld (o_chunk),a
		ld hl,(o_fpos)
		call log_fetch
		ld a,(log_fh)
		or a
		jr z,.skip
		ld hl,stage
		ld de,(o_chunk)
		ld d,0
		ld c,D_WRITE
		rst DSS
		jr nc,.skip
		xor a				; write error: stop logging to the file
		ld (log_fh),a
		ld a,1
		ld (log_err),a
.skip:		ld hl,(o_fpos)
		ld de,(o_chunk)
		ld d,0
		add hl,de
		ld (o_fpos),hl
		jr .lp
.end:		ld hl,0
		ld (log_pos),hl
		ld (o_blk),hl
		ret

; ---------------------------------------------------------------- graphics mode
; gfx_enter: flush the log, set 320x256, palette, buffer 0 shown.  CF on failure.
gfx_enter:	ld a,(o_gfx)
		or a
		ret nz
		call log_flush
		ld hl,(log_pos)
		ld (o_blk),hl
		ld c,D_GETVMOD
		rst DSS
		ld (o_vmode),a
		ld a,b
		ld (o_vscr),a
		ld a,VMODE_320
		ld b,0
		call svmod_safe
		ret c
		ld a,1
		ld (o_gfx),a
		xor a
		call vis_rgmod
		call vis_palette
		or a
		ret

; svmod_safe: DSS SetVMod (A mode, B screen); returns its CF.  SetVMod leaves another
; page in WIN1, where the hot segment and the stack live: run it on a stack in WIN2
; and put the WIN1 page back before anything in WIN1 is touched again.
svmod_safe:	di
		ld (sv_sp),sp
		ld sp,sv_stack_top
		push af
		in a,(P_WIN1)
		ld (sv_win1),a
		pop af
		ld c,D_SETVMOD
		rst DSS
		push af
		di
		ld a,(sv_win1)
		out (P_WIN1),a
		pop af
		ld sp,(sv_sp)
		ei
		ret

; gfx_leave: back to the text mode, then show the lines collected meanwhile.
gfx_leave:	ld a,(o_gfx)
		or a
		ret z
		xor a
		call vis_rgmod
		ld a,(o_vscr)
		ld b,a
		ld a,(o_vmode)
		call svmod_safe
		xor a
		ld (o_gfx),a
		ld (o_lines),a
		ld a,(o_lost)
		or a
		jr z,.bl
		xor a
		ld (o_lost),a
		ld hl,msg_lost
		call scr_line
		; backlog: log page from o_blk to log_pos, line by line
.bl:		ld hl,(o_blk)
		ld (o_fpos),hl
.lp:		ld hl,(log_pos)
		ld de,(o_fpos)
		or a
		sbc hl,de
		ret z
		ld a,h
		or a
		ld a,l
		jr z,.n
		ld a,255
.n:		ld c,a
		ld (o_chunk),a
		ld hl,(o_fpos)
		call log_fetch
		ld hl,stage
		ld a,(o_chunk)
		ld b,a
.ch:		ld a,(hl)
		inc hl
		push hl
		push bc
		cp 13
		jr z,.skipc
		cp 10
		jr z,.eol
		ld c,a
		ld a,(lb_len)
		cp LB_MAX
		jr nc,.skipc
		ld e,a
		ld d,0
		push hl
		ld hl,lb_buf
		add hl,de
		ld (hl),c
		pop hl
		inc a
		ld (lb_len),a
		jr .skipc
.eol:		ld a,(lb_len)			; "R;" / "C;" lines are for the log only
		cp 2
		jr c,.show
		ld a,(lb_buf + 1)
		cp ';'
		jr nz,.show
		ld a,(lb_buf)
		cp 'R'
		jr z,.drop
		cp 'C'
		jr z,.drop
.show:		ld a,(lb_len)
		ld e,a
		ld d,0
		ld hl,lb_buf
		add hl,de
		ld (hl),13
		inc hl
		ld (hl),10
		inc hl
		ld (hl),0
		ld hl,lb_buf
		call scr_line
.drop:		xor a
		ld (lb_len),a
.skipc:		pop bc
		pop hl
		djnz .ch
		ld hl,(o_fpos)
		ld de,(o_chunk)
		ld d,0
		add hl,de
		ld (o_fpos),hl
		jp .lp

; ---------------------------------------------------------------- numbers
; out_u16: HL decimal, right-aligned in A columns (0 = no padding).
out_u16:	push af
		call acc_ld_hl
		pop af
; out_u32: acc32 decimal, width A.
out_u32:	ld (o_width),a
		xor a
		ld (o_frac),a
		jr out_num

; out_fix: acc32 / 10^o_frac with o_frac decimals, width A (sign from o_neg).
out_fix:	ld (o_width),a
out_num:	call acc_is_zero		; no "-0.00"
		jr nz,.sg
		ld (o_neg),a
.sg:		ld hl,o_digits + 15		; digits from the right
		ld (hl),0
		ld (o_dptr),hl
		ld a,(o_frac)
		or a
		jr z,.int
		ld b,a
.fr:		push bc
		call .digit
		pop bc
		djnz .fr
		ld hl,(o_dptr)
		dec hl
		ld (hl),'.'
		ld (o_dptr),hl
.int:		call .digit
		call acc_is_zero
		jr nz,.int
		ld a,(o_neg)
		or a
		jr z,.pad
		ld hl,(o_dptr)
		dec hl
		ld (hl),'-'
		ld (o_dptr),hl
.pad:		xor a
		ld (o_neg),a
		ld (o_frac),a
		ld hl,(o_dptr)			; width - length spaces
		ld de,o_digits + 15
		ex de,hl
		or a
		sbc hl,de			; length
		ld a,(o_width)
		sub l
		jr c,.pr
		jr z,.pr
		call out_sp
.pr:		ld hl,(o_dptr)
		jp out_str
.digit:		ld bc,10
		call div32x16
		ld a,l
		add a,'0'
		ld hl,(o_dptr)
		dec hl
		ld (hl),a
		ld (o_dptr),hl
		ret

; out_fix_hl: HL value, A decimals, B width.
out_fix_hl:	ld (o_frac),a
		ld a,b
		push af
		call acc_ld_hl
		pop af
		jr out_fix

; out_hex8: A as two hex digits.
out_hex8:	push af
		rrca
		rrca
		rrca
		rrca
		call .nib
		pop af
.nib:		and 15
		add a,'0'
		cp '9' + 1
		jr c,.p
		add a,'A' - '9' - 1
.p:		jp out_ch

; out_hex16: HL as #XXXX.
out_hex16:	push hl
		ld a,'#'
		call out_ch
		pop hl
		push hl
		ld a,h
		call out_hex8
		pop hl
		ld a,l
		jr out_hex8

; out_hexb: '#' + A as hex.
out_hexb:	push af
		ld a,'#'
		call out_ch
		pop af
		jr out_hex8
