from review import *
import re

def read(rel,start,end):
 p=SNAP/rel
 print('\n'+rel)
 for n,line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(),1):
  if start<=n<=end:print(f'{n}: {line}')

if sys.argv[1]=='id_mismatch':
 read('contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md',1130,1170)
 for start,end in [(557,595),(700,725),(897,936)]:read('rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v',start,end)
 read('contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md',152,161)
 read('rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v',463,494)
elif sys.argv[1]=='samples':
 for rel,start,end in [
 ('rtl/ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v',326,345),
 ('rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v',571,605),
 ('rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v',980,1002),
 ('rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v',727,766),
 ('rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v',830,850),
 ('rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v',61,66),
 ('contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',196,202)
 ]:read(rel,start,end)
elif sys.argv[1]=='amr':
 p=SNAP/'rtl/ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v'
 for n,line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(),1):
  if any(s in line for s in ['AMR-','check_case(','AMB','epoch','outlier','PPG','measurement','确认']):print(f'{n}: {line}')
elif sys.argv[1]=='registry_families':
 for name in ['PPG_CONTRACT_CLOSURE_MATRIX.md','PPG_ALIAS_MAPPING_TABLE.md']:
  print('\n'+name)
  for n,line in enumerate((SNAP/'contracts'/name).read_text(encoding='utf-8-sig').splitlines(),1):
   if ('| C' in line or '| G-FP' in line or 'AMI-' in line) and re.search(r'FSC|SSW|AMI|AMR|IDT|PWI|SUP|C08|C09|C10|C16|C18|C24',line) and len(line)<1500:
    if n<1220 or 3550<n<3670: print(f'{n}: {line}')
