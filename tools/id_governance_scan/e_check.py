"""List contract IDs with no same-key TB label (code or log) and show where the alias table / matrix
point their evidence. Usage: python e_check.py <repo_root> contract_ids.json tb_sites.json log_labels.json"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

ROOT = sys.argv[1]
C = json.load(open(sys.argv[2], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[3], encoding='utf-8'))
L = json.load(open(sys.argv[4], encoding='utf-8'))


def key(tok):
    fam = family(tok) if not tok.startswith('SUPRST') else 'SUP'
    m = re.match(r'^-?(\d{1,3})', tok[len(fam):])
    return (fam, int(m.group(1)) if m else None)


have = set()
for s in T:
    for t in s['labels']:
        have.add(key(t))
for tb, ls in L.items():
    for x in ls:
        for t in x['labels']:
            have.add(key(t))
alias = open(os.path.join(ROOT, 'contracts', 'PPG_ALIAS_MAPPING_TABLE.md'), encoding='utf-8').read().split('\n')
matrix = open(os.path.join(ROOT, 'contracts', 'PPG_CONTRACT_CLOSURE_MATRIX.md'), encoding='utf-8').read().split('\n')
out = []
for r in C:
    k = (r['family'], r['num'])
    if k in have:
        continue
    pat = re.compile(r'(?<![A-Za-z0-9])' + re.escape(r['family']) + r'-0?' + str(r['num']) + r'(?![0-9])')
    al = [i + 1 for i, l in enumerate(alias) if pat.search(l)]
    mx = [i + 1 for i, l in enumerate(matrix) if pat.search(l)]
    first_alias = alias[al[0] - 1][:220] if al else ''
    out.append((r['family'], r['id'], r['file'], r['line'], al[:6], mx[:6], first_alias))
for o in out:
    print('\t'.join(map(str, o)))
print('E candidates:', len(out), collections.Counter(o[0] for o in out))
