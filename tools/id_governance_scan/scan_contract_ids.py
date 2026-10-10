"""ID governance audit, contract side: every table row whose FIRST cell is a single acceptance-style ID.
Usage: python scan_contract_ids.py <repo_root> <out.json>
Output rows: {id, family, file, line, section, cells[1:]} ; also per-file duplicate / gap / range-claim findings."""
import re, sys, json, glob, os, collections

ROOT = sys.argv[1]
OUT = sys.argv[2]
# ID token: FAMILY-NN[a] (family may itself contain digits/dashes, e.g. AV4C-01, G-FP-01) or bare K01/P01 style.
ID_RE = r'(?:[A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*-\d{1,3}[A-Za-z]?)'
ROW = re.compile(r'^\|\s*(?:\*\*)?`?(' + ID_RE + r')`?(?:\*\*)?(?![-0-9A-Za-z_])([^|]*)\|(.*)$')
HEAD = re.compile(r'^(#{1,6})\s+(.*)')
SKIP_FILES = {'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'}
# first-cell tokens that are not acceptance IDs: contract numbers C01..C25 and the matrix-local R/M/D/L/K/P/N rows
NOT_ACCEPT = re.compile(r'^C\d{2}$')


def family(i):
    m = re.match(r'^(.*?)-?(\d{1,3})([A-Za-z]?)$', i)
    return m.group(1), int(m.group(2)), m.group(3)


rows = []
for path in sorted(glob.glob(os.path.join(ROOT, 'contracts', '*.md'))):
    f = os.path.basename(path)
    if f in SKIP_FILES:
        continue
    sec = ''
    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        h = HEAD.match(line)
        if h:
            sec = h.group(2).strip()[:80]
            continue
        m = ROW.match(line)
        if not m or NOT_ACCEPT.match(m.group(1)):
            continue
        cells = [c.strip() for c in m.group(3).rstrip().rstrip('|').split('|')]
        if m.group(2).strip():  # 'MGR-01复位' style: title shares the ID cell
            cells = [m.group(2).strip()] + cells
        fam, num, suf = family(m.group(1))
        rows.append({'id': m.group(1), 'family': fam, 'num': num, 'suffix': suf, 'file': f, 'line': n,
                     'section': sec, 'cells': cells})

# per (file, family) duplicates and gaps
findings = []
by = collections.defaultdict(list)
for r in rows:
    by[(r['file'], r['family'])].append(r)
for (f, fam), rs in sorted(by.items()):
    ids = collections.Counter(r['id'] for r in rs)
    for i, c in ids.items():
        if c > 1:
            findings.append({'kind': 'duplicate', 'file': f, 'family': fam, 'id': i,
                             'lines': [r['line'] for r in rs if r['id'] == i]})
    nums = sorted({r['num'] for r in rs})
    gaps = [k for k in range(nums[0], nums[-1] + 1) if k not in nums]
    if gaps:
        findings.append({'kind': 'gap', 'file': f, 'family': fam, 'missing': gaps, 'range': [nums[0], nums[-1]]})

# same ID defined in more than one contract file
byid = collections.defaultdict(list)
for r in rows:
    byid[r['id']].append(r)
for i, rs in sorted(byid.items()):
    if len({r['file'] for r in rs}) > 1:
        findings.append({'kind': 'cross_file_duplicate', 'id': i,
                         'where': [(r['file'], r['line'], (r['cells'] or [''])[0][:40]) for r in rs]})

# range claims in prose: "FAM-aa至FAM-bb" / "FAM-aa through FAM-bb" / "FAM-aa~bb" / "FAM-aa..FAM-bb" that exceed the table
RANGE = re.compile(r'(?<![A-Za-z0-9_-])([A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*)-(\d{2})\s*(?:至|到|~|～|through|to|\.\.|-)\s*(?:\1-)?(\d{2})(?!\d)')
for path in sorted(glob.glob(os.path.join(ROOT, 'contracts', '*.md'))):
    f = os.path.basename(path)
    if f in SKIP_FILES:
        continue
    fams = {fam: max(r['num'] for r in rs) for (ff, fam), rs in by.items() if ff == f}
    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        for m in RANGE.finditer(line):
            fam, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
            if fam in fams and hi > fams[fam]:
                findings.append({'kind': 'range_exceeds_table', 'file': f, 'line': n, 'text': m.group(0),
                                 'table_max': fams[fam]})
json.dump({'rows': rows, 'findings': findings}, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
fc = collections.Counter((r['file'], r['family']) for r in rows)
for (f, fam), c in sorted(fc.items()):
    print(f'{f[:58]:58s} {fam:8s} {c:3d}')
print('findings:', collections.Counter(x['kind'] for x in findings))
for x in findings:
    print(' ', x)
