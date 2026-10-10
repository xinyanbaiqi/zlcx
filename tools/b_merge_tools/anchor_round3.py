# -*- coding: utf-8 -*-
"""Round 3 of the anchor conversion: semantic consistency review (coordinator review of
9d62ad4, 2026-10-10).

Usage:
    python anchor_round3.py --table anchor_mapping_table.tsv --out anchor_round3_decisions.tsv
                            [--report round3_review.md] [--repo DIR] [--base 7a8eabf]

Background: the git history of this repository starts at the 2026-09-28 import commit
b858bf0. For every matrix/alias line written before that date, git blame names the import
commit, so the "written-at version" read by the resolver is a later file whose line
numbers may have drifted (e.g. matrix §12.5, written 09-16, shifted by 2 lines after the
09-18 SID-05 change). The resolver also let the content of that line override a symbol the
cell writes next to the anchor. This script reviews every converted symbol anchor:

  (a) written symbol governs (brief §3.13 Q1): when the cell writes a symbol next to the
      anchor (W8: "`a.v:N` (`b.v:M`)" names the symbol of the anchor before it; anchor_semantics.written_name: W1 declaration after the anchor, W2/W3
      "Mod.port（ ... 声明", W4 "Top内部网", W5 "Top边界输入/输出" + row port, W6/W7 a
      backticked name opening / inside the anchor's parenthesis), the anchor must name it.
      If the name exists in the anchor's file it is corrected there; a bare `:N` whose
      name is declared in exactly one other file moves to that file; anything else is a
      hand decision (MANUAL below). For W6/W7 the current symbol is kept when it is itself
      written in the clause just before the anchor.
  (b) no written symbol: the resolved symbol must relate to the row -- appear in the row,
      or match the row port's stem (i_/o_ counterpart). Otherwise:
        alias row whose ID has an @satisfies tag in the anchor file -> that tag;
        written-at commit is a real commit (not the import)        -> kept (reliable);
        import commit: a symbol the row names within +-5 lines of the cited line at the
        import commit (drift)                                        -> that symbol;
        nothing found                                                -> kept, LOW CONFIDENCE.
  (c) the default-converted ("uncertain") anchors go through (a) and (b) like all others.

Output: decisions TSV (doc, line, old, action, arg1, arg2, reason) read by
anchor_mapping.py after anchor_manual_decisions.tsv; actions are 'sym', 'tag' (changes)
and 'note' (keep the resolver's text, record the review result).
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_semantics import written_name, row_port  # noqa: E402

M, A = 'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'
VERILOG_WORDS = set('''input output inout wire reg integer parameter localparam assign always initial begin end
module endmodule generate endgenerate genvar function task case endcase default posedge negedge signed if else'''.split())
RENAMED = {'i_status_clear_event': 'i_diag_clear_event'}
IDR = re.compile(r'\b(?:[A-Z][A-Z0-9]*(?:-[A-Za-z0-9]+)+|P\d\d|N\d\d|K\d\d|L\d\d)\b')
NEW = re.compile(r'^`([A-Za-z0-9_]+\.vh?)`((?:\s*(?:、)?\s*`[^`]+`)*)$')
_M = '第三轮（统筹10-10核对：格内写明的符号为准）：'
# hand decisions for (a) cases the rules leave open: (doc, base line, old) -> (file, symbol or None=keep, reason)
MANUAL = {
    (M, 2272, '`:959,716`'): ('ppg_precision_window_controller.v', 'reacquire_request_event_o', '格内“cluster ⑤\'s ppg_precision_window_controller (reacquire_request_event_o, …)”，生产方为PWC'),
    (M, 2273, '`:219,717`'): ('ppg_precision_window_integration.v', 'amb_recheck_accept_o', '格内写明amb_recheck_accept_o；该名只存在于PWI（重检调度器o_amb_recheck_accept接出的网）'),
    (M, 2367, '`:219,831`'): ('ppg_precision_window_integration.v', 'amb_recheck_accept_o', '同上'),
    (M, 2552, '`:219`'): ('ppg_precision_window_integration.v', 'amb_recheck_accept_o', '同上'),
    (M, 2318, '`:877,745`'): ('ppg_precision_window_integration.v', 'valley_pending_o', '格内写明valley_pending_o；该名只存在于PWI'),
    (M, 2416, '`:956,863`'): ('ppg_precision_window_controller.v', 'fine_window_start_frame_id_o', '格内“ppg_precision_window_controller (fine_window_start_frame_id_o, …)”'),
    (M, 2417, '`:953,864`'): ('ppg_precision_window_controller.v', 'active_precision_mode_o', '格内“ppg_precision_window_controller (active_precision_mode_o, …)”'),
    (M, 3217, '`:167,218,246-254`'): ('ppg_amb_recheck_scheduler.v', 'amb_recheck_pending_o', '格内“C16/amb_recheck_scheduler\'s own pending state (amb_recheck_pending_o, …)”'),
    (M, 2507, 'ppg_dynamic_baseline_cross_detector.v:550'): ('ppg_dynamic_baseline_cross_detector.v', 'o_cross_valid',
                                                           '括注名cross_pending_o是AMI网、不在显式文件中；本行端口i_cross_valid，写入时版本:550为assign o_cross_valid，按显式文件与本行端口'),
    (M, 2515, 'ppg_peak_valley_window_detector.v:441'): ('ppg_peak_valley_window_detector.v', 'o_return_9bit_valid',
                                                        '括注名return_pending_o是AMI网、不在显式文件中；本行端口i_return_9bit_valid，导入版本:440为assign o_return_9bit_valid（漂移1行）'),
    (M, 2532, '`:1135`'): ('ppg_adc_measurement_idac_integration.v', 'o_ami_fault_active', '格内“ORed into `o_ami_fault_active` (:1135)”，AMI的5路lane-active汇总（原解析为PWI o_mode_fault_active，文件错归）'),
    (M, 2509, 'ppg_dynamic_baseline_cross_detector.v:531'): (None, None, '保留：显式文件为交叉检测器，o_cross_frame_id为其输出；格内dec_cross_frame_id是其后“-> PWI”一段的下游网名'),
    (A, 135, 'ppg_400hz_frame_calibration_scheduler.v:463-464'): ('ppg_400hz_frame_calibration_scheduler.v', 'o_owner_deadline_timeout_sticky',
                                                              '格内“o_scheduler_owner_deadline_timeout_sticky(scheduler.v:463-464附近deadline逻辑)”：Top端口由调度器o_owner_deadline_timeout_sticky驱动，锚点文件为调度器'),
}


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), capture_output=True).stdout.decode('utf-8', 'replace')


def widen(line, s, e):
    t = line[s:e].count('`')
    if t % 2 == 0 and s > 0 and line[s - 1] == '`' and e < len(line) and line[e] == '`':
        return s - 1, e + 1
    if t % 2 == 1:
        if line[s:e].startswith('`') and e < len(line) and line[e] == '`':
            return s, e + 1
        if s > 0 and line[s - 1] == '`':
            return s - 1, e
        if e < len(line) and line[e] == '`':
            return s, e + 1
    return s, e


def word(n):
    return r'(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])' % re.escape(n)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--table', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--report')
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf')
    ap.add_argument('--import-commit', default='b858bf0')
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.table, encoding='utf-8'), delimiter='\t'))
    docs = {d: git(a.repo, 'show', '%s:contracts/%s' % (a.base, d)).split('\n') for d in (M, A)}
    rtl = {os.path.basename(p): p for p in git(a.repo, 'ls-files', 'rtl').split('\n')
           if p.endswith('.v') and not os.path.basename(p).startswith('tb_')}
    src = {f: open(os.path.join(a.repo, p), encoding='utf-8').read() for f, p in rtl.items()}
    imp_paths = {os.path.basename(p): p for p in git(a.repo, 'ls-tree', '-r', '--name-only', a.import_commit).split('\n') if p.endswith('.v')}
    imp_cache = {}

    def imp_lines(f):
        if f not in imp_cache:
            imp_cache[f] = git(a.repo, 'show', '%s:%s' % (a.import_commit, imp_paths[f])).split('\n') if f in imp_paths else []
        return imp_cache[f]

    def has(f, n):
        return f in src and re.search(word(n), src[f]) is not None

    def owners(n):
        return [f for f, t in src.items()
                if re.search(r'\b(?:input|output|inout|wire|reg|localparam|parameter|integer)\b[^;()\n]*?' + word(n), t)
                or re.search(r'^\s*module\s+' + re.escape(n) + r'\b', t, re.M)]

    def tags(f):
        return set(i for s in re.findall(r'@satisfies:?\s*([^\n]*)', src.get(f, '')) for i in IDR.findall(s))

    stem = lambda s: re.sub(r'^(?:i|o|io)_', '', s)
    out, stats, listing = [], {}, []

    def emit(r, action, a1, a2, reason, cat):
        out.append([r['doc'], r['line'], r['old'], action, a1, a2, reason])
        if action == 'sym':
            done[(r['doc'], r['line'], int(r['col']))] = '`%s` `%s`' % (a1, a2)
        elif action == 'tag':
            done[(r['doc'], r['line'], int(r['col']))] = '`%s` `@satisfies: %s`' % (a1, a2)
        stats[cat] = stats.get(cat, 0) + 1
        listing.append((cat, r, action, a1, a2, reason))

    done = {}                                  # (doc, line, col) -> effective new text after this review
    for r in rows:
        if r['class'] != 'convert':
            continue
        done[(r['doc'], r['line'], int(r['col']))] = r['new']
        m = NEW.match(r['new'])
        if not m:
            continue
        f = m.group(1)
        syms = re.findall(r'`([^`]+)`', m.group(2))
        plain = [x for x in syms if not x.startswith(('@', '"'))]
        L = docs[r['doc']][int(r['line']) - 1]
        s0 = int(r['col'])
        s, e = widen(L, s0, s0 + len(r['old']))
        key = (r['doc'], int(r['line']), r['old'])
        if key in MANUAL:
            mf, msym, why = MANUAL[key]
            if msym is None:
                emit(r, 'note', '', '', _M + why, '(a) 人工：保留')
            else:
                emit(r, 'sym', mf, msym, _M + why, '(a) 人工：纠正')
            continue
        name, rule = written_name(L, s, e, row_port(L))
        if not name:
            # W8: "`a.v:N` (`b.v:M`)" -- the parenthetical anchor wires the symbol named by the
            # anchor just before it; that anchor's (corrected) symbol is the written name
            pre = L[max(0, s - 160):s]
            pm = re.search(r'`([A-Za-z0-9_./]+\.vh?):[0-9,\-\s]+`\s*[（(]\s*$', pre)
            if pm:
                pcol = s - len(pre) + pm.start(1)
                prev_new = done.get((r['doc'], r['line'], pcol))
                if prev_new:
                    pn = [x for x in re.findall(r'`([^`]+)`', prev_new)[1:] if not x.startswith(('@', '"'))]
                    if len(pn) == 1:
                        name, rule = pn[0], 'W8'
        if name and not name.startswith('_') and name not in syms and RENAMED.get(name) not in syms:
            a0 = L.rfind('|', 0, s) + 1
            clause = L[max(a0, s - 150):s]
            if rule in ('W6', 'W7') and any(re.search(word(x), clause) for x in plain):
                stats['(a) W6/W7：现符号已写在同一子句'] = stats.get('(a) W6/W7：现符号已写在同一子句', 0) + 1
                continue
            bare = r['old'].lstrip('`').startswith(':')
            if has(f, name):
                emit(r, 'sym', f, name, _M + '%s 格内写明`%s`，原解析为%s' % (rule, name, '、'.join(syms)), '(a) 纠正：同文件')
            elif bare and len(owners(name)) == 1:
                emit(r, 'sym', owners(name)[0], name, _M + '%s 格内写明`%s`，原解析文件%s无此名，按声明所在文件' % (rule, name, f), '(a) 纠正：换文件')
            else:
                emit(r, 'note', '', '', _M + '未决：%s 格内写明`%s`，与%s不一致且无法唯一定位（请补MANUAL）' % (rule, name, '、'.join(syms)), '(a) 未决')
            continue
        if name or not plain:
            continue
        if any(re.search(word(x), L) for x in plain):
            continue
        port = row_port(L)
        if port and any(stem(x) == stem(port) or stem(port) in x for x in plain):
            continue
        if r['doc'] == A:
            first = L.strip('|').split('|')[0]
            hit = [t for t in IDR.findall(first) if t in tags(f)]
            if hit:
                emit(r, 'tag', f, hit[0], _M + '无格内符号，原解析%s与本行无关；本行ID在%s有@satisfies标签' % ('、'.join(syms), f), '(b) 纠正：行ID标签')
                continue
        if not r['written_at'].startswith(a.import_commit):
            emit(r, 'note', '', '', _M + '无格内符号，写入时点为真实提交%s，按写入时版本取符号（可靠）' % r['written_at'][:7], '(b) 保留：写入时点可靠')
            continue
        rowsyms = [x for x in set(re.findall(r'`([A-Za-z_][A-Za-z0-9_]*)`', L)) if len(x) > 3 and x not in VERILOG_WORDS]
        nums = [int(x) for x in re.findall(r'\d+', r['old'].split(':', 1)[-1])]
        lo, hi = min(nums), max(nums)
        F = imp_lines(f)
        best = None
        for ln in range(max(1, lo - 5), min(len(F), hi + 5) + 1):
            for x in rowsyms:
                if re.search(word(x), F[ln - 1]) and has(f, x):
                    d = 0 if lo <= ln <= hi else min(abs(ln - lo), abs(ln - hi))
                    if best is None or d < best[0] or (d == best[0] and x < best[1]):
                        best = (d, x, ln)
        if best:
            emit(r, 'sym', f, best[1], _M + '无格内符号，写入时点为导入提交（行号可能漂移）；导入版本第%d行（距引用%d行）出现本行所述`%s`' % (best[2], best[0], best[1]),
                 '(b) 纠正：漂移校正')
        else:
            emit(r, 'note', '', '', _M + '低置信：无格内符号，写入时点为导入提交（行号可能漂移），解析符号%s与本行无关联，±5行内也无本行所述符号' % '、'.join(syms),
                 '(b) 低置信')
    with open(a.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('doc\tline\told\taction\targ1\targ2\treason\n')
        for row in out:
            fh.write('\t'.join(str(c).replace('\t', ' ') for c in row) + '\n')
    if a.report:
        json.dump([[c, x['doc'], x['line'], x['old'], x['new'], act, a1, a2, why, x['note'].startswith('uncertain')]
                   for c, x, act, a1, a2, why in listing], open(a.report, 'w', encoding='utf-8'), ensure_ascii=False)
    for k in sorted(stats):
        print(k, stats[k])
    return 0


if __name__ == '__main__':
    sys.exit(main())
