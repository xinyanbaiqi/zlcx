from pathlib import Path
import re,json,csv,copy,collections
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
out=E/'closure_skill_20261004'; out.mkdir(exist_ok=True)
gate=json.loads((out/'top_gate.json').read_text(encoding='utf-8'))
module=gate['quality_gate']['ast_report']['files'][0]['modules'][0]
# The Verilog parser is the repository's Erie formatter AST, not this helper.
params={p['name']:int(re.fullmatch(r"(?:\d+'d)?(\d+)",p['value'])[1]) for p in module['params'] if re.fullmatch(r"(?:\d+'d)?(\d+)",p['value'])}
def numeric_width(port):
    if not port['width']: return 1
    match=re.fullmatch(r'\[\s*(?:(\w+)\s*-\s*1|(\d+))\s*:\s*0\s*\]',port['width'])
    if not match: raise ValueError(port['width'])
    return params[match[1]] if match[1] else int(match[2])+1
def table_rows(lines):
    rows=[]
    for number,line in enumerate(lines,1):
        cells=[x.strip() for x in line.split('|')]
        if len(cells)<7 or cells[1]!='C01' or 'Top自身边界端口' not in cells[6]: continue
        name=re.fullmatch(r'`(\w+)`',cells[4])
        width=re.search(r'位宽(\d+)-bit',cells[6])
        rows.append(dict(name=name[1] if name else cells[4],direction=cells[3],width=int(width[1]) if width else None,line=number))
    return rows
def compare(ports,rows):
    byname=collections.defaultdict(list)
    for row in rows: byname[row['name']].append(row)
    errors=[]
    for port in ports:
        name=port['name']; matches=byname.pop(name,[])
        if len(matches)!=1: errors.append((name,'row_count',len(matches))); continue
        row=matches[0]
        for key in ('direction','width'):
            expected=port[key] if key=='direction' else numeric_width(port)
            if row[key]!=expected: errors.append((name,key,row[key],expected))
    for name,rows_for_name in byname.items(): errors.append((name,'extra_row',len(rows_for_name)))
    return errors
lines=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
rows=table_rows(lines)
# Prove the Markdown comparison on independent fixtures before interpreting it.
p=[dict(name='i_fixture',direction='input',width=''),dict(name='o_fixture',direction='output',width='[4:0]')]
r=[dict(name='i_fixture',direction='input',width=1,line=1),dict(name='o_fixture',direction='output',width=5,line=2)]
assert compare(p,r)==[]
bad=copy.deepcopy(r);bad[0]['direction']='output';bad[1]['width']=4
assert compare(p,bad)==[('i_fixture','direction','output','input'),('o_fixture','width',4,5)]
assert compare(p,r[:1])==[('o_fixture','row_count',0)]
assert compare(p,r+[r[0]])==[('i_fixture','row_count',2)]
fixture='| C01 | ref | input | `i_fixture` | decl | Top自身边界端口。位宽1-bit |'
assert table_rows([fixture])==[dict(name='i_fixture',direction='input',width=1,line=1)]
(out/'port_table_negative_controls.json').write_text(json.dumps(dict(changed_direction_and_width=compare(p,bad),removed_row=compare(p,r[:1]),duplicate_row=compare(p,r+[r[0]]),markdown_fixture=table_rows([fixture])),ensure_ascii=False,indent=2),encoding='utf-8')
errors=compare(module['ports'],rows)
source=(S/'rtl/ppg_control_top/ppg_control_top.v').read_text(encoding='utf-8').splitlines()
records=[]
for port in module['ports']:
    assert re.search(r'\b'+re.escape(port['name'])+r'\b',source[port['line_start']-1]),port
    matches=[r for r in rows if r['name']==port['name']]
    records.append(dict(name=port['name'],direction=port['direction'],width=numeric_width(port),width_expression=port['width'],signed=port['signed'],source_line=port['line_start'],matrix_lines=';'.join(str(x['line']) for x in matches),group=port['group'],issues=';'.join(str(e) for e in errors if e[0]==port['name'])))
with (out/'top_ports_165.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.DictWriter(stream,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
(out/'top_port_comparison.json').write_text(json.dumps(dict(port_count=len(records),matrix_boundary_rows=len(rows),errors=errors,source='Erie canonical formatter AST from top_gate.json',signed_count=sum(x['signed'] for x in records),scope='name/direction/default width/current source span; not reset or CDC signoff'),ensure_ascii=False,indent=2),encoding='utf-8')
print('TOP_PORTS',len(records),'MATRIX_BOUNDARY',len(rows),'ERRORS',errors,'SIGNED',sum(x['signed'] for x in records))
print('INSTANCES',[(x['module_name'],x['instance_name'],x.get('line_start')) for x in module['instances']])
print('PARAMS',params)
