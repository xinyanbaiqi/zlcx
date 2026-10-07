import json, re, sys
# usage: fix_align.py <gate_json_dir> <rtl_root> <module> [skip_lines...]
gd, root, mod = sys.argv[1:4]; skip = set(int(x) for x in sys.argv[4:])
d = json.load(open(f'{gd}/{mod}.json', encoding='utf-8'))
p = f'{root}/{mod}/{mod}.v'
L = open(p, encoding='utf-8').read().split('\n')
n = 0
for i in d['issues']:
    if (i.get('rule') or '') != 'comments.region_anchor' or i['line'] in skip: continue
    m = re.search(r'column (\d+), aligned.*got (\d+)', i['message']); tgt, got = int(m.group(1)), int(m.group(2))
    k = i['line'] - 1; s = L[k]; c = s.index('//')
    code = s[:c].rstrip(); sp = len(s[:c]) - len(code)
    nsp = sp + (tgt - got)
    if nsp < 1: print('cannot', i['line']); continue
    L[k] = code + ' ' * nsp + s[c:]; n += 1
open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(L)); print(mod, 'fixed', n)
