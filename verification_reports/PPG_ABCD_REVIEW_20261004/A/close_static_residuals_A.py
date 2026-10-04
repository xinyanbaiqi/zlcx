from pathlib import Path
import csv,json,re,collections,datetime,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
ml=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
al=(S/'contracts/PPG_ALIAS_MAPPING_TABLE.md').read_text(encoding='utf-8').splitlines()
manager=(S/'contracts/ppg_system_config_manager_semantic_contract.md').read_text(encoding='utf-8').splitlines()
ssw=(S/'rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v').read_text(encoding='utf-8').splitlines()
assert 'ppg_sar9_sar15_safe_selection_' in ml[3454] and 'wrapper.v:480' in ml[3455]
safe_line=next(n for n,line in enumerate(ssw,1) if 'assign o_analog_safe =' in line)
assert safe_line==482 and not ssw[479].strip()
assert 'start_ready = active_valid' in manager[310]
assert 'semantic_contract.md:297' in ml[1592] and 'semantic_contract.md:297' in ml[1639]
missing=[r for r in json.loads((E/'anchor_scan_v2.json').read_text(encoding='utf-8'))['references'] if r['status']=='missing_file']
assert len(missing)==6
rulings=[]
for r in missing:
 n=r['source_line'];rec={**r}
 if r['reference']=='wrapper.v:480':
  rec.update(state='line_wrapped_filename_resolved_but_index_stale',resolved_path='rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v',resolved_line=480,resolved_text=ssw[479],current_definition_line=safe_line,current_definition_text=ssw[safe_line-1],reason='Filename split over adjacent Markdown3455/3456 resolves to the real SSW. Referenced480 is blank; exact current assign is482. Index wrong, mechanism really present; merge F003.')
 elif r['reference']=='semantic_contract.md:297':
  rec.update(state='abbreviated_manager_filename_with_existing_stale_formula',resolved_path='contracts/ppg_system_config_manager_semantic_contract.md',resolved_line=297,resolved_text=manager[296],current_definition_line=311,current_definition_text=manager[310],reason='Owning C02/manager context in actual row identifies abbreviated basename; formula297 is stale, already represented by F003 Source1593. Row1640 inherits that same formula reference. No nonexistent RTL or new independent defect.')
 else:
  assert r['source']=='contracts/PPG_ALIAS_MAPPING_TABLE.md' and n in (172,175,176)
  assert 'PPG_SESSION_HANDOFF_20260826_2.md' in al[n-1]
  rec.update(state='external_historical_support_unavailable',reason='Quoted historic handoff is not present in fixed repository; cannot inspect its asserted static proof. Current OIB mechanisms/TB checked directly and F042 retains actual OIB06 monitoring gap. Record missing supporting artifact as an audit limit, not assume source correctness or new hardware bug.')
 rulings.append(rec)
(O/'missing_file_candidate_adjudication_A.json').write_text(json.dumps(rulings,ensure_ascii=False,indent=2),encoding='utf-8')
af=E/'anchor_failures.csv';ar=list(csv.DictReader(af.read_text(encoding='utf-8-sig').splitlines()));fields=list(ar[0]);keys={(r['source'],int(r['line']),r['reference'],r['expected']) for r in ar}
for r in rulings:
 if r['state']=='external_historical_support_unavailable':continue
 row=dict(source=r['source'],line=r['source_line'],reference=r['reference'],kind='abbreviated_or_line_wrapped_context',expected='o_analog_safe' if r['reference'].startswith('wrapper') else 'start_ready',status='text_mismatch',target=r['resolved_text'])
 key=(row['source'],int(row['line']),row['reference'],row['expected'])
 if key not in keys:ar.append(row);keys.add(key)
with af.open('w',encoding='utf-8',newline='') as fh:
 w=csv.DictWriter(fh,fieldnames=fields);w.writeheader();w.writerows(ar)
width=json.loads((O/'contract_width_crosscheck_A.json').read_text(encoding='utf-8'))
gate=json.loads((E/'gates/ppg_system_config_manager.json').read_text(encoding='utf-8'))
m=gate['quality_gate']['ast_report']['files'][0]['modules'][0]
assert {p['name'] for p in m['params']}=={'C_CONFIG_WIDTH','C_RUN_GENERATION_WIDTH'}
assert len(width['not_evaluable'])==4
width_rulings=[]
actual_lines=(S/'rtl/ppg_system_config_manager/ppg_system_config_manager.v').read_text(encoding='utf-8').splitlines()
for r in width['not_evaluable']:
 assert r['contract']=='C02' and r['contract_line']==100
 p=next(p for p in m['ports'] if p['name']==r['port'])
 assert p['width']=='[7:0]' and r['port'] in actual_lines[p['line_start']-1]
 width_rulings.append({**r,'state':'known_existing_F024_public_parameter_absence','actual_width':8,
  'rtl_line':p['line_start'],'rtl_text':actual_lines[p['line_start']-1],
  'reason':'All four default eight-bit epochs exist; the named public epoch-width parameters do not. This is existing F024, not another default truncation or an unperformed future check.'})
(O/'grouped_width_manual_rulings_A.json').write_text(json.dumps(width_rulings,ensure_ascii=False,indent=2),encoding='utf-8')
# Do not turn audit coverage into product-signoff coverage. Each RTL/contract
# file already has module-specific semantic records; A's additional cross-layer
# mechanical sweep does not override known project G-FP/ASIC limitations.
source=json.loads((O/'source_adjudication_summary_A.json').read_text(encoding='utf-8'))
assert source['reviewed_rows']==1860 and not source['states'].get('scope_ambiguous_not_counted',0)
decisions=dict(updated_at=datetime.datetime.now().isoformat(timespec='seconds'),
 completed=dict(module_and_contract_semantics='B/C/D detailed file evidence and A independent rebuttals are incorporated; findings derive from current source and actual probes.',
  source_rows=1860,source_pending=0,source_scope_ambiguities=0,explicit_width_checks=799,explicit_sign_checks=sum(r['explicit_sign_check'] for r in width['records']),
  grouped_width_manual_rulings=4,missing_file_candidates=6,id_candidate_four_links=838,id_families_with_semantic_sample=46,
  top_ports=165,explicit_decl_anchors=516,dependency_rows=141,manifest_digests=26,alias_tag_associations=367),
 audit_limits=['9247 references mechanically checked; bounds-only/non-Source implicit-file notes are not all independently assigned an expected token. Do not claim every reference is semantically valid.',
  'Three historical external handoff references unavailable; current mechanisms are checked directly.',
  'Project G-FP reset/CDC/priority signoff of every clustered ledger row is not recreated; detailed module-port semantic review and explicit cross-layer samples are performed. This is distinct from source-index pending work.',
  'No Vivado/xsim, Verilator, synthesis or ASIC CDC/signoff tool; cannot run those checks.',
  'F044 remains suspected pending definition of acceptable P06 entry-layer coverage; do not force an impossible RUN leaf input change.'],
 active_work=['Four full original long regressions, raw final logs and baseline comparison. Automatically refresh factual table; investigate any unexpected final failure before declaring overall completion.'],
 no_pending_source_ruling=True)
(O/'static_residual_disposition_A.json').write_text(json.dumps(decisions,ensure_ascii=False,indent=2),encoding='utf-8')
report=B/'PPG_FULL_REVIEW_20261002.md';t=report.read_text(encoding='utf-8');heading='## A 剩余人工核对裁定及范围：2026-10-04'
if heading not in t:
 t+='\n'+heading+'\n\n本批完成1860条Source、两处C03歧义、6个缺文件候选及显式默认位宽补充核对。799处位宽一致，其中41处明示signed/unsigned属性也一致；改变位宽/翻转符号负对照恰好报出两处故意错误，两个正确对照无误报。4处无法按合同参数名求值已实际人工核实：manager的四个epoch为固定8-bit，但仅声明CONFIG_WIDTH/RUN_GENERATION_WIDTH两个公开参数，归入原F024，不再留作未来待办。\n\n缺文件候选中1处是换行拆开的真实SSW文件名，但引用:480为空，逐字找到实际o_analog_safe赋值:482；2处是C02缩写文件名与已报F003的旧start_ready公式在说明列再次出现；这3个引用出现位置并入F003，现643文字失配及14越界。3处外部历史handoff确实未入库，列为无法读取的证据限度，不编造其结论。非Source的bounds-only/省略文件名注释没有全量逐字语义签核，G-FP全部cluster逐字段项目签核与ASIC工具检查也未重建；这与已完成的模块端口语义审阅、1860 Source裁定和46家族抽查分开标明。F044仍是合同入口范围待owner裁定的疑似，不强行制造非法系统场景。详见static_residual_disposition_A.json。\n\n当前可在回归终态前完成的人工项目已完成并记录；剩余正在执行的是四份完整原长回归及其最终日志/基线核对。任何新FAIL或异常终态仍需人工反驳复核，不能由后台程序直接判成已确认功能错误。\n'
start=t.index('### F-003');end=t.index('\n### F-',start+1);block=t[start:end]
block=block.replace('确认640处','确认643处').replace('成640个','成643个').replace('以及390个合同Source索引。','以及390个合同Source索引和3个说明列缩写/跨行文件名索引。')
t=t[:start]+block+t[end:]
report.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
print('STATIC_RESIDUALS_DISPOSED',decisions['completed'],'LIMITS_EXPLICIT',len(decisions['audit_limits']))
