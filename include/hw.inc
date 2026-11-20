; hw.inc -- Sprinter ports, DSS/BIOS calls and accelerator opcodes used by ACCTEST.

; ---- memory windows (readable) ----
P_WIN0		equ #82			; #0000..#3FFF (DSS, never touched)
P_WIN1		equ #A2			; #4000..#7FFF (hot segment, stack)
P_WIN2		equ #C2			; #8000..#BFFF (cold segment / arena page 0)
P_WIN3		equ #E2			; #C000..#FFFF (arena page 1 / VRAM)

; ---- video ----
P_Y		equ #89			; PORT_Y: VRAM row / palette index (write only)
P_RGMOD		equ #C9			; bit 0: displayed buffer
PORTY_IDLE	equ #C0			; PORT_Y value outside accelerator sequences
VP_NORM		equ #50			; VRAM page: plain write, DRAM mirror updated
VP_NOMIR	equ #54			; VRAM only (mirror not updated)
VP_TRANS	equ #58			; #FF bytes are not written, mirror updated
VP_TRNOM	equ #5C			; transparent + VRAM only
VBUF1		equ #140		; buffer 1 offset inside a VRAM row
VMODE_320	equ #81			; DSS mode: 320x256x256

; ---- Z84C15 CTC (ch0 belongs to the DSS mouse, ch1 is never used) ----
P_CTC2		equ #12
P_CTC3		equ #13
CTC_COUNTER	equ #57			; counter mode, rising edge, TC follows, reset, no IRQ
CTC_RESET	equ #03

; ---- DSS (RST #10, function in C) ----
DSS		equ #10
D_SYSTIME	equ #21
D_WAITKEY	equ #30
D_SCANKEY	equ #31
D_GETMEM	equ #3D
D_FREEMEM	equ #3E
D_EXIT		equ #41
D_SETVMOD	equ #50
D_GETVMOD	equ #51
D_PCHARS	equ #5C
D_CREATE	equ #0A
D_CLOSE		equ #12
D_WRITE		equ #14
D_VERSION	equ #00

; ---- BIOS (RST #08, function in C) ----
BIOS		equ #08
B_EMM_PAGES	equ #C5			; A = block id, HL = buffer -> page list ending with #FF

; ---- accelerator opcodes (decoded on M1, not after a prefix) ----
OP_OFF		equ #40			; LD B,B
OP_FILL		equ #49			; LD C,C
OP_COUNT	equ #52			; LD D,D
OP_VFILL	equ #5B			; LD E,E
OP_DBL		equ #64			; LD H,H
OP_COPY		equ #6D			; LD L,L
OP_VCOPY	equ #7F			; LD A,A
OP_XOR_HL	equ #AE
OP_OR_HL	equ #B6
OP_AND_HL	equ #A6

KEY_ESC		equ 27
