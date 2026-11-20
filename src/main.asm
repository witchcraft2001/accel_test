; main.asm -- program flow, options, memory, environment, cleanup (cold).

cold_main:	ld hl,cold_bss
		ld de,cold_bss + 1
		ld bc,cold_bss_end - cold_bss - 1
		ld (hl),0
		ldir
		ld a,3
		ld (o_mode),a			; screen + log
		call parse_cmd
		PRL "ACCTEST 1.0 - Sprinter accelerator test and benchmark"
		ld a,(opt_help)
		or a
		jr z,.run
		ld hl,txt_usage
		call out_str
		xor a
		jp exit_a
.run:		ld a,(opt_bad)
		or a
		jr z,.optok
		PRL "Unknown option (ACCTEST /? for help)."
		ld a,2
		jp exit_a
.optok:		call mem_alloc
		jr nc,.memok
		PRL "Not enough memory (3 pages needed)."
		ld a,2
		jp exit_a
.memok:		ld a,1
		ld (log_ok),a
		call log_open
		call tm_start
		call sec_env
		ld a,(sel)
		bit 0,a
		jr z,.nt
		call tests_ram
		call chk_abort
		jr c,.fin
		call tests_vram
		call chk_abort
		jr c,.fin
.nt:		ld a,(sel)
		bit 1,a
		jr z,.nv
		call visual_all
		call chk_abort
		jr c,.fin
.nv:		ld a,(sel)
		bit 2,a
		jr z,.fin
		call bench_all
.fin:		call gfx_leave
		call out_nl_if
		PRL "----------------------------------------------------------------"
		ld a,(o_abort)
		or a
		jr z,.na
		PRL "Aborted by Esc."
.na:		PR "RESULT: "
		ld hl,(at_fail)
		ld a,h
		or l
		jr nz,.failr
		PR "PASS"
		jr .cnt
.failr:		PR "FAIL"
.cnt:		PR " (tests passed "
		ld hl,(at_pass)
		xor a
		call out_u16
		PR ", failed "
		ld hl,(at_fail)
		xor a
		call out_u16
		PR ", observations "
		ld hl,(at_info)
		xor a
		call out_u16
		PRL ")"
		ld a,(log_err)
		or a
		jr z,.le
		PRL "Log file write error: the log is incomplete."
.le:		; exit code: 0 pass, 1 test failures, 3 aborted
		ld hl,(at_fail)
		ld a,h
		or l
		ld a,1
		jr nz,.ec
		xor a
.ec:		ld b,a
		ld a,(o_abort)
		or a
		ld a,b
		jr z,.ec2
		ld a,3
.ec2:		push af
		ld hl,(at_fail)			; flag for the MAME script
		ld a,h
		or l
		ld a,1
		jr z,.st
		inc a
.st:		ld (at_state),a
		ld a,(opt_auto)
		or a
		jr z,.nohold
		ld b,25				; let an observer see at_state
		call vis_hold
.nohold:	pop af
		jp exit_a

; out_nl_if: end a pending partial line.
out_nl_if:	ld a,(lb_len)
		or a
		ret z
		jp out_nl

; exit_a: cleanup, then DSS Exit with code A.
exit_a:		ld (exit_code),a
		call cleanup
		ld a,(exit_code)
		ld b,a
		ld c,D_EXIT
		rst DSS
		jr $

; cleanup: idempotent; restores everything the program changed.
cleanup:	di
		call unmap
		ei
		call tm_stop
		call gfx_leave
		call log_close
		ld a,(mem_id)
		or a
		ret z
		ld c,D_FREEMEM
		rst DSS
		xor a
		ld (mem_id),a
		ret

; chk_abort: CF if aborted (Esc now or earlier).  Keeps every register but AF:
; callers hold loop pointers in HL/IX across it, and DSS ScanKey clobbers them.
chk_abort:	ld a,(o_abort)
		or a
		jr nz,.yes
		push bc
		push de
		push hl
		push ix
		push iy
		ld c,D_SCANKEY
		rst DSS
		pop iy
		pop ix
		pop hl
		pop de
		pop bc
		jr z,.no
		cp KEY_ESC
		jr nz,.no
		ld a,1
		ld (o_abort),a
.yes:		scf
		ret
.no:		or a
		ret

; ---------------------------------------------------------------- memory
; mem_alloc: 3 pages (arena 0, 1, log).  CF on failure.
mem_alloc:	ld b,3
		ld c,D_GETMEM
		rst DSS
		ret c
		ld (mem_id),a
		ld hl,mem_pages
		ld c,B_EMM_PAGES
		rst BIOS
		ret c
		ld a,(mem_pages + 2)
		cp #FF
		scf
		ret z
		ld a,(mem_pages)
		ld (arena_p0),a
		ld a,(mem_pages + 1)
		ld (arena_p1),a
		ld a,(mem_pages + 2)
		ld (arena_p2),a
		or a
		ret

; ---------------------------------------------------------------- log file
log_open:	ld a,(opt_nolog)
		or a
		ret nz
		ld a,(log_name)
		or a
		jr nz,.n
		ld hl,txt_logdef
		ld de,log_name
		ld bc,txt_logdef_len
		ldir
.n:		ld hl,log_name
		ld a,0				; normal attributes
		ld c,D_CREATE
		rst DSS
		jr c,.err
		ld (log_fh),a
		ret
.err:		PR "Cannot create the log file "
		ld hl,log_name
		call out_str
		PRL " (continuing without it)."
		ret

log_close:	call log_flush
		ld a,(log_fh)
		or a
		ret z
		ld c,D_CLOSE
		rst DSS
		xor a
		ld (log_fh),a
		ret

; ---------------------------------------------------------------- options
; parse_cmd: /T /V /B select parts (default all), /A auto, /Q quick, /4 offsets 0..3,
; /NOH skip LD H,H, /N no log, /L=name log file, /? help.
parse_cmd:	ld ix,(cmd_ix)
		ld b,(ix+0)
		push ix
		pop hl
		inc hl
.nx:		ld a,b
		or a
		jp z,.done
		ld a,(hl)
		or a
		jp z,.done
		cp '/'
		jr z,.opt
		cp '-'
		jr z,.opt
		inc hl
		dec b
		jr .nx
.opt:		inc hl
		dec b
		jp z,.done
		ld a,(hl)
		call upcase
		inc hl
		dec b
		cp 'T'
		jr z,.selt
		cp 'V'
		jr z,.selv
		cp 'B'
		jr z,.selb
		cp 'A'
		jr z,.auto
		cp 'Q'
		jr z,.quick
		cp '4'
		jr z,.four
		cp '?'
		jr z,.help
		cp 'H'
		jr z,.help
		cp 'L'
		jr z,.log
		cp 'N'
		jr z,.non
		ld a,1
		ld (opt_bad),a
		jr .nx
.selt:		ld c,1
		jr .sel
.selv:		ld c,2
		jr .sel
.selb:		ld c,4
.sel:		ld a,(sel_given)
		or c
		ld (sel_given),a
		jr .nx
.auto:		ld a,1
		ld (opt_auto),a
		jr .nx
.quick:		ld a,1
		ld (opt_quick),a
		jr .nx
.four:		ld a,1
		ld (opt_four),a
		jr .nx
.help:		ld a,1
		ld (opt_help),a
		jr .nx
.non:		ld a,b				; /NOH or /N
		cp 2
		jr c,.nolog
		ld a,(hl)
		call upcase
		cp 'O'
		jr nz,.nolog
		inc hl
		ld a,(hl)
		call upcase
		cp 'H'
		jr nz,.nolog0
		inc hl
		dec b
		dec b
		ld a,1
		ld (opt_noh),a
		jp .nx
.nolog0:	dec hl
.nolog:		ld a,1
		ld (opt_nolog),a
		jp .nx
.log:		ld a,b				; /L=name
		or a
		jp z,.nx
		ld a,(hl)
		cp '='
		jp nz,.nx
		inc hl
		dec b
		ld de,log_name
		ld c,63
.lc:		ld a,b
		or a
		jr z,.le
		ld a,(hl)
		cp ' ' + 1
		jr c,.le
		ld (de),a
		inc de
		inc hl
		dec b
		dec c
		jr nz,.lc
.le:		xor a
		ld (de),a
		jp .nx
.done:		ld a,(sel_given)
		or a
		jr nz,.s
		ld a,7
.s:		ld (sel),a
		ret

upcase:		cp 'a'
		ret c
		cp 'z' + 1
		ret nc
		sub 32
		ret

; ---------------------------------------------------------------- environment
sec_env:	PRL "Units: 1 count = 1/875 kHz = 1.143 us = 8 cycles at 7 MHz = 24 T at 21 MHz."
		PR "Pages: program "
		ld a,(exe_p2)
		call out_hexb
		PR "/"
		ld a,(exe_p3)
		call out_hexb
		PR ", arena "
		ld a,(arena_p0)
		call out_hexb
		PR " "
		ld a,(arena_p1)
		call out_hexb
		PR ", log "
		ld a,(arena_p2)
		call out_hexb
		call out_nl
		; frame period, four samples
		PR "Frame period (counts, expected 17920):"
		ld b,4
.fr:		push bc
		call tm_frame
		ld (env_frame),hl
		ld a,' '
		push hl
		call out_ch
		pop hl
		xor a
		call out_u16
		pop bc
		djnz .fr
		ld hl,(env_frame)		; last sample within 17920 +- 2%
		ld de,17920 - 358
		or a
		sbc hl,de
		jr c,.fbad
		ld de,2 * 358
		or a
		sbc hl,de
		jr nc,.fbad
		PRL "  OK"
		jr .cpu
.fbad:		PRL "  ** timebase unverified **"
.cpu:		; effective CPU clock = 98304 T * 875 / counts kHz
		call tm_cpu
		ld (env_cpu),hl
		ld hl,98304 & #FFFF
		ld (acc32),hl
		ld hl,98304 >> 16
		ld (acc32 + 2),hl
		ld bc,875
		call mul32x16
		ld bc,(env_cpu)
		ld a,b
		or c
		jr nz,.dv
		inc bc
.dv:		call div32x16			; kHz
		ld bc,10
		call div32x16			; 10 kHz units
		PR "CPU: 98304 T loop in "
		ld hl,(env_cpu)
		push hl
		ld hl,(acc32)
		ld (env_mhz),hl
		pop hl
		xor a
		call out_u16
		PR " counts = "
		ld hl,(env_mhz)
		ld a,2
		ld b,0
		call out_fix_hl
		PRL " MHz effective (memory waits included)"
		ld a,(opt_quick)
		or a
		jr z,.nq
		PRL "Quick mode (/Q): reduced test matrix."
.nq:		jp chk_abort
