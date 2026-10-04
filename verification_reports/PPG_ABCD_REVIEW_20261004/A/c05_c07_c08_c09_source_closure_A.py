from pathlib import Path
import json,csv,re,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'
contracts={
 'C05':'contracts/ppg_system_active_config_unpack_semantic_contract.md',
 'C07':'contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md',
 'C08':'contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md',
 'C09':'contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md'}
modules={'C05':'ppg_system_active_config_unpack','C07':'ppg_characterization_control_cdc',
 'C08':'ppg_400hz_frame_calibration_scheduler','C09':'ppg_sar9_sar15_safe_selection_wrapper'}
cl={k:(S/v).read_text(encoding='utf-8').splitlines() for k,v in contracts.items()}
ml=(S/matrix).read_text(encoding='utf-8').splitlines();mods={}
for code,name in modules.items():
 g=json.loads((E/'gates'/f'{name}.json').read_text(encoding='utf-8'))
 mods[code]=next(m for f in g['quality_gate']['ast_report']['files'] for m in f['modules'] if m['name']==name)
def token(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
def section(lines,n):
 end=next((i for i in range(n,len(lines)) if lines[i].startswith('#')),len(lines))
 return '\n'.join(lines[n-1:end])
# Genuine errors are injected into the recognizer before using its positive result.
assert token('o_field','| `o_field` | 1 |') and not token('o_field','| `o_field_extra` | 1 |')
assert not token('o_field','')
assert not token('i_clk',cl['C09'][445]) and token('i_clk',cl['C09'][460])
assert cl['C07'][94].startswith('###') and token('i_source_test_mux_ctrl',section(cl['C07'],95))
assert not token('i_source_test_mux_ctrl',section(cl['C07'],106))
assert not token('o_ssw_fault_frame_id',cl['C09'][606]) and '完整fault identity' in cl['C09'][606]
(O/'C05_C07_C08_C09_source_controls.json').write_text(json.dumps({
 'changed_identifier_rejected':True,'blank_rejected':True,
 'wrong_parameter_row_rejected_with_current_literal_definition':True,
 'wrong_clock_domain_section_rejected':True,
 'complete_identity_group_without_literal_field_not_auto_error':True},indent=2),encoding='utf-8')

groups5={67:['o_amb_manual_code','o_amb_code_min','o_amb_code_max'],
 68:['o_dcs_r_manual_code','o_dcs_r_code_min','o_dcs_r_code_max'],
 69:['o_dcs_ir_manual_code','o_dcs_ir_code_min','o_dcs_ir_code_max'],
 70:['o_amb_threshold_low','o_amb_threshold_high'],71:['o_dcs_threshold_low','o_dcs_threshold_high'],
 72:['o_amb_confirm_count','o_dcs_confirm_count'],73:[f'o_stage1_weight_q16_{i}' for i in range(10)]}
assigns5={a['lhs']:a for a in mods['C05']['assigns']}
records=[]
for n in range(1734,2026):
 cells=[v.strip() for v in ml[n-1].split('|')]
 if cells[1] not in contracts or cells[3] not in ('input','output','inout'):continue
 code=cells[1];name=re.fullmatch(r'`(\w+)`',cells[4])[1]
 ref=re.search(r'([\w/]+\.md):(\d+)',cells[2]);assert ref
 lineno=int(ref[2]);lines=cl[code];target=lines[lineno-1]
 port=next(p for p in mods[code]['ports'] if p['name']==name)
 assert port['direction']==cells[3]
 rtl=f'rtl/{modules[code]}/{modules[code]}.v'
 assert token(name,(S/rtl).read_text(encoding='utf-8').splitlines()[port['line_start']-1])
 current=lineno;extra={}
 if code=='C05':
  if lineno in groups5:
   assert name in groups5[lineno]
   state='accepted_current_field_group'
   groupnames=groups5[lineno]
  else:
   assert token(name,target),(n,name,target)
   state='literal_source_match';groupnames=re.findall(r'`(o_\w+)`',target)
  if name!='i_active_config':
   slices=re.findall(r'`\[([0-9]+(?::[0-9]+)?)\]`',target)
   if lineno==73:
    assert slices==['193:168','427:402']
    i=groupnames.index(name);expected=f'{193+26*i}:{168+26*i}'
   else:assert len(slices)==len(groupnames),(n,slices,groupnames);expected=slices[groupnames.index(name)]
   assert token('i_active_config',assigns5[name]['rhs']) and f'[{expected}]' in assigns5[name]['rhs'],(n,name,expected,assigns5[name])
   extra={'current_ast_assign_line':assigns5[name]['line_start'],'expected_slice':expected,'actual_rhs':assigns5[name]['rhs']}
  reason='Current named bitmap field or manually expanded Chinese/ten-weight group; all 67 output slices independently agree with canonical Erie AST assignments.'
 elif code=='C07':
  assert lineno in (95,106) and target.startswith('###') and token(name,section(lines,lineno)),(n,name,target)
  state='accepted_current_section_source';reason='Exact clock-domain heading; actual same-section port table contains the named port.'
 elif code=='C08':
  assert lineno in (839,854,875,886,913,939,962,977,1026) and target.startswith('###')
  text=section(lines,lineno)
  if not token(name,text):
   assert lineno==1026 and name.startswith('o_scheduler_fault_') and 'full ID' in text,(n,name,text)
   state='accepted_complete_identity_group';reason='Current generation/fault section explicitly includes full ID; actual scheduler AST contains this identity field.'
  else:state='accepted_current_section_source';reason='Current group heading followed by the exact current named port or generation/fault prose.'
 else:
  # All eight frozen Source targets were read literally; no uniform offset is used.
  assert lineno in (446,468,483,508,526,537,578,600) and not token(name,target),(n,name,target)
  if 1976<=n<=2003:
   candidates=[i for i,l in enumerate(lines,1) if 552<=i<=581 and re.match(r'^'+re.escape(name)+r'(?:\[|$)',l)]
  else:
   candidates=[i for i,l in enumerate(lines,1) if 457<=i<=608 and re.match(r'^\| `'+re.escape(name)+r'`(?:\s*\||和)',l)]
  if candidates:assert len(candidates)==1,(n,name,candidates);current=candidates[0]
  elif name in ('i_test_inject_enable','i_context_handover_stall_request','o_owner_q3_window_closed'):
   current=4;assert token(name,lines[current-1])
  else:
   assert name.startswith('o_ssw_fault_') and '完整fault identity' in lines[606]
   current=607
  state='confirmed_wrong_source_line'
  reason='Actual frozen Source points to a different parameter, different port, wrong interface heading or unrelated sticky. Current exact definition or explicitly complete identity group is verified; no historical Source override or normative exception permits the wrong target. Index-only error, not an RTL functional gap.'
 records.append(dict(matrix_line=n,contract=code,port=name,direction=cells[3],reference=ref[0],
  contract_line=lineno,target=target,state=state,current_definition_line=current,
  current_definition_text=lines[current-1],rtl_declaration_line=port['line_start'],reason=reason,**extra))
counts=collections.Counter(r['state'] for r in records);bycontract=collections.Counter(r['contract'] for r in records)
assert len(records)==291 and bycontract=={'C05':68,'C07':16,'C08':106,'C09':101} and counts['confirmed_wrong_source_line']==101,(counts,bycontract)
(O/'C05_C07_C08_C09_source_rows_291.json').write_text(json.dumps({'reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'counts':dict(counts),'by_contract':dict(bycontract),'records':records,
 'limits':'Source and canonical AST declaration/bit-slice ruling. Does not substitute for all per-port reset/CDC/priority/wiring checks.'},ensure_ascii=False,indent=2),encoding='utf-8')
fields=list(dict.fromkeys(k for r in records for k in r))
with (O/'C05_C07_C08_C09_source_rows_291.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(records)
p=E/'anchor_failures.csv';rows=list(csv.DictReader(p.read_text(encoding='utf-8-sig').splitlines()))
key=lambda r:(r['source'],str(r['line']),r['reference'],r['expected']);keys={key(r) for r in rows}
for r in records:
 if r['state']!='confirmed_wrong_source_line':continue
 row=dict(source=matrix,line=r['matrix_line'],reference=r['reference'],kind='explicit_file_line',expected=r['port'],status='text_mismatch',target=r['target'])
 if key(row) not in keys:rows.append(row);keys.add(key(row))
anchor_counts=collections.Counter(r['status'] for r in rows)
assert anchor_counts['text_mismatch']>=381 and anchor_counts['out_of_bounds']==14,anchor_counts
with p.open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
p=B/'PPG_FULL_REVIEW_20261002.md';text=p.read_text(encoding='utf-8');a=text.index('### F-003');z=text.index('### F-',a+8);block=text[a:z]
if 'C05/C07/C08/C09的291条Source' not in block:
 block=block.replace('不能当成280个独立功能错误。','不能当成381个独立功能错误。')
 block+='\n本批继续人工裁定C05/C07/C08/C09的291条Source：68个C05字段（67个输出切片也与Erie AST一致）、16个C07域端口组及106个C08当前章节/完整身份组合法；101个C09 Source均指向其他参数、端口或错误章节，已逐项定位当前明确定义/完整身份组。并入同一F003，当前累计381处文字失配和14越界，不增加独立发现条数。静态确认；原引用、真实现行定义行、实际RTL声明行、反驳和负对照见global_closure_20261004/C05_C07_C08_C09_source_rows_291.json/csv。\n\n'
 text=text[:a]+block+text[z:]
heading='## A C05/C07/C08/C09 Source语义裁定：2026-10-04'
if heading not in text:
 text+='\n'+heading+'\n\n本批291条Source不依赖长回归，已逐条交叉核对当前合同、矩阵和规范Erie AST：C05 68条、C07 16条、C08 106条均接受当前字面/字段组/章节组/完整身份来源；C09 101条Source确认指向其他参数、端口、错误接口章节或无关sticky，并入F003失效引用汇总。C09身份各字段由§7.8完整fault identity和§7.9约束覆盖，不误报缺RTL；测试注入及Q3新增输出有当前第4行明确定义，不根据日期或固定偏移推算行号。C05 67个输出切片逐项复用Erie AST静态核对一致；未将此扩张为全部G-FP复位/CDC/时序签核。累计已单独裁定C02至C09相关453条Source，保留C03两处来源范围歧义。\n'
p.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('SOURCE291',dict(counts),dict(bycontract),'F003',dict(anchor_counts))
