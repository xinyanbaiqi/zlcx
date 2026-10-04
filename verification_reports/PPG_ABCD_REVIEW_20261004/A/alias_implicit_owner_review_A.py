from pathlib import Path
import re,json,collections,sys
B=Path(__file__).resolve().parent;S=B/'snapshot';O=B/'evidence/global_closure_20261004'
short={'idac':'ppg_idac_code_controller.v','ami':'ppg_adc_measurement_idac_integration.v','sched':'ppg_400hz_frame_calibration_scheduler.v',
 'ssw':'ppg_sar9_sar15_safe_selection_wrapper.v','dbc':'ppg_dynamic_baseline_cross_detector.v','pvw':'ppg_peak_valley_window_detector.v',
 'fir':'ppg_coarse_detection_fir.v','manager':'ppg_system_config_manager.v','ccc':'ppg_characterization_control_cdc.v',
 's1':'ppg_adc_s1_programmable_calibrator.v','pwc':'ppg_precision_window_controller.v',
 'startup_tb':'tb_ppg_control_top_startup_idac_calibration.v','pvw_tb':'tb_ppg_peak_valley_window_detector.v',
 'pwc_tb':'tb_ppg_precision_window_controller.v','fir_tb':'tb_ppg_coarse_detection_fir.v',
 'pvw_c':'PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md','pwc_c':'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md',
 'fir_c':'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md','matrix':'PPG_CONTRACT_CLOSURE_MATRIX.md'}
# Explicit reviewer decisions based on the actor and mechanism named by each
# current alias paragraph. Not a nearest-filename heuristic.
groups={'idac':[112,149,213,214,215,218,219,221,288], 'ssw':[144,145,172,245,246,247,248,252,253,281,282,283,284,285,286,287],
 'ami':[147,462,475,476], 'dbc':[183,201], 'pvw':[185,186,341], 'fir':[231,302],
 'manager':[241,251], 'sched':[237], 'ccc':[255], 's1':[264,266], 'pvw_c':[298],
 'pvw_tb':[305], 'pwc_c':[358,362], 'pwc_tb':[391], 'fir_c':[408,412,434], 'fir_tb':[416,436]}
owner={n:k for k,ns in groups.items() for n in ns}
specific={(137,1):'idac',(137,3):'ami',(142,1):'sched',(142,3):'startup_tb',
 (277,1):'idac',(277,2):'ssw',(277,3):'ssw',(277,5):'idac',
 **{(277,n):'ssw' for n in range(6,13)},(303,0):'matrix',(303,1):'fir_c',(303,2):'fir_c',
 (369,4):'pwc_tb',(369,6):'pwc',(369,7):'pwc',(406,1):'pwc_tb',(406,2):'pwc_tb',(406,4):'pwc'}
files=collections.defaultdict(list)
for p in S.rglob('*'):
 if p.is_file():files[p.name].append(p)
rows=json.loads((O/'implicit_reference_inventory_A.json').read_text(encoding='utf-8'))['records']
alias=[r for r in rows if r['source'].endswith('TABLE.md')];records=[];cache={}
for r in alias:
 key=(r['line'],r['ordinal']);actor=specific.get(key,owner.get(r['line']));assert actor is not None,key
 name=short[actor];assert len(files[name])==1,(key,name)
 p=files[name][0]
 if p not in cache:cache[p]=p.read_text(encoding='utf-8').splitlines()
 tokens=r['reference'].strip('`').lstrip(':').split(',');nums=[]
 for t in tokens:
  if '-' in t:a,z=map(int,t.split('-'));nums+=list(range(a,z+1))
  else:nums.append(int(t))
 assert all(1<=n<=len(cache[p]) for n in nums),(key,name,nums)
 spans=[dict(line=n,text=cache[p][n-1]) for n in nums]
 records.append(dict(**r,resolved_actor=actor,resolved_file=p.relative_to(S).as_posix(),
  target_lines=spans,file_resolution='Reviewer fixed mapping from the named actor/ID family, not nearest-file inference.',
  review_state='actual_target_text_read_pending_semantic_ruling'))
assert len(records)==105
(O/'alias_implicit_owner_review_A.json').write_text(json.dumps(dict(records=records,count=len(records),
 note='File resolution and exact text are established. Remaining review_state must not be counted as semantic acceptance.'),ensure_ascii=False,indent=2),encoding='utf-8')
start=int(sys.argv[1]) if len(sys.argv)>1 else 0;end=int(sys.argv[2]) if len(sys.argv)>2 else 55
for i,r in enumerate(records[start:end],start):
 text=' / '.join(f'{x["line"]}:{x["text"].strip()}' for x in r['target_lines'])
 print(i,'ALIAS',r['line'],r['reference'],r['resolved_actor'],text[:500])
