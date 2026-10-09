"""Join contract-side rows, TB label sites and log lines per family into review dumps.
Usage: python join_ids.py contract_ids.json tb_sites.json log_labels.json <outdir>
Numbers are compared as integers (FSC-1 == FSC-01); the printed spelling is kept for the report."""
import re, sys, os, json, collections

C = json.load(open(sys.argv[1], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[2], encoding='utf-8'))
L = json.load(open(sys.argv[3], encoding='utf-8'))
OUT = sys.argv[4]
os.makedirs(OUT, exist_ok=True)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family


def key(tok):
    """(family, int number, letter suffix, trailing -n) using the same family grammar as the scanners."""
    if tok == 'SUPRST':
        return ('SUP', 0, 'RST', '')
    fam = family(tok)
    rest = tok[len(fam):].lstrip('-')
    m = re.match(r'^(\d{1,3})([A-Za-z]?)((?:-\d+)?)$', rest)
    if not m:
        return (fam, None, rest, '')
    return (fam, int(m.group(1)), m.group(2).upper(), m.group(3))


fams = collections.defaultdict(lambda: {'contract': collections.defaultdict(list),
                                        'tb': collections.defaultdict(list),
                                        'log': collections.defaultdict(list)})
for r in C:
    k = key(r['id'])
    fams[k[0]]['contract'][k].append(r)
for s in T:
    for t in dict.fromkeys(s['labels']):
        k = key(t)
        fams[k[0]]['tb'][k].append(dict(s, label=t))
for tb, lines in L.items():
    for x in lines:
        for t in dict.fromkeys(x['labels']):
            k = key(t)
            fams[k[0]]['log'][k].append(dict(x, tb=tb, label=t))

summary = []
for fam, d in sorted(fams.items()):
    keys = sorted(set(d['contract']) | set(d['tb']) | set(d['log']), key=lambda k: (k[1] or 0, k[2], k[3]))
    nc = len(d['contract']); nt = len(d['tb']); nl = len(d['log'])
    summary.append((fam, nc, nt, nl))
    with open(os.path.join(OUT, f'{fam}.md'), 'w', encoding='utf-8') as f:
        f.write(f'# {fam}: contract={nc} tb={nt} log={nl}\n\n')
        for k in keys:
            f.write(f'## {fam}-{k[1]}{k[2]}{k[3]}\n')
            for r in d['contract'].get(k, []):
                f.write(f"- C {r['file']}:{r['line']} [{r['section'][:30]}] {' | '.join(r['cells'])[:400]}\n")
            for s in d['tb'].get(k, []):
                f.write(f"- T {s['file'].split('/')[-1]}:{s['line']} ({s['kind']}) \"{s['literal'][:160]}\"\n"
                        f"    ctx {s['ctx_lines'][0]}-{s['ctx_lines'][1]}: {s['ctx'][:500]}\n")
            for x in d['log'].get(k, [])[:4]:
                f.write(f"- L {x['tb']} x{x['count']} {x['verdict']}: {x['text'][:220]}\n")
            f.write('\n')
with open(os.path.join(OUT, '_summary.tsv'), 'w', encoding='utf-8') as f:
    f.write('family\tcontract_ids\ttb_ids\tlog_ids\n')
    for row in summary:
        f.write('\t'.join(map(str, row)) + '\n')
for row in summary:
    print('%-12s contract=%3d tb=%3d log=%3d' % row)
