"""TB-side statistics per TB file: families, distinct labels in code, labels seen on PASS lines of the real log.
Usage: python tb_stats.py tb_sites.json log_labels.json out.md"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

T = json.load(open(sys.argv[1], encoding='utf-8'))
L = json.load(open(sys.argv[2], encoding='utf-8'))
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')
code = collections.defaultdict(set)
fams = collections.defaultdict(set)
banners = collections.defaultdict(set)
for s in T:
    tb = s['file'].split('/')[-1].rsplit('.', 1)[0]
    if s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1:
        banners[tb].add(s['literal'][:70])
        continue
    for t in s['labels']:
        code[tb].add(t)
        fams[tb].add(family(t) if t != 'SUPRST' else 'SUP')
with open(sys.argv[3], 'w', encoding='utf-8') as f:
    f.write('| TB | 编号族 | 代码中不同标签数 | 实际日志PASS行出现的标签数 | 总横幅 |\n| --- | --- | ---: | ---: | --- |\n')
    for tb in sorted(set(code) | set(banners)):
        seen = {t for x in L.get(tb, []) if x['verdict'] == 'PASS' for t in x['labels']} & code[tb]
        f.write('| %s | %s | %d | %d | %s |\n' % (tb, '、'.join(sorted(fams[tb])), len(code[tb]), len(seen),
                                                  '；'.join('`%s`' % b for b in sorted(banners[tb])) or '—'))
print('ok')
