# -*- coding: utf-8 -*-
"""Round 4 of the anchor conversion: hand decisions on every low-confidence anchor and the
same-class audits (coordinator review of 66bebdf, 2026-10-10).

Usage:
    python anchor_round4.py --table anchor_mapping_table_round2.tsv --round3 r3_list.json
                            --out anchor_round4_decisions.tsv [--report r4_list.json] [--repo DIR]

The coordinator's ruling: "keep the resolver's symbol" is no longer allowed for a
low-confidence anchor. Each of the 56 is decided one of three ways:
  * corrected to the right symbol (or a quoted-text anchor `"..."` when the cited lines are a
    comment block, or the row's `@satisfies` tag when the cell says the line carries it);
  * restored verbatim and classed history / not-anchor;
  * written in the pinned-version form "`file.v:N`（`<sha>`版，未能定位符号）" when the cited
    content cannot be identified; no symbol is given.
Anchors into ppg_dual_precision_top.v (low-confidence #1, binding row 3387) are left as they
are: the coordinator moves them to legacy/ with the orphaned module (repair brief section 1.11).
Binding anchors name the instance plus the bound parameters the row writes (part 3(1)(a)).
A kept symbol ('keep') is one verified by hand against the cited version (reason given).

Same-class audits handled here as well:
  BIND   the 18 rows of the G-FP-05 parameter-propagation ledger (matrix 3367-3370,
         3374-3387 at the baseline): "binding" names the child instance, "target
         declarations (bound N)" the N bound parameters written in the row's parameter cell,
         "own-default M" the child's remaining declared parameters (counts checked against N, M);
  BARE   bare `:N` anchors whose file the resolver took from a module word matched inside a
         signal name (`wrapper_coef_epoch_o` -> "wrapper" -> V4 wrapper): 14 anchors moved to
         the file the row means.

Output: decisions TSV (doc, line, old, action, arg1, arg2, reason) read by anchor_mapping.py
after anchor_round3_decisions.tsv. Actions: sym, text (literal new text), history,
not-anchor, keep (the earlier result stands; reason recorded).
"""
import argparse
import csv
import json
import os
import re
import subprocess
import sys

M, A = 'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'
_R = '第四轮（统筹10-10对66bebdf核对意见：低置信逐条判定）：'
DUAL = ('本批不改：引用ppg_dual_precision_top.v的锚点按统筹10-10意见随P1孤立模块归档移入legacy/再处理（修复轮任务书§1.11）'
        '（人工核对：导入版本336-343行为ppg_config_cdc_bridge_Inst_control例化）')
_B = '第四轮（参数绑定台账同类扩查）：'
_F = '第四轮（裸行号文件归属同类扩查）：'
TOP, AMI, SUP = 'ppg_control_top.v', 'ppg_adc_measurement_idac_integration.v', 'ppg_system_fault_abort_supervisor.v'
SSW, MGR, PWI = 'ppg_sar9_sar15_safe_selection_wrapper.v', 'ppg_system_config_manager.v', 'ppg_precision_window_integration.v'
IDAC, CDC = 'ppg_idac_code_controller.v', 'ppg_characterization_control_cdc.v'


def unloc(f, nums, rev):
    # pinned-version form required by the coordinator (review of 66bebdf, part 3(1)(c))
    return '`%s:%s`（`%s`版，未能定位符号）' % (f, nums, rev)


def label(f, text):
    return '`%s` `"%s"`' % (f, text)


# (doc, baseline line, old) -> (action, arg1, arg2, reason). sym: arg1 file, arg2 comma list.
LOWCONF = {
    (M, 837, 'ppg_dual_precision_top.v:336-343'): ('keep', '', '', DUAL),
    (M, 895, 'ppg_chip_digital_top.v:284,373'): ('keep', '', '',
        '保留（人工核对）：导入版本284行`assign w_source_rstn = w_rstn`（源域复位借用系统复位）、373行`ppg_reset_sync_clk2m_Inst`，即格内“reset-borrow special case”'),
    (M, 924, 'ppg_adc_measurement_idac_integration.v:967'): ('sym', AMI, 'flag_detection_discard_trigger',
        'P02“unconditional broadcast”：导入版本967行为fault dispatch 03（无关），970行`flag_detection_discard_trigger`为detection-discard无条件广播（驱动o_detection_discard_event），行号漂移3行'),
    (M, 924, '`:522`'): ('keep', '', '',
        '保留（人工核对）：导入版本PWI 522行`detection_datapath_empty_o <=`，即格内“next-cycle empty”'),
    (M, 926, 'ppg_system_fault_abort_supervisor.v:201-230,296-405'): ('keep', '', '',
        '保留（人工核对）：导入版本201-215行首故障捕获仲裁flag_capture_*、296-405行首故障原子快照寄存器，即格内“atomic first-fault snapshot latch”'),
    (M, 931, 'ppg_system_fault_abort_supervisor.v:170,174-183,184,185,419-428'): ('keep', '', '',
        '保留（人工核对）：写入时版本bb39a0f 170、174-176行为system_fault_blocking_o/cause_valid_o/cause_o/source_o寄存器'),
    (M, 932, 'ppg_system_fault_abort_supervisor.v:129-133,217-230'): ('sym', SUP, 'SOURCE_AMI,SOURCE_SCHEDULER,SOURCE_SSW,SOURCE_SUPERVISOR,CAUSE_WATCHDOG_TIMEOUT,flag_new_summary_bits',
        '导入版本129-133行为SOURCE_*四个来源码与CAUSE_WATCHDOG_TIMEOUT(8\'h31)，217-230行为flag_new_summary_bits（历史位图），对应格内“blocking-class causes (8\'h01, 8\'h31 watchdog) and the non-blocking discard class”；原解析只取了前4个'),
    (M, 934, 'ppg_control_top.v:295-299'): ('text', label(TOP, '参数化位宽约束（架构不变量，非运行时检查）'), '',
        '导入版本295-299行是纯注释块（参数化位宽约束，架构不变量，非运行时检查），无符号可取；改为注释原文锚点'),
    (M, 936, 'ppg_adc_measurement_idac_integration.v:1223,1620,913'): ('sym', AMI, 'flag_adc_completion_abort_release,flag_adc_transaction_inflight,adc_complete_sample_index_o',
        'P14“exactly-once original-ID success=0 release”：导入版本913行flag_adc_completion_abort_release、1620-1621行flag_adc_transaction_inflight置位、1219-1223行adc_complete_*完成身份寄存器；原解析只取了913'),
    (M, 937, 'ppg_control_top.v:1378-1439'): ('sym', TOP, 'ppg_system_fault_abort_supervisor_Inst',
        '格内“C24 supervisor instantiation”：1378-1439为supervisor例化端口表，取例化名'),
    (M, 942, 'ppg_system_fault_abort_supervisor.v:201-205,184'): ('keep', '', '',
        '保留（人工核对）：导入版本201-205行首故障捕获仲裁（看门狗>AMI>Scheduler>SSW），即格内“priority AMI>Scheduler>SSW determines snapshot source”'),
    (M, 945, 'ppg_system_fault_abort_supervisor.v:198'): ('keep', '', '',
        '保留（人工核对）：导入版本198行`flag_episode_open_edge`，即格内“open/close/rearm design”'),
    (M, 1394, 'ppg_system_config_manager.v:370-376'): ('keep', '', '',
        '保留（人工核对）：写入时版本d18c695 372、375行为flag_snapshot_static_bias_valid/flag_start_static_bias_valid，即格内“manager只用使能位做组合校验”'),
    (M, 1596, '`:247`'): ('history', '', '', '格内“Anchor corrected from stale `:247` (unrelated §4 prose)”：记录的是已被弃用的旧锚点，按历史保留原文'),
    (M, 2468, 'ppg_dynamic_baseline_cross_detector.v:550'): ('keep', '', '',
        '保留（人工核对）：写入时版本bb39a0f 550行`assign o_cross_valid`；PWI以`.o_cross_valid(cross_pending_o)`接出，格内写明cross_pending_o'),
    (M, 2469, 'ppg_peak_valley_window_detector.v:446'): ('keep', '', '', '保留（人工核对）：bb39a0f 446行`assign o_peak_valid`；PWI `.o_peak_valid(peak_pending_o)`'),
    (M, 2470, 'ppg_peak_valley_window_detector.v:455'): ('keep', '', '', '保留（人工核对）：bb39a0f 455行`assign o_valley_valid`；PWI `.o_valley_valid(valley_pending_o)`'),
    (M, 2471, 'ppg_peak_valley_window_detector.v:441'): ('keep', '', '', '保留（人工核对）：bb39a0f 441行`assign o_return_9bit_valid`；PWI `.o_return_9bit_valid(return_pending_o)`'),
    (M, 2736, '`:1985`'): ('keep', '', '', '保留（人工核对）：格内“ppg_normal_transaction_fork\'s own instantiation (`:1985`, …)”，取例化名ppg_normal_transaction_fork_Inst'),
    (M, 3125, 'ppg_adc_async_stage_capture.v:59'): ('keep', '', '',
        '保留（人工核对）：bb39a0f 59行`input i_adc_transaction_start`；AMI以`.i_adc_transaction_start(o_transaction_start_fire)`连接本行端口'),
    (M, 3125, 'ppg_adc_s1_redundancy_corrector.v:62'): ('keep', '', '',
        '保留（人工核对）：bb39a0f 62行`input i_adc_transaction_start`；AMI以`.i_adc_transaction_start(o_transaction_start_fire)`连接本行端口'),
    (M, 3223, 'ppg_control_top.v:338,344-350'): ('sym', TOP, 'flag_owner_abort_event,flag_abort_drain_stop_request,flag_stop_request_event',
        '格内“abort merges into STOP upstream”：导入版本344-347行为abort→STOP合并寄存器flag_owner_abort_event/flag_abort_drain_stop_request/flag_stop_request_event；338行为flag_status_clear_event（无关，去掉）'),
    (M, 3226, '`:384`'): ('sym', TOP, 'flag_test_inject_mode_latched',
        '裸行号属本行第1格的`ppg_control_top.v`（Top自身逻辑）；解析器因`wrapper_run_enable_o`中的“wrapper”误归V4 wrapper。所指为test-inject锁存寄存器的采样分支'),
    (M, 3226, '`:381-382`'): ('sym', TOP, 'flag_test_inject_mode_latched',
        '同上；所指为该锁存寄存器的abort/STOP清除分支（解析器因`wrapper_stop_ack_event_o`误归V4 wrapper）'),
    (M, 3352, 'ppg_control_top.v:288-292'): ('text', label(TOP, '综合RTL禁止使用initial块做运行时elaboration检查'), '',
        '格内引述的注释原文“综合RTL禁止使用initial块做运行时elaboration检查”即所指内容（纯注释，无符号）；导入版本288-292行已漂移为端口声明'),
    (M, 3409, 'ppg_adc_measurement_idac_integration.v:1168-1175'): ('sym', AMI, 'integration_protocol_error_sticky_o',
        '格内写明“AMI\'s own `integration_protocol_error_sticky_o` gives clear unconditional top priority”：1168-1175为该sticky的复位/清除/置位优先级链'),
    (M, 3456, 'wrapper.v:480'): ('keep', '', '',
        '保留（人工核对）：SSW `o_analog_safe = !(flag_red_wave_active || flag_ir_wave_active || calibration_wave_active_o)`，即格内“no RED/IR/calibration waveform”'),
    (M, 3585, 'ppg_sar9_sar15_safe_selection_wrapper.v:25,48,480'): ('text', '`%s` `o_analog_safe`；%s' % (SSW, unloc(SSW, '25,48', 'b858bf0')), '',
        '480行同3456行为o_analog_safe；25、48行在导入版本是文件头修订记录，写入时（09-05）版本不在仓库，所指内容无法确定，如实记为未能定位'),
    (A, 28, 'ppg_system_config_manager.v:556,519-520'): ('keep', '', '',
        '保留（人工核对）：写入时版本d18c695 519-520行active_config_o复位、556行active_valid_o复位，即格内“清空ACTIVE”'),
    (A, 38, 'ppg_control_top.v:945'): ('sym', TOP, 'o_startup_idac_safe_boundary',
        'TOP-11标签在调度器`o_startup_idac_safe_boundary`上，格内“该端口对Top边界留空未连”指该端口；Top中`.o_startup_idac_safe_boundary()`留空（原解析o_macro_frame_start_event，行号漂移）'),
    (A, 45, 'ppg_system_config_manager.v:394-448'): ('sym', MGR, 'flag_snapshot_valid',
        '格内“静态检查侧”：394-448为快照静态检查块（各flag_snapshot_*，止于汇总flag_snapshot_valid），取汇总；原解析只取了末行的flag_snapshot_dc_qualification_valid'),
    (A, 108, 'ppg_adc_measurement_idac_integration.v:1605'): ('keep', '', '',
        '保留（人工核对）：“AMI物理ADC owner代表行”即AMI的owner在途寄存器flag_adc_transaction_inflight（导入版本1605行为其上方注释，1619-1621行为该寄存器）'),
    (A, 112, 'ppg_idac_code_controller.v:170-172,580'): ('text', unloc(IDAC, '170-172,580', 'b858bf0'), '',
        'G-FP-03（IDAC fault 8\'h05 + V2.3死锁修复）：导入版本170-172行为dcs更新输出、580行为flag_control_cancel，与fault 8\'h05对应不上；写入时版本早于导入、不在仓库，如实记为未能定位'),
    (A, 115, 'ppg_adc_measurement_idac_integration.v:2446-2461'): ('sym', AMI, 'ppg_precision_window_integration_Inst',
        '格内“AMI→PWI 15/18参数绑定”：2446-2461为PWI例化的参数绑定块，取例化名（同矩阵参数绑定台账的写法）'),
    (A, 159, 'ppg_control_top.v:355'): ('text', '`%s` `flag_owner_abort_event`、`@satisfies: G-FP-01`' % TOP, '',
        '格内“supervisor自己的自动abort(…:355已有@satisfies: G-FP-01)”：该标签在Top `flag_owner_abort_event <= i_control_abort_event || supervisor_system_abort_event_o`行，加标签锚点'),
    (A, 192, 'ppg_idac_code_controller.v:285'): ('history', '', '', '格内“——**不是**`ppg_idac_code_controller.v:285`”：记录的是被否定的旧假设位置，按历史保留原文'),
    (A, 241, 'ppg_characterization_control_cdc.v:118'): ('text', '`%s` `o_test_mux_ctrl`、`@satisfies: ILM-14`' % CDC, '',
        '保留符号o_test_mux_ctrl（ILM-14“2MHz目标域CDC桥S[4:0]”），该行带ILM-14标签，加标签锚点'),
    (A, 302, ':119'): ('not-anchor', '', '', '“**RTL标签**:119个ID”是计数，不是锚点，恢复原文'),
    (A, 302, '`:465`'): ('history', '', '', '“FIR仍有3个本次之前就存在的VG052/VG061区域归属error(`:312`/`:465`,来自2026-08-31…)”：记录当时门禁报错位置，按历史保留原文（`:312`同样未转换）'),
    (A, 458, 'ppg_precision_window_integration.v:443'): ('text', '`%s` `flag_detection_discard_apply`、`@satisfies: K04`' % PWI, '',
        '格内“同K04锚点…(已打K04标签)”：PWI `flag_detection_discard_apply`行带K04标签，加标签锚点'),
    (A, 464, 'ppg_control_top.v:350-357,368-375'): ('keep', '', '',
        '保留（人工核对）：导入版本350行supervisor_system_stop_request_event_o、345-347行abort合并寄存器、368-375行flag_stop_request_event合并，即格内“Top合并(静态wiring)”'),
    (A, 472, 'ppg_control_top.v:295-299'): ('text', label(TOP, '参数化位宽约束（架构不变量，非运行时检查）'), '', '同矩阵934行：纯注释块，改为注释原文锚点'),
    (A, 481, 'ppg_adc_measurement_idac_integration.v:905,1009-1010,2356,2611'): ('text', '`%s` `@satisfies: TOP-21, TOP-23, TOP-24`' % AMI, '',
        '格内“AMI半…未单独打标签,复用既有TOP-21/23/24标签”：按格内所写取这三个标签；原解析的3个符号与本行无关'),
    (A, 568, 'ppg_control_top.v:295-299'): ('text', label(TOP, '参数化位宽约束（架构不变量，非运行时检查）'), '', '格内“真去…295-299读了原文,确认是纯中文注释块”：改为注释原文锚点'),
}
EXTRA = {
    (M, 3226, '`:380`'): ('sym', TOP, 'flag_test_inject_mode_latched', _F + '同3226行`:384`：裸行号属Top，所指为该锁存寄存器的复位分支（原误归V4 wrapper的i_rstn）'),
    (M, 3402, '`:313,324-330`'): ('sym', TOP, 'flag_status_clear_event',
        _F + '格内“`flag_status_clear_event` (independent register, `:313,324-330`)”：所指为该独立寄存器（原解析flag_system_fault_blocking/flag_diag_clear_event为相邻寄存器，行号漂移）'),
    (A, 112, '`:26`'): ('text', label(IDAC, 'Fix a real cross-module deadlock'), '', '“header注记`:26`”为文件头V2.3修订记录行，改为该行原文锚点'),
    (A, 241, 'ppg_system_config_manager.v:369-371'): ('sym', MGR, 'flag_snapshot_char_current_optical_valid',
        '格内“OFF拒绝锚点(…:369-371,新)”：导入版本369-371行为flag_snapshot_char_current_optical_valid（禁止optical_mode=2\'b11全关闭）；原解析flag_snapshot_char_idac_valid为364行'),
    (M, 2682, 'ppg_adc_measurement_idac_integration.v:1858'): ('sym', AMI, 'ppg_adc_s1_programmable_calibrator_Inst,i_result_valid',
        '例化端口连接扩查：格内“`o_detect_valid` -> calibrator `i_result_valid` binding, `…:1858`”：所指为AMI中calibrator例化的`.i_result_valid(`连接（该端口名在AMI中4个例化重复出现，加例化名）；原解析i_run_generation/o_local_empty为漂移所得，o_local_empty落在fork/overlap例化上'),
    (M, 3245, 'ppg_adc_measurement_idac_integration.v:851,854,1113,1116,2593,2596'): ('sym', AMI, 'baseline_protocol_error_sticky_o,peak_valley_protocol_error_sticky_o',
        '例化端口连接扩查：本行讨论C20/C22（基线检测器、峰谷检测器）的protocol-error sticky，格内“both wires are wire-declared and directly passed through to AMI\'s own top-level ports”：'
        '即AMI中的两条wire baseline_protocol_error_sticky_o、peak_valley_protocol_error_sticky_o（经assign送o_baseline_/o_peak_valley_protocol_error_sticky）；原解析o_protocol_error_sticky落在IDAC控制器例化的连接上，模块不对'),
    (A, 297, 'ppg_adc_measurement_idac_integration.v:416-418'): ('sym', AMI, 'DISCARD_REASON_STOP,DISCARD_REASON_ABORT,DISCARD_REASON_SYSTEM_FAULT',
        '例化端口连接扩查：格内“discard广播(`DISCARD_STOP`/`DISCARD_ABORT`/`DISCARD_SYSTEM_FAULT`,常量取自`…:416-418`)”：所指为AMI的三个discard原因常量DISCARD_REASON_*；原解析i_run_generation/o_local_empty落在fork/overlap例化的端口连接上，与本行无关'),
    (A, 241, '`:522`'): ('sym', MGR, 'active_config_o', '格内“已有的`:522` active_config_o原子保持”：按格内写明的active_config_o（原解析flag_snapshot_char_idac_valid，文件内无关）'),
}
for n, old, s in [(1624, '`:1501`', 'o_coef_epoch'), (1625, '`:1500`', 'o_config_epoch'), (1626, '`:1503`', 'o_dc_recovery_coef_epoch'),
                  (1629, '`:1502`', 'o_stage2_coef_epoch'), (1634, '`:1492`', 'o_commit_ack_event'), (1635, '`:1496`', 'o_commit_ack_sticky'),
                  (1636, '`:1495`', 'o_error_event'), (1637, '`:1497`', 'o_error_sticky'), (1638, '`:1498`', 'o_last_error_code'),
                  (1641, '`:1499`', 'o_schema_version')]:
    EXTRA[(M, n, old)] = ('sym', TOP, s, _F + '格内“Consumer: `ppg_control_top.v:N` (`wrapper_x_o`), exposed at `%s`”：exposed指Top边界输出`assign %s = wrapper_…`；解析器因`wrapper_…_o`中的“wrapper”误归V4 wrapper' % (old.strip('`'), s))

# TRIM: range anchors whose resolver list (capped at 4 names) holds names the row does not
# state (anchor_check rule 1d, per identifier). Each was read against the row: kept as the
# stated subset, corrected, or kept in full when the row describes the dropped names (then a
# reviewed exception, see anchor_semantic_exceptions.json).
_T = '第四轮（范围锚点逐条核对，规则1d）：'
TRIM = {
    (A, 67, 'ppg_precision_window_controller.v:269,672-684'): ('sym', 'ppg_precision_window_controller.v', 'flag_lifecycle_cancel', '保留本行述及的flag_lifecycle_cancel，去掉未述及的flag_fault_hold'),
    (A, 111, 'ppg_precision_window_integration.v:960-961'): ('sym', PWI, 'o_mode_fault_active', '保留本行述及的o_mode_fault_active'),
    (A, 111, 'ppg_adc_measurement_idac_integration.v:2576-2583'): ('sym', AMI, 'o_mode_fault_active', '保留本行述及的o_mode_fault_active'),
    (M, 927, 'ppg_system_fault_abort_supervisor.v:54-55,136,190-192,433-441'): ('sym', SUP, 'C_ADC_DRAIN_WATCHDOG_CYCLES', '格内写明`C_ADC_DRAIN_WATCHDOG_CYCLES=5000`，只保留该参数'),
    (M, 930, 'ppg_adc_measurement_idac_integration.v:434-462,1602-1620,913'): ('sym', AMI, 'reg_adc_inflight_sample_index,flag_adc_transaction_inflight',
        '格内“the same `reg_adc_inflight_*`/`flag_adc_transaction_inflight` owner-binding mechanism”：取这两项，去掉未述及的reg_held_start_*'),
    (M, 933, 'ppg_control_top.v:128-133'): ('sym', TOP, 'i_test_identity_inject_valid,i_test_invalid_sample_valid,i_test_saturation_inject_valid,i_test_calibration_loss_inject_valid,i_test_inject_enable',
        '格内“declares the four held-valid one-shot test-control inputs, all gated by `i_test_inject_enable`”：四个保持型one-shot输入为identity/invalid-sample/saturation/calibration-loss（原解析含i_test_identity_inject_sample_index，那是数据不是one-shot请求，且缺calibration-loss）'),
    (M, 1585, '`:370-377`'): ('keep', '', '', '格内“used in STATIC_BIAS combination checks at `:370-377`”：所指即flag_snapshot_static_bias_valid/flag_start_static_bias_valid两个组合检查，保留全部'),
    (M, 2174, '`:182,208,210`'): ('keep', '', '', '本行端口i_dcs_sample_color_ir在调度器中的使用处：`o_calibration_color_ir`由其选出（208/210行），保留'),
    (M, 2182, '`:1359-1377`'): ('history', '', '', '格内“旧范围若按+15换算得`:1359-1377`…都不是块边界，故此处不能靠加偏移量”：这是被否定的换算范围，按历史保留原文'),
    (M, 2182, '`:1374-1384`'): ('sym', AMI, 'calibration_color_ir_o', '格内“颜色`:1374-1384`”：颜色载荷锁存块即calibration_color_ir_o'),
    (M, 2182, '`:1387-1397`'): ('sym', AMI, 'calibration_frame_type_o', '格内“帧类型`:1387-1397`”：即calibration_frame_type_o'),
    (M, 2182, '`:1400-1410`'): ('sym', AMI, 'calibration_request_reason_o', '格内“请求原因`:1400-1410`”：即calibration_request_reason_o'),
    (M, 2523, '`:990,952`'): ('sym', PWI, 'amb_recheck_busy_o', '格内写明amb_recheck_busy_o，只保留该名'),
    (M, 3226, 'ppg_control_top.v:373,377-386'): ('sym', TOP, 'flag_test_inject_mode_latched,wrapper_run_enable_o,wrapper_stop_ack_event_o', '保留本行述及的三项，去掉flag_stop_request_event（导入版本373行，与本行test-inject锁存无关）'),
    (M, 3228, 'ppg_sar9_sar15_safe_selection_wrapper.v:304-305,1089-1097,1274-1282'): ('sym', SSW, 'flag_red_context_valid,flag_ir_context_valid,i_control_abort_event', '保留本行述及的三项'),
    (M, 3229, 'ppg_peak_valley_window_detector.v:353-357,391,475-487'): ('sym', 'ppg_peak_valley_window_detector.v', 'peak_valid_o,flag_peak_accept_event', '保留本行述及的两项'),
    (M, 3231, 'ppg_coarse_detection_fir.v:310,322,325,437-459'): ('sym', 'ppg_coarse_detection_fir.v', 'result_valid_o,flag_commit_event,flag_recheck_clear', '保留本行述及的三项'),
    (M, 3232, 'ppg_adc_measurement_idac_integration.v:1602-1610,1493-1499'): ('sym', AMI, 'flag_adc_completion_emit,reg_adc_inflight_sample_index,o_transaction_start_fire', '保留本行述及的三项'),
    (M, 3238, '`:1421-1430`'): ('sym', AMI, 'flag_ami_fault_pending_02',
        '格内“Lane `8\'h02` (`:1421-1430`)”：lane 02为flag_ami_fault_pending_02（导入版本1441行置位；原解析为lane 01的寄存器，行号漂移约11行）'),
    (M, 3238, '`:1432-1440`'): ('sym', AMI, 'flag_ami_fault_pending_03', '格内“Lane `8\'h03` (`:1432-1440`)”：lane 03为flag_ami_fault_pending_03（原解析为lane 01/02，漂移）'),
    (M, 3242, 'ppg_control_top.v:1068-1069'): ('sym', TOP, 'o_ssw_fault_valid,o_ssw_fault_cause',
        '格内“Forwarded to Top at `:1068-1069` -> supervisor”：Top中SSW例化的`.o_ssw_fault_valid(`/`.o_ssw_fault_cause(`（导入版本1068-1069已漂移为o_s_in/o_clk_2m连接）'),
    (M, 3244, '`:635-638`'): ('sym', IDAC, 'o_controller_fault_blocking', '格内“never promoted into `o_controller_fault_blocking`…confirmed by reading `:635-638`”：只保留该名'),
    (M, 3366, 'ppg_control_top.v:288-292'): ('text', label(TOP, '综合RTL禁止使用initial块做运行时elaboration检查'), '', '格内“(documented-only invariants)”：同3352行，为注释块，改为注释原文锚点'),
    (M, 3371, 'ppg_system_fault_abort_supervisor.v:44-55'): ('sym', SUP, 'C_FRAME_ID_WIDTH,C_SAMPLE_INDEX_WIDTH,C_CONFIG_EPOCH_WIDTH,C_COEF_EPOCH_WIDTH,C_DC_RECOVERY_EPOCH_WIDTH,C_CODE_EPOCH_WIDTH,C_RUN_GENERATION_WIDTH,C_FAULT_CAUSE_WIDTH,C_FAULT_SOURCE_WIDTH,C_FAULT_SUMMARY_WIDTH,C_ADC_DRAIN_WATCHDOG_CYCLES,C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH',
        '格内“12 declared…(full declaration block)”：列出全部12个参数（原解析只取4个）'),
    (M, 3401, 'ppg_config_cdc_bridge.v:163-179'): ('keep', '', '', '格内“source->dest request sync”：flag_request_sync_meta/flag_request_sync即该双触发器同步器，保留全部'),
    (M, 3401, '`:145-161`'): ('keep', '', '', '格内“dest->source ack sync”：flag_ack_sync_meta/flag_ack_sync即该同步器，保留全部'),
    (M, 3402, 'ppg_system_config_manager.v:657-659,671-673,685-687'): ('keep', '', '', '格内“only clears `commit_ack_sticky`/`error_sticky` (W1C, …)”：所指三个sticky寄存器，保留'),
    (M, 3403, 'ppg_precision_window_integration.v:980-987'): ('sym', PWI, 'ppg_amb_recheck_scheduler_Inst,flag_detection_discard_apply', '保留本行述及的两项'),
    (M, 3404, 'ppg_idac_code_controller.v:26,580,1123-1124'): ('sym', IDAC, 'flag_control_cancel', '保留本行述及的flag_control_cancel'),
    (M, 3405, 'ppg_peak_valley_window_detector.v:346-347,478-481'): ('sym', 'ppg_peak_valley_window_detector.v', 'flag_runtime_clear,flag_context_clear', '保留本行述及的两项'),
    (M, 3242, 'ppg_sar9_sar15_safe_selection_wrapper.v:440'): ('keep', '', '', '格内写明`ssw_fault_cause_o = flag_blocking_fault ? 8\'h21 : 8\'h00`（W11），解析一致'),
}

BIND_ROWS =[3367, 3368, 3369, 3370] + list(range(3374, 3388))


def git(repo, *args):
    return subprocess.run(['git', '-C', repo] + list(args), capture_output=True).stdout.decode('utf-8', 'replace')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--table', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--report')
    ap.add_argument('--repo', default='.')
    ap.add_argument('--base', default='7a8eabf')
    a = ap.parse_args()
    rows = list(csv.DictReader(open(a.table, encoding='utf-8'), delimiter='\t'))
    doc = git(a.repo, 'show', '%s:contracts/%s' % (a.base, M)).split('\n')
    rtl = {os.path.basename(p): p for p in git(a.repo, 'ls-files', 'rtl').split('\n') if p.endswith('.v')}
    src = lambda f: open(os.path.join(a.repo, rtl[f]), encoding='utf-8').read()

    def params(f):
        # parameters declared in the module header #( ... ) of f, in order
        code = '\n'.join(l.split('//')[0] for l in src(f).split('\n'))
        m = re.search(r'^\s*module\s+%s\s*#\s*\((.*?)\)\s*\(' % re.escape(f[:-2]), code, re.S | re.M)
        return re.findall(r'parameter\b[^=,]*?\b([A-Z][A-Z0-9_]*)\s*=', m.group(1)) if m else []

    def instance(parent, module):
        lines = src(parent).split('\n')
        for i, l in enumerate(lines):
            if re.match(r'^\s*%s\b' % re.escape(module), l):
                for k in range(i, min(i + 40, len(lines))):
                    m = re.match(r'^\s*\)?\s*(?:%s\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\($' % re.escape(module), lines[k].split('//')[0].rstrip())
                    if m and m.group(1) != module:
                        return m.group(1)
        raise SystemExit('no instance of %s in %s' % (module, parent))

    out, listing, stale = [], [], []

    def emit(key, act, a1, a2, why, cat):
        out.append([key[0], key[1], key[2], act, a1, a2, why])
        listing.append([cat, key[0], key[1], key[2], act, a1, a2, why])

    table = {(r['doc'], int(r['line']), r['old']): r for r in rows}
    for key, (act, a1, a2, why) in list(LOWCONF.items()) + list(EXTRA.items()) + list(TRIM.items()):
        if key not in table:
            raise SystemExit('no table row for %s' % (key,))
        cat = '低置信' if key in LOWCONF else ('范围锚点' if key in TRIM else '同类扩查')
        emit(key, act, a1, a2, (_R if key in LOWCONF else _T if key in TRIM else '') + why, cat + '：' + act)

    # BIND: G-FP-05 parameter-propagation ledger
    for n in BIND_ROWS:
        line = doc[n - 1]
        cells = line.split('|')
        pm = re.search(r'->\s*`([A-Za-z0-9_]+\.v)`', cells[1]) or re.search(r'\(`([A-Za-z0-9_]+\.v)`', cells[1])
        child = pm.group(1)
        parent = re.search(r'binding `([A-Za-z0-9_]+\.v):', line).group(1)
        bound = re.findall(r'`([A-Z][A-Z0-9_]*)`', cells[2].split(' -- ')[0])
        decl = params(child)
        own = [p for p in decl if p not in bound]
        inst = instance(parent, child[:-2])
        for key, r in sorted(table.items()):
            if key[0] != M or key[1] != n or r['class'] != 'convert':
                continue
            pre = line[:int(r['col'])]
            tail = line[int(r['col']) + len(r['old']):int(r['col']) + len(r['old']) + 60]
            if n == 3387:
                emit(key, 'keep', '', '', _B + DUAL, '参数绑定：dual_precision本批不改')
            elif pre.rstrip('`').endswith('binding '):
                emit(key, 'sym', parent, ','.join([inst] + bound),
                     _B + 'binding指%s中%s的例化参数绑定块：例化名%s加本行写明的%d个被绑定参数' % (parent, child, inst, len(bound)), '参数绑定：binding')
            elif n == 3369 and r['old'].startswith(child):
                # one anchor for the whole declaration span: the row's bound 8; the row's own-default
                # count (7) predates C_ADC_COMPLETION_LOST_CYCLES/LIMIT -- reported, not rewritten
                emit(key, 'sym', child, ','.join(bound), _B + '%s的参数声明：本行参数格写明的%d个被绑定参数；行内“own-default 7”与基线RTL不符（现为%d个：%s），已登记'
                     % (child, len(bound), len(own), '、'.join(own)), '参数绑定：target')
                stale.append((n, 'own-default 7 vs RTL %d' % len(own)))
            elif 'own-default' in tail.split(')')[0]:
                mm = re.search(r'own-default (\d+)', tail)
                if mm and int(mm.group(1)) != len(own):
                    stale.append((n, 'own-default %s vs RTL %d' % (mm.group(1), len(own))))
                emit(key, 'sym', child, ','.join(own), _B + '%s声明的参数中未被绑定的%d个（own-default）' % (child, len(own)), '参数绑定：own-default')
            elif child[:-2] in r['old'] or (pre.rstrip().endswith('target declarations `') or 'target declaration' in pre[-40:]):
                mm = re.search(r'bound (\d+)', tail)
                lst = bound if (mm or n in (3370,)) else decl
                if mm and int(mm.group(1)) != len(bound):
                    stale.append((n, 'bound %s vs written list %d' % (mm.group(1), len(bound))))
                missing = [p for p in lst if p not in decl]
                if missing:
                    raise SystemExit('row %d: %s not declared in %s' % (n, missing, child))
                emit(key, 'sym', child, ','.join(lst), _B + '%s的参数声明：本行参数格写明的%d个被绑定参数%s' % (child, len(bound), '（另含own-default %d个，同一行号段）' % len(own) if n == 3369 else ''),
                     '参数绑定：target')
            else:
                raise SystemExit('unclassified anchor in binding row %d: %s' % (n, r['old']))
    with open(a.out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('doc\tline\told\taction\targ1\targ2\treason\n')
        for row in out:
            fh.write('\t'.join(str(c).replace('\t', ' ') for c in row) + '\n')
    if a.report:
        json.dump(listing, open(a.report, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    from collections import Counter
    for k, v in sorted(Counter(x[0] for x in listing).items()):
        print(k, v)
    for n, what in stale:
        print('binding row %d: count in row text differs from baseline RTL (%s)' % (n, what))
    return 0


if __name__ == '__main__':
    sys.exit(main())
