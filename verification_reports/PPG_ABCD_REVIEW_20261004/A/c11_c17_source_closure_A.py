from pathlib import Path
import re,json,csv,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md';ml=(S/matrix).read_text(encoding='utf-8').splitlines()
files={'C11':'contracts/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md','C17':'contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md'}
modules={'C11':'ppg_adc_s1_programmable_calibrator','C17':'ppg_idac_code_controller'}
cl={k:(S/v).read_text(encoding='utf-8').splitlines() for k,v in files.items()};mods={}
for k,name in modules.items():
 g=json.loads((E/'gates'/f'{name}.json').read_text(encoding='utf-8'))
 mods[k]=next(m for f in g['quality_gate']['ast_report']['files'] for m in f['modules'] if m['name']==name)
def token(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
assert not token('o_frame_id','| input | `i_frame_id` | 16 |')
assert not token('i_stage1_weight_q16_4','')
assert 'i_stage1_weight_q16_0..9' in cl['C11'][254] and not token('i_stage1_weight_q16_4',cl['C11'][254])
assert token('i_stop_ack_event',cl['C17'][289]) and not token('i_clk',cl['C17'][289])
(O/'C11_C17_source_controls.json').write_text(json.dumps({'opposite_direction_prefix_rejected':True,'blank_rejected':True,
 'ten_weight_definition_is_group_not_literal_gap':True,'lifecycle_paragraph_matches_only_its_real_named_events':True},indent=2),encoding='utf-8')
records=[]
for n in list(range(2026,2148))+list(range(2683,2736)):
 cells=[v.strip() for v in ml[n-1].split('|')];code=cells[1];assert code in files
 name=re.fullmatch(r'`(\w+)`',cells[4])[1];ref=re.search(r'([\w/]+\.md):(\d+)',cells[2]);assert ref
 ln=int(ref[2]);lines=cl[code];target=lines[ln-1]
 p=next(p for p in mods[code]['ports'] if p['name']==name);assert p['direction']==cells[3]
 rtl=f'rtl/{modules[code]}/{modules[code]}.v'
 assert token(name,(S/rtl).read_text(encoding='utf-8').splitlines()[p['line_start']-1])
 if token(name,target):
  assert code=='C17' and n in (2031,2033)
  state='accepted_current_named_lifecycle_rule';current=ln
  reason='Current STOP/abort cancellation rule expressly names this port; not an invalid anchor merely because it is prose.'
 else:
  state='confirmed_wrong_source_line'
  if code=='C17':
   candidates=[i for i,l in enumerate(lines,1) if 152<=i<=277 and re.match(r'^\s*(?:input|output)\b',l) and token(name,l)]
   if candidates:assert len(candidates)==1;current=candidates[0]
   elif name=='i_status_clear_event':
    current=305;assert token('i_diag_clear_event',lines[current-1])
    assert '### F-032' in (B/'PPG_FULL_REVIEW_20261002.md').read_text(encoding='utf-8')
   else:
    assert name in ('i_test_inject_enable','i_test_saturation_inject_valid','o_test_saturation_inject_ready') and token(name,lines[2]),(n,name)
    current=3
  else:
   candidates=[i for i,l in enumerate(lines,1) if 246<=i<=296 and re.match(r'^\| (?:input|output) \| `'+re.escape(name)+r'` \|',l)]
   if candidates:assert len(candidates)==1;current=candidates[0]
   elif name.startswith('i_stage1_weight_q16_'):
    assert int(name.rsplit('_',1)[1]) in range(10) and 'i_stage1_weight_q16_0..9' in lines[254];current=255
   else:
    assert n in range(2727,2736) and '其余同名元数据' in lines[296];current=297
  reason='Current Source is blank/fence, parameter/other-direction port, unrelated threshold or handshake, or wrong payload field. Current named definition/ten-weight/metadata group checked independently, with actual AST direction. Accepted C11 discard exemption concerns behavior, not the false index; no RTL missing-port finding is inferred.'
 records.append(dict(matrix_line=n,contract=code,port=name,direction=cells[3],reference=ref[0],contract_line=ln,target=target,
  state=state,current_definition_line=current,current_definition_text=lines[current-1],rtl_declaration_line=p['line_start'],reason=reason))
counts=collections.Counter(r['state'] for r in records);assert len(records)==175 and counts['confirmed_wrong_source_line']==173 and counts['accepted_current_named_lifecycle_rule']==2,counts
(O/'C11_C17_source_rows_175.json').write_text(json.dumps({'counts':dict(counts),'records':records,'reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'limits':'Exact Source/port ruling. Does not alter accepted conditional discard exemption or independently prove every functional rule.'},ensure_ascii=False,indent=2),encoding='utf-8')
with (O/'C11_C17_source_rows_175.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
p=E/'anchor_failures.csv';rows=list(csv.DictReader(p.read_text(encoding='utf-8-sig').splitlines()))
key=lambda r:(r['source'],str(r['line']),r['reference'],r['expected']);keys={key(r) for r in rows}
for r in records:
 if r['state']!='confirmed_wrong_source_line':continue
 row=dict(source=matrix,line=r['matrix_line'],reference=r['reference'],kind='explicit_file_line',expected=r['port'],status='text_mismatch',target=r['target'])
 if key(row) not in keys:rows.append(row);keys.add(key(row))
ac=collections.Counter(r['status'] for r in rows);assert ac['text_mismatch']>=554 and ac['out_of_bounds']==14,ac
with p.open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
p=B/'PPG_FULL_REVIEW_20261002.md';text=p.read_text(encoding='utf-8');a=text.index('### F-003');z=text.index('### F-',a+8);block=text[a:z]
if 'C11/C17的175条Source' not in block:
 block=block.replace('不能当成381个独立功能错误。','不能当成554个独立功能错误。')
 block+='\n进一步逐项核对C11/C17的175条Source：C17两个STOP/abort同名规则合法，其余173条失效并入同一F003。当前累计554处文字失配及14越界；不能视作554项功能错误。现行明确端口/十权重组/其余原子元数据组均有合同来源和真实RTL端口，不把用户接受的C11 discard条件豁免重复报作缺实现。静态确认，逐条当前原文、真实行号、反驳及负对照见global_closure_20261004/C11_C17_source_rows_175.json/csv。\n\n'
 text=text[:a]+block+text[z:]
heading='## A C11/C17 Source语义裁定：2026-10-04'
if heading not in text:text+='\n'+heading+'\n\n完整核对C11当前53条Source、C17当前122条Source；共173条引用指向空行、围栏、参数、错误方向端口、阈值说明或无关规则。C17 STOP/abort的两个当前同名取消条款合法。正确来源逐条按当前完整声明、规范端口表及允许的十权重/同名元数据组定位，没有套偏移。C11受条件保护的discard广播豁免保持原裁定，不因为错误来源推断缺RTL。证据和负对照均在global_closure_20261004。本轮Source人工裁定累计628条，F003累计554文字失配+14越界。\n'
p.write_bytes(text.replace('\n','\r\n').encode('utf-8'));print('SOURCE175',dict(counts),'F003',dict(ac))
