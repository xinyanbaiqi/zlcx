from pathlib import Path
import json,re,csv,collections,copy
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
mapping={
 'C01':['ppg_control_top','ppg_active_v4_control_plane_integration','ppg_characterization_control_cdc','ppg_400hz_frame_calibration_scheduler','ppg_sar9_sar15_safe_selection_wrapper','ppg_adc_measurement_idac_integration','ppg_system_fault_abort_supervisor'],
 'C02':['ppg_system_config_manager'], 'C03':['ppg_active_v4_control_plane_integration'],
 'C04':['ppg_system_active_config_unpack','ppg_active_v4_control_plane_integration','ppg_system_config_manager','ppg_config_cdc_bridge','ppg_adc_measurement_idac_integration','ppg_adc_s1_programmable_calibrator'],
 'C05':['ppg_system_active_config_unpack'],'C07':['ppg_characterization_control_cdc'],
 'C08':['ppg_400hz_frame_calibration_scheduler'],'C09':['ppg_sar9_sar15_safe_selection_wrapper'],
 'C10':['ppg_adc_measurement_idac_integration','ppg_adc_async_stage_capture','ppg_adc_s1_redundancy_corrector','ppg_adc_result_router'],'C11':['ppg_adc_s1_programmable_calibrator'],
 'C13':['ppg_adc_pipeline_overlap_corrector'],'C14':['ppg_adc_programmable_reconstructor'],
 'C15':['ppg_adc_dc_recovery'],'C16':['ppg_normal_transaction_fork','ppg_amb_recheck_scheduler'],
 'C17':['ppg_idac_code_controller'],'C19':['ppg_coarse_detection_fir'],
 'C20':['ppg_dynamic_baseline_cross_detector'],'C22':['ppg_peak_valley_window_detector'],
 'C23':['ppg_precision_window_controller'],'C24':['ppg_system_fault_abort_supervisor']}
mods={}
for gate in (E/'gates').glob('*.json'):
 for f in json.loads(gate.read_text(encoding='utf-8'))['quality_gate']['ast_report']['files']:
  for m in f.get('modules',[]):mods[m.get('name',m.get('module_name'))]=m
for code,names in mapping.items():
 for name in names:assert name in mods,(code,name)

def check(port,direction,possible):
 hits=[(module,p) for module,ps in possible.items() for p in ps if p['name']==port]
 if not hits:return 'missing_name_candidate',[]
 if not any(p['direction']==direction for _,p in hits):return 'direction_candidate',hits
 return 'name_direction_match',hits
fixture={'fixture_module':[{'name':'i_a','direction':'input'},{'name':'o_b','direction':'output'}]}
controls=[('good',check('i_a','input',fixture)[0],'name_direction_match'),
 ('missing',check('i_missing','input',fixture)[0],'missing_name_candidate'),
 ('direction',check('o_b','input',fixture)[0],'direction_candidate')]
assert all(actual==expected for _,actual,expected in controls),controls
def expand_group(value):
 m=re.fullmatch(r'`([A-Za-z0-9_]+_)(\d+)\.\.(\d+)`',value)
 if not m or int(m[3])<int(m[2]):return None
 return [m[1]+str(i) for i in range(int(m[2]),int(m[3])+1)]
assert expand_group('`i_weight_0..2`')==['i_weight_0','i_weight_1','i_weight_2']
assert expand_group('`i_weight_2..0`') is None
gp={'group_fixture':[{'name':n,'direction':'input'} for n in expand_group('`i_weight_0..2`') if n!='i_weight_1']}
assert [n for n in expand_group('`i_weight_0..2`') if check(n,'input',gp)[0]!='name_direction_match']==['i_weight_1']
controls.append(('removed_group_member',['i_weight_1'],['i_weight_1']))
(O/'ledger_port_inventory_controls.json').write_text(json.dumps(controls,indent=2),encoding='utf-8')
rows=[]
for n,l in enumerate((S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines(),1):
 c=[x.strip() for x in l.split('|')]
 if len(c)<7 or c[1] not in mapping or c[3] not in ('input','output','inout'):continue
 name=re.fullmatch(r'`([A-Za-z0-9_]+)`',c[4])
 if not name:
  expanded=expand_group(c[4])
  hits_by_name=[check(item,c[3],{m:mods[m]['ports'] for m in mapping[c[1]]}) for item in expanded] if expanded else []
  state='expanded_group_match' if expanded and all(x[0]=='name_direction_match' for x in hits_by_name) else 'grouped_unresolved'
  rows.append(dict(line=n,contract=c[1],name=c[4],direction=c[3],state=state,
   modules=';'.join(sorted({m for _,hs in hits_by_name for m,p in hs})),
   declaration_lines=';'.join(item+':'+','.join(str(p['line_start']) for m,p in hs) for item,(_,hs) in zip(expanded or [],hits_by_name))))
  continue
 state,hits=check(name[1],c[3],{m:mods[m]['ports'] for m in mapping[c[1]]})
 if n==1633:
  assert c[1]=='C03' and name[1]=='o_system_fault_blocking' and 'defect finding' in c[6] and 'phantom/mis-filed' in c[6]
  assert state=='missing_name_candidate'
  assert check(name[1],'output',{'ppg_control_top':mods['ppg_control_top']['ports']})[0]=='name_direction_match'
  state='explicitly_documented_phantom_row'
 rows.append(dict(line=n,contract=c[1],name=name[1],direction=c[3],state=state,
  modules=';'.join(m for m,p in hits),declaration_lines=';'.join(str(p['line_start']) for m,p in hits)))
with (O/'ledger_port_inventory.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
summary=dict(rows=len(rows),counts=dict(collections.Counter(r['state'] for r in rows)),
 by_contract={code:dict(collections.Counter(r['state'] for r in rows if r['contract']==code)) for code in mapping},
 mapping=mapping,limits='Name/direction existence using Erie AST; unions are needed for C01/C04/C16 multi-module contracts. This does not independently prove producer/consumer wiring, widths, resets, handshake or CDC semantics. Missing candidates need cross-file rebuttal.')
(O/'ledger_port_inventory_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('COUNTS',summary['counts']);print('NONLITERAL',[r for r in rows if r['state']!='name_direction_match'])
