; hot_bss.asm -- hot variables (WIN1, zeroed at start).  The MAME script reads at_state,
; at_pass, at_fail and vis_no through the symbol file.
hot_bss:
cmd_ix		dw 0			; DSS command line (IX at entry)
exe_p2		db 0			; program pages of WIN2/WIN3
exe_p3		db 0
arena_p0	db 0			; physical pages of the arena block
arena_p1	db 0
arena_p2	db 0			; log page
tm_on		db 0
tm_last		dw 0
tm_acc		dd 0

at_state	db 0			; 0 running, 1 finished (pass), 2 finished (fail)
at_pass		dw 0			; P tests passed / failed
at_fail		dw 0
vis_no		db 0			; visual screen being drawn/shown
vis_held	db 0			; visual screen waiting for the key (0 = none)

; ---- test descriptor (t_reset clears t_blk..t_blk_end) ----
t_blk:
t_drv		dw 0
t_kind		db 0
t_op		db 0
t_val		db 0
t_n		dw 0			; 1..256
t_w		db 0			; repetitions
t_dst		dw 0
t_dy		db 0
t_dv		db 0			; 1: vertical destination
t_dstr		dw 0			; RAM destination step per repetition
t_src		dw 0
t_sy		db 0
t_sv		db 0			; 1: vertical source
t_sstr		dw 0			; source step per repetition
t_slo		dw 0			; source window (background bgS)
t_slen		dw 0
t_map		db 0
t_vpage		db 0
t_tpat		db 0
t_aux		db 0
t_aux2		dw 0
t_info		db 0			; 1: observation, not counted as pass/fail
t_nsp		db 0
t_spans		ds SPAN_SIZE * MAX_SPANS
t_blk_end:

r_bad		dw 0
r_addr		dw 0
r_y		db 0
r_exp		db 0
r_got		db 0

cur_y		db 0
sw_rows		db 0
sp_action	dw 0
e_j		db 0
e_i		dw 0
d_d		dw 0
d_s		dw 0
d_row		db 0
d_srow		db 0
d_cnt		db 0
d_op		dw 0

; ---- benchmarks ----
bm_body		dw 0
bm_cur		dw 0
bm_map		db 0
bm_vpage	db 0
bm_patch1	dw 0
bm_mode1	db 0
bm_patch2	dw 0
bm_mode2	db 0
bm_reps		dw 0
bm_real		dw 0
bm_null		dw 0
bm_spread	dw 0
bm_t0		dw 0
bp_hl		dw 0
bp_de		dw 0
bp_n		dw 0
bp_c		db 0
bp_y		db 0
bp_w		dw 0			; byte used, high byte kept 0
bp_h		dw 0

vi_kind		db 0
vi_first	db 0
vi_last		db 0
vi_fval		db 0
vi_mrow		db 0

sc_fn		dw 0
sc_res		dd 0
sc_val		db 0
sc_cnt		db 0

; ---- WIN1 scratch for tests that must not remap (decoder, HALT, observations)
; and for the sprites of the visual screens ----
SCRATCH_SIZE	equ 2048
		ALIGN 256
scratch		ds SCRATCH_SIZE
stage		ds 256			; file write staging buffer
hot_bss_end:
