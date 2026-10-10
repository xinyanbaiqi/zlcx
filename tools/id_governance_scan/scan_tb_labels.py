"""ID governance audit, TB side.
Usage: python scan_tb_labels.py <repo_root> <out.json>
For every rtl/**/tb_*.v and rtl/**/*.vh (legacy/ excluded) emit "label sites":
  * string-literal sites: a non-comment code line whose string literal carries a governed check label;
  * numeric sites: per-TB call rules where the label is printed through a %0d format (FSC-%0d, CCC-%0d ...).
Each site carries the code context (the whole call statement, or the if-condition that guards a $display),
so that the check's real comparison can be read from code rather than from comments."""
import re, sys, os, json, glob, collections

ROOT, OUT = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import GOV, NOISE_FAM, family
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
# numeric-label rules: file basename -> list of (regex on code, printed family, zero-pad width or 0)
NUM_RULES = {
    'tb_ppg_400hz_frame_calibration_scheduler.v': [(r'\bcheck_fsc\(\s*(\d+)\s*,', 'FSC', 0)],
    'tb_ppg_characterization_control_cdc.v': [(r"\bcheck_case\(\s*8'd(\d+)\s*,", 'CCC', 0)],
    'tb_ppg_adc_dc_recovery.v': [(r'\bdrive_and_check\(\s*(\d+)\s*,', 'DCR', 0)],
    'tb_ppg_adc_programmable_reconstructor.v': [(r'\bcheck_transaction\(\s*(\d+)\s*\)', 'PR', 0),
                                                (r'\bsend_transaction\(\s*(\d+)\s*,', 'PR', 0)],
    'tb_ppg_adc_pipeline_overlap_corrector.v': [(r"\breg_test_case_id\s*=\s*8'd(\d+)\s*;", 'OVL', 0)],
    'tb_ppg_control_top_adc_numeric_scoreboard.v': [(r'\bdrive_and_check_transaction\(\s*(\d+)\s*,', 'ADCN', 0)],
}


def strip_comment(line):
    out, q = [], False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"' and (i == 0 or line[i - 1] != '\\'):
            q = not q
        if not q and line.startswith('//', i):
            break
        out.append(ch)
        i += 1
    return ''.join(out)


def statement_from(code, i):
    """Return (start, end) line indexes of the statement that begins at line i (paren-balanced, ends with ';')."""
    depth, j = 0, i
    while j < len(code):
        depth += code[j].count('(') - code[j].count(')')
        if depth <= 0 and ';' in code[j]:
            return i, j
        j += 1
        if j - i > 25:
            break
    return i, min(j, len(code) - 1)


def guard_from(code, i):
    """For a $display at line i, walk back to the nearest enclosing if/else-if/case-item condition (<=15 lines)."""
    for k in range(i, max(-1, i - 16), -1):
        if re.search(r'\b(if|else\s+if)\s*\(', code[k]) or re.search(r'\bcheck\w*\s*\(|\bexpect\w*\s*\(', code[k]):
            return k, i
    return i, i


sites = []
files = sorted(f for f in glob.glob(os.path.join(ROOT, 'rtl', '**', '*.v'), recursive=True) +
               glob.glob(os.path.join(ROOT, 'rtl', '**', '*.vh'), recursive=True)
               if 'legacy' not in f.replace('\\', '/').split('/') and
               (os.path.basename(f).startswith('tb_') or f.endswith('.vh')))
for path in files:
    rel = os.path.relpath(path, ROOT).replace('\\', '/')
    raw = open(path, encoding='utf-8', errors='replace').read().split('\n')
    code = [strip_comment(l) for l in raw]
    base = os.path.basename(path)
    for i, l in enumerate(code):
        for lit in STR.findall(l):
            toks = [t for t in GOV.findall(lit) if family(t) not in NOISE_FAM]
            if not toks:
                continue
            kind = 'pass' if 'PASS' in lit else ('fail' if re.search(r'FAIL|ERROR|MISMATCH', lit) else 'other')
            if re.search(r'\b(check\w*|begin_case|expect\w*|jnt_check\w*)\s*\(\s*"', l):
                s, e = statement_from(code, i)
                kind = 'call'
            else:
                s, e = guard_from(code, i)
            sites.append({'file': rel, 'line': i + 1, 'labels': toks, 'family': family(toks[0]), 'kind': kind,
                          'literal': lit[:200], 'ctx_lines': [s + 1, e + 1],
                          'ctx': ' '.join(x.strip() for x in code[s:e + 1])[:600]})
    for rx, fam, pad in NUM_RULES.get(base, []):
        for i, l in enumerate(code):
            for m in re.finditer(rx, l):
                n = int(m.group(1))
                s, e = statement_from(code, i)
                lab = f'{fam}-{n}'
                sites.append({'file': rel, 'line': i + 1, 'labels': [lab], 'family': fam, 'kind': 'numeric',
                              'literal': f'{fam}-%0d <- {n}', 'ctx_lines': [s + 1, e + 1],
                              'ctx': ' '.join(x.strip() for x in code[s:e + 1])[:600]})

json.dump(sites, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
c = collections.Counter((s['file'].split('/')[-1], s['family']) for s in sites)
for (f, fam), n in sorted(c.items()):
    print(f'{f[:60]:60s} {fam:10s} {n:4d}')
print('sites', len(sites))
