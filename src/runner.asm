; runner.asm -- table-free test runner (hot).
;
; A test is described by the t_* variables (hot_bss.asm) and a list of spans.  t_run:
;   DI -> map WIN2/WIN3 -> write the background init(y,a) over every span -> call the
;   driver (t_drv) -> verify every span byte against the model exp(y,a) -> unmap, EI.
;
; Locations: an address a, plus a row y for VRAM.  A location is VRAM iff t_map = MAP_VRAM
; and a >= #C000 (WIN3 holds VRAM, WIN2 arena page 0); everything else is RAM.
;
; Background:  RAM  bgD(a) = (lo*3 + hi) & #7F; inside the source window [t_slo,
;              t_slo+t_slen) bgS(a) = bgD(a) | #80 (t_tpat: #FF when (lo & 3) = 0)
;              VRAM bgV(y,x) = (xlo*3 + xhi*11 + y*5) & #7F
; So guard bytes (< #80) never equal fill values or copied bytes (>= #80).
;
; Operation model: element (j,i), j = repetition 0..t_w-1, i = byte 0..t_n-1.
;   destination  VRAM H: (t_dy+j, t_dst+i)       VRAM V: (t_dy+i, t_dst+j)
;                RAM  H: t_dst + j*t_dstr + i     RAM  V: t_dst + j*t_dstr (last i wins)
;   source       H: (t_sy+j, t_src + j*t_sstr + i)   V: (t_sy+i, t_src + j*t_sstr)
;   value        fill: t_val; copy: init(source); logic: init(source) OP init(dest);
;                none: destination unchanged.  A VRAM write through a no-mirror page leaves
;                the (mirror) readback unchanged, through a transparent page #FF is skipped.

MAP_NONE	equ 0			; WIN1 scratch, nothing remapped
MAP_ARENA	equ 1			; WIN2 = arena page 0, WIN3 = arena page 1
MAP_VRAM	equ 2			; WIN2 = arena page 0, WIN3 = VRAM

K_FILL		equ 0
K_COPY		equ 1
K_LOGIC		equ 2
K_NONE		equ 3

SPAN_SIZE	equ 6			; y, rows (0 = 256), lo (word), hi (word, exclusive)
MAX_SPANS	equ 40

; ---------------------------------------------------------------- mapping
map_test:	ld a,(t_map)
		or a
		ret z
		ld a,(arena_p0)
		out (P_WIN2),a
		ld a,(t_map)
		cp MAP_VRAM
		jr z,.v
		ld a,(arena_p1)
		out (P_WIN3),a
		ret
.v:		ld a,VP_NORM
		out (P_WIN3),a
		ret

; set_vpage: the driver's write page (VRAM tests only).
set_vpage:	ld a,(t_map)
		cp MAP_VRAM
		ret nz
		ld a,(t_vpage)
		out (P_WIN3),a
		ret

; map_vram_a: WIN2 = arena page 0, WIN3 = VRAM page A (under DI).
map_vram_a:	out (P_WIN3),a
		ld a,(arena_p0)
		out (P_WIN2),a
		ret

; map_arena: WIN2/WIN3 = arena pages 0/1 (under DI).
map_arena:	ld a,(arena_p0)
		out (P_WIN2),a
		ld a,(arena_p1)
		out (P_WIN3),a
		ret

; unmap: program pages back, PORT_Y idle.  Interrupts stay as they are.
unmap:		ld a,PORTY_IDLE
		out (P_Y),a
		ld a,(exe_p2)
		out (P_WIN2),a
		ld a,(exe_p3)
		out (P_WIN3),a
		ret

jp_hl:		jp (hl)

; ---------------------------------------------------------------- t_run
; Out: HL = r_bad (mismatching bytes), Z = pass.
t_run:		di
		call map_test
		ld hl,prefill_byte
		ld (sp_action),hl
		call span_walk
		ld hl,(t_drv)
		call jp_hl
		call map_test			; WIN3 back to the plain page for the readback
		ld hl,0
		ld (r_bad),hl
		ld hl,verify_byte
		ld (sp_action),hl
		call span_walk
		call unmap
		ei
		ld hl,(r_bad)
		ld a,h
		or l
		ret

; span_walk: call (sp_action) with HL = address for every byte of every span; cur_y
; holds the row and PORT_Y is set to it.
span_walk:	ld ix,t_spans
		ld a,(t_nsp)
		or a
		ret z
		ld b,a
.sp:		push bc
		ld a,(ix+0)
		ld (cur_y),a
		ld a,(ix+1)
		ld (sw_rows),a
.row:		ld a,(cur_y)
		out (P_Y),a
		ld l,(ix+2)
		ld h,(ix+3)
.byte:		push hl
		ld de,.ret
		push de
		ld de,(sp_action)
		push de
		ret				; call (sp_action)
.ret:		pop hl
		inc hl
		ld a,l
		cp (ix+4)
		jr nz,.byte
		ld a,h
		cp (ix+5)
		jr nz,.byte
		ld a,(cur_y)
		inc a
		ld (cur_y),a
		ld a,(sw_rows)
		dec a
		ld (sw_rows),a
		jr nz,.row
		ld de,SPAN_SIZE
		add ix,de
		pop bc
		djnz .sp
		ret

prefill_byte:	call init_at
		ld (hl),a
		ret

verify_byte:	call exp_at
		cp (hl)
		ret z
		ld c,a
		ld de,(r_bad)
		ld a,d
		or e
		inc de
		ld (r_bad),de
		ret nz				; keep the first mismatch only
		ld (r_addr),hl
		ld a,c
		ld (r_exp),a
		ld a,(hl)
		ld (r_got),a
		ld a,(cur_y)
		ld (r_y),a
		ret

; ---------------------------------------------------------------- model
; is_vram: Z if HL is a VRAM location.  Clobbers A.
is_vram:	ld a,(t_map)
		cp MAP_VRAM
		ret nz
		ld a,h
		cp #C0
		jr c,.no
		xor a
		ret
.no:		or 1
		ret

; init_at: A = background at (cur_y, HL).  Keeps HL; clobbers BC, DE.
init_at:	call is_vram
		jr z,.vram
		ld a,l
		add a,a
		add a,l
		add a,h
		and #7F
		ld c,a
		push hl
		ld de,(t_slo)
		or a
		sbc hl,de
		ld de,(t_slen)
		or a
		sbc hl,de			; CF = inside the source window
		pop hl
		ld a,c
		ret nc
		ld a,(t_tpat)
		or a
		jr z,.s
		ld a,l
		and 3
		jr nz,.s
		ld a,#FF
		ret
.s:		ld a,c
		or #80
		ret
.vram:		ld a,l
		add a,a
		add a,l
		ld c,a				; xlo*3
		ld a,h
		and 3
		ld b,a
		add a,a
		add a,a
		add a,a
		add a,b
		add a,b
		add a,b				; xhi*11
		add a,c
		ld c,a
		ld a,(cur_y)
		ld b,a
		add a,a
		add a,a
		add a,b				; y*5
		add a,c
		and #7F
		ret

; dst_lookup: CF = 1 if (cur_y, HL) is a destination element; e_j, e_i set.
; Keeps HL; clobbers AF, BC, DE.
dst_lookup:	call is_vram
		jr nz,.ram
		ld a,(t_dy)
		ld b,a
		ld a,(cur_y)
		sub b				; row offset
		ld c,a
		ld a,(t_dv)
		or a
		jr nz,.vv
		; VRAM H: j = row offset < w, i = a - dst < n
		ld a,(t_w)
		ld b,a
		ld a,c
		cp b
		ret nc
		ld (e_j),a
		push hl
		ld de,(t_dst)
		or a
		sbc hl,de
		ld (e_i),hl
		ld de,(t_n)
		or a
		sbc hl,de
		pop hl
		ret
.vv:		; VRAM V: i = row offset < n, j = a - dst < w
		ld b,0
		ld (e_i),bc
		push hl
		ld hl,(t_n)
		or a
		sbc hl,bc			; n - i: NC and nonzero when i < n
		jr c,.no
		jr z,.no
		pop hl
		push hl
		ld de,(t_dst)
		or a
		sbc hl,de			; j
		ld a,h
		or a
		jr nz,.no
		ld a,l
		ld (e_j),a
		ld a,(t_w)
		ld b,a
		ld a,l
		cp b
		pop hl
		ret
.no:		pop hl
		or a
		ret
.ram:		ld de,(t_dst)
		xor a
		ld (e_j),a
.rl:		push hl
		or a
		sbc hl,de			; a - dst_j
		ld a,(t_dv)
		or a
		jr nz,.rv
		ld (e_i),hl
		ld bc,(t_n)
		or a
		sbc hl,bc
		pop hl
		ret c
		jr .next
.rv:		ld a,h
		or l
		pop hl
		jr nz,.next
		ld bc,(t_n)
		dec bc
		ld (e_i),bc
		scf
		ret
.next:		push hl
		ld hl,(t_dstr)
		add hl,de
		ex de,hl
		pop hl
		ld a,(e_j)
		inc a
		ld (e_j),a
		ld b,a
		ld a,(t_w)
		cp b
		jr nz,.rl
		or a
		ret

; src_val: A = init(source element e_j, e_i).  Keeps HL; clobbers BC, DE.
src_val:	push hl
		ld a,(cur_y)
		push af
		ld hl,(t_src)
		ld a,(e_j)
		or a
		jr z,.j0
		ld b,a
		ld de,(t_sstr)
.mj:		add hl,de
		djnz .mj
.j0:		ld a,(t_sv)
		or a
		jr nz,.v
		ld de,(e_i)
		add hl,de
		ld a,(t_sy)
		ld b,a
		ld a,(e_j)
		add a,b
		jr .go
.v:		ld a,(t_sy)
		ld b,a
		ld a,(e_i)
		add a,b
.go:		ld (cur_y),a
		call init_at
		ld c,a
		pop af
		ld (cur_y),a
		ld a,c
		pop hl
		ret

; exp_at: A = expected byte at (cur_y, HL).  Keeps HL; clobbers BC, DE.
exp_at:		ld a,(t_kind)
		cp K_NONE
		jp z,init_at
		call dst_lookup
		jp nc,init_at
		ld a,(t_kind)
		or a
		jr nz,.cp
		ld a,(t_val)
		jr .post
.cp:		call src_val
		ld c,a
		ld a,(t_kind)
		cp K_LOGIC
		ld a,c
		jr nz,.post
		push bc
		call init_at			; current destination byte
		pop bc
		ld b,a
		ld a,(t_op)
		cp OP_XOR_HL
		jr z,.x
		cp OP_OR_HL
		jr z,.o
		ld a,b
		and c
		jr .post
.x:		ld a,b
		xor c
		jr .post
.o:		ld a,b
		or c
.post:		ld c,a
		call is_vram
		ld a,c
		ret nz
		ld a,(t_vpage)
		bit 2,a
		jp nz,init_at			; VRAM only: the mirror keeps the background
		bit 3,a
		ld a,c
		ret z
		inc a
		jp z,init_at			; transparent #FF
		ld a,c
		ret

; ---------------------------------------------------------------- drivers
; Each driver runs the operation of the current test (DI, test pages mapped).

; patch_n: write t_n (0 = 256) into the size operand of every kernel.
patch_n:	ld a,(t_n)
		ld (k_fill.n),a
		ld (k_copy.n),a
		ld (k_logic.n),a
		ld (k_copy2v.n),a
		ld (k_vldir.n),a
		ld (k_copy_rd.n),a
		ld (k_setn.n),a
		ret

; next_rep: advance d_s, d_d, d_row to the next repetition.
next_rep:	ld hl,(t_dst)			; is the destination VRAM?
		call is_vram
		jr nz,.dram
		ld a,(t_dv)
		or a
		jr nz,.dcol
		ld hl,d_row
		inc (hl)
		jr .src
.dcol:		ld hl,(d_d)
		inc hl
		ld (d_d),hl
		jr .src
.dram:		ld hl,(d_d)
		ld de,(t_dstr)
		add hl,de
		ld (d_d),hl
.src:		ld hl,(d_s)
		ld de,(t_sstr)
		add hl,de
		ld (d_s),hl
		ld a,(t_sv)			; a vertical source steps its column via sstr,
		or a				; a horizontal VRAM source its row
		ret nz
		ld hl,(t_src)
		call is_vram
		ret nz
		ld hl,d_srow
		inc (hl)
		ret

rep_init:	ld hl,(t_dst)
		ld (d_d),hl
		ld hl,(t_src)
		ld (d_s),hl
		ld a,(t_dy)
		ld (d_row),a
		ld a,(t_sy)
		ld (d_srow),a
		ld a,(t_w)
		ld (d_cnt),a
		ret

; rep_loop: call (d_op) t_w times with fresh registers: HL = d_d, DE = d_s, C = t_val,
; PORT_Y = d_row (or d_srow for a VRAM source with a RAM destination).
rep_loop:	call patch_n
		call set_vpage
		call rep_init
.lp:		ld hl,(t_dst)
		call is_vram
		ld a,(d_row)
		jr z,.y
		ld a,(d_srow)
.y:		out (P_Y),a
		ld hl,(d_d)
		ld de,(d_s)
		ld a,(t_val)
		ld c,a
		ld ix,.ret
		push ix
		ld ix,(d_op)
		jp (ix)
.ret:		call next_rep
		ld hl,d_cnt
		dec (hl)
		jr nz,.lp
		ret

drv_fill:	ld a,OP_FILL
		ld (k_fill.m),a
		ld a,(t_dv)
		or a
		jr z,.go
		ld a,OP_VFILL
		ld (k_fill.m),a
.go:		ld hl,k_fill
		ld (d_op),hl
		jp rep_loop

drv_copy:	ld a,OP_COPY
		ld (k_copy.m),a
		ld a,(t_dv)
		or a
		jr z,.go
		ld a,OP_VCOPY
		ld (k_copy.m),a
.go:		ld hl,op_copy
		ld (d_op),hl
		jp rep_loop
op_copy:	ex de,hl			; HL = source, DE = destination
		jp k_copy

drv_logic:	ld a,OP_COPY
		ld (k_logic.m),a
		ld a,(t_op)
		ld (k_logic.op),a
		ld hl,k_logic			; HL = destination, DE = source
		ld (d_op),hl
		jp rep_loop

drv_xor2:	call drv_logic			; t_op = XOR: twice gives the background back
		jr drv_logic

drv_copy2v:	ld a,OP_COPY
		ld (k_copy2v.m1),a
		ld a,OP_VCOPY
		ld (k_copy2v.m2),a
		ld hl,op_copy2v
		ld (d_op),hl
		jp rep_loop
op_copy2v:	ex de,hl
		ld a,(d_row)
		ld b,a
		ld a,(d_srow)
		out (P_Y),a			; source row for a VRAM source
		ld c,P_Y
		jp k_copy2v

; drv_vldir: t_w columns of LD A,A + LDIR (t_n should be 256).
drv_vldir:	call patch_n
		call set_vpage
		ld a,(t_dy)
		out (P_Y),a
		ld hl,(t_src)
		ld de,(t_dst)
		ld a,(t_w)
		ld c,a
		ld b,0
		jp k_vldir

; drv_persist: latch t_n, then fill without a size.
drv_persist:	call patch_n
		call k_setn
		ld a,OP_FILL
		ld (k_fill.m),a			; (unused, keeps the kernels consistent)
		ld hl,(t_dst)
		ld a,(t_val)
		ld c,a
		jp k_fill_nc

; drv_rw3: one buffer load from t_src, t_w writes at t_dst + j*t_dstr.
drv_rw3:	call patch_n
		ld hl,(t_src)
		call k_copy_rd
		ld de,(t_dst)
		ld a,(t_w)
		ld b,a
.lp:		push bc
		push de
		call k_copy_wr
		pop de
		ld hl,(t_dstr)
		add hl,de
		ex de,hl
		pop bc
		djnz .lp
		ret

; drv_bufkeep: load the buffer, then LD B,B + EI + HALT, then write it (WIN1 only).
drv_bufkeep:	call patch_n
		ld hl,(t_src)
		call k_copy_rd
		ei
		halt
		di
		ld de,(t_dst)
		jp k_copy_wr

; drv_rdwr: load t_n bytes, latch t_aux bytes, write (size mismatch probe).
drv_rdwr:	call patch_n
		ld hl,(t_src)
		call k_copy_rd
		ld a,(t_aux)
		ld (k_setn.n),a
		call k_setn
		ld de,(t_dst)
		jp k_copy_wr

; drv_cntmem: the size is read from memory: (t_src) = t_aux.
drv_cntmem:	ld hl,(t_src)
		ld a,(t_aux)
		ld (hl),a
		ex de,hl
		ld hl,(t_dst)
		ld a,(t_val)
		ld c,a
		jp k_cnt_mem

drv_dbl:	ld hl,(t_dst)
		ld a,(t_val)
		ld c,a
		jp k_dbl

; drv_probe: latch t_aux (size), then call the decoder probe t_aux2 (address).
drv_probe:	ld a,(t_aux)
		ld (k_setn.n),a
		call k_setn
		ld hl,(t_src)
		ex de,hl			; DE = source/destination for kd_fd6d, any for ed52
		ld hl,(t_dst)
		ld a,(t_val)
		ld c,a
		ld ix,(t_aux2)
		jp (ix)
