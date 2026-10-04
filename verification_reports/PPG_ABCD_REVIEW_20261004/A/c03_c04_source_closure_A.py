from pathlib import Path
import json,csv,re,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'
c03='contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md'
c04='contracts/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md'
ml=(S/matrix).read_text(encoding='utf-8').splitlines()
cl3=(S/c03).read_text(encoding='utf-8').splitlines();cl4=(S/c04).read_text(encoding='utf-8').splitlines()
def token(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
# Rebuttal: a correctly named group is legitimate even without every full port.
# Classification choices below are manual, not inferred from a generic regex.
assert token('o_field','output o_field;') and not token('o_field','output o_field_extra;')
assert not token('o_field','')
assert '十个Stage1' in cl3[242] and not token('o_stage1_weight_q16_3',cl3[242])
assert token('o_stage1_weight_q16_0',cl4[301].replace('_0..9','_0'))
(O/'C03_C04_source_negative_controls.json').write_text(json.dumps({'changed_identifier_rejected':True,
 'blank_rejected':True,'ten_weight_group_without_literal_member_not_auto_error':True,
 'group_member_expansion_checked_separately':True},ensure_ascii=False,indent=2),encoding='utf-8')

correct={1605:151,1606:150,1607:154,1608:108,1609:152,1610:153,1611:109,
 1612:87,1613:89,1614:90,1615:88,1616:110,1617:114,1618:112,1619:111,1620:113,
 1621:226,1622:174,1623:176,1624:229,1625:228,1626:231,1627:175,1628:179,
 1629:230,1630:177,1631:178,1634:136,1636:137}
assert len(correct)==29
gate=json.loads((E/'gates/ppg_active_v4_control_plane_integration.json').read_text(encoding='utf-8'))
module=next(m for f in gate['quality_gate']['ast_report']['files'] for m in f['modules'] if m['name']=='ppg_active_v4_control_plane_integration')
ports={p['name']:p for p in module['ports']}
rtl='rtl/ppg_active_v4_control_plane_integration/ppg_active_v4_control_plane_integration.v'
source=(S/rtl).read_text(encoding='utf-8').splitlines()
records=[]
for n in range(1605,1708):
 cells=[v.strip() for v in ml[n-1].split('|')];assert cells[1]=='C03'
 name=re.fullmatch(r'`(\w+)`',cells[4])[1]
 ref=re.search(r'([\w/]+\.md):(\d+)',cells[2]);assert ref
 target_line=int(ref[2]);target=cl3[target_line-1]
 current=correct.get(n)
 if n in correct:
  assert name in ports and ports[name]['direction']==cells[3]
  assert token(name,source[ports[name]['line_start']-1])
  assert not token(name,target) and token(name,cl3[current-1]),(n,name,target,current)
  state='confirmed_wrong_source_line'
  reason='Current target is blank, fence, parameter override, exclusion list or unrelated rule; current explicit definition found and source line checked literally. No historical override in Source.'
 elif 1641<=n<=1707:
  assert 239<=target_line<=249 and '逐项导出其具名输出' in cl3[236] and '名称、位宽和signed属性' in cl3[250]
  assert name in ports and ports[name]['direction']=='output'
  state='accepted_current_group_source'
  reason='C03§8 groups forwarded C05 named outputs; group prose need not spell every o_ prefix. Names/directions checked against real wrapper AST; group semantics manually read.'
 elif n==1632:
  assert target_line==168 and '生命周期' in target and token(name,cl3[179])
  state='accepted_current_section_source';reason='Section6 lifecycle heading plus same section180 exact STOP episode definition; no loss of implementation.'
 elif n in (1635,1637,1638):
  assert target_line==279 and '输出状态与错误保持' in target and 'ACK、error、sticky' in cl3[280]
  assert name in ports
  state='accepted_current_group_source';reason='Current §11 is the manager status/error forwarding group. Full literal port absence is not a missing implementation.'
 elif n==1633:
  assert 'phantom/mis-filed' in cells[6] and name not in ports
  state='already_explicitly_documented_phantom';reason='Matrix openly marks invalid C03 port. Correct Top output exists; no new implementation-gap finding.'
 elif n in (1639,1640):
  assert target_line==220 and 'ACTIVE与epoch' in target and name in ports
  state='scope_ambiguous_not_counted';reason='Source points to ACTIVE/epoch heading while row uses C02 manager status forwarding. Correct hardware exists; exact C03 normative source needs fuller cross-contract scope ruling.'
 else:raise AssertionError((n,name))
 records.append(dict(matrix_line=n,contract='C03',port=name,direction=cells[3],reference=ref[0],
  contract_line=target_line,target=target,state=state,current_definition_line=current,
  current_definition_text=cl3[current-1] if current else '',rtl_declaration_line=ports.get(name,{}).get('line_start'),reason=reason))
for n in range(1708,1734):
 cells=[v.strip() for v in ml[n-1].split('|')];assert cells[1]=='C04'
 name=cells[4].strip('`');ref=re.search(r'([\w/]+\.md):(\d+)',cells[2]);assert ref
 line=int(ref[2]);target=cl4[line-1]
 assert token(name,target),(n,name,line,target)
 state='accepted_ten_weight_group' if n==1725 else 'literal_source_match'
 if n==1725:assert name=='i_stage1_weight_q16_0..9'
 records.append(dict(matrix_line=n,contract='C04',port=name,direction=cells[3],reference=ref[0],
  contract_line=line,target=target,state=state,current_definition_line=line,current_definition_text=target,
  rtl_declaration_line=None,reason='Current C04 exact mapping Source line verified; ten-weight expansion separately exists in ledger_port_inventory.csv.'))
counts=collections.Counter(r['state'] for r in records)
assert len(records)==129 and counts['confirmed_wrong_source_line']==29 and counts['accepted_current_group_source']==70 and counts['literal_source_match']==25,counts
(O/'C03_C04_source_rows_129.json').write_text(json.dumps({'reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'counts':dict(counts),'records':records,'limits':'Source semantic/index ruling only. Does not independently sign off reset/CDC/lifecycle wiring for every row. Two C03 scope ambiguities retained.'},ensure_ascii=False,indent=2),encoding='utf-8')
with (O/'C03_C04_source_rows_129.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
p=E/'anchor_failures.csv';rows=list(csv.DictReader(p.read_text(encoding='utf-8-sig').splitlines()))
key=lambda r:(r['source'],str(r['line']),r['reference'],r['expected']);keys={key(r) for r in rows}
for r in records:
 if r['state']!='confirmed_wrong_source_line':continue
 row=dict(source=matrix,line=r['matrix_line'],reference=r['reference'],kind='explicit_file_line',
  expected=r['port'],status='text_mismatch',target=r['target'])
 if key(row) not in keys:rows.append(row);keys.add(key(row))
counts=collections.Counter(r['status'] for r in rows);assert counts['text_mismatch']==280 and counts['out_of_bounds']==14,counts
with p.open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
p=B/'PPG_FULL_REVIEW_20261002.md';text=p.read_text(encoding='utf-8');a=text.index('### F-003');z=text.index('### F-',a+8);block=text[a:z]
if 'C03/C04的129条Source' not in block:
 block=block.replace('现累计251处文字失配。','现累计251处文字失配。继续人工裁定C03/C04的129条Source，确认29处C03端口指向空行/代码围栏/参数覆盖/无关条款，已逐一核对现行明确端口定义；另接受97处分组、章节及字面匹配，1处矩阵已明示的phantom不新增报错，2处规范范围歧义暂不计入。现累计280处文字失配。')
 block=block.replace('不能当成251个独立功能错误。','不能当成280个独立功能错误。')
 text=text[:a]+block+text[z:]
heading='## A C03/C04 Source语义裁定：2026-10-04'
if heading not in text:
 text+='\n'+heading+'\n\n不等待长回归，实际对C03/C04全部129个Source引用逐条核对：29个C03旧Source确认失效并入F003；70个C03当前分组引用、1个生命周期节标题、25个C04完整字面映射、1个十权重组引用接受，共97个合法引用；1个C03 phantom原表已经明示，未新报缺RTL；2个C03输出的Source只指ACTIVE/epoch标题，但C02已有状态透传来源，保留范围歧义不计缺陷。这些不是机械103个“没有完整端口名”候选都报错：C03§8明确保持unpack当前端口名/宽度/signed，C03§11允许manager状态组透传；当前组标题本身有效。F003现280处文字失配+14越界。Source原行、逐项反驳、真实AST端口声明行及现行明确定义行见global_closure_20261004/C03_C04_source_rows_129.json/csv，所有行号取当前文件真实文字，未按偏移推算。\n'
p.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('C03/C04 SOURCE129 adjudicated',dict(collections.Counter(r['state'] for r in records)),'F003',dict(counts))
