import json, sys, glob, os
for p in sorted(glob.glob(sys.argv[1] + '/*.json')):
    d = json.load(open(p, encoding='utf-8'))
    iss = [(i.get('rule') or i.get('code'), i.get('line'), (i.get('message') or '')[:80]) for i in d.get('issues', [])]
    print(os.path.basename(p)[:-5], 'errors=%s strict=%s ready=%s' % (d['errors'], d['strict_warnings'], d['delivery_ready']), d['delivery_issues_by_rule'])
    for x in iss: print('   ', x)
