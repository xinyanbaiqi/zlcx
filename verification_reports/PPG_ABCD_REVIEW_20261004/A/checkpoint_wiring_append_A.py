from pathlib import Path
import json,csv,collections
B=Path(__file__).resolve().parent;E=B/'evidence';O=E/'global_closure_20261004'
d=json.loads((O/'canonical_instance_crosscheck_A.json').read_text(encoding='utf-8'))
assert d['counts']['faults']==0 and d['counts']['plain_net_widths']=={'match':2024} and d['counts']['plain_net_width_not_evaluable']==0
clocks=[c for c in d['connections'] if 'rstn' in str(c['formal']) or c['formal'] in ('i_source_clk','i_dest_clk','i_destination_clk','i_clk')]
with (O/'canonical_clock_reset_bindings_A.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=['parent','module','instance','formal','actual','direction','source_line','source_text']);w.writeheader()
 w.writerows({k:c[k] for k in w.fieldnames} for c in clocks)
summary=json.loads((O/'static_residual_disposition_A.json').read_text(encoding='utf-8'))
summary['completed'].update(canonical_instances=39,canonical_associations=2168,plain_net_default_width_matches=2024,canonical_clock_reset_associations=len(clocks))
summary['audit_limits'].append('Four isolated timing instances lack usable canonical aggregate leaf-port metadata; original sources exist and real Icarus compile/full original timing TB passed. Not classified as missing modules or new defects.')
(O/'static_residual_disposition_A.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
report=B/'PPG_FULL_REVIEW_20261002.md';t=report.read_text(encoding='utf-8');heading='## A 实际实例连线补充核对：2026-10-04'
if heading not in t:
 t+='\n'+heading+'\n\n复用仓库Erie canonical AST及其原有实例/关联提取helper，实际核对39个可用实例、2168个命名端口关联：没有未知formal、重复formal、缺接或显式留空的输入，也没有一个plain net被多个子模块输出共同驱动；2024处完整单根actual net的默认参数化位宽与child formal相同。未知端口、重复、开路输入、漏输入四个负对照分别精确报出故意错误，正确输入和留空输出不误报；位宽/符号比较沿用已通过的独立负对照。时钟/复位逐关联真实行导出canonical_clock_reset_bindings_A.csv；Top与chip reset/两source CDC路径按已有语义复核和F007边界解释。\n\n另4个孤立timing实例在旧strict聚合AST中未得到可用leaf端口元数据；原源文件确实在库，真实Icarus37RTL编译及dual/timing完整原TB已通过，保留为本次额外AST连线扫描的限度，不谎称缺模块或新增RTL缺陷。对常数/拼接/留空输出未用单根net宽度比较来证明语义正确。全部实际关联与原行、参数覆盖和限制见global_closure_20261004/canonical_instance_crosscheck_A.json；不以此代替握手/CDC/优先级签核。\n'
report.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
print('WIRING_EVIDENCE_RECORDED',len(clocks),'CLOCK_RESET_BINDINGS')
