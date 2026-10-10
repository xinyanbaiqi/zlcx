"""ID governance audit, log side: which governed labels a real regression run actually printed.
Usage: python scan_logs.py <out.json> <tb_name>=<xsim.log> ...
Every log line carrying a governed label is kept verbatim (first 300 chars) with its occurrence count."""
import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import GOV, NOISE_FAM, family

out = {}
for arg in sys.argv[2:]:
    tb, path = arg.split('=', 1)
    lines = collections.OrderedDict()
    for l in open(path, encoding='utf-8', errors='replace'):
        l = l.rstrip('\n')
        if l.startswith(('#', 'INFO:', 'Time resolution', '$finish')):
            continue
        toks = [t for t in GOV.findall(l) if family(t) not in NOISE_FAM]
        if toks:
            key = l[:300]
            if key not in lines:
                lines[key] = {'text': key, 'labels': toks, 'count': 0,
                              'verdict': 'PASS' if 'PASS' in l else ('FAIL' if 'FAIL' in l else 'INFO')}
            lines[key]['count'] += 1
    out[tb] = list(lines.values())
json.dump(out, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for tb, ls in out.items():
    labs = collections.Counter(t for x in ls for t in x['labels'])
    print(f'{tb:60s} lines={len(ls):4d} distinct_labels={len(labs):4d}')
