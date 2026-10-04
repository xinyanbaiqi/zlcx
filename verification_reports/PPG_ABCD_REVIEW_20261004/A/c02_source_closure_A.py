from pathlib import Path
import json,csv,re,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md';contract='contracts/ppg_system_config_manager_semantic_contract.md'
ml=(S/matrix).read_text(encoding='utf-8').splitlines();cl=(S/contract).read_text(encoding='utf-8').splitlines()
def matches(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
assert matches('i_clk','input i_clk;') and not matches('i_clk','input i_clk_extra;') and not matches('start_ready','')
records=[]
for n in range(1572,1605):
 cells=[x.strip() for x in ml[n-1].split('|')]
 assert cells[1]=='C02'
 name=re.fullmatch(r'`(\w+)`',cells[4])[1]
 ref=re.search(r'([\w/]+\.md):(\d+)',cells[2]);assert ref and ref[1].endswith('ppg_system_config_manager_semantic_contract.md')
 line=int(ref[2]);actual=cl[line-1]
 records.append({'matrix_line':n,'reference':ref[0],'port':name,'contract_line':line,'actual':actual,'literal_match':matches(name,actual)})
assert sum(r['literal_match'] for r in records)==32
bad=[r for r in records if not r['literal_match']];assert len(bad)==1 and bad[0]['matrix_line']==1593 and bad[0]['actual']==''
assert 'formula documented' in ml[1592] and 'semantic_contract.md:297' in ml[1592]
assert 'start_ready = active_valid' in cl[310]
assert 'o_start_ready' in (S/'rtl/ppg_system_config_manager/ppg_system_config_manager.v').read_text(encoding='utf-8').splitlines()[89]
(O/'C02_source_rows_33.json').write_text(json.dumps({'reviewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rows':records,
 'rebuttal':'Formula is in current contract311 and manager has output90/assign503. Matrix1593 itself discloses omitted formal port table; this is not missing RTL or a new claim of previously unknown functional gap. Only its literal formula/source297 is stale.'},ensure_ascii=False,indent=2),encoding='utf-8')
p=E/'anchor_failures.csv';rows=list(csv.DictReader(p.read_text(encoding='utf-8-sig').splitlines()))
row=dict(source=matrix,line=1593,reference=bad[0]['reference'],kind='explicit_file_line',expected='start_ready',status='text_mismatch',target='')
key=lambda r:(r['source'],str(r['line']),r['reference'],r['expected'])
if key(row) not in {key(r) for r in rows}:rows.append(row)
counts=collections.Counter(r['status'] for r in rows);assert counts['text_mismatch']==251 and counts['out_of_bounds']==14,counts
with p.open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8');a=t.index('### F-003');z=t.index('### F-',a+8);block=t[a:z]
if 'C02 Source 33行' not in block:
 block=block.replace('总计250处文字失配。','总计250处文字失配。随后逐条复核C02 Source 33行，32处源行含所列端口，:1593所称start_ready公式C02:297却为空行，实际公式为:311；新增1处，现累计251处文字失配。')
 block=block.replace('不能当成250个独立功能错误。','不能当成251个独立功能错误。')
 t=t[:a]+block+t[z:]
heading='## A C02 Source交叉引用裁定：2026-10-04'
if heading not in t:
 t+='\n'+heading+'\n\n§12.5的33个C02 Source锚点已逐行对当前UTF-8合同核实，32个含明确的同名端口；仅:1593引用C02:297时目标为空行。C02:311存在完整start_ready公式，manager实际:90有o_start_ready、:503直接赋值，故不存在该输出的RTL缺实现。:1593本身已明示完整I/O表漏登记的文档缺口，此轮不把其已自述的缺口另编号；只把公式/Source行号失效作为F003新增记录。现F003汇总251处文字失配及14处越界，C02 Source逐行证据见global_closure_20261004/C02_source_rows_33.json。\n'
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
print('C02 SOURCE 33 reviewed:32 literal matches,1 confirmed stale formula reference; F003',dict(counts))
