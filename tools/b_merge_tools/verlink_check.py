# -*- coding: utf-8 -*-
"""Independent check of the version-linkage edit.
Usage: python verlink_check.py <repo> [OLD_REV NEW_REV [ALLOW_FILE:LINE ...]]
ALLOW_FILE:LINE names a line that is expected to differ in other text (for example
the change-record line written in the same commit); it is reported as ALLOWED.
Without revisions it compares HEAD with the working tree; the B merge batch
linkage commit is reproduced with: verlink_check.py . 8b2b259~1 8b2b259
Line by line:
Every differing line must differ only in version tokens; each changed token must be
the first version token after a file-name occurrence whose bump is (old -> new)."""
import re, subprocess, sys, os, glob
src = open(os.path.join(os.path.dirname(__file__), 'verlink.py'), encoding='utf-8').read()
BUMPS = eval(src.split('BUMPS = ', 1)[1].split('\n}\n', 1)[0] + '\n}')
VTOK = re.compile(r'(?<![A-Za-z0-9.])V\d+(?:\.\d+)*(?![0-9.])')
root = sys.argv[1]
OLD = sys.argv[2] if len(sys.argv) > 3 else 'HEAD'
NEW = sys.argv[3] if len(sys.argv) > 3 else None
ALLOW = set(sys.argv[4:])
bad = 0; good = 0
for path in sorted(glob.glob(os.path.join(root, 'contracts', '*.md'))):
    rel = os.path.relpath(path, root).replace('\\', '/')
    old_txt = subprocess.run(['git', '-C', root, 'show', OLD + ':' + rel], capture_output=True).stdout.decode('utf-8')
    new_txt = (subprocess.run(['git', '-C', root, 'show', NEW + ':' + rel], capture_output=True).stdout.decode('utf-8')
               if NEW else open(path, encoding='utf-8').read())
    ol, nl = old_txt.split('\n'), new_txt.split('\n')
    if len(ol) != len(nl):
        print('LINECOUNT', rel); bad += 1; continue
    for i, (a, b) in enumerate(zip(ol, nl)):
        if a == b:
            continue
        # strip version tokens -> must be identical
        if '%s:%d' % (rel, i + 1) in ALLOW:
            print('ALLOWED', rel, i + 1); continue
        if VTOK.sub('V*', a) != VTOK.sub('V*', b):
            print('NONVERSION DIFF', rel, i + 1); bad += 1; continue
        ta, tb = list(VTOK.finditer(a)), list(VTOK.finditer(b))
        for x, y in zip(ta, tb):
            if x.group(0) == y.group(0):
                continue
            # find nearest preceding file-name in the new line
            pre = b[:y.start()]
            owner = None; best = -1
            for t in BUMPS:
                k = pre.rfind(t)
                if k > best:
                    best, owner = k, t
            ok = owner is not None and BUMPS[owner] == (x.group(0), y.group(0))
            # the token must be the first version token after that file name
            if ok:
                first = VTOK.search(b, best + len(owner))
                ok = first is not None and first.start() == y.start()
            if ok:
                good += 1
            else:
                bad += 1
                print('BAD', rel, i + 1, x.group(0), '->', y.group(0), 'owner', owner)
print('good', good, 'bad', bad)
