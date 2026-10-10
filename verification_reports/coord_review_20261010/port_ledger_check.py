import re,sys,os,collections
root=sys.argv[1]
M=os.path.join(root,'contracts','PPG_CONTRACT_CLOSURE_MATRIX.md')
lines=open(M,encoding='utf-8').read().split('\n')
# index rtl files by basename
files={}
for dp,dn,fn in os.walk(os.path.join(root,'rtl')):
    for f in fn:
        if f.endswith(('.v','.vh')): files.setdefault(f,[]).append(os.path.join(dp,f))
cache={}
def text(b):
    if b not in cache:
        ps=files.get(b,[])
        cache[b]=open(ps[0],encoding='utf-8',errors='replace').read() if ps else None
    return cache[b]
def has_port(t,p):
    # declaration (input/output ... p) or instance connection .p(
    return re.search(r'\b(input|output|inout)\b[^;\n]*\b'+re.escape(p)+r'\b',t) is not None or re.search(r'\.'+re.escape(p)+r'\s*\(',t) is not None
start=next(i for i,l in enumerate(lines) if l.startswith('### 12.5 '))
end=next(i for i,l in enumerate(lines) if l.startswith('### 12.6 '))
anc=re.compile(r'`([A-Za-z0-9_]+\.vh?)`\s*`([A-Za-z_][A-Za-z0-9_]*)`')
rows=0;bad=[];nofile=[];missing_sym=[]
for i in range(start,end):
    l=lines[i]
    if not l.startswith('|'): continue
    c=[x.strip() for x in l.split('|')]
    if len(c)<7: continue
    m=re.fullmatch(r'`([A-Za-z_]\w*)`',c[4])
    if not m: continue
    port=m.group(1)
    a=anc.findall(c[5])
    if not a: continue
    rows+=1
    for f,sym in a:
        t=text(f)
        if t is None: nofile.append((i+1,port,f,sym)); continue
        if not re.search(r'\b'+re.escape(sym)+r'\b',t): missing_sym.append((i+1,port,f,sym))
        if has_port(t,port) and sym!=port: bad.append((i+1,port,f,sym))
        elif not has_port(t,port) and sym!=port: pass
print('rows_with_col5_anchor',rows)
print('col5 wrong (file has same-name port but anchor symbol differs):',len(bad),'rows',len(set(b[0] for b in bad)))
for b in bad[:60]: print('  BAD',b)
print('anchor file not found:',len(nofile),nofile[:5])
print('anchor symbol absent from file:',len(missing_sym),missing_sym[:5])
# col5 anchors where file lacks the port name
lack=[]
for i in range(start,end):
    l=lines[i]
    if not l.startswith('|'): continue
    c=[x.strip() for x in l.split('|')]
    if len(c)<7: continue
    m=re.fullmatch(r'`([A-Za-z_]\w*)`',c[4])
    if not m: continue
    port=m.group(1)
    for f,sym in anc.findall(c[5]):
        t=text(f)
        if t is not None and not has_port(t,port): lack.append((i+1,port,f,sym))
print('col5 anchors whose file lacks the row port:',len(lack))
for x in lack[:20]: print('  LACK',x)
