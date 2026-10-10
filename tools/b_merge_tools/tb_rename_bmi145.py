# -*- coding: utf-8 -*-
"""B merge batch BMI-145: the MGR unit-TB banner claims MGR-01..MGR-24, but MGR-21
(calibration responsibility boundary, contract C02 requires the three-module joint TB)
has no check in this TB.  Banner text and its regression regex only; plus the
bilingual change-log entry.  Run from the repository root.  Every replacement asserts
exactly one occurrence.

ID governance (verification_reports/ID_GOVERNANCE_AUDIT_20261005.md section 5) for the
other range banners: PR-13 is checked under the combined label "PR-09/13"; MGR-23 is
checked under the MGR-18 label (overlap registered as BMI-181); RTR, CAL, CCC, OVL and
AV4C have no contract row without a same-meaning check.  Those banners stay.
"""
TB = 'rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v'
SH = 'tools/run_unit_tb_regression.sh'
EDITS = {
    TB: [
        ('$display("PASS: ppg_system_config_manager MGR-01 through MGR-24 all directed checks passed");',
         '$display("PASS: ppg_system_config_manager MGR-01 through MGR-24 except MGR-21 (joint-TB item) all directed checks passed");'),
        ('// Version:         V4.10\n// Revision Date:   2026/10/06',
         '// Version:         V4.11\n// Revision Date:   2026/10/09'),
        ('// 当前版本:        V4.10\n// 修订日期:        2026年10月06日',
         '// 当前版本:        V4.11\n// 修订日期:        2026年10月09日'),
        ('\n///////////////////////////////////Chinese////////////////////////////////////////\n',
         '\n// 2026/10/09        V4.11       Erie          B merge batch BMI-145 (ID governance): banner text only. The PASS banner no longer claims MGR-21, which this TB does not check (C02 requires the three-module joint TB); checks and counts unchanged.'
         '\n///////////////////////////////////Chinese////////////////////////////////////////\n'),
        ('\n\n// 对配置原子提交、生命周期命令、错误保持和STOPPING排空执行定向自检\n',
         '\n// 2026年10月09日   V4.11       Erie          B合并批次BMI-145（编号治理）：只改横幅文字。PASS横幅不再宣称覆盖MGR-21（本TB无此检查，C02要求三模块联合TB验证）；判定与计数不变。'
         '\n\n// 对配置原子提交、生命周期命令、错误保持和STOPPING排空执行定向自检\n'),
    ],
    SH: [
        ('|^PASS: ppg_system_config_manager MGR-01 through MGR-24 all directed checks passed$|',
         '|^PASS: ppg_system_config_manager MGR-01 through MGR-24 except MGR-21 \\(joint-TB item\\) all directed checks passed$|'),
    ],
}

for path, pairs in EDITS.items():
    raw = open(path, 'rb').read()
    crlf = b'\r\n' in raw
    s = raw.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        assert s.count(old) == 1, (path, old[:60], s.count(old))
        s = s.replace(old, new)
    if crlf:
        s = s.replace('\n', '\r\n')
    open(path, 'wb').write(s.encode('utf-8'))
    print('edited', path, len(pairs))
