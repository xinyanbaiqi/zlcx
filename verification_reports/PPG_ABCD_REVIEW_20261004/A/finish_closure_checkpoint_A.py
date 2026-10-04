from pathlib import Path
import json,re,csv,collections,runpy,contextlib,io,datetime,hashlib
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';report=B/'PPG_FULL_REVIEW_20261002.md';out=E/'global_closure_20261004'
source_files=sorted(out.glob('*_source_rows_*.json'));source_rows=[]
for sf in source_files:
    data=json.loads(sf.read_text(encoding='utf-8'))
    for original in data.get('records',data.get('rows',[])):
        r=dict(original);r['evidence_file']=sf.name
        if 'state' not in r:r['state']='literal_source_match' if r['literal_match'] else 'confirmed_wrong_source_line'
        source_rows.append(r)
assert len({r['matrix_line'] for r in source_rows})==len(source_rows)
source_summary={'reviewed_rows':len(source_rows),'states':dict(collections.Counter(r['state'] for r in source_rows)),
    'evidence_files':[sf.name for sf in source_files],
    'limits':'Each record is an actual Source ruling with frozen line text. Name/group acceptance does not sign off every reset, width, CDC, priority or TB scenario.'}
(out/'source_adjudication_summary_A.json').write_text(json.dumps(source_summary,ensure_ascii=False,indent=2),encoding='utf-8')
tagrows=list(csv.DictReader((out/'alias_tag_consistency.csv').read_text(encoding='utf-8-sig').splitlines()))
decisions=[]
for row in tagrows:
    if row['state']!='different_id_tag_candidate':continue
    if row['alias_line'] in ('47','147','455'):decision='确认失效锚点；源908是TOP21生产门控，当前身份替换911带TOP22/P07/SID10；并入F003'
    elif row['alias_line']=='148':decision='数值互斥锚点文字本身真，但SID11现行公开注入边界解除旧不可达理由；F050'
    else:decision='共享实现/静态门禁代表锚点；实际tag为相关交叉验收，源行机制与本表描述已跨文件核对，不自动报漏实现或新错误'
    decisions.append({**row,'adjudication':decision})
(out/'different_tag_adjudication.json').write_text(json.dumps(decisions,ensure_ascii=False,indent=2),encoding='utf-8')
text=report.read_text(encoding='utf-8');heading='## A 标签核对及本批边界：2026-10-04'
if heading not in text:
    counts=json.loads((out/'tag_summary.json').read_text(encoding='utf-8'))['counts']
    text+='\n'+heading+'\n\n'
    text+=f'全570行别名表的标签/字面RTL锚点机械核对：{counts}。同时检验错ID、删标签及明确“不是旧锚点”的负对照，RRC02行中的否定旧idac引用已剔除，避免脚本反向误判。17个不同标签候选全部人工逐条裁定：三处真实AMI行号漂移并入F003、SID11旧不可达状态并入F050，13处为共享实现或静态台账代表锚点。逐条原文和裁定见alias_tag_consistency.csv与different_tag_adjudication.json。不存在把所有“不同tag/无tag”升级成新功能缺陷的做法。\n\n'
    text+='本批A已完成Top165端口、TOP24语义、838候选四链全量机械检查、46家族语义抽查、141版本绑定/26摘要和两份非规范参考裁定。仍未逐项独立签核G-FP其余全部cluster，也未对9247机械锚点的每个合法组表头/继承引用候选逐条完成语义裁定；这些限度在§5矩阵/别名行保留，用户已知事项不重复编号。最终原长回归日志尚未全部到齐，因此报告仍为阶段报告，不能称ABCD整体审阅交付已全部结束。\n'
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
cov=list(csv.DictReader((B/'coverage_A.csv').read_text(encoding='utf-8-sig').splitlines()))
for row in cov:
    if Path(row['path']).stem in ('PPG_CONTRACT_CLOSURE_MATRIX','PPG_ALIAS_MAPPING_TABLE'):
        row['evidence']=';'.join(str(p) for p in [out/'all_id_four_links.csv',out/'A_remaining_family_adjudication.json',out/'different_tag_adjudication.json',E/'dependency_audit_A.json',out/'port_declaration_anchors.csv',out/'ledger_port_inventory.csv',out/'source_adjudication_summary_A.json',*source_files])
        if Path(row['path']).stem=='PPG_ALIAS_MAPPING_TABLE' and row['check_item']=='版本与依赖':row['status']='完成'
        row['remaining']=f"838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、{len(source_rows)}个单独Source、141版本绑定/26摘要及367标签关联已核对；Source待办0、C03两处歧义已裁定。799显式默认位宽/41明示符号属性及4个参数组人工核对、6个缺文件候选已裁定。范围限度：非Source缺省文件名/bounds-only引用未全部逐字语义核实，未重建G-FP全部cluster逐字段项目签核或ASIC CDC；这些不能记通过。F044入口范围为疑似，4份原长回归终态未齐。F003/F024/F045/F046/F048/F050/F051保留。"
        if row['check_item']=='内部端口/正文/验收/修订一致性':row['status']='完成'
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(cov[0]));w.writeheader();w.writerows(cov)
for script in ('regression_audit.py','coverage_checkpoint_oct4b.py','current_checkpoint_oct4.py','handoff_checkpoint_oct4h.py'):
    stream=io.StringIO()
    with contextlib.redirect_stdout(stream):runpy.run_path(str(B/script))
    (out/(script+'.stdout')).write_text(stream.getvalue(),encoding='utf-8')
    print(script,stream.getvalue().splitlines()[-1:] if script=='regression_audit.py' else stream.getvalue()[-240:])
text=report.read_text(encoding='utf-8');start=text.index('## 3. 新发现');end=text.index('## 4. 已知事项',start);block=text[start:end]
matches=list(re.finditer(r'^### (F-\d+)(?:：| — )[^\n]+\n.*?(?=^### F-|\Z)',block,re.M|re.S));assert len(matches) in (50,51),len(matches)
prefix=block[:matches[0].start()]
ordered=sorted(matches,key=lambda m:(re.search(r'S[1-4]',m[0])[0],m[1]))
text=text[:start]+prefix+''.join(m[0] for m in ordered)+text[end:]
assert 'd18c6954621e53e5a6505dd3a6c688c266d23839' in text.splitlines()[0]
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'));(B/'PPG_FULL_REVIEW_20261004.md').write_bytes(report.read_bytes())
runpy.run_path(str(B/'final_report_if_ready_A.py'))
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'));assert len(ledger)==119
for r in ledger:assert hashlib.sha256((S/r['file']).read_bytes()).hexdigest()==r['sha256'],r['file']
rows=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
print('CURRENT',dict(collections.Counter(x['status'] for x in ledger)),dict(collections.Counter(x['state'] for x in rows)))
print('REPORT',B/'PPG_FULL_REVIEW_20261004.md')
