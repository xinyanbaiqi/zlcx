"""Build the alias-table rows that depend on the stage-3 TB label renames (draft).

Usage: python make_alias_draft_renamed.py <ID_GOVERNANCE_AUDIT_20261005.md> <out.md>

The FSC rows are derived from the audit's section 5.2 FSC verdicts ("the same-meaning
check of contract FSC-nn is TB FSC-a, FSC-b"), with TB numbers printed as the new
TB-local name SCHT-n. RTL anchors are only given where the scheduler RTL carries a
matching `@satisfies` tag at the base revision; otherwise "无映射". The other renamed
labels (SUP, DCR, SSW-18, AMI-13, LFA-11a) are fixed text below.
"""
import re
import sys

TAGGED = {  # contract FSC id -> scheduler RTL symbol anchor carrying @satisfies
    'FSC-03': '`ppg_400hz_frame_calibration_scheduler.v` `flag_frame_restart`、`@satisfies: FSC-03`',
    'FSC-17': '`ppg_400hz_frame_calibration_scheduler.v` `@satisfies: FSC-17`',
    'FSC-31': '`ppg_400hz_frame_calibration_scheduler.v` `flag_calibration_rollover`、`@satisfies: FSC-31, FSC-32`',
    'FSC-32': '`ppg_400hz_frame_calibration_scheduler.v` `flag_calibration_rollover`、`@satisfies: FSC-31, FSC-32`',
    'FSC-46': '`ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50`',
    'FSC-49': '`ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50`',
    'FSC-50': '`ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50`',
}
EXTRA_TB = {  # later local checks that also serve a contract row
    'FSC-03': 'FRAME-NN/FRAME-NC/FRAME-CN/FRAME-NC-LAST',
    'FSC-17': 'L1-NOREPEND',
    'FSC-19': 'L3-IDLEBND',
    'FSC-31': 'CAL-ROLLOVER-STOP',
    'FSC-32': 'CAL-ROLLOVER-ABORT',
    'FSC-38': 'L3-NOEXTRA',
    'FSC-46': 'L4-EXPIRE/L4-ONTIME',
    'FSC-49': 'L4-EXPIRE',
    'FSC-54': 'LOST-REL/LOST-MISM',
}
SYSTEM = {  # system-level evidence state, ID_GOVERNANCE_AUDIT_FOLLOWUP section 2 (FSC-35 per SSW18 report section 5)
    'FSC-18': '部分', 'FSC-19': '无', 'FSC-20': '已有', 'FSC-21': '已有', 'FSC-23': '无', 'FSC-24': '无',
    'FSC-27': '无', 'FSC-34': '部分', 'FSC-35': '部分', 'FSC-43': '已有', 'FSC-44': '无', 'FSC-47': '已有',
    'FSC-48': '部分', 'FSC-53': '部分', 'FSC-57': '部分',
}


def main():
    src, out = sys.argv[1], sys.argv[2]
    rows = []
    for line in open(src, encoding='utf-8'):
        m = re.match(r'^\| FSC \| (FSC-\d\d) \| ([^|]*) \|[^|]*\|[^|]*\| (\w) \| (.*) \|$', line.rstrip('\n'))
        if not m:
            continue
        cid, title, verdict, note = m.groups()
        if int(cid[4:]) > 57:
            continue
        same = re.search(r'合同%s的同义检查在TB的([^；;]+)' % cid, note)
        if cid == 'FSC-01':
            tb = 'SCHT-1（部分：复位后无在途、frame/sample为0、无协议sticky；缺完成事件与其他sticky清零）'
        elif same:
            nums = re.findall(r'FSC-(\d+)', same.group(1))
            tb = '、'.join('SCHT-%d' % int(n) for n in nums)
        else:
            tb = '无（单元TB无同义检查）'
        if cid in EXTRA_TB:
            tb += '；另有TB本地%s' % EXTRA_TB[cid]
        if cid in SYSTEM:
            tb += '；系统级证据：%s' % SYSTEM[cid]
        rows.append('| %s | `tb_ppg_400hz_frame_calibration_scheduler.v` %s | %s | C08 §18 %s行；ID治理§5.2；B合并批次7a8eabf重扫 |'
                    % (cid, tb, TAGGED.get(cid, '无映射（RTL无该ID的`@satisfies`标签）'), cid))
    head = ['### 调度器单元TB：合同FSC-nn ↔ TB本地SCHT-n（TB标签改名后生效，BMI-133/140）', '',
            '> 调度器单元TB原以`check_fsc(n, …)`打印`FSC-n`，n只是TB内场景序号，与C08同号条目含义不同（ID治理§6.1）。改名后打印`SCHT-n`，`check_fsc`实参不变（交接书Q3）。下表按合同条目列出真正检查其含义的TB检查。TB SCHT-14＝合同FSC-03（F-011已收紧为严格5000），TB SCHT-32＝合同FSC-30。TB SCHT-58/59语义属FSC-17，SCHT-60/61/62语义属FSC-50（V1.12补充），按用户决定不在C08登记FSC-58~62。', '',
            '| 验收ID | 对应TB场景名 | 对应RTL标签位置 | 出处 |', '| --- | --- | --- | --- |']
    tail = ['', '### 其余随改名生效的映射（BMI-141~144、103）', '',
            '| 验收ID | 对应TB场景名 | 对应RTL标签位置 | 出处 |', '| --- | --- | --- | --- |',
            '| SUP-03 | 无（原子标签SUP03A测的是episode开启期间诊断清除无效，改名为TB本地CLRBLK，属SUP-07前半） | 无映射 | C24 §7；ID治理§6.2 |',
            '| SUP-06 | `tb_ppg_system_fault_abort_supervisor.v` SUP06B、SUP06C（看门狗边界）；WDIDLE（原SUP09A：阈值前idle不超时） | `ppg_system_fault_abort_supervisor.v` `@satisfies: P05` | C24 §6；ID治理§6.2 |',
            '| SUP-07 | `tb_ppg_system_fault_abort_supervisor.v` SUP07A；CLRBLK（原SUP03A）；EPICLS（原SUP06A：episode关闭后阻断解除） | 无映射 | C24 §5、§7 |',
            '| SUP-09 | 无（原SUP09A改名为WDIDLE，属SUP-06） | 无映射 | C24 §7；ID治理§6.2 |',
            '| SUP-10 | 无（该条归C10 AMI-53；原SUP10A测第二个独立episode完整trio，改名为TB本地EPI2ND） | 无映射 | C24 §7（V1.6注明归属）；ID治理§6.2 |',
            '| （TB本地）EPI2ND、RE-ARM | `tb_ppg_system_fault_abort_supervisor.v` 同名 | 无映射 | C24 §4（episode重开） |',
            '| DCR-04 | `tb_ppg_adc_dc_recovery.v` DCRT-3向量（9-bit且DC码0时DC项为0） | 无映射 | C15 DCR-04行；ID治理§6.3 |',
            '| DCR-07、DCR-11 | `tb_ppg_adc_dc_recovery.v` DCRT-4向量（15-bit双结果+K_DC15） | 无映射 | C15；ID治理§6.3 |',
            '| DCR-12 | `tb_ppg_adc_dc_recovery.v` DCRT-5向量与"FAIL DCR-12 qualification"检查 | 无映射 | C15；ID治理§6.3 |',
            '| DCR-09 | `tb_ppg_adc_dc_recovery.v` DCRT-6、DCRT-7向量与"FAIL DCR-09 saturation endpoints"检查 | 无映射 | C15；ID治理§6.3 |',
            '| DCR-03、DCR-06 | 无（证据缺口） | 无映射 | ID治理§10 |',
            '| SSW-18 | `tb_ppg_sar9_sar15_safe_selection_wrapper.v` S1-LATE、S1-ONTM（原SSW-18场景测校准owner截止，已改名为TB本地CAL-ODL） | `ppg_sar9_sar15_safe_selection_wrapper.v` `calibration_timeout_sticky_o`（`@satisfies`在阶段4补） | C09 §5.4、§7.8、SSW-18行（V1.11改写） |',
            '| （TB本地）CAL-ODL | `tb_ppg_sar9_sar15_safe_selection_wrapper.v` CAL-ODL | 无映射 | C09 §4.5、SSW-37/SSW-38 |',
            '| AMI-13 | 无（单元TB原同号检查测的是反压保持，已改名为TB本地FORK-HOLD，属AMI-12） | `ppg_adc_measurement_idac_integration.v` `flag_result_fork_all_released`（RTL结构，无动态证据） | C10 §17 AMI-13行（V2.5注明） |',
            '| （TB本地）FORK-HOLD | `tb_ppg_adc_measurement_idac_integration.v` FORK-HOLD | 无映射 | C10 §17 AMI-12 |',
            '| LFA-11 | `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` LFA-11b（后半句）；前半句无断言 | 无映射 | C25 LFA-11行；ID治理§6.5 |',
            '| （TB本地）AUTOABT-QUIET | `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` AUTOABT-QUIET（原LFA-11a；informational分支仍打印PASS，按交接书Q6只登记） | 无映射 | 矩阵P03行；ID治理§6.5 |']
    open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(head + rows + tail) + '\n')
    print('fsc rows', len(rows))


if __name__ == '__main__':
    main()
