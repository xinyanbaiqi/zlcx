from pathlib import Path
import json,datetime,re,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
def lines(path):return (S/path).read_text(encoding='utf-8').splitlines()
matrix=lines('contracts/PPG_CONTRACT_CLOSURE_MATRIX.md')
pwc=lines('rtl/ppg_precision_window_controller/ppg_precision_window_controller.v')
contract=lines('contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md')
assert 'C23 protocol-sticky clear-on-START' in matrix[3407]
assert 'first-priority' in matrix[3407] and 'i_start_ack_event' in matrix[3407]
assert 'i_diag_clear_event' in pwc[505] and 'protocol_error_sticky_o' in pwc[506]
assert 'protocol_error_sticky_o <= protocol_error_sticky_o' in pwc[510]
assert 'PWC-41' in contract[953] and '新合法START本身不清' in contract[953]
log=E/'compile/tb_ppg_precision_window_controller/run.log'
logtext=log.read_text(encoding='utf-8');loglines=logtext.splitlines()
keys=[x for x in loglines if 'PWC-41 new legal START' in x or 'ALL PASS' in x]
assert len(keys)==3 and 'fail=0' in keys[-1]
known=dict(id='K-001',severity='S3',layer='矩阵·台账',confidence='静态确认；原模块级仿真旁证',
 location='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:3408',quote=matrix[3407],
 description='G-FP-03仍把PWC protocol sticky描述为START优先重评并清历史，与09-17修复后的当前RTL、C23/PWC-41以及同矩阵的验收状态不一致。属于用户第4节已知PWC修复的台账状态有误，不重复报告RTL错误。',
 rebuttal_a='flag_fault_hold确实在START重评（RTL675-676），但它与protocol_error_sticky_o是两个不同寄存器；不能用fault_hold机制为sticky行辩护。',
 rebuttal_b='PWC 09-17修复已列为已知；故单独列已知事项状态有误。',
 rebuttal_c='C23:954/PWC-41明确新START不清sticky，只允许diag-clear或复位清；不允许矩阵所述行为。',
 related=[dict(path='rtl/ppg_precision_window_controller/ppg_precision_window_controller.v',line=506,quote='\n'.join(pwc[505:508])),
          dict(path='rtl/ppg_precision_window_controller/ppg_precision_window_controller.v',line=511,quote=pwc[510]),
          dict(path='contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md',line=954,quote=contract[953]),
          dict(path='contracts/PPG_ALIAS_MAPPING_TABLE.md',line=406,quote=lines('contracts/PPG_ALIAS_MAPPING_TABLE.md')[405])],
 simulation=dict(log=str(log),sha256=hashlib.sha256(log.read_bytes()).hexdigest(),key_output=keys),
 suggestion='同步G-FP-03的PWC sticky清除与优先级文字，保留fault_hold的独立语义。')
(O/'known_status_error_K001_A.json').write_text(json.dumps(known,ensure_ascii=False,indent=2),encoding='utf-8')
raw=json.loads((E/'anchor_scan_v2.json').read_text(encoding='utf-8'))
implicit=[r for r in raw['references'] if r['status']=='ambiguous_inherited_context']
assert len(implicit)==1656
manual=dict(updated_at=datetime.datetime.now().isoformat(timespec='seconds'),complete=False,
 source_pending=0,source_reviewed=1860,
 work_items=[dict(name='Non-Source inherited-file reference semantic adjudication',state='active',candidate_occurrences=1656,
                 note='Candidate count is a mechanical workload, not a defect count. Earlier Source and declaration proofs are not reset.'),
             dict(name='Other bounds-only reference expected-text adjudication',state='active',mechanical_occurrences=5144,
                 note='Overlaps completed Source/dependency/decl/tag checks; not a remaining-work total.'),
             dict(name='G-FP cluster producer/consumer/reset/CDC/priority independent review',state='active',
                 note='Detailed module reviews are complete; independent row-level semantic completion is not exhaustive yet.'),
             dict(name='Three full original long regressions and raw final-log checks',state='running')],
 known_status_errors=[known['id']],
 limits=['No xsim/Vivado/Verilator/ASIC CDC tools available','Three external historical handoff references not in snapshot','F044 suspected; acceptable entry-layer coverage scope not decided'])
(O/'manual_closure_completion_A.json').write_text(json.dumps(manual,ensure_ascii=False,indent=2),encoding='utf-8')
p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8')
old='当前未确认需要另编号的“已知事项状态有误”。下列已核实内容按用户已知事项排除；其余风险保留于逐文件台账，未自动转为新发现。'
new='已确认1条“已知事项状态有误”（K-001，S3），单独列于本节，不计入50条确认新发现。下列其余已核实内容按用户已知事项排除；其余风险保留于逐文件台账，未自动转为新发现。'
assert old in t or new in t
t=t.replace(old,new,1)
if '### K-001' not in t:
 pos=t.index('## 5.',t.index('## 4. 已知事项'))
 block='''### K-001：PWC START不清sticky的已知修复未同步G-FP优先级台账

- 严重度／层／置信度：S3／矩阵·台账／静态确认，已执行原模块级仿真旁证。
- 位置及原文：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:3408`：“`i_start_ack_event` -> `protocol_error_sticky_o <= flag_protocol_error_event`”；同一行仍称START是“first-priority”重评触发。
- 当前事实：`rtl/ppg_precision_window_controller/ppg_precision_window_controller.v:506`为`end else if(i_diag_clear_event == 1'b1)begin`，507行为`protocol_error_sticky_o <= 1'b0;`；511行为`protocol_error_sticky_o <= protocol_error_sticky_o;`。实际sticky过程没有START清除分支。`contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md:954`／PWC-41明确“新合法START本身不清…只有`i_diag_clear_event`或复位可以清”。
- 反驳：RTL675-676的`flag_fault_hold`确实在START重评，但它是另一寄存器，不能为sticky台账文字辩护；别名表406已记录当前PWC-41规则，因此不是修复缺失。本条只报用户已知09-17修复对应的台账状态错误，不重复上报RTL缺陷。
- 实际原TB关键输出（`evidence/compile/tb_ppg_precision_window_controller/run.log`）：`PASS PWC-41 new legal START preserves protocol sticky`；`PASS PWC-41 new legal START preserves switch-timeout sticky`；`PWC-01 through PWC-41 ALL PASS pass=48 fail=0`。
- 建议方向：同步G-FP-03的sticky清除/优先级文字，并继续区分fault_hold与历史sticky；未实施修复。完整原行、日志SHA及跨文件反驳见`global_closure_20261004/known_status_error_K001_A.json`。

'''
 t=t[:pos]+block+t[pos:]
heading='## A 人工收尾仍在进行：2026-10-04'
if heading not in t:
 t+='\n'+heading+'\n\nSource工作项1860/1860及两处范围歧义已完成。仍需人工核实非Source的省略文件名引用、未逐条指定预期文字的bounds-only引用，以及G-FP各cluster生产者/消费者、复位、CDC、优先级的独立语义。机械扫描的1656处隐式上下文候选和5144处bounds-only存在与先前证据重叠，不能相加当作精确剩余总量，也不能直接当作缺陷数。已据实际PWC代码、合同和原模块TB确认K-001状态错误。人工闭环状态保存于manual_closure_completion_A.json；报告终态程序已增加该状态门槛，三份长回归通过不会自动把未完成人工核对变成完成。\n'
assert 'd18c6954621e53e5a6505dd3a6c688c266d23839' in t.splitlines()[0]
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'));(B/'PPG_FULL_REVIEW_20261004.md').write_bytes(p.read_bytes())
print('KNOWN_STATUS_ERROR',known['id'],'MANUAL_CLOSURE_COMPLETE',False,'SOURCE_PENDING',0,'IMPLICIT_CONTEXT_CANDIDATES',len(implicit))
