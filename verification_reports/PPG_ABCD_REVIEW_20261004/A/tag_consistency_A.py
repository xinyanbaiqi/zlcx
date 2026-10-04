from pathlib import Path
import json,re,csv,runpy,contextlib,io,collections
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';out=E/'global_closure_20261004'
with contextlib.redirect_stdout(io.StringIO()):namespace=runpy.run_path(str(B/'id_contract_audit_v2.py'))
ids=namespace['ids']
def classify(expected,text):
    if '@satisfies:' not in text:return 'symbol_anchor_without_tag',set()
    actual=ids(text.split('@satisfies:',1)[1])
    return ('same_id_tag' if expected&actual else 'different_id_tag_candidate'),actual
assert classify({'CTRL-01'},'// @satisfies: CTRL-01')[0]=='same_id_tag'
assert classify({'CTRL-01'},'// @satisfies: CTRL-02')[0]=='different_id_tag_candidate'
assert classify({'CTRL-01'},'// signal only')[0]=='symbol_anchor_without_tag'
def positive_anchors(text):
    return [m for m in re.finditer(r'([A-Za-z0-9_]+\.v):(\d+)(?:-(\d+))?',text) if not re.search(r'(?:不是|NOT)\s*(?:\*\*|`)*$',text[:m.start()])]
assert [m[1] for m in positive_anchors('`correct.v:3`；**不是**`old.v:2`')]==['correct.v']
assert [m[1] for m in positive_anchors('`correct.v:3`；`old.v:2`')]==['correct.v','old.v']
(out/'tag_negative_controls.json').write_text(json.dumps([classify({'CTRL-01'},s)[0] for s in ['// @satisfies: CTRL-01','// @satisfies: CTRL-02','// signal only']],ensure_ascii=False,indent=2),encoding='utf-8')
files={p.name:p for p in (S/'rtl').rglob('*.v')};records=[]
for n,line in enumerate((S/'contracts/PPG_ALIAS_MAPPING_TABLE.md').read_text(encoding='utf-8').splitlines(),1):
    cells=[c.strip() for c in line.split('|')]
    if len(cells)<5:continue
    expected=ids(cells[1])
    if not expected:continue
    anchors=positive_anchors(cells[3])
    if not anchors:
        records.append(dict(alias_line=n,ids=','.join(sorted(expected)),file='',line='',actual_tags='',state='explicit_NA' if re.search(r'\bN/A\b|无映射|不适用',cells[3]) else 'no_literal_source_anchor',source_text=cells[3]));continue
    for a in anchors:
        source=files.get(a[1]);lo=int(a[2]);hi=int(a[3] or lo)
        if not source:
            records.append(dict(alias_line=n,ids=','.join(sorted(expected)),file=a[1],line=lo,actual_tags='',state='missing_file_candidate',source_text=''));continue
        lines=source.read_text(encoding='utf-8').splitlines(); actual=set();span=[]
        if lo>len(lines) or hi>len(lines):state='out_of_bounds_candidate'
        else:
            for number in range(lo,hi+1):
                span.append(f'{number}: {lines[number-1]}')
                actual.update(classify(expected,lines[number-1])[1])
            state='same_id_tag' if actual&expected else 'different_id_tag_candidate' if actual else 'symbol_anchor_without_tag'
        records.append(dict(alias_line=n,ids=','.join(sorted(expected)),file=source.relative_to(S).as_posix(),line=f'{lo}-{hi}' if hi!=lo else str(lo),actual_tags=','.join(sorted(actual)),state=state,source_text='\n'.join(span)))
with (out/'alias_tag_consistency.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
counts=dict(collections.Counter(x['state'] for x in records));(out/'tag_summary.json').write_text(json.dumps(dict(counts=counts,limits='Literal alias line/range comparison; different tags, stale anchors or missing literal tags are candidates, not automatically missing implementation. Shared/N/A anchors require semantic adjudication.'),ensure_ascii=False,indent=2),encoding='utf-8')
print('TAG_COUNTS',counts)
print('DIFFERENT_CANDIDATES',[(r['alias_line'],r['ids'],Path(r['file']).name,r['line'],r['actual_tags']) for r in records if r['state']=='different_id_tag_candidate'])
