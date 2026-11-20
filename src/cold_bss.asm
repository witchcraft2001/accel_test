; cold_bss.asm -- cold variables (WIN2, not in the file, zeroed by cold_main).
cold_bss:
lb_buf		ds LB_MAX + 4
lb_len		db 0
o_mode		db 0			; bit 0 screen, bit 1 log
o_gfx		db 0
o_lines		db 0
o_abort		db 0
o_blk		dw 0
o_fpos		dw 0
o_chunk		dw 0
sv_sp		dw 0
sv_win1		db 0
		ds 128				; SetVMod stack (WIN2)
sv_stack_top:
o_lost		db 0			; log flushed in graphics mode: backlog incomplete
o_vmode		db 0
o_vscr		db 0
o_width		db 0
o_frac		db 0
o_neg		db 0
o_digits	ds 16
o_dptr		dw 0
o_cnt		db 0
log_ok		db 0
log_fh		db 0
log_err		db 0
log_pos		dw 0
log_name	ds 64

acc32		dd 0
arg32		dd 0
rem32		dd 0
tmp32		dd 0

opt_help	db 0
opt_bad		db 0
opt_auto	db 0
opt_quick	db 0
opt_four	db 0
opt_noh		db 0
opt_nolog	db 0
sel		db 0
sel_given	db 0
mem_id		db 0
mem_pages	ds 8
exit_code	db 0
at_info		dw 0
env_frame	dw 0
env_cpu		dw 0
env_mhz		dw 0

grp_name	dw 0
cur_name	dw 0
grp_pass	dw 0
grp_fail	dw 0
it_fn		dw 0
cur_p		db 0
cur_n		dw 0
n_list		dw 0
cur_op		db 0
t_aux2_tmp	dw 0
al_d0		db 0
al_s0		db 0
sv_lo		dw 0
sv_hi		dw 0
sv_y		dw 0

vo_op		db 0
vo_half		db 0
vo_w		db 0
vo_h		db 0
vo_tr		db 0
gs_y		db 0
gs_cx		db 0
gs_cy		db 0
vs_tab		dw 0
vs_bad		dw 0
vs_name		dw 0

bm_ptype	db 0
bm_par		db 0
bm_n		dw 0
bm_store	dw 0
bm_net		dw 0
bm_c100		dw 0
bm_list		dw 0
sum_list	dw 0
sum_fill	ds 4 * 22 * 2
sum_copy	ds 16 * 22 * 2
sum_i16		db 0
sum_i256	db 0
sum_len		db 0
sum_row		dw 0
sum_c16		dw 0
sum_slope	dw 0
sp_r0		dw 0
sp_rk		dw 0
sp_sum		dw 0

rc_kind		dw 0
rc_rows		dd 0
rc_cols		dd 0
rc_cpu		dd 0
rc_name		ds 32
rc_np		dw 0
