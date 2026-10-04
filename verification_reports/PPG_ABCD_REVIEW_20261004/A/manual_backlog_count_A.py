from pathlib import Path
import csv,json,collections,datetime,re
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
def remaining(all_ids,reviewed_ids):
 assert len(all_ids)==len(set(all_ids)), 'duplicate work item'
 assert len(reviewed_ids)==len(set(reviewed_ids)), 'duplicate review marker'
 assert set(reviewed_ids)<=set(all_ids), 'review marker outside inventory'
 return set(all_ids)-set(reviewed_ids)
# Counter negative controls: a removed review marker must restore exactly its task;
# duplicate/foreign markers must not falsely reduce remaining work.
assert remaining([1,2,3],[1])=={2,3}
assert remaining([1,2,3],[1,2])=={3}
assert remaining([1,2,3],[])=={1,2,3}
controls={}
for label,a,r in [('duplicate_inventory',[1,1,2],[1]),('duplicate_review',[1,2],[1,1]),('foreign_review',[1,2],[99])]:
 try:remaining(a,r)
 except AssertionError:controls[label]='rejected'
 else:raise AssertionError(label)
controls['remove_review_marker_restores_exact_item']=True
rows=list(csv.DictReader((O/'ledger_port_inventory.csv').read_text(encoding='utf-8-sig').splitlines()))
byline={int(r['line']):r for r in rows};assert len(byline)==len(rows)==1860
reviewed=[];evidence=[]
for f in sorted(O.glob('*_source_rows_*.json')):
 d=json.loads(f.read_text(encoding='utf-8'));evidence.append(f.name)
 for r in d.get('records',d.get('rows',[])):
  reviewed.append({**r,'evidence_file':f.name})
pending_ids=remaining([int(r['line']) for r in rows],[int(r['matrix_line']) for r in reviewed])
assert len(reviewed)+len(pending_ids)==1860
ml=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
pending=[]
for n in sorted(pending_ids):
 r=byline[n];c=[v.strip() for v in ml[n-1].split('|')]
 assert c[1]==r['contract'] and c[3]==r['direction'] and c[4].strip('`')==r['name'].strip('`'),(n,c,r)
 pending.append(dict(matrix_line=n,contract=r['contract'],port=r['name'],direction=r['direction'],
  source_cell=c[2],rtl_modules=r['modules'],rtl_declaration_lines=r['declaration_lines'],
  state='source_manual_ruling_pending',scope='Source meaning/index only; name/direction existence already checked.'))
for r in reviewed:
 n=int(r['matrix_line']);assert r['port'].strip('`')==byline[n]['name'].strip('`'),(n,r,byline[n])
 assert r['reference'] in ml[n-1],(n,r['reference'])
ambiguous=[r for r in reviewed if r.get('state')=='scope_ambiguous_not_counted']
counts=collections.Counter(r['contract'] for r in pending)
with (O/'source_manual_backlog_current.csv').open('w',encoding='utf-8-sig',newline='') as f:
 fields=['matrix_line','contract','port','direction','source_cell','rtl_modules','rtl_declaration_lines','state','scope']
 w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(pending)
summary=dict(updated_at=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(timespec='seconds'),
 source_inventory_rows=1860,source_reviewed_rows=len(reviewed),source_pending_rows=len(pending),source_pending_by_contract=dict(counts),
 scope_ambiguous_reviewed_rows=len(ambiguous),scope_ambiguities=ambiguous,negative_controls=controls,evidence_files=evidence,
 other_manual_work='Other default/inherited reference rulings and per-field producer/consumer, reset, timing, CDC checks are not exhaustively itemized in a unified backlog. Cannot honestly report an exact overall remaining count or percent.',
 limits='Counts are Source work items, not defects, unique ports or all remaining manual work. No inference that B/C/D original module reviews were undone.')
(O/'manual_remaining_summary_A.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
heading='## A 人工剩余项计数：2026-10-04'
p=B/'PPG_FULL_REVIEW_20261002.md';text=p.read_text(encoding='utf-8')
if heading not in text:
 table='\n'.join(f'| {code} | {counts[code]} |' for code in ['C01','C10','C13','C14','C15','C16'])
 text+='\n'+heading+'\n\n按实际逐项证据而非估计计数：G-FP的1860条端口台账Source工作项中，996条已有单独人工裁定记录，864条尚待单独裁定；另有已审的C03:矩阵1639/1640两处来源范围歧义（o_lifecycle_state/o_start_ready）。来源待办分布如下：\n\n| 合同 | 待单独裁定Source条数 |\n| --- | ---: |\n'+table+'\n| 合计 | 864 |\n\n每条待办的当前矩阵行、端口、完整Source原单元格及真实模块/声明行已导出global_closure_20261004/source_manual_backlog_864.csv；计数负对照、两处歧义证据和范围见manual_remaining_summary_A.json。864是引用工作量，不是864个缺陷；此前全量名称/方向机械检查已完成，不能把此待办理解为864端口的代码从未审过。缺省/继承引用及端口生产者/消费者、复位、时序、CDC独立逐字段核对尚未形成统一穷尽待办清单，因此当前不能诚实给出全部人工工作的精确剩余总数或整体完成百分比。B/C/D的原分组审阅不因此重置为未完成。\n'
p.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
(B/'PPG_FULL_REVIEW_20261004.md').write_bytes(p.read_bytes())
print('SOURCE_PENDING',len(pending),'BY_CONTRACT',dict(counts),'REVIEWED_SCOPE_AMBIGUITIES',len(ambiguous),'OTHER_WORK_NOT_QUANTIFIED')
