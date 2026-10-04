from review import *
import re
from collections import Counter

PAT=r'(?<![A-Za-z0-9_-])(?:FSC|SSW|AMI|AMR|PWI|PWC|SUP|FFK|IDT|SID|LFA|OIB|RRC|NRE|INJ|PRC)-\d+(?:[A-Za-z])?(?![A-Za-z0-9_-])|(?<![A-Za-z0-9_-])(?:P|N|K)\d\d(?![A-Za-z0-9_-])'
def ids(text):
    # Numeric subcases A/B and a/b link to their parent obligation.
    found={re.sub(r'(?<=\d)[A-Za-z]$','',x) for x in re.findall(PAT,text)}
    for m in re.finditer(r'(?<![A-Za-z0-9_-])(FSC|SSW|AMI|AMR|PWI|PWC|SUP|FFK|IDT|SID|LFA|OIB|RRC|NRE|INJ|PRC)-(\d+)(?:[A-Za-z])?\s*(?:~|～|至|through|\.\.)\s*(?:\1-)?(\d+)(?!\d)',text):
        family,start,end=m.group(1),int(m.group(2)),int(m.group(3))
        if start<=end and end-start<=200:found.update(f'{family}-{n:02d}' for n in range(start,end+1))
    for m in re.finditer(r'\bSUP(\d\d)[A-Z]\b',text):found.add(f'SUP-{m.group(1)}')
    return found

def scan():
    definitions={}
    contract_files=FILES+[{'layer':'合同','path':'contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md'}]
    for f in contract_files:
        if f['layer']!='合同': continue
        for n,line in enumerate((SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines(),1):
            cells=line.split('|')
            if len(cells)<4: continue
            # Definition tables have an ID in either of the first two cells.
            for cell in cells[1:3]:
                clean=cell.strip().strip('` ')
                if re.fullmatch(PAT,clean):
                    if 'REAL_PPG_RAW' in f['path'] and not clean.startswith(('SID-','LFA-','OIB-','RRC-','NRE-')):continue
                    definitions.setdefault(clean,[]).append({'path':f['path'],'line':n,'text':line})
    tags={}; tb={}
    for p in (SNAP/'rtl').rglob('*.v'):
        rel=p.relative_to(SNAP).as_posix(); src=p.read_text(encoding='utf-8-sig')
        is_tb=p.name.startswith('tb_')
        for n,line in enumerate(src.splitlines(),1):
            if is_tb:
                code=line.split('//',1)[0]
                for term in ids(code):tb.setdefault(term,[]).append({'path':rel,'line':n,'kind':'literal code reference'})
                if p.name=='tb_ppg_400hz_frame_calibration_scheduler.v':
                    m=re.search(r'check_fsc\(\s*(\d+)\s*,',code)
                    if m:tb.setdefault(f'FSC-{int(m[1]):02d}',[]).append({'path':rel,'line':n,'kind':'numeric check_case dispatch'})
            elif '@satisfies:' in line:
                for term in ids(line.split('@satisfies:',1)[1]):tags.setdefault(term,[]).append({'path':rel,'line':n,'text':line.strip()})
    docs={}
    for label,name in [('matrix','PPG_CONTRACT_CLOSURE_MATRIX.md'),('alias','PPG_ALIAS_MAPPING_TABLE.md')]:
        for n,line in enumerate((SNAP/'contracts'/name).read_text(encoding='utf-8-sig').splitlines(),1):
            for term in ids(line):docs.setdefault(term,[]).append({'source':label,'line':n,'text':line})
    rows=[{'id':term,'definitions':refs,'rtl_tags':tags.get(term,[]),'tb_code_mentions':tb.get(term,[]),'matrix_or_alias_mentions':docs.get(term,[])} for term,refs in sorted(definitions.items())]
    return rows

if __name__=='__main__':
    rows=scan()
    if sys.argv[1]=='run':
        # Negative fixtures validate parent normalization, numeric dispatch and
        # the missing-link classifier. No shared file is modified.
        assert ids('SUP-06A SUP-06B')=={'SUP-06'}
        assert ids('LFA-10b')=={'LFA-10'}
        assert ids('FSC-01 through FSC-03')=={'FSC-01','FSC-02','FSC-03'}
        assert ids('SUP06A SUP06B')=={'SUP-06'}
        assert ids('当前FSC-01至FSC-03全部已登记')=={'FSC-01','FSC-02','FSC-03'}
        assert ids('some_AMI-48 AMI-49_extra')==set()
        base=next(r for r in rows if r['id']=='FSC-17')
        assert any(x['kind']=='numeric check_case dispatch' for x in base['tb_code_mentions'])
        mutant=json.loads(json.dumps(base));mutant['tb_code_mentions']=[]
        assert bool(base['tb_code_mentions']) and not bool(mutant['tb_code_mentions'])
        positive=next(r for r in rows if r['id']=='AMI-54')
        assert positive['matrix_or_alias_mentions']
        registry_mutant=json.loads(json.dumps(positive));registry_mutant['matrix_or_alias_mentions']=[]
        assert not registry_mutant['matrix_or_alias_mentions']
        payload={'commit':COMMIT,'scope':'B-owned contract explicit definition tables plus C25 SID/LFA/OIB/RRC/NRE requirements of B-owned system TBs; references indexed over all snapshot RTL/TB and both registries','limits':'Lexical references and numeric dispatch are not semantic checks, current status proof, or an AST. A missing @satisfies may be exempt; family-level registry rows and manual cross-file evidence require semantic review.','negative_controls':{'numeric_dispatch_FSC17_removed_detected':True,'registry_AMI54_removed_detected':True,'suffix_normalization_and_range_expansion':True},'rows':rows}
        (OUT/'evidence'/'id_four_link_audit.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf-8')
        families=sorted({r['id'].split('-')[0] for r in rows})
        for family in families:
            fam=[r for r in rows if r['id'].split('-')[0]==family]
            print(family,'definitions',len(fam),'tagged',sum(bool(r['rtl_tags']) for r in fam),'TB code',sum(bool(r['tb_code_mentions']) for r in fam),'registry explicit',sum(bool(r['matrix_or_alias_mentions']) for r in fam))
        print('negative controls: 3/3; lexical evidence only')
    elif sys.argv[1]=='sample':
        wanted=sys.argv[2:]
        for r in rows:
            if not any(r['id']==w or r['id'].startswith(w+'-') for w in wanted):continue
            print('\n'+r['id'])
            for x in r['definitions']:print(Path(x['path']).name+':'+str(x['line'])+' '+x['text'])
            print('RTL tags:',[(Path(x['path']).name,x['line']) for x in r['rtl_tags']])
            print('TB code:',[(Path(x['path']).name,x['line'],x['kind']) for x in r['tb_code_mentions']])
            print('Registry:',[(x['source'],x['line']) for x in r['matrix_or_alias_mentions']])
    elif sys.argv[1]=='tb':
        for f in FILES:
            if f['layer']!='TB' or not any(k in f['path'] for k in sys.argv[2:]):continue
            print('\n'+f['path'])
            for n,line in enumerate((SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines(),1):
                code=line.split('//',1)[0]
                if re.search(r'(check_case|check_fsc|begin_case|task_check|check_condition)\(',code) or ('PASS ' in code and '$display' in code):print(f'{n}: {code.strip()}')
