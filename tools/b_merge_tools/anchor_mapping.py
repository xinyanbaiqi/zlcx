# -*- coding: utf-8 -*-
"""Complete old -> new table for every line-number anchor in the matrix and alias table.

Usage:
    python anchor_mapping.py --resolved RES.json --decisions anchor_manual_decisions.tsv
                             [--repo DIR] [--head REV] --out-dir DIR

RES.json is the output of anchor_resolve.py (one record per anchor found by
anchor_inventory.py).  The decisions TSV (anchor_manual_seed.py, then reviewed) settles
every anchor the resolver left unresolved / ambiguous / weak.  Nothing is written into
the matrix or the alias table; the outputs are

  anchor_mapping_table.tsv   one row per anchor: doc, line, line SHA-1 (12), column,
                             old text, kind, written-at commit, class, new text,
                             source (auto / manual), note
  anchor_mapping_summary.md  counts per class and per source

Classes:
  convert          the old anchor is replaced by `new`
  history-strike   inside ~~strikethrough~~ -- kept verbatim (history)
  history-dated    dated narrative (date earlier in the same cell) -- kept verbatim
  history          other history kept verbatim (manual, reason in note)
  not-anchor       the pattern matched but the text is not a line number (kept)
  external         points into a document not in this repository (kept, flagged)
  lost             失效锚点（无法追溯）
"""
import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_resolve import governing_heading, heading_index, nums_list  # noqa: E402

MATRIX, ALIAS = 'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), capture_output=True).stdout.decode('utf-8', 'replace')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--resolved', required=True)
    ap.add_argument('--decisions', required=True)
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf', help='revision the inventory was taken at')
    ap.add_argument('--head', default='HEAD', help='revision new section numbers are checked against')
    ap.add_argument('--out-dir', required=True)
    a = ap.parse_args()
    res = json.load(open(a.resolved, encoding='utf-8'))
    dec = {}
    with open(a.decisions, encoding='utf-8') as fh:
        for row in csv.DictReader(fh, delimiter='\t'):
            dec[(row['doc'], int(row['line']), row['old'])] = row
    docs = {d: git(a.repo, 'show', '%s:contracts/%s' % (a.base, d)).split('\n') for d in (MATRIX, ALIAS)}
    cid = {}
    for l in docs[MATRIX]:
        m = re.match(r'^\| (C\d\d) \| `(?:[a-z_/]+/)?([A-Za-z0-9_]+\.md)`', l)
        if m and m.group(2) not in cid:
            cid[m.group(2)] = m.group(1)
    cache = {}

    def lines(rev, name):
        if (rev, name) not in cache:
            cache[(rev, name)] = git(a.repo, 'show', '%s:contracts/%s' % (rev, name)).split('\n')
        return cache[(rev, name)]

    def section(name, blame, nums, row_id):
        then, now = lines(blame, name), lines(a.head, name)
        idx = heading_index(now)
        outs, ok = [], True
        for lo, hi in nums_list(nums):
            num, title = governing_heading(then, lo)
            if num is None:
                outs.append('文件头')
                continue
            ok = ok and num in idx
            lab = '§%s' % num + (' ' + title[:30] if len(idx.get(num, [])) > 1 else '')
            if row_id and lo <= len(then) and then[lo - 1].startswith('|'):
                lab += ' %s行' % then[lo - 1].strip('|').split('|')[0].strip()[:40]
            num2, _ = governing_heading(then, hi)
            if num2 != num:
                lab += '–§%s' % num2
            outs.append(lab)
        return '、'.join(dict.fromkeys(outs)), ok

    out_rows, cnt = [], Counter()
    for r in res:
        line_text = docs[r['file']][r['line'] - 1]
        sha = hashlib.sha1(line_text.encode('utf-8')).hexdigest()[:12]
        st, d = r['status'], dec.get((r['file'], r['line'], r['text']))
        source, note = 'auto', ''
        if st == 'history-strike':
            cls, new = 'history-strike', ''
        elif st == 'history-dated':
            cls, new = 'history-dated', ''
        elif d is not None and d['action'] != 'keep-auto':
            source, act, a1, a2, note = 'manual', d['action'], d['arg1'], d['arg2'], d['reason']
            cls = 'convert'
            if act == 'sym':
                new = '`%s` %s' % (a1, '、'.join('`%s`' % s for s in a2.split(',')))
            elif act == 'tag':
                new = '`%s` `@satisfies: %s`' % (a1, a2)
            elif act == 'text':
                new = a1
            elif act == 'file':
                new = '`%s`' % a1
            elif act == 'label':
                new = '`%s` `"%s"`' % (a1, a2)
            elif act in ('csec', 'msec'):
                name = a1 if act == 'csec' else MATRIX
                nums = re.sub(r'^.*?:', '', r['text'].strip('`'))
                sec, ok = section(name, r['blame'], nums, act == 'msec')
                new = '%s %s' % (cid.get(name, name), sec)
                if not ok:
                    note += '；HEAD中该节号不存在，需复核'
            elif act in ('history', 'not-anchor', 'external', 'lost'):
                cls, new = act, ('失效锚点（无法追溯）' if act == 'lost' else '')
            else:
                raise SystemExit('undecided anchor: %s:%d %s' % (r['file'], r['line'], r['text']))
        elif st.startswith('resolved') and r.get('new'):
            cls, new = 'convert', r['new']
            if d is not None:
                source, note = 'manual', d['reason']
        else:
            raise SystemExit('no decision for %s:%d %s (%s)' % (r['file'], r['line'], r['text'], st))
        cnt[(cls, source)] += 1
        out_rows.append([r['file'], r['line'], sha, r['pos'], r['text'], r['kind'], r['blame'], cls, new, source, note])
    os.makedirs(a.out_dir, exist_ok=True)
    with open(os.path.join(a.out_dir, 'anchor_mapping_table.tsv'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('doc\tline\tline_sha1\tcol\told\tkind\twritten_at\tclass\tnew\tsource\tnote\n')
        for row in out_rows:
            fh.write('\t'.join(str(c).replace('\t', ' ').replace('\n', ' ') for c in row) + '\n')
    with open(os.path.join(a.out_dir, 'anchor_mapping_summary.md'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('# 阶段4锚点旧→新对照表汇总\n\n')
        fh.write('清单基线 `%s`，新节号核对版本 `%s`；锚点总数 %d。\n\n' % (a.base, git(a.repo, 'rev-parse', '--short', a.head).strip(), len(out_rows)))
        fh.write('| 类别 | 来源 | 数量 |\n|---|---|---|\n')
        for (c, s), n in sorted(cnt.items()):
            fh.write('| %s | %s | %d |\n' % (c, s, n))
        per_doc = Counter((row[0], row[7]) for row in out_rows)
        fh.write('\n| 文件 | 类别 | 数量 |\n|---|---|---|\n')
        for (f, c), n in sorted(per_doc.items()):
            fh.write('| %s | %s | %d |\n' % (f, c, n))
    print(sorted(cnt.items()))


if __name__ == '__main__':
    main()
