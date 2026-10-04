from pathlib import Path
import json, collections, csv, runpy, contextlib
B=Path(__file__).resolve().parent; E=B/'evidence'; S=B/'snapshot'
gate=json.loads((E/'closure_skill_20261004/top_gate.json').read_text(encoding='utf-8'))
ast=gate['quality_gate']['ast_report']['files'][0]
print('GATE',gate['delivery_issues_by_rule'],{k:v['status'] for k,v in gate['checks'].items()})
print('AST_KEYS',list(ast)); print('MODULE_SAMPLE',str(ast.get('modules',[]))[:1600])
for m in ast.get('modules',[]):
    print('MODULE_KEYS',list(m)); print('PORTS',len(m.get('ports',[])),m.get('ports',[])[:2]); print('INSTANCES',len(m.get('instances',[])),str(m.get('instances',[]))[:1000])
with (E/'regression_audit_latest_stdout.txt').open('w',encoding='utf-8') as out,contextlib.redirect_stdout(out): runpy.run_path(str(B/'regression_audit.py'))
reg=json.loads((E/'regression_results.json').read_text(encoding='utf-8'))
print('REGRESSION',dict(collections.Counter(x['state'] for x in reg)))
for x in reg:
    if x['state']!='finished' or x.get('rc') or x.get('fail_lines') or x.get('baseline')!=x.get('pass_lines'): print('REG_DETAIL',x)
print('PARTIAL_A')
for x in csv.DictReader((B/'coverage_A.csv').read_text(encoding='utf-8-sig').splitlines()):
    if x['status']!='完成': print(x['path'],x['check_item'],x['remaining'])
print('COVERAGE_SCRIPT_START')
print('\n'.join((B/'coverage_checkpoint_oct4b.py').read_text(encoding='utf-8').splitlines()[:42]))
for relative,lo,hi in [('contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md',904,954),('contracts/PPG_CONTRACT_CLOSURE_MATRIX.md',1310,1333),('contracts/PPG_ALIAS_MAPPING_TABLE.md',20,60)]:
    print('SOURCE',relative)
    lines=(S/relative).read_text(encoding='utf-8').splitlines()
    for i in range(lo-1,min(hi,len(lines))): print(f'{i+1}: {lines[i]}')
