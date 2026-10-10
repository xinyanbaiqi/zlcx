"""Compare two erie-verilog-generator deliverable-gate JSON reports (baseline vs branch).

Usage:
    python gate_compare.py BASELINE.json BRANCH.json

Used for files that do not pass the strict gate at the baseline either (the TBs touched by
the stage-3 label renames): the requirement is "no new finding", not "0 errors".  Issues
are compared per (file, rule, severity) and per (file, rule, severity, message) with line
numbers removed, because a change-log entry added to the file header shifts every later
line.  Prints the totals, the per-file table and every differing issue key.
"""
import collections
import json
import ntpath
import re
import sys


def load(path):
    d = json.load(open(path, encoding='utf-8'))
    c = collections.Counter()
    for i in d['issues']:
        f = re.sub(r':\d+(:\d+)?$', '', ntpath.basename(i.get('path') or i.get('file') or ''))
        msg = re.sub(r'\b(line|Line)\s*\d+', 'line N', str(i.get('message', '')))
        c[(f, i.get('rule') or i.get('code'), i.get('severity'), msg)] += 1
    return d, c


def main():
    a, ca = load(sys.argv[1])
    b, cb = load(sys.argv[2])
    print('errors %s -> %s ; strict_warnings %s -> %s' % (a['errors'], b['errors'], a['strict_warnings'], b['strict_warnings']))
    print('by_rule baseline:', a['delivery_issues_by_rule'])
    print('by_rule branch  :', b['delivery_issues_by_rule'])
    fa, fb = collections.Counter(), collections.Counter()
    for k, v in ca.items():
        fa[k[:3]] += v
    for k, v in cb.items():
        fb[k[:3]] += v
    print('per file (file, rule, severity): baseline -> branch')
    for k in sorted(set(fa) | set(fb)):
        print('  %s %s %s: %d -> %d' % (k[0], k[1], k[2], fa[k], fb[k]))
    diff = [(k, ca[k], cb[k]) for k in set(ca) | set(cb) if ca[k] != cb[k]]
    print('issue (file, rule, severity, message without line numbers) differences:', len(diff))
    for k, x, y in diff:
        print('  ', x, '->', y, k[0], k[1], k[3][:160])
    return 0


if __name__ == '__main__':
    sys.exit(main())
