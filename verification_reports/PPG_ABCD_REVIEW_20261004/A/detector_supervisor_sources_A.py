from pathlib import Path
import re,csv,json,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md';ml=(S/matrix).read_text(encoding='utf-8').splitlines()
mapping={'C19':'ppg_coarse_detection_fir','C20':'ppg_dynamic_baseline_cross_detector','C22':'ppg_peak_valley_window_detector','C23':'ppg_precision_window_controller','C24':'ppg_system_fault_abort_supervisor'}
mods={}
for code,name in mapping.items():
 g=json.loads((E/'gates'/f'{name}.json').read_text(encoding='utf-8'))
 mods[code]=next(m for f in g['quality_gate']['ast_report']['files'] for m in f['modules'] if m['name']==name)
def token(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
def scope(lines,n):
 level=len(lines[n-1])-len(lines[n-1].lstrip('#'))
 end=next((i for i in range(n,len(lines)) if (lines[i].startswith('#') and len(lines[i])-len(lines[i].lstrip('#'))<=level) or (not level and not lines[i].startswith('|'))),len(lines))
 return '\n'.join(lines[n-1:end])
assert not token('i_wrong',scope(['### good','| i_a |','### next','| i_wrong |'],1))
assert token('i_a',scope(['### good','| i_a |','### next','| i_wrong |'],1))
assert not token('i_saturation_high','`i_saturation_low/high`')
assert 'i_saturation_high'=='i_saturation_low/high'.rsplit('_',1)[0]+'_high'
assert not token('o_frame_id','| `frame_id` | 16 |') and token('frame_id','| `frame_id` | 16 |')
(O/'detector_supervisor_source_controls.json').write_text(json.dumps({'other_section_member_rejected':True,
 'real_section_member_accepted':True,'slash_member_manually_expanded':True,'bare_field_requires_explicit_prefix_rule':True},indent=2),encoding='utf-8')
records=[];cache={}
for n,l in enumerate(ml,1):
 c=[v.strip() for v in l.split('|')]
 if len(c)<7 or c[1] not in mapping or c[3] not in ('input','output','inout'):continue
 ref=re.search(r'([\w/]+\.md):(\d+)',c[2]);name=re.fullmatch(r'`(\w+)`',c[4]);assert ref and name
 code=c[1];name=name[1];ln=int(ref[2]);path='contracts/'+ref[1].split('/')[-1]
 if path not in cache:cache[path]=(S/path).read_text(encoding='utf-8').splitlines()
 lines=cache[path];target=lines[ln-1];text=scope(lines,ln)
 p=next(p for p in mods[code]['ports'] if p['name']==name);assert p['direction']==c[3]
 rtl=f'rtl/{mapping[code]}/{mapping[code]}.v';assert token(name,(S/rtl).read_text(encoding='utf-8').splitlines()[p['line_start']-1])
 current=ln
 if token(name,text):state='accepted_literal_or_current_section';reason='Current source line or its exact current API section contains the named member.'
 elif (code,ln) in (('C20',839),('C22',765),('C19',528)):
  assert name.startswith('i_detection_discard_') and 'TXN_ID' in text
  state='accepted_complete_transaction_group';reason='Explicit registered discard group includes complete TXN_ID, not merely an unspecified future interface.'
 elif (code,ln)==('C23',762):
  assert name.startswith('i_detection_discard_') and '完整事务身份' in text
  state='accepted_expanded_slash_identity';reason='Current per-port table expands full epoch/identity slash list; actual named child port exists with matching direction.'
 elif (code,ln)==('C23',828):
  assert name.startswith('o_mode_fault_') and '<FAULT_ID>' in text
  state='accepted_complete_fault_group';reason='Current output table explicitly includes frame/sample/color/type/precision/generation fault identity.'
 elif (code,ln) in (('C20',728),('C22',664),('C23',752),('C19',474)):
  assert name in ('i_run_generation','o_local_empty') and '生命周期' in target
  actual={'C20':839,'C22':765,'C23':762,'C19':528}[code];extension=scope(lines,actual)
  assert token(name,extension) or (name=='o_local_empty' and 'local empty' in extension)
  current=actual;state='accepted_lifecycle_category_with_explicit_addendum'
  reason='Lifecycle Source heading is still the correct category; a current normative lifecycle addendum explicitly specifies generation/local-empty. Do not infer missing semantics from the old shorter table.'
 elif code=='C20' and ln==763:
  assert name in ('i_valley_config_epoch','i_valley_coef_epoch','i_valley_dc_recovery_coef_epoch') and '谷事件的三个epoch必须与峰事件同样透传' in text
  state='accepted_explicit_valley_epoch_forwarding';reason='Same section expressly mandates all three valley epochs, though table spells the peak epoch members individually.'
 elif code=='C20' and ln==708:
  assert name.startswith('o_cross_') and token(name,scope(lines,806))
  state='accepted_event_payload_with_named_output_table';current=806
  reason='Current event contract lists bare logical payload names; current §14.5 declares each named o_cross endpoint. It is an event group Source, not a port declaration anchor.'
 elif code=='C19' and ln==300:
  assert name.startswith('o_') and token(name[2:],text) and '端口使用对应`o_`前缀' in scope(lines,512)
  state='accepted_center_metadata_prefix_rule';reason='Current center metadata table plus §11.4 explicitly requires matching o_ prefix for each field.'
 elif code=='C24' and ln in (49,50,51,66):
  prefix={49:'i_ami_fault_',50:'i_scheduler_fault_',51:'i_ssw_fault_',66:'o_system_fault_'}[ln]
  assert name.startswith(prefix) and '<FAULT_ID>' in target and 'FAULT_ID' in lines[57]
  state='accepted_complete_fault_group';reason='Exact source-lane/output fault group and explicit six-field FAULT_ID definition; no unsupported TXN epoch members inferred.'
 elif code=='C24' and ln==43:
  assert name in ('i_clk','i_rstn') and lines[5].startswith('> Clock domain:')
  state='module_boundary_index_with_reset_name_conflict';reason='Module-level API Source is real; reset name in §2 conflicts with actual interface (F051). Clock is specified by the one-system-domain rule; no literal clock-table declaration is claimed.'
 else:
  # Manually checked low/high and min/max abbreviations in the exact current section.
  short=name.rsplit('_',1)[0]
  assert name.endswith(('_high','_max')) and (short+'_low/high' in text or short+'_min/max' in text),(n,code,name,ln,text)
  state='accepted_expanded_endpoint_pair';reason='Current table explicitly defines low/high or min/max pair, so lack of a second full name is not an invalid anchor.'
 records.append(dict(matrix_line=n,contract=code,port=name,direction=c[3],reference=ref[0],contract_line=ln,target=target,
  state=state,current_definition_line=current,current_definition_text=lines[current-1],rtl_declaration_line=p['line_start'],reason=reason))
counts=collections.Counter(r['state'] for r in records);by=collections.Counter(r['contract'] for r in records)
assert len(records)==368 and by=={'C20':95,'C22':82,'C23':68,'C19':71,'C24':52},by
(O/'C19_C20_C22_C23_C24_source_rows_368.json').write_text(json.dumps({'counts':dict(counts),'by_contract':dict(by),'records':records,
 'reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'limits':'Source group and real module interface checked. No independent blanket reset/CDC/timing signoff. F051 reset-name mismatch preserved.'},ensure_ascii=False,indent=2),encoding='utf-8')
with (O/'C19_C20_C22_C23_C24_source_rows_368.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
p=B/'PPG_FULL_REVIEW_20261002.md';report=p.read_text(encoding='utf-8')
if '### F-051' not in report:
 # Actual source literals and canonical ports are checked before adding the finding.
 contract='contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md'
 assert token('i_rstn_2m',(S/contract).read_text(encoding='utf-8').splitlines()[55])
 assert 'i_rstn_2m' not in {p['name'] for p in mods['C24']['ports']} and 'i_rstn' in {p['name'] for p in mods['C24']['ports']}
 assert '.i_rstn(i_rstn)' in (S/'rtl/ppg_control_top/ppg_control_top.v').read_text(encoding='utf-8').splitlines()[1392]
 finding='''### F-051：Supervisor规范复位端口名与真实模块接口不一致

- 严重度/层：S3 / 合同；置信度：静态确认。
- 位置：`contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:56`、`rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v:60`、`rtl/ppg_control_top/ppg_control_top.v:1393`；引用原文3行：
```text
| `i_rstn_2m` | 1 | Top reset boundary | Active-low system reset. |
input i_rstn,                               // 低有效异步复位输入
.i_rstn(i_rstn),                                      // 接supervisor.i_rstn：低有效异步复位输入（.I_RSTN）（专属标识一）
```
- 描述/依据：当前规范C24§2名为Complete Supervisor Port Contract，将复位输入列作`i_rstn_2m`；实际叶子只声明`i_rstn`，Top也按该真实端口连线。此处是冻结接口名不一致，不能由表中名称直接生成正确实例。
- 证据与反驳：当前C24全文仅第56行出现该复位名，没有声明它是允许的叶子端口别名；C01 Top实际端口为`i_rstn`（Top RTL:99），芯片层实际连Top为`.i_rstn(w_rstn)`（chip RTL:501）。矩阵:3068一边登记真实`i_rstn`，一边转述合同的`i_rstn_2m`，不能消解此矛盾。规范Erie AST独立确认52个实际端口中存在`i_rstn`且没有`i_rstn_2m`；这不是五组悬空输出、CDC审计等级或既有F032的IDAC清除端口问题，不属第4节接受事项。代码事实明确，无需功能仿真；不据此声称存在硬件复位缺陷。
- 建议方向：统一C24冻结端口名与真实接口，或由设计者明确写出且限定逻辑别名映射。

'''
 report=report.replace('## 4. 已知事项',finding+'## 4. 已知事项',1)
heading='## A 检测链与Supervisor Source语义裁定：2026-10-04'
if heading not in report:report+='\n'+heading+'\n\n完整核对C19/C20/C22/C23/C24的368条端口Source：真实章节/表格、完整TXN/FAULT身份组、显式low/high或min/max缩写、中心元数据o_前缀和谷epoch透传均有当前规范覆盖；旧生命周期表未逐个列新端口，但现行附加条款已明文定义，不误报缺RTL。C24两个module-level API索引保留复位名矛盾，另以F051静态确认合同端口名不一致；不是reset功能错误。逐条裁定及章节边界负对照在global_closure_20261004。累计单独裁定996条Source；F003计数不因合法分组增加。\n'
p.write_bytes(report.replace('\n','\r\n').encode('utf-8'));print('SOURCE368',dict(counts),dict(by),'F051_RECORDED')
