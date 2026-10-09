# -*- coding: utf-8 -*-
"""Seed the stage-4 manual decisions for anchors the resolver could not settle.

Usage:
    python anchor_manual_seed.py --resolved RES.json [--repo DIR] [--base REV] --out anchor_manual_decisions.tsv

Input is the output of anchor_resolve.py.  Every anchor whose status is
unresolved / ambiguous / resolved-weak / symbol-gone / section-gone gets one row in
the decisions file.  Decisions come from two sources, in this order:

  1. OVERRIDES below -- one hand judgment per anchor (doc, line, old text), each with
     the reason read from the cell text and the written-at line;
  2. the row-ID tag rule for the alias table -- when the referenced RTL file carries
     an `@satisfies` tag naming the row's own ID (or the ID the cell says it shares
     the anchor with), the anchor becomes that tag.

Anything left without a decision is written as action `todo` so it cannot slip
through silently.  The TSV is the reviewed record; anchor_mapping.py reads it.

Actions:  sym FILE SYM[,SYM]   tag FILE ID   file FILE   label TBFILE TEXT
          csec CONTRACT.md      (section governing the line at the written-at commit)
          text LITERAL          (replacement written out by hand, e.g. the section the cell names)
          msec                  (matrix row, same rule)
          history / not-anchor / external / lost   (text kept, reason recorded)
"""
import argparse
import json
import re
import subprocess

AMI = 'ppg_adc_measurement_idac_integration.v'
TOP = 'ppg_control_top.v'
PWI = 'ppg_precision_window_integration.v'
SSW = 'ppg_sar9_sar15_safe_selection_wrapper.v'
C17 = 'ppg_idac_code_controller.v'
SCH = 'ppg_400hz_frame_calibration_scheduler.v'
CDC = 'ppg_config_cdc_bridge.v'
C02 = 'ppg_system_config_manager.v'
PVW_TB = 'tb_ppg_peak_valley_window_detector.v'

# (doc, base line, old anchor text) -> (action, arg1, arg2, reason)
M, A = 'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'
OVERRIDES = {
    (M, 1593, 'semantic_contract.md:297'): ('csec', 'ppg_system_config_manager_semantic_contract.md', '', 'C02语义合同简写；行号取写入时该合同所在小节'),
    (M, 1593, '`:88-100`'): ('csec', 'ppg_system_config_manager_semantic_contract.md', '', '续接左侧semantic_contract.md（C02），正式I/O表'),
    (M, 1640, 'semantic_contract.md:297'): ('csec', 'ppg_system_config_manager_semantic_contract.md', '', 'C02语义合同简写'),
    (M, 1725, 'ppg_active_v4_control_plane_integration.v:784'): ('sym', 'ppg_active_v4_control_plane_integration.v', 'o_stage1_weight_q16_0', '“C03 wrapper (… area)”指C03的Stage1权重0导出端口；:784属Top，另条处理'),
    (M, 2220, '`:1006`'): ('sym', AMI, 'o_calibration_sample_valid', '左侧引文即AMI的assign o_calibration_sample_valid'),
    (M, 2221, '`:1007`'): ('sym', AMI, 'o_calibration_frame_type', '本行端口为AMI输出o_calibration_frame_type，锚点为其assign'),
    (M, 2224, '`:1010`'): ('sym', AMI, 'o_calibration_request_reason', '本行端口为AMI输出o_calibration_request_reason，锚点为其assign'),
    (M, 2255, '`:1074`'): ('sym', AMI, 'o_idac_fault_blocking', '左侧引文即AMI的assign o_idac_fault_blocking'),
    (M, 2257, '`:2426,1076`'): ('sym', AMI, 'startup_search_complete_o', 'C17输出经AMI内部线startup_search_complete_o（右侧括注）'),
    (M, 2258, '`:2427,1077`'): ('sym', AMI, 'idac_idle_o', 'C17输出经AMI内部线idac_idle_o（右侧括注）'),
    (M, 2505, '`:993`'): ('sym', PWI, 'i_normal_measurement_active', 'PWI内部把本端口同时送给amb_recheck_scheduler'),
    (M, 2517, '`:442`'): ('sym', PWI, 'dec_return_reason', '括注符号dec_return_reason（PWI内部线）'),
    (M, 2518, '`:443`'): ('sym', PWI, 'dec_return_frame_id', '括注符号dec_return_frame_id（PWI内部线）'),
    (M, 2572, '`:942,946`'): ('sym', AMI, 'flag_detection_transfer,flag_result_fork_all_released', '括注两个fork释放符号均在AMI'),
    (M, 2621, '`:1001`'): ('sym', AMI, 'i_macro_frame_safe_boundary', 'AMI-hub行，端口i_macro_frame_safe_boundary在AMI内分送两个调度器'),
    (M, 2635, '`:1138`'): ('sym', AMI, 'o_ami_fault_cause', '左侧“o_ami_fault_cause=8\'h04 dispatch”'),
    (M, 2636, '`:84`'): ('text', 'C10 §3', '', '格内写明“§3 (:84, integration module scope)”；写入时:84已漂入§2，按格内节号与标题（§3 集成模块范围）'),
    (M, 2652, '`:2634`'): ('sym', AMI, 'o_transaction_start_fire', '左侧“AMI\'s own o_transaction_start_fire”'),
    (M, 2682, '`:190-200`'): ('csec', 'PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md', '', '“§6.1 (…)”指C11合同行'),
    (M, 2682, '`:224-226`'): ('csec', 'PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md', '', '“§6.1 port table (…)”指C11合同行'),
    (M, 2682, 'ppg_adc_s1_programmable_calibrator.v:58-116'): ('file', 'ppg_adc_s1_programmable_calibrator.v', '', '整段端口声明（58-116），文件级锚点'),
    (M, 2736, '`:1985`'): ('sym', AMI, 'ppg_normal_transaction_fork_Inst', 'AMI内fork例化'),
    (M, 2760, '`:1931`'): ('sym', AMI, 'flag_idac_search_dcs_ready', '括注符号'),
    (M, 2985, '`:482-500`'): ('csec', 'PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md', '', '“§11.5 (…)”指C15合同行'),
    (M, 2985, 'ppg_adc_dc_recovery.v:55-145'): ('file', 'ppg_adc_dc_recovery.v', '', '整段端口声明（55-145），文件级锚点'),
    (M, 3027, '`:949`'): ('sym', AMI, 'coarse_ppg_value_o', '“unpacked at (:949) into coarse_ppg_value_o”，AMI结果解包'),
    (M, 3119, '`:93-395`'): ('file', AMI, '', 'AMI全部265行端口声明，文件级锚点'),
    (M, 3125, '`:984`'): ('sym', AMI, 'o_transaction_start_fire', '本行端口o_transaction_start_fire，锚点为其assign'),
    (M, 3130, '`:1015`'): ('sym', AMI, 'o_measurement_result_valid', '本行端口，右侧引文为其assign'),
    (M, 3189, 'ppg_idac_code_controller.v:2314'): ('sym', AMI, 'i_idac_code_safe_boundary', '写入时C17不足2314行，该行号属AMI（C17例化端口连线）；符号i_idac_code_safe_boundary在AMI'),
    (M, 3217, '`:928,1001`'): ('sym', C17, 'CTX_AMB_PENDING_VALID_BIT', '写入时两行均为reg_context_next[CTX_AMB_PENDING_VALID_BIT]置位'),
    (M, 3228, '`:1091,1276`'): ('sym', SSW, 'flag_red_context_valid,flag_ir_context_valid', '本行RED/IR波形上下文锁存，abort立即释放'),
    (M, 3228, '`:1089,1274`'): ('sym', SSW, 'flag_red_context_valid,flag_ir_context_valid', '本行RED/IR波形上下文锁存，复位清零'),
    (M, 3229, '`:421-422`'): ('sym', 'ppg_dynamic_baseline_cross_detector.v', 'flag_reacquire_clear', '左侧引文flag_reacquire_clear = i_reacquire_request_event'),
    (M, 3232, '`:1499`'): ('sym', AMI, 'reg_adc_inflight_frame_id', '“identity snapshot registers latch”指reg_adc_inflight_*身份快照'),
    (M, 3232, '`:1604`'): ('sym', AMI, 'flag_adc_transaction_inflight', '本行物理ADC owner，复位清零'),
    (M, 3240, 'ppg_idac_code_controller.v:26'): ('file', C17, '', 'RTL文件头V2.3修订记录，非代码行，文件级锚点'),
    (M, 3241, 'ppg_400hz_frame_calibration_scheduler.v:421'): ('sym', SCH, 'scheduler_fault_cause_o', '右侧引文scheduler_fault_cause_o = …'),
    (M, 3242, '`:48`'): ('file', SSW, '', 'SSW文件头V1.4注记，非代码行，文件级锚点'),
    (M, 3246, '`:1171-1172`'): ('sym', AMI, 'integration_protocol_error_sticky_o', '本行AMI集成协议sticky，START ACK/诊断清除'),
    (M, 3246, '`:1170`'): ('sym', AMI, 'integration_protocol_error_sticky_o', '本行AMI集成协议sticky，复位清除'),
    (M, 3247, '`:521-526,592-613`'): ('sym', C02, 'dec_error_code', '本行C02命令拒绝（dec_error_code）'),
    (M, 3401, 'ppg_config_cdc_bridge.v:70-190'): ('file', CDC, '', '整段两域实现（70-190），文件级锚点'),
    (M, 3456, 'wrapper.v:480'): ('sym', SSW, 'o_analog_safe', 'SSW简写；:480为assign o_analog_safe'),
    (M, 3557, 'ppg_sar9_sar15_safe_selection_wrapper.v:480'): ('sym', SSW, 'o_analog_safe', '右侧引文assign o_analog_safe'),
    (M, 3585, 'ppg_sar9_sar15_safe_selection_wrapper.v:25,48,480'): ('sym', SSW, 'o_analog_safe', ':25/:48为文件头修订记录，:480为assign o_analog_safe'),
    (A, 86, ':1024'): ('not-anchor', '', '', '“1024-bit CDC payload”位宽，不是行号'),
    (A, 296, ':2026-09'): ('not-anchor', '', '', '“**历史**:2026-09-15”日期，不是行号'),
    (A, 486, ':4'): ('not-anchor', '', '', '“方法:4个并行…”数量，不是行号'),
    (A, 562, ':6'): ('not-anchor', '', '', '“D01链…:6段”数量，不是行号'),
    (A, 172, 'PPG_SESSION_HANDOFF_20260826_2.md:1044-1047'): ('external', '', '', '会话交接文档未随本仓库快照入库，无法读取'),
    (A, 175, 'PPG_SESSION_HANDOFF_20260826_2.md:1042-1044'): ('external', '', '', '会话交接文档未随本仓库快照入库，无法读取'),
    (A, 176, 'PPG_SESSION_HANDOFF_20260826_2.md:1042-1044'): ('external', '', '', '会话交接文档未随本仓库快照入库，无法读取'),
    (A, 298, '`:837`'): ('csec', 'PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md', '', '“PVW-37按合同:837”指C22合同行'),
    (A, 302, '`:312`'): ('history', '', '', '记录当时deliverable gate报告的FIR错误行号，属gate输出原文'),
    (A, 303, '`:3532`'): ('text', 'PPG_CONTRACT_CLOSURE_MATRIX.md §12.13 Acceptance-D01-01行', '', '“PWC-40有真实映射但矩阵:3532那一行…”；写入时:3532为续行，含PWC-40映射的行为§12.13 Acceptance-D01-01'),
    (A, 303, '`:10`'): ('csec', 'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md', '', '“FIR合同:10/:686散文”'),
    (A, 303, '`:686`'): ('csec', 'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md', '', '“FIR合同:10/:686散文”'),
    (A, 305, '`:1099`'): ('label', PVW_TB, 'PVW-01 through PVW-48 ALL PASS', 'TB末尾cnt_pass/cnt_fail总判定，对应其PASS打印'),
    (A, 358, '`:913-953`'): ('csec', 'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md', '', 'PWC合同验收表'),
    (A, 362, '`:914-953`'): ('csec', 'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md', '', 'PWC合同验收表'),
    (A, 472, 'ppg_control_top.v:295-299'): ('sym', TOP, 'C_ADC_DRAIN_WATCHDOG_CYCLES', '参数化位宽约束注释块，紧邻C_ADC_DRAIN_WATCHDOG_CYCLES'),
    (A, 568, 'ppg_control_top.v:295-299'): ('sym', TOP, 'C_ADC_DRAIN_WATCHDOG_CYCLES', '同P12行'),
    (A, 462, 'ppg_normal_transaction_fork.v:194-309'): ('file', 'ppg_normal_transaction_fork.v', '', '两分支所有权整段（194-309），文件级锚点'),
    (A, 112, '`:26`'): ('file', C17, '', 'C17文件头V2.3修订记录，文件级锚点'),
    (A, 116, 'ppg_config_cdc_bridge.v:66-190'): ('file', CDC, '', '整段两域实现，文件级锚点'),
    (A, 108, 'ppg_adc_measurement_idac_integration.v:1605'): ('sym', AMI, 'flag_adc_transaction_inflight', '本行“AMI物理ADC owner代表行”；写入时:1605为owner交接注释，AMI无G-FP-01本号标签'),
    (A, 45, 'ppg_system_config_manager.v:394-448'): ('sym', C02, 'flag_snapshot_dc_qualification_valid', '静态检查侧，写入时:448为该汇总资格'),
}
# matrix line ranges whose anchors name a symbol in the same parentheses: (lo, hi, file).
# The symbol nearest to the anchor (left first, then right) that exists in the file at
# HEAD replaces the line number (brief section 3.13 Q1: the written symbol governs).
FAMILIES = [
    (2575, 2592, AMI, 'C05 unpack结果字段，AMI内同名解包线（payload解包assign）'),
    (2718, 2735, AMI, 'AMI内router输出线同时旁路给fork（括注符号）'),
    (3070, 3089, TOP, 'Top内部线（括注符号）'),
    (3121, 3188, AMI, 'AMI内部线/端口（括注符号）'),
    (3241, 3241, SCH, '调度器故障原因位（括注符号）'),
    (3401, 3401, CDC, 'CDC桥源域寄存器（括注符号）'),
    (3561, 3561, SSW, 'SSW宏帧tick（括注符号）'),
]
# Contract references written as `Cxx:N` that are section numbers, not line numbers
# (the resolver read them as lines).  Only the two "repair record" tables use this
# form (matrix rows R01-R08 and the stale-text ledger), recognisable by dotted
# numbers such as `C23:18.5, 19` or by dependency sections (`C10:2`).  The inventory
# matched only the integer part, so the replacement is `Cxx §N` and the rest of the
# original text (".5, 19") stays, giving `C23 §18.5, 19`.
_W = '写入人用冒号写节号（同格/同表为节号写法），解析器误作行号'
SECTION_COLON = {}
for _ln, _old, _new in [
        (999, 'C23:18', 'C23 §18'), (1000, 'C17:3', 'C17 §3'),
        (1001, 'C10:2', 'C10 §2'), (1001, 'C18:2-2', 'C18 §2–§2'), (1001, 'C23:2', 'C23 §2'), (1001, 'C25:2', 'C25 §2'),
        (1002, 'C18:5', 'C18 §5'), (1002, 'C23:8', 'C23 §8'),
        (1003, 'C01:6', 'C01 §6'), (1003, 'C10:6', 'C10 §6'),
        (3215, 'C10:6', 'C10 §6'),
        (3216, 'C10:7, 10', 'C10 §7、§10'), (3216, 'C13:3', 'C13 §4'), (3216, 'C18:5', 'C18 §5'),
        (3217, 'C16:8-13', 'C16 §8–§13'), (3217, 'C17:10-12', 'C17 §10–§12'),
        (3263, 'C17:11', 'C17 §11'),
        (3265, 'C01:6', 'C01 §6'), (3265, 'C23:19', 'C23 §19'),
        (3266, 'C18:5', 'C18 §5'), (3266, 'C23:8', 'C23 §8'),
        (3267, 'C01:6', 'C01 §6'), (3267, 'C10:6', 'C10 §6'),
        (3268, 'C10:2', 'C10 §2'), (3268, 'C18:2-2', 'C18 §2–§2'), (3268, 'C23:2', 'C23 §2'), (3268, 'C25:2', 'C25 §2'),
        (3397, 'C10:11', 'C10 §11')]:
    SECTION_COLON[(M, _ln, _old)] = ('text', _new, '', _W + ('；写入时C10第11行为版本日期，同表“matrix 9.”亦为节号写法' if _ln == 3397 else ''))
SECTION_COLON[(M, 3216, 'C13:3')] = ('text', 'C13 §4', '', _W + '；C13自导入起从无§3.1（§3为Stage1校准字段），本行内容为generation标记交接，取§4.1 Generation and lifecycle pass-through（原文“.1”保留）')
ID = re.compile(r'\b(?:[A-Z][A-Z0-9]*(?:-[A-Za-z0-9]+)+|P\d\d|N\d\d|K\d\d)\b')


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), capture_output=True).stdout.decode('utf-8', 'replace')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--resolved', required=True)
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    res = json.load(open(a.resolved, encoding='utf-8'))
    paths = {p.rsplit('/', 1)[-1]: p for p in git(a.repo, 'ls-files', 'rtl').split('\n') if p.endswith('.v')}
    head = {}

    def tags(f):
        if f not in head:
            t = open('%s/%s' % (a.repo, paths[f]), encoding='utf-8').read() if f in paths else ''
            head[f] = set(re.findall(r'@satisfies:?\s*([^\n]*)', t))
            head[f] = set(i for s in head[f] for i in ID.findall(s))
        return head[f]

    def src(f):
        return open('%s/%s' % (a.repo, paths[f]), encoding='utf-8').read() if f in paths else ''

    docs = {d: git(a.repo, 'show', '%s:contracts/%s' % (a.base, d)).split('\n') for d in (M, A)}
    rows, todo = [], 0
    for r in res:
        key = (r['file'], r['line'], r['text'])
        if r['status'] not in ('unresolved', 'ambiguous', 'resolved-weak', 'symbol-gone', 'section-gone') and key not in SECTION_COLON:
            continue
        line = docs[r['file']][r['line'] - 1]
        dec = OVERRIDES.get(key) or SECTION_COLON.get(key)
        if dec is None and r['file'] == M:
            for lo, hi, f, why in FAMILIES:
                if lo <= r['line'] <= hi:
                    cell_l = line[:r['pos']].rsplit('|', 1)[-1]
                    cell_r = line[r['end']:].split('|', 1)[0]
                    left = re.findall(r'`([A-Za-z_][A-Za-z0-9_]*)`', cell_l)[::-1]
                    right = re.findall(r'`([A-Za-z_][A-Za-z0-9_]*)`', cell_r)
                    for sym in left[:3] + right[:2]:
                        if re.search(r'(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])' % re.escape(sym), src(f)):
                            dec = ('sym', f, sym, why)
                            break
        if dec is None and r['file'] == A and (r.get('ref') or '').startswith('tb_'):
            first = line.strip('|').split('|')[0].strip()
            if first and ('"%s"' % first) in src(r['ref']):
                dec = ('label', r['ref'], first, '行ID即TB check_case用例名；写入时行号已漂移')
        if dec is None and r['file'] == A:
            first = line.strip('|').split('|')[0]
            win = line[max(0, r['pos'] - 120):r['end'] + 120]
            f = r.get('ref') if (r.get('ref') or '').endswith('.v') else None
            if f is None and r['line'] in (246, 247, 248):
                f = SSW                       # 与ILM-04共用的三处SSW锚点
            if f is None and r['line'] in (282, 283):
                f = SSW                       # 同ISE-01锚点
            cand = ID.findall(first) + [i for i in ID.findall(win) if i not in first]
            hit = [i for i in cand if f and i in tags(f)]
            if hit:
                dec = ('tag', f, hit[0], '行ID/本格点名ID在%s有@satisfies标签' % f)
        if dec is None and r['status'] == 'resolved-weak' and r.get('new'):
            dec = ('keep-auto', '', '', '弱解析结果经人工核对接受')
        if dec is None and r['file'] == M and r.get('symbols') is None:
            pass
        if dec is None:
            dec = ('todo', '', '', '')
            todo += 1
        rows.append([r['file'], str(r['line']), r['text'], dec[0], dec[1], dec[2], dec[3]])
    with open(a.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('doc\tline\told\taction\targ1\targ2\treason\n')
        for row in rows:
            fh.write('\t'.join(c.replace('\t', ' ') for c in row) + '\n')
    print('decisions', len(rows), 'todo', todo)


if __name__ == '__main__':
    main()
