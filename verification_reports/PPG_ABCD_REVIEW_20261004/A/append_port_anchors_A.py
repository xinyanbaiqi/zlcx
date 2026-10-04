from pathlib import Path
import json, csv, collections, re
B=Path(__file__).resolve().parent; E=B/'evidence'; O=E/'global_closure_20261004'
csv_path=E/'anchor_failures.csv'
rows=list(csv.DictReader(csv_path.read_text(encoding='utf-8-sig').splitlines()))
keys={(r['source'],str(r['line']),r['reference'],r['expected']) for r in rows}
new=json.loads((O/'new_port_anchor_mismatches.json').read_text(encoding='utf-8'))
added=0
for r in new:
    key=(r['source'],str(r['line']),r['reference'],r['expected'])
    if key in keys: continue
    rows.append(dict(source=r['source'],line=r['line'],reference=r['reference'],
        kind='explicit_file_line',expected=r['expected'],status='text_mismatch',target=r['actual']))
    keys.add(key); added+=1
counts=collections.Counter(r['status'] for r in rows)
assert counts['text_mismatch']==250+int(any(str(r['line'])=='1593' and r['expected']=='start_ready' for r in rows)) and counts['out_of_bounds']==14,counts
with csv_path.open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
report=B/'PPG_FULL_REVIEW_20261002.md';text=report.read_text(encoding='utf-8')
start=text.index('### F-003');end=text.index('### F-',start+8)
block=text[start:end]
if '再确认64处' not in block:
    block=block.replace('累计186处。','累计186处。本轮复用Erie canonical AST核对矩阵明确的单端口声明列：516处中287处字面匹配、229处失配；其中165处Top声明已计入，再确认64处Scheduler/AMI子模块声明失效，总计250处文字失配。')
    block=block.replace('不能当成186个独立功能错误。','不能当成250个独立功能错误。')
    block=block.replace('没有给出实际端口行号。','没有给出实际端口行号。新增64处逐项确认所列端口在目标模块的正式AST端口集合中存在、方向正确、引用行却不含该端口；单端口声明列未设历史删除线，说明列没有替代当前声明行；实际正确端口位置来自AST并逐行核对，未按偏移计算。C16/C17的244条声明锚点字面均匹配，此结论不替代其生命周期签核。')
    text=text[:start]+block+text[end:]
heading='## A 声明锚点补充复核：2026-10-04'
if heading not in text:
    text+='\n'+heading+'\n\n复用37份既有skill gate的canonical formatter AST（35个不同模块名）进行Markdown单端口声明锚点核对，先通过错误行号、错误方向、缺端口及越界四个负对照；正确对照不误报。实际516处声明引用中287处字面匹配、229处失配，后者含已计入F003的165处Top引用与新增64处Scheduler/AMI引用。去重后F003为250处文字失配和14处越界，详表anchor_failures.csv；原始目标行和当前逐行验证的声明行见port_declaration_anchors.csv。未带明确声明的1365行及1个分组行保留语义边界，没有伪造它们的“通过”。C16/C17共244处声明字面匹配，名称/方向正确不等于已完成所有跨域、优先级及在途语义签核。\n'
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('F003',dict(counts),'added',added)
