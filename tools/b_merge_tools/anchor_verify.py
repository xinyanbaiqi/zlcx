# -*- coding: utf-8 -*-
"""Independent re-check of the stage-4 anchor conversion (brief section 3.2, BMI-152).

Usage:
    python anchor_verify.py --table anchor_mapping_table.tsv --before REV
                            [--base 7a8eabf] [--repo DIR] [--after-dir DIR]

`--before` is the commit taken just before anchor_apply.py ran (the snapshot); the
converted files are read from disk (contracts/, or --after-dir for a negative control).
For every line the expected converted text is rebuilt from the snapshot line and the
mapping table with a different placement rule than anchor_apply.py: all rows of the
line (kept history included, so that a struck-out copy of the same text is stepped
over) are taken in column order and each old text is searched left to right from
the end of the previous one (anchor_apply.py uses the occurrence index).  The
rebuilt line must equal the line on disk; a line with no convert row must be unchanged.
So every old/new pair is checked and the text between the pairs must be byte-equal.

Exit status 1 on any mismatch; each mismatching line is printed with both texts.
"""
import argparse
import csv
import difflib
import os
import subprocess
import sys

DOCS = ['PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md']


def show(repo, rev, path):
    return subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (rev, path)],
                          capture_output=True).stdout.decode('utf-8').replace('\r\n', '\n').split('\n')


def rebuild(line, entries):
    out, p = [], 0
    for r in entries:
        s = line.find(r['old'], p)
        if s < 0:
            return None
        e = s + len(r['old'])
        if r['class'] != 'convert':
            # kept on purpose (history / not an anchor): consume it unchanged
            out.append(line[p:e])
            p = e
            continue
        ticks = r['old'].count('`')
        if ticks % 2 == 0 and s > 0 and line[s - 1] == '`' and e < len(line) and line[e] == '`':
            s, e = s - 1, e + 1
        elif ticks % 2 == 1:
            if r['old'].startswith('`') and e < len(line) and line[e] == '`':
                e += 1
            elif s > 0 and line[s - 1] == '`':
                s -= 1
            elif e < len(line) and line[e] == '`':
                e += 1
        out.append(line[p:s])
        out.append(r['new'])
        p = e
    out.append(line[p:])
    return ''.join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--table', required=True)
    ap.add_argument('--before', required=True)
    ap.add_argument('--base', default='7a8eabf')
    ap.add_argument('--repo', default='.')
    ap.add_argument('--after-dir')
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.table, encoding='utf-8'), delimiter='\t'))
    bad = checked_pairs = changed = 0
    for doc in DOCS:
        base = show(a.repo, a.base, 'contracts/' + doc)
        before = show(a.repo, a.before, 'contracts/' + doc)
        after_path = os.path.join(a.after_dir, doc) if a.after_dir else os.path.join(a.repo, 'contracts', doc)
        after = open(after_path, encoding='utf-8').read().replace('\r\n', '\n').split('\n')
        if len(after) != len(before):
            print('LINE-COUNT %s before=%d after=%d' % (doc, len(before), len(after)))
            bad += 1
            continue
        b2s = {}
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, base, before, autojunk=False).get_opcodes():
            if tag == 'equal' or (tag == 'replace' and i2 - i1 == j2 - j1):
                for k in range(i2 - i1):
                    b2s[i1 + k] = j1 + k
        per = {}
        for r in rows:
            if r['doc'] == doc:
                j = b2s.get(int(r['line']) - 1)
                if j is None:
                    print('UNMAPPED %s base line %s %s' % (doc, r['line'], r['old']))
                    bad += 1
                    continue
                per.setdefault(j, []).append(r)
        for j, (old_line, new_line) in enumerate(zip(before, after)):
            entries = sorted(per.get(j, []), key=lambda r: int(r['col']))
            expect = rebuild(old_line, entries) if any(r['class'] == 'convert' for r in entries) else old_line
            checked_pairs += sum(1 for r in entries if r['class'] == 'convert')
            changed += old_line != new_line
            if expect != new_line:
                bad += 1
                print('MISMATCH %s:%d (%d pairs)\n  expected: %s\n  on disk : %s' % (doc, j + 1, len(entries), (expect or '<old text not found>')[:400], new_line[:400]))
    print('pairs checked %d, changed lines %d, mismatches %d' % (checked_pairs, changed, bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
