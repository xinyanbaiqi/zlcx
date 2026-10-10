# -*- coding: utf-8 -*-
"""Round 5 of the anchor conversion: explicitly superseded old anchors (coordinator review of
67707b3, part 2).

Usage:
    python anchor_round5.py --table anchor_mapping_table_round4.tsv --out anchor_round5_decisions.tsv
                            [--scan scan.json] [--repo DIR] [--base 7a8eabf]

The coordinator found two matrix rows (baseline 1577 `:234`, 1585 `:245`) of the same class as
1596 `:247`: the cell itself says the anchor is a stale, replaced one ("Anchor corrected from
stale `:234` (unrelated §4 heading)"), yet it was converted. This round
  RULE    scans the baseline text around every anchor with anchor_history_rules.superseded_wording
          (wording at the anchor that names it as the old / voided / wrong reference, or the
          old side of an old->new pair of bare line numbers) and classes every hit
          'history-superseded' (restored verbatim, allowlisted) -- class 3 of the 2026-10-09
          ruling, the same class 1596 `:247`, alias 192 and the 2182 `:1359-1377` range now share;
  MANUAL  the same class where the wording is too irregular for the rule (rows 2147, 2860:
          "`i_clk`标`:1972`", "所引的`:2005`", "形如\"`:2306`\"至\"`:2427`\"" ...);
  FIX     rows 2147 and 2860 are 2026-09-28/30 audit notes about AMI line numbers; their
          verified (current) numbers had been resolved into the wrong file (the row's first
          file, fork / IDAC controller) and named the row port -- corrected to the AMI symbols
          those lines hold at the written-at version (checked: d18c695, b1de2e0).
Decisions carry the column ('col') because the same old text recurs in these rows with
different meanings (e.g. 2860 `:2374` on both sides of an arrow).
"""
import argparse
import csv
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_history_rules import superseded_wording  # noqa: E402

M, A = 'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'
AMI, IDAC, FORK = 'ppg_adc_measurement_idac_integration.v', 'ppg_idac_code_controller.v', 'ppg_normal_transaction_fork.v'
_S = '第五轮（统筹10-10对67707b3核对意见：被明示取代的旧锚点）：'
_F = '第五轮（同行审计注记中已核实的行号，原误归首个文件并取本行端口）：'

# (doc, baseline line, col) -> (action, arg1, arg2, reason)
MANUAL = {
    (M, 2860, 1082): ('history-superseded', '', '', '“如`i_clk`标`:1972`”：矩阵原标的旧行号（统一少15），本格明示错误'),
    (M, 2860, 1114): ('history-superseded', '', '', '“`i_measurement_ready`所引的`:2005`等…统一比实际行号少15”：旧行号，本格明示错误'),
    (M, 2860, 2122): ('history-superseded', '', '', '“`:912`实际只差+7”：指旧行号`:912`本身（实为`:919`），明示取代'),
    (M, 2860, 2207): ('history-superseded', '', '', '“…连接锚点及`:1336`处”：指旧行号`:1336`（实为`:1351`），明示取代'),
    (M, 2147, 853): ('history-superseded', '', '', '“行号引用（形如\"`:2306`\"至\"`:2427`\"）统一比实际行号少15”：旧行号示例，本格明示错误'),
    (M, 2147, 863): ('history-superseded', '', '', '同上，旧行号示例`:2427`'),
    (M, 2860, 1169): ('sym', AMI, 'ppg_normal_transaction_fork_Inst,i_clk', _F + '“`i_clk`…实际`:1987`”：d18c695版AMI 1987行为fork例化的`.i_clk(i_clk)`'),
    (M, 2860, 1225): ('sym', AMI, 'ppg_normal_transaction_fork_Inst,i_datapath_discard_run_generation',
                      _F + '“`i_datapath_discard_run_generation`…实际`:1998`”：d18c695版AMI 1998行为fork例化的该端口连接'),
    (M, 2860, 1777): ('sym', AMI, 'ppg_normal_transaction_fork_Inst', _F + '“fork自身连接点21个（…→`:2020`-`:2040`）”：d18c695版AMI 2020~2040行为fork例化的端口连接'),
    (M, 2860, 1785): ('sym', AMI, 'ppg_normal_transaction_fork_Inst', _F + '同上（区间终点`:2040`）'),
    (M, 2860, 1863): ('sym', AMI, 'ppg_adc_pipeline_overlap_corrector_Inst', _F + '“overlap_corrector例化连接点21个（…→`:2086`-`:2105`及`:2107`）”：d18c695版AMI为该例化的端口连接'),
    (M, 2860, 1871): ('sym', AMI, 'ppg_adc_pipeline_overlap_corrector_Inst', _F + '同上（`:2105`）'),
    (M, 2860, 1879): ('sym', AMI, 'ppg_adc_pipeline_overlap_corrector_Inst', _F + '同上（`:2107`）'),
    (M, 2860, 1900): ('sym', AMI, 'ppg_adc_pipeline_overlap_corrector_Inst', _F + '“逐端口名对照AMI内该例化`:2074`-`:2135`”：d18c695版AMI 2074行为`)ppg_adc_pipeline_overlap_corrector_Inst(`'),
    (M, 2860, 1908): ('sym', AMI, 'ppg_adc_pipeline_overlap_corrector_Inst', _F + '同上（例化块终点`:2135`）'),
    (M, 2860, 1991): ('sym', AMI, 'ppg_idac_code_controller_Inst', _F + '“IDAC控制器例化连接点16个（…→`:2374`-`:2389`）”：d18c695版AMI为该例化的端口连接'),
    (M, 2860, 1999): ('sym', AMI, 'ppg_idac_code_controller_Inst', _F + '同上（`:2389`）'),
    (M, 2860, 2052): ('sym', AMI, 'measurement_result_discard_run_generation_o', _F + '“AMI内部信号（`:1336`→`:1351`）”：d18c695版AMI 1351行为measurement_result_discard_run_generation_o寄存器赋值'),
    (M, 2860, 2067): ('sym', AMI, 'flag_normal_track_qualified', _F + '“`:912`→`:919`”：d18c695版AMI 919行为`assign flag_normal_track_qualified`（同2843行所述）'),
    (M, 2860, 732): ('sym', FORK, 'ppg_normal_transaction_fork', '第五轮：“与`ppg_normal_transaction_fork.v:61-146`独立核对的端口声明”：所指为模块端口声明区，取模块名（原解析取本行端口o_local_empty）'),
    (M, 2860, 993): ('sym', FORK, 'ppg_normal_transaction_fork', '第五轮：“本子模块自身文件声明行引用（`:61-146`）”：同上'),
    (M, 2147, 925): ('sym', AMI, 'ppg_idac_code_controller_Inst,i_clk', _F + '“`i_clk`矩阵标`:2306`，实际`:2321`”：b1de2e0版AMI为IDAC控制器例化的`.i_clk(i_clk)`'),
    (M, 2147, 961): ('sym', AMI, 'ppg_idac_code_controller_Inst,o_idac_idle', _F + '“本行`o_idac_idle`…实际`:2442`”：AMI中IDAC控制器例化的`.o_idac_idle(`连接'),
    (M, 2147, 472): ('sym', IDAC, 'ppg_idac_code_controller', '第五轮：“`ppg_idac_code_controller.v:67-207`声明区”：所指为模块端口声明区，取模块名（原解析取本行端口o_idac_idle）'),
    (M, 2147, 620): ('text', '`%s` `"输出信号连线"`' % IDAC, '', '第五轮：“模块自身文件内引用（声明行+实现行，如`:602-682`）”：b1de2e0版602-682行为“输出信号连线”段，改为该段标题注释原文锚点（原解析取本行端口o_idac_idle）'),
}


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), capture_output=True).stdout.decode('utf-8', 'replace')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--table', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--scan')
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf')
    a = ap.parse_args()
    docs = {d: git(a.repo, 'show', '%s:contracts/%s' % (a.base, d)).split('\n') for d in (M, A)}
    rows = list(csv.DictReader(open(a.table, encoding='utf-8'), delimiter='\t'))
    out, scan = [], []
    for r in rows:
        L = docs[r['doc']][int(r['line']) - 1]
        c = int(r['col'])
        key = (r['doc'], int(r['line']), c)
        w = superseded_wording(L, c, c + len(r['old']))
        if w:
            scan.append({'doc': r['doc'], 'line': int(r['line']), 'col': c, 'old': r['old'], 'wording': w, 'was': r['class'],
                         'was_new': r['new'], 'ctx': L[max(0, c - 70):c] + '⟦' + r['old'] + '⟧' + L[c + len(r['old']):c + len(r['old']) + 40]})
            if key in MANUAL:
                raise SystemExit('rule hit also in MANUAL: %s' % (key,))
            if r['class'].startswith('history-') and r['class'] != 'history-superseded' and r['class'] not in ('history',):
                continue      # already struck / block history, nothing to change
            out.append([r['doc'], r['line'], c, r['old'], 'history-superseded', '', '',
                        _S + '格内措辞“%s”表明该锚点本身是被明示取代/作废的旧锚点，按历史保留原文（规则anchor_history_rules.superseded_wording）' % w])
        elif key in MANUAL:
            act, a1, a2, why = MANUAL[key]
            out.append([r['doc'], r['line'], c, r['old'], act, a1, a2, (_S if act == 'history-superseded' else '') + why])
    missing = set(MANUAL) - set((x[0], int(x[1]), int(x[2])) for x in out)
    if missing:
        raise SystemExit('MANUAL keys not in table: %s' % sorted(missing))
    with open(a.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('doc\tline\tcol\told\taction\targ1\targ2\treason\n')
        for row in out:
            fh.write('\t'.join(str(x).replace('\t', ' ') for x in row) + '\n')
    if a.scan:
        json.dump(scan, open(a.scan, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    from collections import Counter
    print('rule hits', len(scan), 'decisions', len(out), dict(Counter(x[4] for x in out)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
