"""Resolve old line-number anchors to symbol / section anchors (dry run; writes nothing).

Usage:
    python anchor_resolve.py --inventory INV.json --base 7a8eabf --out RES.json [--repo DIR]

Input: the inventory from anchor_inventory.py (taken at the same base revision).
For every anchor that is not inside ~~strikethrough~~:

RTL anchors (`file.v:N`, ranges, lists, bare `:N`):
  1. Candidate files: the named file; for a bare `:N`, every RTL file named in the
     same table row, plus files implied by module words in the cell (AMI, Top,
     Scheduler, SSW, supervisor, manager, PWI, IDAC, ...).
  2. The referenced lines are read at the blame commit of the matrix/alias line
     ("written-at" commit, brief 3.13 Q1). When that commit is the 2026-09-28 import,
     the import snapshot is the earliest version available; such results are flagged
     `written_at_import`.
  3. Symbol choice: a backticked identifier of the cell (then of the row) that occurs
     on the referenced line wins; otherwise the line's own declared / assigned /
     connected name, or its `@satisfies:` IDs, is extracted.
  4. The symbol must exist in the base revision of that file (word boundary in code,
     or the `@satisfies` tag in a comment); otherwise the anchor is `unresolved`.
  For a bare `:N` with several candidate files, the file whose referenced line
  contains a row symbol wins; if none or several qualify the anchor is `ambiguous`.

Contract anchors (`X.md:N`, `Cxx:N`): the numbered heading that governs line N at the
written-at commit gives `§x.y`; it must exist in the base revision of that contract
(title added when the number is duplicated). Line numbers before the first numbered
heading map to `file header`.

Matrix / alias self references (`MATRIX:N`, `alias:N`, `..._MATRIX.md:N`): the
governing heading plus, for a table row, its first cell (row ID).

Every result carries: status (resolved / ambiguous / unresolved / written-at
unavailable), the proposed replacement text and the evidence (line text read).
"""
import argparse
import json
import os
import re
import subprocess
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_history_rules import classify as history_classify, classify_struck  # noqa: E402

MODULE_WORDS = [
    (r'\bAMI\b', 'ppg_adc_measurement_idac_integration.v'),
    (r'\bTop\b|control_top', 'ppg_control_top.v'),
    (r'\bScheduler\b|scheduler', 'ppg_400hz_frame_calibration_scheduler.v'),
    (r'\bSSW\b', 'ppg_sar9_sar15_safe_selection_wrapper.v'),
    (r'[Ss]upervisor', 'ppg_system_fault_abort_supervisor.v'),
    (r'\bmanager\b', 'ppg_system_config_manager.v'),
    (r'\bPWI\b', 'ppg_precision_window_integration.v'),
    (r'\bPWC\b|precision controller', 'ppg_precision_window_controller.v'),
    (r'\bIDAC\b', 'ppg_idac_code_controller.v'),
    (r'\bFIR\b', 'ppg_coarse_detection_fir.v'),
    (r'\bPVW\b|peak/valley', 'ppg_peak_valley_window_detector.v'),
    (r'baseline', 'ppg_dynamic_baseline_cross_detector.v'),
    (r'wrapper', 'ppg_active_v4_control_plane_integration.v'),
    (r'\brecheck\b', 'ppg_amb_recheck_scheduler.v'),
    (r'\bfork\b', 'ppg_normal_transaction_fork.v'),
    (r'\bSPI\b', 'ppg_spi_register_file.v'),
    (r'\bchip\b|glue', 'ppg_chip_digital_top.v'),
]
KEYWORDS = set('''module endmodule input output inout wire reg integer parameter localparam assign always begin end if else
case endcase default posedge negedge or and not signed unsigned generate endgenerate genvar for initial function task
endfunction endtask'''.split())
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_$]*')
TICK = re.compile(r'`([A-Za-z_][A-Za-z0-9_$]*)(?:\[[^\]]*\])?`')
HEADING = re.compile(r'^(#{1,6})\s+(?:§\s*)?(\d+(?:\.\d+)*[a-z]?)[.\s]\s*(.*)$')
ANYHEAD = re.compile(r'^(#{1,6})\s+(.*)$')


class Git:
    def __init__(self, repo):
        self.repo = repo
        self.blob = {}
        self.tree = {}

    def ls(self, rev):
        if rev not in self.tree:
            out = subprocess.run(['git', '-C', self.repo, 'ls-tree', '-r', '--name-only', rev],
                                 capture_output=True).stdout.decode('utf-8').split('\n')
            idx = defaultdict(list)
            for p in out:
                if p and not p.startswith('legacy/'):
                    idx[os.path.basename(p)].append(p)
            self.tree[rev] = idx
        return self.tree[rev]

    def lines(self, rev, base):
        key = (rev, base)
        if key not in self.blob:
            paths = self.ls(rev).get(base, [])
            if len(paths) != 1:
                self.blob[key] = None
            else:
                out = subprocess.run(['git', '-C', self.repo, 'show', '%s:%s' % (rev, paths[0])], capture_output=True)
                self.blob[key] = out.stdout.decode('utf-8', 'replace').replace('\r\n', '\n').split('\n') if out.returncode == 0 else None
        return self.blob[key]


def split_comment(line):
    q = False
    for i, ch in enumerate(line):
        if ch == '"':
            q = not q
        if not q and line.startswith('//', i):
            return line[:i], line[i + 2:]
    return line, ''


def extract(line):
    """Primary symbols of one Verilog line: (kind, [names])."""
    code, comment = split_comment(line)
    sat = re.search(r'@satisfies:\s*([A-Za-z0-9_, -]+)', comment)
    c = code.strip()
    m = re.match(r'^(?:input|output|inout)\b.*?([A-Za-z_][A-Za-z0-9_$]*)\s*[,;)]?\s*$', c)
    if m:
        return 'port', [m.group(1)]
    m = re.match(r'^(?:wire|reg|integer)\b[^;=]*?([A-Za-z_][A-Za-z0-9_$]*)\s*(?:\[[^\]]*\])?\s*(?:=[^;]*)?;', c)
    if m:
        return 'decl', [m.group(1)]
    m = re.match(r'^(?:parameter|localparam)\b[^=]*?([A-Za-z_][A-Za-z0-9_$]*)\s*=', c)
    if m:
        return 'param', [m.group(1)]
    m = re.match(r'^assign\s+([A-Za-z_][A-Za-z0-9_$]*)', c)
    if m:
        return 'assign', [m.group(1)]
    m = re.match(r'^\.([A-Za-z_][A-Za-z0-9_$]*)\s*\(\s*([A-Za-z_][A-Za-z0-9_$]*)?', c)
    if m:
        return 'conn', [x for x in (m.group(1), m.group(2)) if x]
    m = re.match(r'^(?:end\s+)?(?:else\s+)?(?:if\s*\(.*\)\s*(?:begin)?\s*)?([A-Za-z_][A-Za-z0-9_$]*)\s*(?:\[[^\]]*\])*\s*<?=', c)
    if m and m.group(1) not in KEYWORDS:
        return 'lvalue', [m.group(1)]
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_$]*)\s+(?:#\s*\(.*)?([A-Za-z_][A-Za-z0-9_$]*_Inst)\s*\(', c)
    if m:
        return 'instance', [m.group(2)]
    if sat:
        return 'satisfies', ['@satisfies:' + t.strip() for t in sat.group(1).split(',') if t.strip()]
    ids = [t for t in IDENT.findall(c) if t not in KEYWORDS and not re.match(r"^\d", t)]
    return ('other', ids[:1]) if ids else ('none', [])


NOISE = {'i_clk', 'i_rstn', 'always', 'begin', 'end', 'else'}
DATED = re.compile(r'20\d\d-\d\d-\d\d|20\d\d年\d+月\d+日|20\d\d/\d\d/\d\d')
# module words that only appear inside clauses (used to give a bare `:N` its file)
EXTRA_WORDS = [
    (r'AMI[- ]internal|AMI\'s own|AMI-hub', 'ppg_adc_measurement_idac_integration.v'),
    (r'Top[- ]internal|Top\'s own', 'ppg_control_top.v'),
    (r'\bC05\b|unpack', 'ppg_system_active_config_unpack.v'),
    (r'\bC03\b', 'ppg_active_v4_control_plane_integration.v'),
    (r'\bC17\b', 'ppg_idac_code_controller.v'),
    (r'\bC02\b', 'ppg_system_config_manager.v'),
    (r'\bC24\b', 'ppg_system_fault_abort_supervisor.v'),
    (r'characterization CDC|表征CDC', 'ppg_characterization_control_cdc.v'),
]
# symbols renamed in RTL after the anchor was written (F-032)
RENAMED = {'i_status_clear_event': 'i_diag_clear_event'}
CALL_LABEL = re.compile(r'\b(check_fsc|check_case|check_local|drive_and_check|send_transaction|check_transaction|'
                        r'drive_and_check_transaction|jnt_check_case|begin_case|end_case)\s*\(\s*([^,)]+)')


def tb_label(line):
    """Check label written on a TB line: first string literal (up to a format
    specifier), else a numbered check call such as `check_fsc(14`."""
    m = re.search(r'"([^"]+)"', line)
    if m:
        lab = m.group(1).split('%')[0].strip()
        if len(lab) >= 4:
            return lab[:80]
    m = CALL_LABEL.search(split_comment(line)[0])
    if m:
        return '%s(%s' % (m.group(1), m.group(2).strip())
    return None


def resolve_tb(g, base, it, row, cands, res):
    """TB / .vh anchors point at checks: resolve to the check label text."""
    quoted = [x for tup in re.findall(r'"([^"]{6,})"|“([^”]{6,})”', row) for x in tup if x]
    found = []
    for f in cands:
        src = g.lines(it['blame'], f)
        now = g.lines(base, f)
        if src is None or now is None:
            continue
        raw_now = '\n'.join(now)
        labels, evid = [], []
        for lo, hi in nums_list(it['nums']):
            for n in range(lo, min(hi, lo + 5, len(src)) + 1):
                evid.append(src[n - 1].strip()[:140])
                lab = tb_label(src[n - 1])
                if lab and lab in raw_now:
                    labels.append(lab)
        drift = False
        if not labels:
            labels = [q.split('%')[0].strip() for q in quoted if q.split('%')[0].strip() in raw_now][:2]
            drift = bool(labels)
        if labels:
            found.append((f, list(dict.fromkeys(labels))[:3], evid, drift))
    if len(found) == 1 or (found and len(cands) == 1):
        f, labs, evid, drift = found[0]
        res.update(status='resolved-tb-by-text' if drift else 'resolved-tb', target=f, symbols=labs, evidence=evid[:3],
                   new='`%s` %s' % (f, '、'.join('`"%s"`' % l for l in labs)))
    else:
        res.update(status='ambiguous' if found else 'unresolved', new=None, candidates=cands)


def nums_list(nums):
    out = []
    for part in nums.split(','):
        if '-' in part:
            a, b = part.split('-')
            a, b = int(a), int(b)
            out.append((a, b))
        else:
            out.append((int(part), int(part)))
    return out


def governing_heading(lines, n):
    """(number, title) of the nearest numbered heading at or above line n (1-based)."""
    for i in range(min(n, len(lines)) - 1, -1, -1):
        m = HEADING.match(lines[i])
        if m:
            return m.group(2), m.group(3).strip()
    return None, None


def short_title(title, limit=30):
    """Heading title for a duplicated section number, cut at a word boundary."""
    title = title.strip()
    if len(title) <= limit:
        return title
    cut = title[:limit]
    if title[limit].isascii() and title[limit].isalnum() and ' ' in cut:
        cut = cut[:cut.rfind(' ')]
    return cut.rstrip(' ,;:-')


def heading_index(lines):
    idx = defaultdict(list)
    for l in lines:
        m = HEADING.match(l)
        if m:
            idx[m.group(2)].append(m.group(3).strip())
    return idx


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--inventory', required=True)
    ap.add_argument('--base', default='7a8eabf')
    ap.add_argument('--out', required=True)
    ap.add_argument('--repo', default='.')
    a = ap.parse_args()
    g = Git(a.repo)
    inv = json.load(open(a.inventory, encoding='utf-8'))
    imp = subprocess.run(['git', '-C', a.repo, 'rev-list', '--max-parents=0', 'HEAD'], capture_output=True).stdout.decode().split()
    imp_short = {c[:10] for c in imp} | {subprocess.run(['git', '-C', a.repo, 'rev-parse', 'b858bf0'], capture_output=True).stdout.decode().strip()[:10]}
    # full text of the matrix / alias at base, for row context
    docs = {}
    for name in ('PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'):
        docs[name] = g.lines(a.base, name)
    cid = {}
    for l in docs['PPG_CONTRACT_CLOSURE_MATRIX.md']:
        m = re.match(r'^\| (C\d\d) \| `(?:[a-z_/]+/)?([A-Za-z0-9_]+\.md)`', l)
        if m and m.group(1) not in cid:
            cid[m.group(1)] = m.group(2)
    rtl_names = set(b for b in g.ls(a.base) if b.endswith(('.v', '.vh')))
    results = []
    base_cache = {}
    for it in inv:
        res = dict(it)
        res['written_at_import'] = it['blame'] in imp_short
        if it['strike']:
            res.update(status=classify_struck(docs[it['file']][it['line'] - 1], it.get('pos', 0)), new=None)
            results.append(res)
            continue
        row = docs[it['file']][it['line'] - 1]
        # history rules of the coordinator's 2026-10-09 ruling (anchor_history_rules.py):
        # "> " blocks, revision-record sections and explicitly superseded entries are
        # kept; dated current conclusions are converted (doubtful ones flagged)
        hist, uncertain = history_classify(docs[it['file']], it['line'], it.get('pos', 0), it.get('end', 0))
        if hist:
            res.update(status=hist, new=None)
            results.append(res)
            continue
        res['uncertain'] = uncertain
        if it['kind'] in ('rtl', 'bare-no-context'):
            cell_syms = []
            for s in it['cell_symbols']:
                s = s.split('=')[0] if '=' in s else s
                s = re.sub(r'\[[^\]]*\]', ' ', s).replace('(', ' ').replace(')', ' ').split()
                if s and IDENT.fullmatch(s[-1]) and s[-1] not in KEYWORDS:
                    cell_syms.append(s[-1])
            row_syms = [s for s in TICK.findall(row)]
            if it['kind'] == 'rtl' and it['ref'] in rtl_names:
                cands = [it['ref']]
            else:
                cands = [b for b in re.findall(r'([A-Za-z0-9_]+\.vh?)\b', row) if b in rtl_names]
                cands += [f for pat, f in MODULE_WORDS if re.search(pat, it['text'] + ' ' + row)]
                cands = list(dict.fromkeys(cands))
            # symbol / module stated right next to the anchor (brief 3.13 Q1: the cell text governs)
            pos, end = it.get('pos', 0), it.get('end', 0)
            before, after = row[max(0, pos - 80):pos], row[end:end + 90]
            bare = it['text'].lstrip('`').startswith(':')
            near = before[-14:]
            mod = [f for pat, f in MODULE_WORDS if re.search(pat, near)]
            if bare and not mod:
                # nearest module word earlier in the same clause (stop at a previous file anchor)
                clause = re.split(r'\.vh?:\d|->|→|←|；|。', before)[-1]
                hits = []
                for pat, f in MODULE_WORDS + EXTRA_WORDS:
                    for m in re.finditer(pat, clause):
                        hits.append((m.end(), f))
                if hits:
                    mod = [max(hits)[1]]
            if bare:
                # a bare `:N` right after a contract mention is a contract line, not RTL
                cm = re.search(r'(?:(C\d\d)|contract|合同)\s*(?:§\s*([\d.]+[a-z]?))?\s*[（(]?\s*(?:当前|now|at)?\s*`?$', before[-40:])
                if cm:
                    cname = cid.get(cm.group(1)) if cm.group(1) else None
                    if not cname:
                        fm = re.search(r'`(?:[a-z_/]+/)?([A-Za-z0-9_]+\.md)(?::\d+)?`', row)
                        cname = fm.group(1) if fm else None
                    then = g.lines(it['blame'], cname) if cname else None
                    if then:
                        lo = nums_list(it['nums'])[0][0]
                        num, title = governing_heading(then, lo)
                        if num:
                            idx = heading_index(g.lines(a.base, cname) or [])
                            label = '§%s' % num + (' ' + short_title(title) if len(idx.get(num, [])) > 1 else '')
                            res.update(status='resolved-contract-bare' if num in idx else 'section-gone',
                                       target=cname, new=label, sections=[(num, title)])
                            results.append(res)
                            continue
            if bare and mod:
                cands = [mod[-1]]
            hints = []
            h1 = re.match(r'^[`\s]*[,，(（]\s*`([^`]+)`', after) or re.match(r'^\s*[(（]`([^`]+)`', after)
            if h1:
                hints.append(h1.group(1).strip())
            h2 = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*[（(][^（(）)]*$', before)
            if h2:
                hints.append(h2.group(2))
            h3 = re.search(r'`([A-Za-z_][A-Za-z0-9_]*)`\s*(?:at|在|[(（])\s*`?$', before)
            if h3:
                hints.append(h3.group(1))
            h4 = re.search(r'`assign\s+([A-Za-z_][A-Za-z0-9_]*)[^`]*`\s*[(（]\s*`?$', before)
            if h4:
                hints.append(h4.group(1))
            if hints and (len(cands) == 1 or bare) and not (cands and (cands[0].startswith('tb_') or cands[0].endswith('.vh'))):
                f = cands[0] if len(cands) == 1 else None
                code_now, cmt_now = '', ''
                if f:
                    if f not in base_cache:
                        base_src = g.lines(a.base, f) or []
                        base_cache[f] = ('\n'.join(split_comment(l)[0] for l in base_src),
                                         '\n'.join(split_comment(l)[1] for l in base_src))
                    code_now, cmt_now = base_cache[f]
                good_h = []
                for h in (hints if f else []):
                    sm = re.match(r'^@satisfies:\s*(.+)$', h)
                    if sm and all(re.search(r'@satisfies:[^\n]*' + re.escape(t.strip()), cmt_now) for t in sm.group(1).split(',')):
                        good_h.append('@satisfies:' + sm.group(1).strip())
                    elif IDENT.fullmatch(h) and re.search(r'(?<![A-Za-z0-9_$])' + re.escape(h) + r'(?![A-Za-z0-9_$])', code_now):
                        good_h.append(h)
                    elif h in RENAMED and re.search(r'(?<![A-Za-z0-9_$])' + re.escape(RENAMED[h]) + r'(?![A-Za-z0-9_$])', code_now):
                        good_h.append(RENAMED[h])
                if not good_h and bare:
                    # the stated symbol decides the file: the RTL file whose line N (at the
                    # written-at commit) contains it
                    lo = nums_list(it['nums'])[0][0]
                    owners = []
                    for fname in sorted(rtl_names):
                        if fname.startswith('tb_'):
                            continue
                        src = g.lines(it['blame'], fname)
                        if src and lo <= len(src) and any(re.search(r'(?<![A-Za-z0-9_$])' + re.escape(h) + r'(?![A-Za-z0-9_$])', split_comment(src[lo - 1])[0]) for h in hints if IDENT.fullmatch(h)):
                            owners.append(fname)
                    if len(owners) == 1:
                        f = owners[0]
                        now = '\n'.join(split_comment(l)[0] for l in (g.lines(a.base, f) or []))
                        good_h = [h for h in hints if IDENT.fullmatch(h) and re.search(r'(?<![A-Za-z0-9_$])' + re.escape(h) + r'(?![A-Za-z0-9_$])', now)][:1]
                if good_h:
                    sat = [x.split(':', 1)[1] for x in good_h if x.startswith('@satisfies:')]
                    plain = [x for x in good_h if not x.startswith('@satisfies:')]
                    parts = ['`%s`' % x for x in dict.fromkeys(plain)] + (['`@satisfies: %s`' % ', '.join(sat)] if sat else [])
                    res.update(status='resolved-by-hint', target=f, symbols=good_h, new='`%s` %s' % (f, '、'.join(parts)))
                    results.append(res)
                    continue
            if cands and all(c.startswith('tb_') or c.endswith('.vh') for c in cands):
                resolve_tb(g, a.base, it, row, cands, res)
                results.append(res)
                continue
            picks = []
            for f in cands:
                src = g.lines(it['blame'], f)
                if src is None:
                    continue
                syms, evid, kinds = [], [], []
                for lo, hi in nums_list(it['nums']):
                    if hi - lo > 40 or lo < 1 or lo > len(src):
                        continue
                    for n in range(lo, min(hi, len(src)) + 1):
                        line = src[n - 1]
                        evid.append(line.strip()[:160])
                        code, _ = split_comment(line)
                        hit = [s for s in cell_syms + row_syms if re.search(r'(?<![A-Za-z0-9_$])' + re.escape(s) + r'(?![A-Za-z0-9_$])', code)]
                        if hit:
                            syms.append(max(hit, key=len)); kinds.append('row-symbol')
                        else:
                            k, names = extract(line)
                            if names and k not in ('other', 'none'):
                                syms.append(names[0]); kinds.append(k)
                            elif names:
                                syms.append(names[0]); kinds.append('weak')
                if len(syms) > 1:
                    keep = [(s, k) for s, k in zip(syms, kinds) if s not in NOISE and k != 'weak']
                    if keep:
                        syms, kinds = [s for s, _ in keep], [k for _, k in keep]
                picks.append((f, syms, evid, kinds))
            # choose file
            good = [p for p in picks if p[1] and 'row-symbol' in p[3]]
            if len(cands) == 1 and picks:
                choice = picks[0]
            elif len(good) == 1:
                choice = good[0]
            else:
                choice = None
            by_name = False
            if (choice is None or not choice[1]) and len(cands) == 1:
                # Q1: the row states the symbol -> locate it by name in the base file
                f = cands[0]
                if f not in base_cache:
                    base_src = g.lines(a.base, f) or []
                    base_cache[f] = ('\n'.join(split_comment(l)[0] for l in base_src),
                                     '\n'.join(split_comment(l)[1] for l in base_src))
                code_now = base_cache[f][0]
                cols = [c.strip() for c in row.strip().strip('|').split('|')]
                port_col = TICK.findall(cols[3]) if re.match(r'^C\d\d$', cols[0] if cols else '') and len(cols) > 4 else []
                present = [s for s in dict.fromkeys(cell_syms + row_syms)
                           if re.search(r'(?<![A-Za-z0-9_$])' + re.escape(s) + r'(?![A-Za-z0-9_$])', code_now)]
                pick = [s for s in port_col if s in present] or (present if len(present) == 1 else [])
                if pick:
                    choice = (f, pick[:1], [], ['by-name'])
                    by_name = True
            if choice is not None and choice[1] and 'row-symbol' not in choice[3] and not by_name:
                # Q1: a symbol written in the anchor's own cell governs a drifted line
                f = choice[0]
                if f not in base_cache:
                    base_src = g.lines(a.base, f) or []
                    base_cache[f] = ('\n'.join(split_comment(l)[0] for l in base_src),
                                     '\n'.join(split_comment(l)[1] for l in base_src))
                code_now = base_cache[f][0]
                cell_present = [s for s in dict.fromkeys(cell_syms)
                                if re.search(r'(?<![A-Za-z0-9_$])' + re.escape(s) + r'(?![A-Za-z0-9_$])', code_now)]
                if cell_present and not set(choice[1]) & set(cell_present):
                    res['line_drift'] = {'read': choice[1][:3], 'evidence': choice[2][:2]}
                    choice = (f, cell_present[:2], choice[2], ['by-name'])
                    by_name = True
            if choice is None:
                res.update(status='ambiguous' if picks else 'unresolved', new=None, candidates=cands)
            else:
                f, syms, evid, kinds = choice
                if f not in base_cache:
                    base_src = g.lines(a.base, f) or []
                    base_cache[f] = ('\n'.join(split_comment(l)[0] for l in base_src),
                                     '\n'.join(split_comment(l)[1] for l in base_src))
                base_code, base_cmt = base_cache[f]
                uniq = list(dict.fromkeys(syms))
                ok = []
                for s in uniq:
                    if s.startswith('@satisfies:'):
                        ok.append(re.search(r'@satisfies:[^\n]*' + re.escape(s.split(':', 1)[1]), base_cmt) is not None)
                    else:
                        ok.append(re.search(r'(?<![A-Za-z0-9_$])' + re.escape(s) + r'(?![A-Za-z0-9_$])', base_code) is not None)
                if not all(ok) and any(s in RENAMED for s in uniq):
                    uniq = [RENAMED[s] if (s in RENAMED and not o) else s for s, o in zip(uniq, ok)]
                    ok = [re.search(r'(?<![A-Za-z0-9_$])' + re.escape(s) + r'(?![A-Za-z0-9_$])', base_code) is not None
                          if not s.startswith('@satisfies:') else o for s, o in zip(uniq, ok)]
                    kinds = kinds + ['renamed']
                if not uniq:
                    status = 'unresolved'
                elif by_name and all(ok):
                    status = 'resolved-by-name'
                elif all(ok) and 'weak' not in kinds:
                    status = 'resolved'
                elif all(ok):
                    status = 'resolved-weak'
                else:
                    status = 'symbol-gone'
                sat = [s.split(':', 1)[1] for s in uniq if s.startswith('@satisfies:')]
                plain = [s for s in uniq if not s.startswith('@satisfies:')]
                parts = ['`%s`' % s for s in plain[:4]] + (['`@satisfies: %s`' % ', '.join(sat)] if sat else [])
                res.update(status=status, target=f, symbols=uniq, kinds=kinds, evidence=evid[:4],
                           new='`%s` %s' % (f, '、'.join(parts)) if parts else None)
        elif it['kind'] in ('contract', 'matrix', 'alias'):
            name = cid.get(it['ref'], it['ref']) if re.fullmatch(r'C\d\d', it['ref'] or '') else it['ref']
            if it['kind'] == 'matrix':
                name = 'PPG_CONTRACT_CLOSURE_MATRIX.md'
            elif it['kind'] == 'alias':
                name = 'PPG_ALIAS_MAPPING_TABLE.md'
            then = g.lines(it['blame'], name)
            now = g.lines(a.base, name)
            if then is None or now is None:
                res.update(status='unresolved', new=None)
            else:
                secs = []
                for lo, hi in nums_list(it['nums']):
                    num, title = governing_heading(then, lo)
                    rowid = None
                    if lo <= len(then) and then[lo - 1].startswith('|'):
                        rowid = then[lo - 1].strip('|').split('|')[0].strip()[:40]
                    secs.append((num, title, rowid, then[lo - 1].strip()[:120] if lo <= len(then) else '', False))
                    if hi != lo:
                        num2, title2 = governing_heading(then, hi)
                        if num2 != num:
                            secs.append((num2, title2, None, '', True))
                idx = heading_index(now)
                outs, st = [], 'resolved'
                for num, title, rowid, ev, is_end in secs:
                    if num is None:
                        outs.append('文件头'); continue
                    if is_end and outs:
                        if num not in idx:
                            st = 'section-gone'
                        outs[-1] += '–§%s' % num
                        continue
                    if num not in idx:
                        st = 'section-gone'
                    label = '§%s' % num
                    if len(idx.get(num, [])) > 1:
                        label += ' ' + short_title(title)
                    if it['kind'] != 'contract' and rowid and not rowid.startswith('---'):
                        label += ' %s行' % rowid
                    outs.append(label)
                outs = list(dict.fromkeys(outs))
                res.update(status=st, sections=secs, new='%s %s' % (it['ref'] if it['kind'] == 'contract' else name, '、'.join(outs)))
        else:
            res.update(status='unresolved', new=None)
        results.append(res)
    json.dump(results, open(a.out, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    from collections import Counter
    print(Counter((r['kind'], r['status']) for r in results).most_common())
    print('written_at_import (non-strike):', sum(1 for r in results if r['written_at_import'] and r['status'] != 'history-strike'))


if __name__ == '__main__':
    main()
