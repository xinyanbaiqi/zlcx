from pathlib import Path
import sys
base=Path(__file__).resolve().parent/'snapshot'
root='ppg_control_top_Inst.'
ami=root+'ppg_adc_measurement_idac_integration_Inst.'
pwi=ami+'ppg_precision_window_integration_Inst.'
changes=[(pwi+'ppg_peak_valley_window_detector_Inst.','PVW.'),(pwi+'ppg_dynamic_baseline_cross_detector_Inst.','BSL.'),(pwi+'ppg_coarse_detection_fir_Inst.','FIR.'),(pwi+'ppg_precision_window_controller_Inst.','PWC.'),(root+'ppg_400hz_frame_calibration_scheduler_Inst.','FSC.'),(root+'ppg_sar9_sar15_safe_selection_wrapper_Inst.','SSW.'),(pwi,'PWI.'),(ami,'AMI.'),(root,'TOP.')]
for arg in sys.argv[1:]:
 rel,rng=arg.rsplit('@',1);a,z=map(int,rng.split('-'));p=base/rel;ls=p.read_text(encoding='utf-8').splitlines();print('FILE',rel,'TOTAL',len(ls))
 for i in range(a-1,min(z,len(ls))):
  x=ls[i].split('//')[0].strip()
  if not x:continue
  for before,after in changes:x=x.replace(before,after)
  print(f'{i+1}: {x}')
