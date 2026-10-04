from pathlib import Path
import json, re, csv
B=Path(__file__).resolve().parent;E=B/'evidence';O=E/'global_closure_20261004';report=B/'PPG_FULL_REVIEW_20261002.md'
summary=json.loads((O/'ledger_port_inventory_summary.json').read_text(encoding='utf-8'))
assert summary['rows']==1860 and summary['counts']=={'name_direction_match':1858,'explicitly_documented_phantom_row':1,'expanded_group_match':1}
text=report.read_text(encoding='utf-8');heading='## A 全台账端口存在性核对：2026-10-04'
if heading not in text:
 text+='\n'+heading+'\n\n实际提取§12.5全部1860个Direction为input/output/inout的端口行，复用Erie AST逐合同对照名称与方向：1858个单端口匹配，1个Stage1权重组展开0..9十端口全部匹配，1个C03的o_system_fault_blocking不在wrapper中，但该行:1633已经明确标注“defect finding / phantom/mis-filed”，且实际Top有同名输出，故记作已明示的待协调台账条目，没有新报缺RTL功能。初次只按合同对应外层模块匹配时的其余候选，经当前C04映射正文和C10捕获/冗余/Router子模块表逐项反驳，全部找到了真实边界；这体现为什么不能凭机械名字搜索直接报错。名称、方向及少一个分组成员三种负对照先通过。详见ledger_port_inventory.csv/summary/controls。\n\n'
 text+='边界：多模块合同使用明示模块集合并保留命中的实际声明行，名称/方向存在性不证明producer/consumer连线、位宽、复位、CDC或等待释放规则已逐字段签核；这些仍与分组语义审阅及G-FP已知未复核范围分开记录。别名明确否定旧锚点的语法已排除；838候选四链、46家族抽查、516条明确声明锚点、141版本绑定和26字节摘要本批均已实际完成。长回归仍执行，最终汇总未称全部完成。\n'
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
cov=list(csv.DictReader((B/'coverage_A.csv').read_text(encoding='utf-8-sig').splitlines()))
for row in cov:
 if Path(row['path']).stem in ('PPG_CONTRACT_CLOSURE_MATRIX','PPG_ALIAS_MAPPING_TABLE'):
  row['evidence']+=';'+str(O/'port_declaration_anchors.csv')+';'+str(O/'ledger_port_inventory.csv')
  row['remaining']='838候选四链、46家族语义抽查、1860端口行名称方向（含十权重展开）、516声明锚点、141版本绑定/26摘要及367标签关联已核对；缺省/分组引用未全部逐条语义裁定，其余G-FP cluster的复位/时序/CDC等未逐字段独立签核，原长回归终态未齐。F003/F045/F046/F048/F050保留。'
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(cov[0]));w.writeheader();w.writerows(cov)
print('1860 port-row checkpoint saved')
