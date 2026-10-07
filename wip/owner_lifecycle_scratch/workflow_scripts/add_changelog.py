# add_changelog.py <file> <new_version> <en_text> <cn_text>
# Bumps Version/Revision Date (EN) and 当前版本/修订日期 (CN) and appends one history line to each section,
# copying the date/version/author column layout of that section's last history line.
import sys, re, os
Y, M, D = os.environ.get('CL_DATE', '2026-10-05').split('-')
path, ver, en, cn = sys.argv[1:5]
raw = open(path, 'rb').read()
crlf = b'\r\n' in raw
t = raw.decode('utf-8').replace('\r\n', '\n').split('\n')
def last_hist(lo, hi):
    idx = None
    for i in range(lo, hi):
        if re.match(r'//\s*20\d\d[-/年]', t[i]): idx = i
    return idx
def entry_end(i, hi):
    # skip multi-line continuation lines of the entry starting at i
    j = i
    while j + 1 < hi and re.match(r'//\s{10,}\S', t[j + 1]): j += 1
    return j
cn_i = next(i for i, l in enumerate(t) if 'Chinese' in l and l.startswith('//'))
end = next(i for i, l in enumerate(t) if i > cn_i and not l.startswith('//'))
def mk(line, text, cnfmt):
    m = re.match(r'(//\s*)(20\d\d[-/年][0-9]{2}[-/月][0-9]{2}日?)(\s+)(V[\d.]+)(\s+)(\S+)(\s+)', line)
    d = (Y + '年' + M + '月' + D + '日') if '年' in m.group(2) else ((Y + '/' + M + '/' + D) if '/' in m.group(2) else (Y + '-' + M + '-' + D))
    return m.group(1) + d + m.group(3) + ver + ' ' * max(1, len(m.group(4)) + len(m.group(5)) - len(ver)) + 'Erie' + ' ' * max(1, len(m.group(6)) + len(m.group(7)) - 4) + text
def first_hist(lo, hi):
    for i in range(lo, hi):
        if re.match(r'//\s*20\d\d[-/年]', t[i]): return i
def dkey(line):
    return re.sub(r'\D', '', re.match(r'//\s*(20\d\d[-/年][0-9]{2}[-/月][0-9]{2})', line).group(1))
e = last_hist(0, cn_i); c = last_hist(cn_i, end); e0 = first_hist(0, cn_i); c0 = first_hist(cn_i, end)
newest_first = dkey(t[e0]) > dkey(t[e])
if newest_first:
    t.insert(c0, mk(t[c0], cn, True))
    t.insert(e0, mk(t[e0], en, False))
else:
    t.insert(entry_end(c, end) + 1, mk(t[c], cn, True))
    t.insert(entry_end(e, cn_i) + 1, mk(t[e], en, False))
print('order', 'newest-first' if newest_first else 'oldest-first')
s = '\n'.join(t)
s = re.sub(r'(// Version:\s*)V[\d.]+', lambda m: m.group(1) + ver, s, 1)
s = re.sub(r'(// Revision Date:\s*)\S+', lambda m: m.group(1) + ((Y + '/' + M + '/' + D) if re.search(r'// Revision Date:\s*20\d\d/', s) else (Y + '-' + M + '-' + D)), s, 1)
s = re.sub(r'(// 当前版本:\s*)V[\d.]+', lambda m: m.group(1) + ver, s, 1)
s = re.sub(r'(// 修订日期:\s*)\S+', lambda m: m.group(1) + (Y + '年' + M + '月' + D + '日'), s, 1)
if crlf: s = s.replace('\n', '\r\n')
open(path, 'wb').write(s.encode('utf-8'))
print('ok', path, 'crlf' if crlf else 'lf')
