"""Inventory of old line-number anchors in the closure matrix and the alias table.

Usage:
    python anchor_inventory.py [--repo DIR] [--rev REV] --out OUT.json

For every line of contracts/PPG_CONTRACT_CLOSURE_MATRIX.md and
contracts/PPG_ALIAS_MAPPING_TABLE.md (at REV, default HEAD) it records:
  * the git-blame commit that last wrote the line (the "written-at" commit used to
    read the referenced file, brief section 3.13 Q1);
  * every old anchor on the line, with its kind (rtl / contract / matrix / alias /
    report / other), referenced file, line numbers, the cell it sits in, whether it
    is inside ~~strikethrough~~, and any backticked symbol text in the same cell.

Recognised forms (brief section 6.5): `file.v:N`, `file.v:N-M`, `file.v:N,M,K`,
bare `:N` continuing the nearest file name to its left in the same cell,
`Cxx:N` lists (`Cxx:a, Cxx:b-Cxx:c`), `Cxx :N`, `MATRIX:N`, `alias:N`.
A file-name match needs a left boundary so that `tb_xxx.v` is never read as `xxx.v`.
"""
import argparse
import json
import os
import re
import subprocess

FILES = ['contracts/PPG_CONTRACT_CLOSURE_MATRIX.md', 'contracts/PPG_ALIAS_MAPPING_TABLE.md']
FNAME = r'(?<![A-Za-z0-9_])((?:[A-Za-z0-9_]+/)*[A-Za-z0-9_]+\.(?:v|vh|md|sh|py|json|f))'
NUMS = r'(\d+(?:\s*-\s*\d+)?(?:\s*,\s*\d+(?:\s*-\s*\d+)?)*)'
FILE_ANCHOR = re.compile(FNAME + r'`?\s*:\s*' + NUMS)
CID_ANCHOR = re.compile(r'(?<![A-Za-z0-9])(C\d\d)\s*:\s*' + NUMS)
SELF_ANCHOR = re.compile(r'(?<![A-Za-z0-9])(MATRIX|matrix|alias|ALIAS)\s*:\s*' + NUMS)
BARE = re.compile(r'(?<![A-Za-z0-9_.)\]>:])`?:(\d+(?:\s*-\s*\d+)?(?:\s*,\s*\d+(?:\s*-\s*\d+)?)*)`?')
TICKED = re.compile(r'`([^`]+)`')


def blame(repo, rev, path):
    out = subprocess.run(['git', '-C', repo, 'blame', '--line-porcelain', rev, '--', path],
                         capture_output=True).stdout.decode('utf-8', 'replace').split('\n')
    commits = []
    for line in out:
        if re.match(r'^[0-9a-f]{40} ', line):
            commits.append(line[:40])
    return commits


def cells(line):
    """(start, end) of every table cell; whole line when not a table row."""
    if not line.lstrip().startswith('|'):
        return [(0, len(line))]
    pos = [i for i, ch in enumerate(line) if ch == '|']
    return [(pos[k] + 1, pos[k + 1]) for k in range(len(pos) - 1)]


def strike(line):
    spans, p = [], 0
    while True:
        a = line.find('~~', p)
        if a < 0:
            return spans
        b = line.find('~~', a + 2)
        if b < 0:
            return spans
        spans.append((a, b + 2))
        p = b + 2


def kind_of(fname):
    base = os.path.basename(fname)
    if base.endswith(('.v', '.vh')):
        return 'rtl'
    if base == 'PPG_CONTRACT_CLOSURE_MATRIX.md':
        return 'matrix'
    if base == 'PPG_ALIAS_MAPPING_TABLE.md':
        return 'alias'
    if base.endswith('.md') and ('CONTRACT' in base or 'contract' in base or base.startswith(('PPG_', 'TAPEOUT'))):
        return 'contract'
    if base.endswith('.md'):
        return 'report'
    return 'other'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='.')
    ap.add_argument('--rev', default='HEAD')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    items = []
    for path in FILES:
        text = subprocess.run(['git', '-C', a.repo, 'show', '%s:%s' % (a.rev, path)],
                              capture_output=True).stdout.decode('utf-8')
        lines = text.split('\n')
        commits = blame(a.repo, a.rev, path)
        for n, line in enumerate(lines, 1):
            sp = strike(line)
            for c0, c1 in cells(line):
                cell = line[c0:c1]
                found = []
                for m in FILE_ANCHOR.finditer(cell):
                    found.append((m.start(), m.end(), kind_of(m.group(1)), os.path.basename(m.group(1)), m.group(2)))
                for m in CID_ANCHOR.finditer(cell):
                    found.append((m.start(), m.end(), 'contract', m.group(1), m.group(2)))
                for m in SELF_ANCHOR.finditer(cell):
                    found.append((m.start(), m.end(), 'matrix' if m.group(1).lower() == 'matrix' else 'alias',
                                  m.group(1), m.group(2)))
                covered = [(s, e) for s, e, _, _, _ in found]
                for m in BARE.finditer(cell):
                    if any(s <= m.start() < e for s, e in covered):
                        continue
                    left = [f for f in found if f[0] < m.start()]
                    ctx = max(left, key=lambda f: f[0]) if left else None
                    found.append((m.start(), m.end(), ctx[2] if ctx else 'bare-no-context',
                                  ctx[3] if ctx else None, m.group(1)))
                symbols = [t for t in TICKED.findall(cell) if not re.search(r':\d', t)]
                for s, e, kind, ref, nums in sorted(found):
                    items.append({'file': os.path.basename(path), 'line': n, 'blame': commits[n - 1][:10] if n - 1 < len(commits) else None,
                                  'kind': kind, 'ref': ref, 'nums': re.sub(r'\s+', '', nums), 'pos': c0 + s, 'end': c0 + e,
                                  'strike': any(x <= c0 + s < y for x, y in sp),
                                  'text': cell[s:e], 'cell_symbols': symbols[:8]})
    json.dump(items, open(a.out, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print('anchors', len(items))


if __name__ == '__main__':
    main()
