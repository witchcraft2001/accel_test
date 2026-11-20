; math.asm -- 32-bit helpers on acc32 / arg32 (cold).

; acc_ld_hl: acc32 = HL.
acc_ld_hl:	ld (acc32),hl
		ld hl,0
		ld (acc32 + 2),hl
		ret

; acc_ld_mem: acc32 = 32-bit value at HL.
acc_ld_mem:	ld de,acc32
		ld bc,4
		ldir
		ret

; acc_st_mem: 32-bit value at HL = acc32.
acc_st_mem:	ex de,hl
		ld hl,acc32
		ld bc,4
		ldir
		ret

; mul32x16: acc32 *= BC (low 32 bits).
mul32x16:	ld hl,(acc32)
		ld (tmp32),hl
		ld hl,(acc32 + 2)
		ld (tmp32 + 2),hl
		ld hl,0
		ld (acc32),hl
		ld (acc32 + 2),hl
		ld a,16
.lp:		ld hl,(acc32)
		add hl,hl
		ld (acc32),hl
		ld hl,(acc32 + 2)
		adc hl,hl
		ld (acc32 + 2),hl
		sla c
		rl b
		jr nc,.nx
		ld hl,(acc32)
		ld de,(tmp32)
		add hl,de
		ld (acc32),hl
		ld hl,(acc32 + 2)
		ld de,(tmp32 + 2)
		adc hl,de
		ld (acc32 + 2),hl
.nx:		dec a
		jr nz,.lp
		ret

; div32x16: acc32 /= BC (BC != 0), HL = remainder.
div32x16:	ld hl,0
		ld a,32
.lp:		push af
		ld de,(acc32)
		sla e
		rl d
		ld (acc32),de
		ld de,(acc32 + 2)
		rl e
		rl d
		ld (acc32 + 2),de
		adc hl,hl
		jr c,.sub			; 17-bit remainder: certainly >= BC
		or a
		sbc hl,bc
		jr nc,.set
		add hl,bc
		jr .nx
.sub:		or a
		sbc hl,bc
.set:		ld a,(acc32)
		or 1
		ld (acc32),a
.nx:		pop af
		dec a
		jr nz,.lp
		ret

; div32x32: acc32 /= arg32 (arg32 != 0), remainder in rem32.
div32x32:	ld hl,0
		ld (rem32),hl
		ld (rem32 + 2),hl
		ld b,32
.lp:		ld hl,(acc32)			; shift acc32 into rem32
		add hl,hl
		ld (acc32),hl
		ld hl,(acc32 + 2)
		adc hl,hl
		ld (acc32 + 2),hl
		ld hl,(rem32)
		adc hl,hl
		ld (rem32),hl
		ld hl,(rem32 + 2)
		adc hl,hl
		ld (rem32 + 2),hl
		; rem32 - arg32
		ld hl,(rem32)
		ld de,(arg32)
		or a
		sbc hl,de
		ld (tmp32),hl
		ld hl,(rem32 + 2)
		ld de,(arg32 + 2)
		sbc hl,de
		jr c,.nx
		ld (rem32 + 2),hl
		ld hl,(tmp32)
		ld (rem32),hl
		ld a,(acc32)
		or 1
		ld (acc32),a
.nx:		djnz .lp
		ret

; acc_sub_hl: acc32 -= HL (saturates at 0).
acc_sub_hl:	ex de,hl
		ld hl,(acc32)
		or a
		sbc hl,de
		ld (acc32),hl
		ld hl,(acc32 + 2)
		ld de,0
		sbc hl,de
		ld (acc32 + 2),hl
		ret nc
		ld hl,0
		ld (acc32),hl
		ld (acc32 + 2),hl
		ret

; acc_is_zero: Z if acc32 = 0.
acc_is_zero:	ld hl,(acc32)
		ld a,h
		or l
		ld hl,(acc32 + 2)
		or h
		or l
		ret
