; kernels.asm -- every accelerator sequence of the program lives here.
;
; Rules (ACCELER.TDF): the mode opcode is decoded on M1; while a mode is set, EVERY
; non-M1 memory access (operand fetch, displacement, PUSH/CALL/RET, interrupt push)
; is a block operation.  So: callers run under DI, the trigger instruction is followed
; immediately by LD B,B, nothing sits between the source read and the destination
; write, and the byte after a HALT is never an LD r,r opcode.
; The block size is the immediate operand of the LD A,n after LD D,D (self-modified,
; label .n; 0 = 256).  The mode byte (label .m) is patched by the callers: the null
; variant of a benchmark writes OP_OFF there, which leaves the same instruction
; stream with plain single-byte accesses.

; k_fill: HL = destination, C = value.  .m = OP_FILL / OP_VFILL / OP_OFF.
k_fill:		ld d,d
		db #3E
.n:		db 0
.m:		ld c,c
		ld (hl),c
		ld b,b
		ret

; k_copy: HL = source, DE = destination.  .m = OP_COPY / OP_VCOPY / OP_OFF.
k_copy:		ld d,d
		db #3E
.n:		db 0
.m:		ld l,l
		ld a,(hl)
		ld (de),a
		ld b,b
		ret

; k_logic: HL = destination (read and written), DE = source.  .op = XOR/OR/AND (HL)
; (or another ALU (HL) opcode for the alias probe).  .m = OP_COPY / OP_OFF.
k_logic:	ld d,d
		db #3E
.n:		db 0
.m:		ld l,l
		ld a,(de)
.op:		xor (hl)
		ld (hl),a
		ld b,b
		ret

; k_copy2v: two-phase column write.  HL = source (read horizontally into the buffer),
; DE = destination (written vertically from row B), C = P_Y.  The source row (VRAM
; source) must already be in PORT_Y.  .m1 = OP_COPY / OP_OFF, .m2 = OP_VCOPY / OP_OFF.
k_copy2v:	ld d,d
		db #3E
.n:		db 0
.m1:		ld l,l
		ld a,(hl)
		ld b,b
		out (c),b			; ED 41: two M1 fetches, no memory access
.m2:		ld a,a
		ld (de),a
		ld b,b
		ret

; k_vldir: LD A,A + LDIR -- BC columns, each a vertical read and a vertical write of
; .n rows (use 256: PORT_Y then returns to its start after every phase).
; HL = source column, DE = destination column, PORT_Y = first row.
k_vldir:	ld d,d
		db #3E
.n:		db 0
.m:		ld a,a
		ldir
		ld b,b
		ret

; k_copy_rd: load the buffer only (.n bytes from HL).
k_copy_rd:	ld d,d
		db #3E
.n:		db 0
		ld l,l
		ld a,(hl)
		ld b,b
		ret

; k_copy_wr: write the buffer to DE without loading a new size.
k_copy_wr:	ld l,l
		ld (de),a
		ld b,b
		ret

; k_setn: latch a block size and switch off.
k_setn:		ld d,d
		db #3E
.n:		db 0
		ld b,b
		ret

; k_fill_nc: fill with the size latched earlier (HL = destination, C = value).
k_fill_nc:	ld c,c
		ld (hl),c
		ld b,b
		ret

; k_cnt_mem: the size comes from a memory read: (DE) = size, HL = destination, C = value.
k_cnt_mem:	ld d,d
		ld a,(de)
		ld c,c
		ld (hl),c
		ld b,b
		ret

; k_dbl: LD H,H ("double byte") + one write.  HL = address, C = value.
k_dbl:		ld h,h
		ld (hl),c
		ld b,b
		ret

; ---- decoder probes: the size is latched (k_setn) beforehand; HL = destination,
; C = value.  A correct decoder leaves the accelerator off, so each probe writes one
; byte (ed52: the size must stay as latched and the fill uses it).
kd_dd49:	db #DD,#49			; LD C,C behind a DD prefix
		ld (hl),c
		ld b,b
		ret
kd_fd49:	db #FD,#49
		ld (hl),c
		ld b,b
		ret
kd_cb49:	db #CB,#49			; BIT 1,C
		ld (hl),c
		ld b,b
		ret
kd_op49:	ld a,OP_FILL			; #49 as an operand byte
		ld (hl),c
		ld b,b
		ret
kd_fd6d:	db #FD,#6D			; LD L,L behind FD (LD IYL,IYL); DE = source
		ld a,(de)
		ld (hl),a
		ld b,b
		ret
; kd_fd5b / kd_ed5b: #5B (LD E,E, vertical fill) behind a prefix.  Run on VRAM: only
; there a vertical fill differs from a plain write (16 rows instead of one byte).
kd_fd5b:	db #FD,#5B			; LD E,E behind FD
		ld (hl),c
		ld b,b
		ret
kd_ed5b:	ld de,(t_dst)			; ED 5B nn nn
		ld (hl),c
		ld b,b
		ret
kd_ed52:	or a
		db #ED,#52			; SBC HL,DE (#52 = LD D,D after the prefix)
		add hl,de
		ld a,4				; would become the size if ED 52 latched it
		ld c,c
		ld (hl),c
		ld b,b
		ret
; kd_halt: arm a fill, then EI + HALT: the HALT fetch must switch the mode off, so the
; interrupt push and the following write are plain accesses.  WIN1 only (the ISR runs).
kd_halt:	ld c,c
		ei
		halt
		di				; the byte after HALT: never an LD r,r
		ld (hl),c
		ld b,b
		ret
