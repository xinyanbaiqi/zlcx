import sys, re, difflib, pathlib
ref, new = map(pathlib.Path, sys.argv[1:3]); show = len(sys.argv) > 3
DROP = re.compile(r'^(Time resolution|INFO: \[|\*\*\*\*|.*Vivado Simulator|.*Copyright|# |Built|Start of session|run -all|exit|quit|Exiting xsim|Tool Version|Date|Host|source|## )')
def f(p): return [re.sub(r'File "[^"]*"', '', l) for l in p.read_text(encoding='utf-8', errors='replace').splitlines() if not DROP.match(l)]
for d in sorted(x for x in new.iterdir() if (x / 'xsim.log').exists()):
    a, b = f(ref / d.name / 'xsim.log'), f(d / 'xsim.log')
    dl = [l for l in difflib.unified_diff(a, b, lineterm='', n=0) if l[:1] in '+-' and not l.startswith(('+++', '---'))]
    print(d.name, len(a), len(b), len(dl))
    if show and dl:
        for l in dl[:int(sys.argv[3])]: print('   ', l[:220])
