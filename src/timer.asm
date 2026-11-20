; timer.asm -- interrupt-free time base: CTC ch2 counts the 875 kHz CLK/TRG2 input
; (42 MHz / 48), its ZC/TO2 clocks ch3.  Both in counter mode with TC = 256 and no
; interrupt: a free-running 16-bit counter, period 65536 counts = 74.9 ms.
; 1 count = 1.142857 us = 8 cycles of the 7 MHz accelerator clock = 24 T at 21 MHz.

tm_start:	ld a,CTC_COUNTER
		out (P_CTC3),a
		xor a
		out (P_CTC3),a
		ld a,CTC_COUNTER
		out (P_CTC2),a
		xor a
		out (P_CTC2),a
		ld a,1
		ld (tm_on),a
		ret

tm_stop:	ld a,(tm_on)
		or a
		ret z
		xor a
		ld (tm_on),a
		ld a,CTC_RESET
		out (P_CTC2),a
		out (P_CTC3),a
		ret

; tm_now: HL = counts since the counter was (re)loaded, increasing.  Clobbers AF, BC.
; ch3 is read on both sides of ch2: a change means ch2 wrapped in between, read again.
tm_now:		in a,(P_CTC3)
		ld b,a
		in a,(P_CTC2)
		ld c,a
		in a,(P_CTC3)
		cp b
		jr nz,tm_now
		xor a
		sub b
		ld h,a
		xor a
		sub c
		ld l,a
		ret

; tm_mark: tm_acc (32 bit) += now - tm_last; tm_last = now.  Clobbers AF, BC, DE, HL.
tm_mark:	call tm_now
		ld de,(tm_last)
		ld (tm_last),hl
		or a
		sbc hl,de
		ld de,(tm_acc)
		add hl,de
		ld (tm_acc),hl
		ret nc
		ld hl,(tm_acc + 2)
		inc hl
		ld (tm_acc + 2),hl
		ret

; tm_acc_start: tm_acc = 0, tm_last = now.
tm_acc_start:	ld hl,0
		ld (tm_acc),hl
		ld (tm_acc + 2),hl
		call tm_now
		ld (tm_last),hl
		ret

; tm_frame: HL = counts between two frame interrupts (interrupts enabled on return).
tm_frame:	ei
		halt
		di
		call tm_now
		ld (tm_last),hl
		ei
		halt
		di
		call tm_now
		ld de,(tm_last)
		or a
		sbc hl,de
		ei
		ret

; tm_cpu: HL = counts for 4096 iterations of DEC BC / LD A,B / OR C / JP NZ
; (24 T each by the Z80 tables = 98304 T, wait states included in the result).
tm_cpu:		di
		call tm_now
		ld (tm_last),hl
		ld bc,4096
.lp:		dec bc
		ld a,b
		or c
		jp nz,.lp
		call tm_now
		ld de,(tm_last)
		or a
		sbc hl,de
		ei
		ret
