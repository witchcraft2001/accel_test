; text.asm -- strings (cold).

txt_usage:	db "Usage: ACCTEST [/T] [/V] [/B] [/A] [/Q] [/4] [/NOH] [/N] [/L=file]",10
		db "  /T tests  /V visual screens  /B benchmarks  (default: all three)",10
		db "  /A automatic: no key waits     /Q quick: reduced matrices",10
		db "  /4 address offsets 0..3 instead of 0..1",10
		db "  /NOH skip the LD H,H probe     /N no log file",10
		db "  /L=file log file name (default ACCTEST.LOG)",10
		db "Exit code: 0 all passed, 1 failures, 2 setup error, 3 aborted (Esc).",10,0
txt_logdef:	db "ACCTEST.LOG",0
txt_logdef_len	equ $ - txt_logdef

msg_more:	db "-- more: any key, Esc = stop --",0
msg_unmore:	db 13,"                               ",13,0
msg_lost:	db "  (the log page filled up in graphics mode: earlier lines are in the log file)",13,10,0
msg_anykey:	db "Press a key to start (Esc = skip).",13,10,0

; groups and cases (RAM)
txg_fill:	db "fill RAM: address & 1 x sizes",0
txg_copy:	db "copy RAM: src/dst parity x sizes",0
txg_bound:	db "page boundaries #xxFF and #BFFF/#C000",0
txg_overlap:	db "overlapping copies (memmove)",0
txg_xor:	db "XOR (HL) RAM: parity x sizes",0
txg_or:		db "OR (HL) RAM: parity x sizes",0
txg_and:	db "AND (HL) RAM: parity x sizes",0
txg_xor2:	db "XOR twice restores the block",0
txg_count:	db "size latch: persistence, read once/write 3",0
txc_persist:	db "fill with the size latched earlier",0
txc_rw3:	db "one load written 3 times",0
txg_vert:	db "vertical modes on RAM: one byte",0
txc_vfill:	db "LD E,E fill in RAM",0
txc_vcopy:	db "LD A,A copy in RAM",0
txg_dec:	db "decoder: prefixes, operands, HALT",0
txd_dd49:	db "DD 49 (LD C,C after DD)",0
txd_fd49:	db "FD 49",0
txd_cb49:	db "CB 49 (BIT 1,C)",0
txd_op49:	db "#49 as an operand",0
txd_fd6d:	db "FD 6D (LD L,L after FD)",0
txd_ed52:	db "ED 52 keeps the size",0
txd_halt:	db "HALT switches the mode off",0
txg_info:	db "observations",0
txi_keep:	db "buffer kept over LD B,B+EI+HALT",0
txi_dbl:	db "LD H,H + LD (HL),#C3",0
txa_add:	db "ADD A,(HL) in the logic slot",0
txa_adc:	db "ADC A,(HL) in the logic slot",0
txa_sub:	db "SUB (HL) in the logic slot",0
txa_sbc:	db "SBC A,(HL) in the logic slot",0
txa_cp:		db "CP (HL) in the logic slot",0
txi_rd16:	db "load 16, latch 8, write",0
txi_rd8:	db "load 8, latch 16, write",0
txi_cntmem:	db "size from LD D,D + LD A,(DE), (DE)=5",0

; VRAM
txg_vhfill:	db "VRAM fill: x & 1 x sizes",0
txg_vvfill:	db "VRAM vertical fill: x & 1 x rows",0
txg_vcopy:	db "RAM -> VRAM copy: parity x sizes",0
txg_v2v:	db "column write (load + LD A,A)",0
txg_vmisc:	db "VRAM: rectangles, mirror, aliases, edges",0
txv_hrect:	db "fill 37 x 12 rows",0
txv_vwrap:	db "vertical fill wraps row 255 -> 0",0
txv_vrect:	db "vertical fill 5 columns x 40",0
txv_spr:	db "sprite 33 x 20 rows from RAM",0
txv_v2r:	db "VRAM -> RAM",0
txv_buf:	db "buffer 0 -> buffer 1, 100 x 8",0
txv_vcopy:	db "LD A,A copy of a 256-row column",0
txv_vldir:	db "LD A,A + LDIR, 4 columns",0
txv_trans:	db "transparent page #58, #FF skipped",0
txv_nomir:	db "page #54: mirror unchanged",0
txv_trnom:	db "page #5C: mirror unchanged",0
txv_xor:	db "XOR (HL) into VRAM",0
txv_bfill:	db "fill RAM #BFF8 -> VRAM #C000",0
txv_bcopy:	db "copy into RAM #BFF8 -> VRAM",0
txv_bsrc:	db "copy from RAM #BFF8 + VRAM",0

; visual
txs_1:		db "horizontal fills",0
txs_2:		db "vertical fills",0
txs_3:		db "sprites by rows",0
txs_4:		db "transparency (#58)",0
txs_5:		db "sprites by columns",0
txs_6:		db "buffer 0 -> 1, LD A,A + LDIR",0
txs_7:		db "XOR twice",0

; benchmarks
txb_fill:	db "fill RAM",0
txb_copy:	db "copy RAM",0
txb_xor:	db "XOR (HL) RAM",0
txb_fillnc:	db "fill #BFF0",0
txb_fillcr:	db "fill across #C000",0
txb_copysc:	db "copy src across",0
txb_copydc:	db "copy dst across",0
txb_copy256:	db "copy across #xxFF",0
txb_ldir:	db "CPU LDIR",0
txb_cfill:	db "CPU LD (HL),A loop",0
txb_cfldir:	db "CPU fill LDIR",0
txb_cvline:	db "CPU vertical line",0
txb_cldirv:	db "CPU LDIR RAM->VRAM",0
txb_cldirvv:	db "CPU LDIR VRAM->VRAM",0
txb_r2vcr:	db "copy RAM|VRAM edge",0
txb_fillrv:	db "fill RAM|VRAM edge",0
txb_vfill_h:	db "fill VRAM",0
txb_r2v:	db "copy RAM->VRAM",0
txb_v2v:	db "copy VRAM->VRAM",0
txb_trans:	db "copy RAM->VRAM #5C",0
txb_vfill:	db "vertical fill",0
txb_col:	db "column load+LD A,A",0

; rows versus columns
txr_clr1:	db "clear 256+64 / 320 cols",0
txr_clr2:	db "clear 160+160 / 320 cols",0
txr_pic:	db "picture from RAM",0
txr_buf:	db "buffer 0 -> 1",0
txr_fill:	db "fill",0
txr_spr:	db "sprite",0
txr_sprt:	db "sprite #5C",0
