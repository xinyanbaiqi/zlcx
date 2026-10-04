from pathlib import Path
import sys
BASE = Path(__file__).resolve().parent / 'snapshot'
code_only='--code' in sys.argv
if code_only: sys.argv.remove('--code')
for arg in sys.argv[1:]:
    file, sep, bounds = arg.partition('@')
    p = BASE / file
    lines = p.read_text(encoding='utf-8-sig').splitlines()
    start, end = map(int, bounds.split('-')) if sep else (1, len(lines))
    print('\nFILE', file, 'TOTAL', len(lines))
    for n in range(start, min(end, len(lines))+1):
        if code_only and (not lines[n-1].strip() or lines[n-1].lstrip().startswith('//')): continue
        value=lines[n-1].split('//',1)[0].rstrip() if code_only else lines[n-1]
        print(str(n)+': '+value)
