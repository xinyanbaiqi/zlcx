# -*- coding: utf-8 -*-
"""Stage 4: write the old -> new anchor table into the matrix and the alias table.

Usage:
    python anchor_apply.py --table anchor_mapping_table.tsv [--repo DIR] [--base 7a8eabf]
                           [--dry-run] [--report OUT.tsv]

The table (anchor_mapping.py) was built on the base revision.  For each of
contracts/PPG_CONTRACT_CLOSURE_MATRIX.md and contracts/PPG_ALIAS_MAPPING_TABLE.md the
base text is aligned with the working-tree text (difflib, line level) so that rows
added or edited after the base are followed.  Inside a mapped line the old anchor is
found again by its occurrence index among identical texts on the base line; when the
line was edited after the base the same occurrence must still exist, otherwise the
anchor is reported as `unplaced` and nothing is written for it.

Only rows of class `convert` are written.  Surrounding backticks of the old text are
absorbed so that `` `file.v:12` `` becomes `` `file.v` `sym` `` and not a nested quote.
Every line that keeps an old anchor on purpose (history-dated, history, not-anchor,
external) is written to anchor_history_allowlist.json by SHA-1 of the stripped final
line, which is what anchor_check.py reads.

Exit status 1 when any convert row could not be placed.
"""
import argparse
import csv
import difflib
import hashlib
import json
import os
import subprocess
import sys

DOCS = ['PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md']
HERE = os.path.dirname(os.path.abspath(__file__))


def git_show(repo, rev, path):
    return subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (rev, path)],
                          capture_output=True).stdout.decode('utf-8').replace('\r\n', '\n')


def occurrence(line, text, pos):
    """Index of the occurrence of text that starts at pos."""
    k, i = 0, line.find(text)
    while i >= 0 and i < pos:
        k += 1
        i = line.find(text, i + 1)
    return k if i == pos else None


def nth(line, text, k):
    i = line.find(text)
    while i >= 0 and k > 0:
        i = line.find(text, i + 1)
        k -= 1
    return i


def widen(line, s, e):
    """Absorb backticks around the old anchor so that the result stays balanced."""
    inner = line[s:e].count('`')
    if inner % 2 == 1:
        if line[s:e].startswith('`') and e < len(line) and line[e] == '`':
            e += 1
        elif s > 0 and line[s - 1] == '`':
            s -= 1
        elif e < len(line) and line[e] == '`':
            e += 1
    elif s > 0 and line[s - 1] == '`' and e < len(line) and line[e] == '`':
        s, e = s - 1, e + 1
    return s, e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--table', required=True)
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report')
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.table, encoding='utf-8'), delimiter='\t'))
    report, unplaced, allow = [], 0, set()
    allow_path = os.path.join(HERE, 'anchor_history_allowlist.json')
    for doc in DOCS:
        path = os.path.join(a.repo, 'contracts', doc)
        base = git_show(a.repo, a.base, 'contracts/' + doc).split('\n')
        raw = open(path, 'rb').read()
        crlf = b'\r\n' in raw
        cur = raw.decode('utf-8').replace('\r\n', '\n').split('\n')
        mapping = {}
        sm = difflib.SequenceMatcher(None, base, cur, autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag == 'equal' or (tag == 'replace' and i2 - i1 == j2 - j1):
                for k in range(i2 - i1):
                    mapping[i1 + k + 1] = j1 + k + 1
        per_line = {}
        keep_lines = set()
        for r in rows:
            if r['doc'] != doc:
                continue
            bl = int(r['line'])
            if r['class'] in ('history-dated', 'history', 'not-anchor', 'external'):
                if bl in mapping:
                    keep_lines.add(mapping[bl])
                continue
            if r['class'] != 'convert':
                continue
            cl = mapping.get(bl)
            k = occurrence(base[bl - 1], r['old'], int(r['col']))
            if cl is None or k is None:
                unplaced += 1
                report.append([doc, r['line'], '', r['old'], 'unplaced', 'base line not mapped' if cl is None else 'occurrence'])
                continue
            per_line.setdefault(cl, []).append((k, r))
        for cl, items in per_line.items():
            line = cur[cl - 1]
            spans = []
            for k, r in items:
                s = nth(line, r['old'], k)
                if s < 0:
                    spans.append(None)
                    unplaced += 1
                    report.append([doc, r['line'], cl, r['old'], 'unplaced', 'old text gone from edited line'])
                    continue
                s, e = widen(line, s, s + len(r['old']))
                spans.append((s, e, r))
            for s, e, r in sorted((x for x in spans if x), key=lambda x: -x[0]):
                line = line[:s] + r['new'] + line[e:]
                report.append([doc, r['line'], cl, r['old'], 'written', r['new']])
            cur[cl - 1] = line
        for cl in keep_lines:
            allow.add(hashlib.sha1(cur[cl - 1].strip().encode('utf-8')).hexdigest())
        if not a.dry_run:
            text = '\n'.join(cur)
            if crlf:
                text = text.replace('\n', '\r\n')
            open(path, 'wb').write(text.encode('utf-8'))
    if not a.dry_run:
        json.dump({'note': 'Lines of the closure matrix and the alias table that keep an old line-number anchor on purpose '
                           '(dated narrative, history, not an anchor, repository-external document); SHA-1 of the stripped line. '
                           'Written by anchor_apply.py from verification_reports/b_merge_batch_evidence/anchor_conversion/anchor_mapping_table.tsv.',
                   'line_sha1': sorted(allow)}, open(allow_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    if a.report:
        with open(a.report, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('doc\tbase_line\tline\told\tresult\tdetail\n')
            for row in report:
                fh.write('\t'.join(str(c) for c in row) + '\n')
    written = sum(1 for r in report if r[4] == 'written')
    print('written', written, 'unplaced', unplaced, 'allowlisted lines', len(allow))
    return 1 if unplaced else 0


if __name__ == '__main__':
    sys.exit(main())
