from pathlib import Path
import json,collections,datetime,re,hashlib,csv
B=Path(__file__).resolve().parent;E=B/'evidence';O=E/'global_closure_20261004';S=B/'snapshot'
def ready(rows,expected_count):
 return (len(rows)==expected_count and len({r['tb'] for r in rows})==expected_count and
  all(r.get('state')=='finished' and r.get('rc')==0 and not r.get('fail_lines') and r.get('banner') and
   (r.get('baseline') is None or r.get('baseline')==r.get('pass_lines')) for r in rows))
good=[dict(tb='a',state='finished',rc=0,fail_lines=[],banner=['A_PASS'],baseline=2,pass_lines=2),
 dict(tb='b',state='finished',rc=0,fail_lines=[],banner=['B_PASS'],baseline=None,pass_lines=1)]
assert ready(good,2)
controls=[]
for label,key,value in [('running','state','running'),('nonzero_rc','rc',1),('fail_marker','fail_lines',['FAIL']),('missing_banner','banner',[]),('count_change','pass_lines',3)]:
 fixture=[dict(r) for r in good];fixture[0][key]=value;actual=ready(fixture,2);assert not actual,label;controls.append(dict(case=label,eligible=actual))
assert not ready(good[:1],2) and not ready([good[0],good[0]],2)
controls.extend([dict(case='missing_case',eligible=False),dict(case='duplicate_case',eligible=False)])
(O/'report_finalization_negative_controls_A.json').write_text(json.dumps(controls,indent=2),encoding='utf-8')
rows=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
source=json.loads((O/'source_adjudication_summary_A.json').read_text(encoding='utf-8'))
manual_path=O/'manual_closure_completion_A.json'
manual=json.loads(manual_path.read_text(encoding='utf-8')) if manual_path.exists() else {'complete':False,'reason':'Non-Source reference and G-FP clustered semantic independent review remains active; regression completion alone cannot close the requested audit.'}
eligible=ready(rows,48) and source['reviewed_rows']==1860 and not source['states'].get('scope_ambiguous_not_counted',0) and manual.get('complete') is True
state=dict(updated_at=datetime.datetime.now().isoformat(timespec='seconds'),eligible=eligible,
 regression_states=dict(collections.Counter(r['state'] for r in rows)),unfinished=[r['tb'] for r in rows if r['state']!='finished'],
 unexpected_terminal=[r['tb'] for r in rows if r['state']=='finished' and not ready([r],1)],
 manual_closure=manual,
 limits='Only closes the report when all48 actual original logs have normal terminal banners, no FAIL and baseline PASS counts match, and required independent manual closure is complete. Regression completion cannot hide unfinished manual work. Any unexpected terminal remains pending manual adjudication. Explicit unavailable-tool ranges and F044 stay in the report; no source fixes or product signoff.')
if eligible:
 ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'));assert len(ledger)==119
 for r in ledger:assert hashlib.sha256((S/r['file']).read_bytes()).hexdigest()==r['sha256'],r['file']
 p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8');assert 'd18c6954621e53e5a6505dd3a6c688c266d23839' in t.splitlines()[0]
 t=t.replace('# PPG 数字部分全量审阅报告（进行中）','# PPG 数字部分全量审阅报告（审阅结束；未验证范围明确列出）')
 t=t.replace('尚未完成全量语义审阅。已确认','本轮文件审阅、所列交叉核对、独立反驳复核及48份原回归日志核对已结束；不将§5/§7明确列出的未验证范围算作通过。已确认',1)
 heading='## 最终交付状态'
 if heading not in t:
  t+='\n'+heading+'\n\n48/48完整原TB实际运行结束，均rc=0、最终横幅存在、无FAIL标记，系统TB的PASS行数与最新基线相同；实际采用Icarus11，未复现xsim。1860条Source、799个显式默认位宽、2024个单根实例连线位宽、四链及46家族语义抽查和全部已报告发现反驳已写证据。确认发现50条（S1=11/S2=20/S3=19），另F044疑似；发现存在不妨碍本轮只读审阅结束，未实施任何修复。\n\n未验证范围仍包括：非Source省略文件名/bounds-only引用的逐条语义、G-FP全部cluster逐字段项目签核、三处未入库历史handoff、4个孤立timing实例的附加AST端口元数据、不可用的Vivado/Verilator/综合/ASIC CDC及非穷尽变异/状态空间。逐文件标为部分的项目保留限度，不全部涂为完成。早期检查点中的待办数字均为历史；以本段、§5及最新§6为准。\n'
 p.write_bytes(t.replace('\n','\r\n').encode('utf-8'));(B/'PPG_FULL_REVIEW_20261004.md').write_bytes(p.read_bytes())
 state['final_report_written']=True
(O/'report_finalization_state_A.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
print('REPORT_FINALIZATION_ELIGIBLE',eligible,'STATES',state['regression_states'],'UNEXPECTED',state['unexpected_terminal'])
