from review import *
import re

comments=[]
for f in FILES:
 if f['layer']=='合同': continue
 lines=(SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines()
 selected=[]; in_block=False
 for n,line in enumerate(lines,1):
  has_comment=in_block; in_string=False; j=0; fragments=[]; start=0 if in_block else None
  while j<len(line):
   if in_block:
    if line[j:j+2]=='*/':fragments.append(line[start:j]);in_block=False;start=None;j+=2
    else:j+=1
   elif in_string:
    if line[j]=='\\':j+=2
    elif line[j]=='"':in_string=False;j+=1
    else:j+=1
   elif line[j]=='"':in_string=True;j+=1
   elif line[j:j+2]=='//':has_comment=True;fragments.append(line[j+2:]);break
   elif line[j:j+2]=='/*':has_comment=True;in_block=True;j+=2;start=j
   else:j+=1
  if in_block:fragments.append(line[start:])
  comment=' '.join(fragments).strip()
  if has_comment and re.search(r'[A-Za-z0-9\u4e00-\u9fff]',comment):selected.append((n,comment))
 comments.append({'path':f['path'],'layer':f['layer'],'lines':selected})
if sys.argv[1]=='stats':
 for i,f in enumerate(comments): print(i,f['layer'],len(f['lines']),f['path'])
 (OUT/'evidence'/'comment_inventory.json').write_text(json.dumps(comments,ensure_ascii=False,indent=2),encoding='utf-8')
elif sys.argv[1]=='comments':
 for i in map(int,sys.argv[2:]):
  f=comments[i];print('\n'+f['path'])
  for n,line in f['lines']:print(f'{n}: {line}')
elif sys.argv[1]=='comment_slice':
 f=comments[int(sys.argv[2])];print(f['path'])
 for n,line in f['lines'][int(sys.argv[3]):int(sys.argv[4])]:print(f'{n}: {line}')
elif sys.argv[1] in ('unique','unique_slice'):
 unique={}
 for f in comments:
  for n,line in f['lines']:
   key=re.sub(r'\s+',' ',line).strip(' /-*\t')
   if not re.search(r'[A-Za-z0-9\u4e00-\u9fff]',key):continue
   unique.setdefault(key,[]).append({'path':f['path'],'line':n})
 entries=[{'text':key,'locations':refs} for key,refs in unique.items()]
 if sys.argv[1]=='unique':
  (OUT/'evidence'/'unique_comments.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf-8')
  print('Unique comments',len(entries),'all occurrences',sum(len(e['locations']) for e in entries))
 else:
  for i,e in enumerate(entries[int(sys.argv[2]):int(sys.argv[3])],int(sys.argv[2])):
   ref=e['locations'][0];print(f'{i} {Path(ref["path"]).stem}:{ref["line"]}: {e["text"]}')
elif sys.argv[1]=='versions':
 for f in FILES:
  if f['layer']!='合同':continue
  print('\n'+f['path'])
  lines=(SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines()
  for n,line in enumerate(lines,1):
   if n<20 or re.search(r'Current.*[Vv]|[Ss]ole current|normative version|唯一.*版本|C\d+.*V\d+\.',line): print(f'{n}: {line}')
elif sys.argv[1]=='ids':
 ids={};matrix=(SNAP/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8-sig').splitlines()
 aliases=(SNAP/'contracts/PPG_ALIAS_MAPPING_TABLE.md').read_text(encoding='utf-8-sig').splitlines()
 pat=r'\b(?:FSC|SSW|AMI|AMR|PWI|PWC|SUP|SID|LFA|OIB|RRC|NRE|INJ|PRC|FFK|IDT)-\d+(?:[A-Za-z])?\b|\b(?:P|N|K)\d\d\b'
 for f in FILES:
  if f['layer']!='合同':continue
  lines=(SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines()
  found={}
  for n,line in enumerate(lines,1):
   for term in re.findall(pat,line):found.setdefault(term,[]).append(n)
  ids[f['path']]=found
  print('\n'+f['path']+' '+', '.join(found))
 (OUT/'evidence'/'contract_id_inventory.json').write_text(json.dumps(ids,ensure_ascii=False,indent=2),encoding='utf-8')
 allids=sorted({term for f in ids.values() for term in f})
 rows=[]
 for term in allids:
  exact=re.compile(r'(?<![A-Za-z0-9_-])'+re.escape(term)+r'(?![A-Za-z0-9_-])')
  entries=[]
  for label,lines in [('matrix',matrix),('alias',aliases)]:
   entries.extend({'source':label,'line':n,'text':line} for n,line in enumerate(lines,1) if exact.search(line))
  tbs=[]
  for f in FILES:
   if f['layer']!='TB':continue
   lines=(SNAP/f['path']).read_text(encoding='utf-8-sig').splitlines()
   matches=[n for n,line in enumerate(lines,1) if exact.search(line)]
   if matches:tbs.append({'path':f['path'],'lines':matches})
  rows.append({'id':term,'references':entries,'primary_tb_mentions':tbs})
 (OUT/'evidence'/'contract_id_links.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
elif sys.argv[1]=='links':
 rows=json.loads((OUT/'evidence'/'contract_id_links.json').read_text(encoding='utf-8'))
 selected=sys.argv[2:]
 for r in rows:
  if selected and not any(r['id'].startswith(k) for k in selected):continue
  print('\n'+r['id']+' primary_TB='+','.join(Path(t['path']).name for t in r['primary_tb_mentions']))
  for ref in r['references']:
   if ref['text'].lstrip().startswith('|'): print(ref['source']+':'+str(ref['line'])+' '+ref['text'])
