from pathlib import Path
from native_probe import run
B=Path(__file__).resolve().parent;S=B/'snapshot'
E=B.parent.parent/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/evidence'
for case,mod in [('pwc_cancel_commit','ppg_precision_window_controller'),('ssw_abort_done','ppg_sar9_sar15_safe_selection_wrapper')]:
 original=S/'rtl'/mod/(mod+'.v');tb=E/case/('tb_'+mod+'.v')
 r=run('A_'+case,[original,tb],'tb_'+mod);assert (r['compile_rc'],r['run_rc'])==(0,1)
 variant=E/(case+'_counterfactual')/(mod+'.v')
 r=run('A_'+case+'_countercontrol',[variant,tb],'tb_'+mod);assert (r['compile_rc'],r['run_rc'])==(0,0)
print('PWC_SSW_A_INDEPENDENT_RUNS_CONFIRMED')
