"""Re-scan gate for the merge batch: compare a new TB-label scan against the audited baseline.
Usage: python rescan_diff.py baseline_tb_sites.json new_tb_sites.json contract_ids.json
Reports, for labels whose family owns a contract table:
  B?  a (file, label, check-code) site that did not exist in the baseline -> its meaning must be re-read
      against the contract row of the same number (possible same-number-different-meaning);
  D   a label number that the contract table does not define and the baseline did not already carry.
Line numbers are ignored; only the label and the whitespace-normalised check code are compared."""
import sys, os, re, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

base = json.load(open(sys.argv[1], encoding='utf-8'))
new = json.load(open(sys.argv[2], encoding='utf-8'))
rows = json.load(open(sys.argv[3], encoding='utf-8'))['rows']
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')
table = {}
for r in rows:
    table.setdefault(r['family'], set()).add(r['num'])


def num(t):
    m = re.match(r'^-?(\d{1,3})', t[len(family(t)):]) if t != 'SUPRST' else None
    return int(m.group(1)) if m else None


def prints(sites):
    out = set()
    for s in sites:
        if s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1:
            continue  # range banners are judged separately, not per check
        ctx = re.sub(r'\s+', ' ', s['ctx']).strip()
        for t in s['labels']:
            out.add((s['file'], t, ctx))
    return out


b, n = prints(base), prints(new)
b_labels = {(f, t) for f, t, _ in b}
reports = []
for f, t, ctx in sorted(n - b):
    fam = family(t) if t != 'SUPRST' else 'SUP'
    if fam not in table:
        continue
    k = num(t)
    if k is not None and k not in table[fam] and (f, t) not in b_labels:
        reports.append(('D', f, t, ctx[:160]))
    elif k is not None and k in table[fam]:
        reports.append(('B?', f, t, ctx[:160]))
for r in reports:
    print('\t'.join(r))
print('reports=%d' % len(reports))
