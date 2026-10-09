# -*- coding: utf-8 -*-
"""B merge batch stage 3: TB label renames (string literals / format strings only)
and the matching banner regexes in tools/run_unit_tb_regression.sh.
Each replacement asserts its exact occurrence count. Run from repo root."""
import io

EDITS = {
    'rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v': [
        ('$display("PASS FSC-%0d", i_case_number);', '$display("PASS SCHT-%0d", i_case_number);', 1),
        ('$display("FAIL FSC-%0d cycle=%0d tick=%0d", i_case_number, cnt_cycle, o_macro_tick);',
         '$display("FAIL SCHT-%0d cycle=%0d tick=%0d", i_case_number, cnt_cycle, o_macro_tick);', 1),
        ('$display("FSC-01 through FSC-62: pass=%0d fail=%0d", cnt_pass, cnt_fail);',
         '$display("SCHT-1 through SCHT-62: pass=%0d fail=%0d", cnt_pass, cnt_fail);', 1),
        ('$display("ALL FSC-01 THROUGH FSC-62 PASSED");', '$display("ALL SCHT-1 THROUGH SCHT-62 PASSED");', 1),
    ],
    'rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v': [
        ('check_case("SUP03A",', 'check_case("CLRBLK",', 1),
        ('check_case("SUP06A",', 'check_case("EPICLS",', 1),
        ('check_case("SUP09A",', 'check_case("WDIDLE",', 1),
        ('check_case("SUP10A",', 'check_case("EPI2ND",', 1),
        ('$display("SUP-01 through SUP-10 PASS: %0d real comparisons", cnt_pass);',
         '$display("SUP-01/02/04/06/07 and TB-local supervisor checks PASS: %0d real comparisons", cnt_pass);', 1),
    ],
    'rtl/ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v': [
        ('$display("FAIL DCR-%0d coarse=%0d fine=%0d", test_id,', '$display("FAIL DCRT-%0d coarse=%0d fine=%0d", test_id,', 1),
        ('$display("PASS ppg_adc_dc_recovery DCR-01..DCR-22");',
         '$display("PASS ppg_adc_dc_recovery directed DCR checks and DCRT-n vectors");', 1),
    ],
    'rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v': [
        ('begin_case("SSW-18");', 'begin_case("CAL-ODL");', 1),
        ('end_case("SSW-18");', 'end_case("CAL-ODL");', 1),
    ],
    'rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v': [
        ('check_case("AMI-13", o_measurement_result_valid', 'check_case("FORK-HOLD", o_measurement_result_valid', 1),
    ],
    'rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v': [
        ('$display("FAIL LFA-11a a formal result', '$display("FAIL AUTOABT-QUIET a formal result', 1),
        ('$display("PASS LFA-11a informational:', '$display("PASS AUTOABT-QUIET informational:', 1),
        ('$display("PASS LFA-11a the supervisor', '$display("PASS AUTOABT-QUIET the supervisor', 1),
    ],
    'tools/run_unit_tb_regression.sh': [
        ('|^ALL FSC-01 THROUGH FSC-62 PASSED$|', '|^ALL SCHT-1 THROUGH SCHT-62 PASSED$|', 1),
        ('|^SUP-01 through SUP-10 PASS: [0-9]+ real comparisons$|',
         '|^SUP-01/02/04/06/07 and TB-local supervisor checks PASS: [0-9]+ real comparisons$|', 1),
        ('|^PASS ppg_adc_dc_recovery DCR-01\\.\\.DCR-22$|', '|^PASS ppg_adc_dc_recovery directed DCR checks and DCRT-n vectors$|', 1),
    ],
}


def main():
    for path, pairs in EDITS.items():
        raw = open(path, 'rb').read()
        crlf = b'\r\n' in raw
        s = raw.decode('utf-8').replace('\r\n', '\n')
        for old, new, cnt in pairs:
            got = s.count(old)
            assert got == cnt, (path, old, got)
            s = s.replace(old, new)
        if crlf:
            s = s.replace('\n', '\r\n')
        open(path, 'wb').write(s.encode('utf-8'))
        print('edited', path, len(pairs))


main()


# ---------------- changelog entries (comments only) ----------------
import re
LOG = {
    'rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v': ('V1.10', 'V1.11',
        'B merge batch (ID governance): label strings only. check_fsc prints the TB-local name SCHT-n (was FSC-n, a TB scenario number that does not share meaning with C08 FSC-nn; TB SCHT-14 = contract FSC-03, SCHT-32 = FSC-30, mapping in the alias table); both summary banners follow. check_fsc arguments, stimulus, checks and counts unchanged.',
        'B合并批次（编号治理）：只改标签字符串。check_fsc打印TB本地名SCHT-n（原FSC-n是TB场景序号，与C08同号条目含义不同；TB SCHT-14=合同FSC-03，SCHT-32=FSC-30，对应关系见别名表），两行总横幅同步。check_fsc实参、激励、判定与计数均不变。'),
    'rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v': ('V1.4', 'V1.5',
        'B merge batch (ID governance): label strings only. SUP03A->CLRBLK, SUP06A->EPICLS, SUP09A->WDIDLE, SUP10A->EPI2ND (they do not test the same-numbered C24 rows); the final banner lists the SUP rows actually checked. Checks and counts unchanged.',
        'B合并批次（编号治理）：只改标签字符串。SUP03A->CLRBLK、SUP06A->EPICLS、SUP09A->WDIDLE、SUP10A->EPI2ND（它们测的不是C24同号条目）；总横幅改为列出实际检查的SUP条目。判定与计数不变。'),
    'rtl/ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v': ('V1.1', 'V1.2',
        'B merge batch (ID governance): label strings only. drive_and_check prints the TB-local vector name DCRT-n (test_id also drives stimulus, so it is unchanged; DCRT-3..7 test C15 DCR-04/07/12/09/09, mapping in the alias table); the PASS banner no longer claims DCR-01..DCR-22. Stimulus, checks and counts unchanged.',
        'B合并批次（编号治理）：只改标签字符串。drive_and_check打印TB本地向量名DCRT-n（test_id参与激励，未改；DCRT-3~7实测C15 DCR-04/07/12/09/09，对应关系见别名表）；PASS横幅不再宣称DCR-01..DCR-22。激励、判定与计数不变。'),
    'rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v': ('V1.8', 'V1.9',
        'B merge batch (ID governance): case label SSW-18 -> TB-local CAL-ODL (it tests the calibration owner deadline, C09 SSW-37/38, not contract SSW-18). Checks unchanged.',
        'B合并批次（编号治理）：用例标签SSW-18改为TB本地名CAL-ODL（实测校准owner截止，属C09 SSW-37/38，不是合同SSW-18）。判定不变。'),
    'rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v': ('V1.14', 'V1.15',
        'B merge batch (ID governance): check label AMI-13 -> TB-local FORK-HOLD (it tests backpressure hold, part of C10 AMI-12; contract AMI-13 same-edge replacement has no dynamic check); banner notes the exception. Checks and counts unchanged.',
        'B合并批次（编号治理）：检查标签AMI-13改为TB本地名FORK-HOLD（实测反压保持，属C10 AMI-12；合同AMI-13同拍替换无动态检查）；横幅注明此例外。判定与计数不变。'),
    'rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v': ('V1.4', 'V1.5',
        'B merge batch (ID governance): sub-label LFA-11a -> TB-local AUTOABT-QUIET (it checks no formal result during the supervisor automatic owner-scoped abort, contract section 9.5.1 rule 5 / matrix P03, not C25 LFA-11). Checks and PASS count unchanged.',
        'B合并批次（编号治理）：子标签LFA-11a改为TB本地名AUTOABT-QUIET（实测supervisor自动owner级abort期间无正式结果，属合同§9.5.1规则5/矩阵P03，不是C25 LFA-11）。判定与PASS行数不变。'),
}
EDITS_AMI_BANNER = ('$display("AMI-01 through AMI-45, AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: %0d real comparisons", cnt_pass);',
                    '$display("AMI-01 through AMI-45 except AMI-13 (TB-local FORK-HOLD), AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: %0d real comparisons", cnt_pass);')
REGEX_AMI = ('|^AMI-01 through AMI-45, AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: [0-9]+ real comparisons$|',
             '|^AMI-01 through AMI-45 except AMI-13 \(TB-local FORK-HOLD\), AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: [0-9]+ real comparisons$|')
DATE_RE = re.compile(r'^// (\d{4}[-/]\d{2}[-/]\d{2}|\d{4}年\d{2}月\d{2}日)(\s+)(V\d+(?:\.\d+)*)(\s+)(\S+)(\s+)')


def fmt_date(sample):
    if '年' in sample:
        return '2026年10月09日'
    return '2026/10/09' if '/' in sample else '2026-10-09'


def add_log(path, old_v, new_v, en, cn):
    raw = open(path, 'rb').read()
    crlf = b'\r\n' in raw
    L = raw.decode('utf-8').replace('\r\n', '\n').split('\n')
    sep = next(i for i, l in enumerate(L) if l.startswith('///') and 'Chinese' in l)
    code = next(i for i, l in enumerate(L) if l.startswith('module '))
    en_dates = [i for i in range(sep) if DATE_RE.match(L[i])]
    cn_dates = [i for i in range(sep, code) if DATE_RE.match(L[i])]
    assert en_dates and cn_dates, path

    def entry(i, text):
        m = DATE_RE.match(L[i])
        return '// %s%s%s%s%s%s%s' % (fmt_date(m.group(1)), m.group(2), new_v, ' ' * max(1, len(m.group(4)) + len(m.group(3)) - len(new_v)), 'Erie', m.group(6), text)

    def after(i):
        j = i + 1
        while j < len(L) and re.match(r'^//\s{20,}\S', L[j]):
            j += 1
        return j
    ce = cn_dates[-1]
    L.insert(after(ce), entry(ce, cn))
    ee = en_dates[-1]
    L.insert(after(ee), entry(ee, en))
    for i in range(code):
        if re.match(r'^// (Version|版本):', L[i]) and old_v in L[i]:
            L[i] = L[i].replace(old_v, new_v)
        if re.match(r'^// Revision Date:', L[i]):
            L[i] = re.sub(r'\d{4}[-/]\d{2}[-/]\d{2}', lambda m: fmt_date(m.group(0)), L[i])
        if re.match(r'^// 修订日期:', L[i]):
            L[i] = re.sub(r'\d{4}年\d{2}月\d{2}日', '2026年10月09日', L[i])
    s = '\n'.join(L)
    if crlf:
        s = s.replace('\n', '\r\n')
    open(path, 'wb').write(s.encode('utf-8'))
    print('changelog', path, old_v, '->', new_v)


def sub_once(path, old, new):
    raw = open(path, 'rb').read()
    crlf = b'\r\n' in raw
    s = raw.decode('utf-8').replace('\r\n', '\n')
    assert s.count(old) == 1, (path, old)
    s = s.replace(old, new)
    if crlf:
        s = s.replace('\n', '\r\n')
    open(path, 'wb').write(s.encode('utf-8'))


sub_once('rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v', *EDITS_AMI_BANNER)
sub_once('tools/run_unit_tb_regression.sh', *REGEX_AMI)
for p, (ov, nv, en, cn) in LOG.items():
    add_log(p, ov, nv, en, cn)
