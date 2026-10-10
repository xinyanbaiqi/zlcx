"""Build the per-ID comparison table and per-family statistics for the report.
Usage: python gen_table.py <repo_root> contract_ids.json tb_sites.json log_labels.json out_table.md out_stats.md"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family
from decisions import DEC, FAMILY_DEFAULT, CONTRACT_ONLY, TB_ONLY, CMAP

ROOT = sys.argv[1]
C = json.load(open(sys.argv[2], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[3], encoding='utf-8'))
L = json.load(open(sys.argv[4], encoding='utf-8'))
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')


def key(tok):
    if tok == 'SUPRST':
        return ('SUP', 0)
    fam = family(tok)
    m = re.match(r'^-?(\d{1,3})', tok[len(fam):])
    return (fam, int(m.group(1)) if m else None)


crow = collections.defaultdict(list)
for r in C:
    crow[(r['family'], r['num'])].append(r)
tsite = collections.defaultdict(list)
banner = collections.defaultdict(list)
for s in T:
    for t in dict.fromkeys(s['labels']):
        k = key(t)
        (banner if (s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1)
         else tsite)[k].append((s, t))
printed = collections.defaultdict(set)
for tb, ls in L.items():
    for x in ls:
        if x['verdict'] != 'PASS':
            continue
        for t in x['labels']:
            printed[key(t)].add(t)
contract_fams = {r['family'] for r in C}
alias = open(os.path.join(ROOT, 'contracts', 'PPG_ALIAS_MAPPING_TABLE.md'), encoding='utf-8').read().split('\n')


def alias_lines(fam, num):
    pat = re.compile(r'(?<![A-Za-z0-9])' + re.escape(fam) + r'-0?' + str(num) + r'(?![0-9])')
    return [i + 1 for i, l in enumerate(alias) if pat.search(l)]


keys = sorted(set(crow) | set(tsite), key=lambda k: (k[0], k[1] if k[1] is not None else -1))
rows = []
for k in keys:
    fam, num = k
    cr = crow.get(k, [])
    ts = tsite.get(k, [])
    cloc = '; '.join('%s:%d' % (CMAP.get(r['file'], r['file']), r['line']) for r in cr) or '—'
    files = collections.OrderedDict()
    for s, t in ts:
        files.setdefault(os.path.splitext(s['file'].split('/')[-1])[0].replace('tb_ppg_', ''), []).append((s['line'], t))
    tloc = '; '.join('%s:%s' % (f, ','.join(str(l) for l, _ in v[:3]) + ('…' if len(v) > 3 else '')) for f, v in files.items()) or '—'
    subs = sorted({t for _, t in ts if re.search(r'\d[A-Za-z]$|-[A-Z]+$|\d-\d', t)})
    if k in DEC:
        cls, note = DEC[k]
    elif fam in TB_ONLY:
        cls, note = TB_ONLY[fam]
    elif fam in CONTRACT_ONLY:
        cls, note = CONTRACT_ONLY[fam]
    elif cr and (ts or fam == 'RTR'):
        cls, note = FAMILY_DEFAULT.get(fam, ('A', ''))
    elif cr:
        al = alias_lines(fam, num)
        cls, note = 'E', ('无同名TB标签；别名表%s行' % '/'.join(map(str, al[:5]))) if al else '无同名TB标签，别名表无映射'
    else:
        cls, note = ('D' if fam in contract_fams else 'F'), '合同无此编号' if fam in contract_fams else 'TB本地编号'
    if not printed.get(k) and ts and cls in ('A', 'C') and 'FAIL' not in note and '注释' not in note and '组合' not in note:
        if all(s['kind'] in ('fail',) for s, _ in ts):
            note = (note + '；' if note else '') + '仅FAIL分支带编号'
    if subs:
        note = (note + '；' if note else '') + '子标签：' + '、'.join(subs[:6])
    title = (cr[0]['cells'][0] if cr and cr[0]['cells'] else '').replace('|', '/')[:40]
    idtxt = 'SUPRST' if k == ('SUP', 0) else '%s-%02d' % (fam, num) if num is not None else fam
    rows.append((fam, idtxt, title, cloc, tloc, cls, note.replace('|', '/')))

with open(sys.argv[5], 'w', encoding='utf-8') as f:
    f.write('| 族 | 编号 | 合同条目标题 | 合同位置 | TB位置（文件:行） | 分类 | 说明 |\n| --- | --- | --- | --- | --- | --- | --- |\n')
    for r in rows:
        f.write('| ' + ' | '.join(r) + ' |\n')
stat = collections.defaultdict(collections.Counter)
for r in rows:
    stat[r[0]][r[5]] += 1
tot = collections.Counter(r[5] for r in rows)
with open(sys.argv[6], 'w', encoding='utf-8') as f:
    cls_order = ['A', 'B', 'C', 'D', 'E', 'F', '待定', 'N/A']
    f.write('| 族 | 合同条目数 | TB带编号检查数 | ' + ' | '.join(cls_order) + ' |\n| --- | ---: | ---: | ' + ' | '.join(['---:'] * len(cls_order)) + ' |\n')
    for fam in sorted(stat):
        nc = sum(1 for k in crow if k[0] == fam)
        nt = sum(1 for k in tsite if k[0] == fam)
        f.write('| %s | %d | %d | ' % (fam, nc, nt) + ' | '.join(str(stat[fam].get(c, 0)) for c in cls_order) + ' |\n')
    f.write('| **合计** | %d | %d | ' % (len(crow), len(tsite)) + ' | '.join(str(tot.get(c, 0)) for c in cls_order) + ' |\n')
print(len(rows), dict(tot))
