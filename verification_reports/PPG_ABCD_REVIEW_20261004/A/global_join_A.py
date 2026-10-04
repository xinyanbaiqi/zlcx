from pathlib import Path
import json,csv,re,collections,copy
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';root=B.parent.parent
out=E/'global_closure_20261004';out.mkdir(exist_ok=True)
presence=json.loads((E/'id_presence_v2.json').read_text(encoding='utf-8'))['rows']
group_paths={
 'B':root/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/evidence/id_four_link_audit.json',
 'C':root/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/id_review_matrix.csv',
 'D':root/'01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D/evidence/id_local_D.json',
 'A':E/'closure_skill_20261004/top_24_semantic.json'}
reviews=collections.defaultdict(list)
for owner,path in group_paths.items():
    raw=path.read_bytes();(out/(owner+'_'+path.name)).write_bytes(raw)
    rows=list(csv.DictReader(raw.decode('utf-8-sig').splitlines())) if path.suffix=='.csv' else json.loads(raw.decode('utf-8'))
    if isinstance(rows,dict):rows=rows['rows']
    for row in rows:
        identity=row.get('id') or row.get('contract_id')
        if identity:reviews[identity].append(dict(owner=owner,source=str(path),row=row))
def family(identity):
    if re.fullmatch(r'[KNPRLD]\d{2}',identity):return identity[0]
    if identity.startswith('G-FP-'):return 'G-FP'
    return re.sub(r'-\d+.*$','',identity)
def missing(identity,pools):return [name for name,values in pools.items() if identity not in values]
pools={k:{'CTRL-01'} for k in ('definition','rtl_tag','tb_text','index')}
assert missing('CTRL-01',pools)==[]
controls=[]
for key in pools:
    broken=copy.deepcopy(pools);broken[key].clear();actual=missing('CTRL-01',broken)
    assert actual==[key],actual;controls.append(dict(removed=key,actual=actual))
assert family('TOP-24')=='TOP' and family('N08')=='N' and family('G-FP-01-D01-04')=='G-FP'
records=[]
for row in presence:
    identity=row['id']; r=reviews.get(identity,[])
    records.append(dict(id=identity,family=family(identity),contract_refs=';'.join(f"{x['file']}:{x['line']}" for x in row['contract_definition']),rtl_tag_refs=';'.join(f"{x['file']}:{x['line']}" for x in row['rtl_tag']),tb_text_refs=';'.join(f"{x['file']}:{x['line']}" for x in row['tb_text']),index_refs=';'.join(f"{x['file']}:{x['line']}" for x in row['matrix_or_alias']),no_anchor_reason_refs=';'.join(f"{x['file']}:{x['line']}" for x in row['explicit_no_rtl_anchor_reason']),missing_text_edges=','.join(row['missing_presence_candidate']),semantic_review_owners=','.join(sorted(set(x['owner'] for x in r))),semantic_review_sources=';'.join(sorted(set(x['source'] for x in r))),semantic_scope='已合并逐项语义审阅；状态与限制须读原行，非验收CLOSED' if r else '无逐ID独立语义记录；按家族/结构抽查，机械候选不等于活跃验收缺口'))
with (out/'all_id_four_links.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
families=[]
for name in sorted(set(x['family'] for x in records)):
    rows=[r for r in records if r['family']==name]
    reviewed=[r for r in rows if r['semantic_review_owners']]
    families.append(dict(family=name,candidates=len(rows),with_contract=sum(bool(r['contract_refs']) for r in rows),with_semantic_record=len(reviewed),owners=sorted(set(o for r in reviewed for o in r['semantic_review_owners'].split(','))),sample_ids=[r['id'] for r in reviewed[:3]],unreviewed_ids=[r['id'] for r in rows if not r['semantic_review_owners']]))
(out/'family_summary.json').write_text(json.dumps(families,ensure_ascii=False,indent=2),encoding='utf-8')
(out/'negative_controls.json').write_text(json.dumps(controls,ensure_ascii=False,indent=2),encoding='utf-8')
print('JOIN',len(records),'WITH_SEMANTIC_RECORD',sum(bool(r['semantic_review_owners']) for r in records),'FAMILIES',len(families))
print('FAMILY_COMPLETE_INDEX',[(r['family'],r['candidates'],r['with_semantic_record'],r['owners']) for r in families])
print('FAMILY_NO_RECORD_WITH_CONTRACT',[(r['family'],r['candidates'],r['unreviewed_ids'][:12]) for r in families if r['with_contract'] and not r['with_semantic_record']])
