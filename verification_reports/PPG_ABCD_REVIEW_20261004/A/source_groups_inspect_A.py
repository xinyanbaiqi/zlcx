from pathlib import Path
import re,sys,collections
B=Path(__file__).resolve().parent;S=B/'snapshot'
def scope(lines,n):
 if not lines[n-1].startswith(('#','|')):return lines[n-1]
 level=len(lines[n-1])-len(lines[n-1].lstrip('#'))
 end=next((i for i in range(n,len(lines)) if (lines[i].startswith('#') and len(lines[i])-len(lines[i].lstrip('#'))<=level) or (not level and not lines[i].startswith('|'))),len(lines))
 return '\n'.join(lines[n-1:end])
def token(name,text):return bool(re.search(r'\b'+re.escape(name)+r'\b',text))
assert scope(['### good','| i_a |','#### child','| o_b |','### other','| i_wrong |'],1)=='### good\n| i_a |\n#### child\n| o_b |'
assert not token('i_wrong',scope(['### good','| i_a |','### other','| i_wrong |'],1))
assert scope(['| a |','| b |','','other'],1)=='| a |\n| b |'
def active_source(cell):
 ref=re.search(r'([\w/]+\.md):(\d+)',cell)
 if not ref:return None
 override=re.search(r'当前\s*`?:(\d+(?:-\d+)?)',cell)
 return ('contracts/'+ref[1].split('/')[-1],int((override[1] if override else ref[2]).split('-')[0]),override[0] if override else ref[0])
assert active_source('`ppg_system_integration/a.md:1` ~~`:1`~~ **当前`:2`（分组文字行）**')[1]==2
assert active_source('`ppg_system_integration/a.md:1`')[1]==1
compact='--compact' in sys.argv;codes=set(sys.argv[1:]);ml=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
groups=collections.defaultdict(list);counts=collections.Counter();cache={}
for n,l in enumerate(ml,1):
 c=[v.strip() for v in l.split('|')]
 if len(c)<7 or c[1] not in codes or c[3] not in ('input','output','inout'):continue
 ref=active_source(c[2]);name=re.fullmatch(r'`(\w+)`',c[4])
 if not ref or not name:continue
 path,ln,_=ref;counts[c[1]]+=1
 if path not in cache:cache[path]=(S/path).read_text(encoding='utf-8').splitlines()
 if not token(name[1],scope(cache[path],ln)):groups[(c[1],ln,path)].append((n,name[1]))
print('PORT_ROW_COUNTS',dict(counts))
for (code,ln,path),rows in groups.items():
 print('CANDIDATE',code,ln,'N',len(rows),rows);print(scope(cache[path],ln)[:260] if compact else scope(cache[path],ln))
