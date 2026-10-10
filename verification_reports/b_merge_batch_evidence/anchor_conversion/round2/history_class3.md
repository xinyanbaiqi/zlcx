# 第③类：被后续条目取代的旧条目（统筹2026-10-09裁定）

判定规则：`tools/b_merge_tools/anchor_history_rules.py`（`classify_struck`与`SUPERSEDED`）。自测共17个样例，其中本类6个。逐条停用规则后，本类的样例恰好失败（`history_rules_selftest.txt`、`history_rules_negctl.txt`）。

| 子类 | 本表分类 | 数量 | 判定方法 | 处理 |
|---|---|---:|---|---|
| ③带删除线 | history-superseded-struck | 402 | 旧条目在~~删除线~~内，同一格中删除线之后接续了取代它的新条目（“~~旧~~ **新**”）。它同时满足①，按③单列 | 保留原文，不进allowlist（anchor_check对删除线内锚点直接按历史处理） |
| ③无删除线 | history-superseded | 0 | 不在删除线内，但同一格后文明示前文作废、不成立或已被取代（“以上/上述/前述…作废/不成立/已被…取代”、“superseded”） | 保留原文并进allowlist |
| （对照）①删除线内、无接续条目 | history-strike | 8 | 在删除线内，同一格中删除线之后没有新条目 | 保留原文 |
| （对照）③类候选但未明示取代 | convert（uncertain） | 98 | 同一格后文有带日期的勘误或补记，但没有明示前文作废 | 按“拿不准时默认转换”转换，note中标uncertain |

“③无删除线”为0个：两份文件中，没有一处在不划删除线的情况下用文字明示前文作废。实际做法都是把旧条目划删除线、后接新条目，归入“③带删除线”。

## ③带删除线：抽样（共402条，按固定种子随机列出12条）

| 位置 | 旧锚点 | 被取代的旧条目（删除线内原文） | 取代它的后续条目（同一格） | 保留理由 |
|---|---|---|---|---|
| 别名表:109 | PPG_CONTRACT_CLOSURE_MATRIX.md:2968 | ~~`PPG_CONTRACT_CLOSURE_MATRIX.md:2968`~~ | **`PPG_CONTRACT_CLOSURE_MATRIX.md:3033` (2026-09-10 Stage2批次1订正:2968现指向G-FP-01港口账12.5节`o_measurement_result_discard_color_ir`行,与本ID无关——矩阵12.6节`G-FP-05/06`等新增内容使行号整体下移,真实证据行是3033)** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1352 | ppg_control_top.v:832 | ~~Producer: chip boundary. Consumer: `ppg_control_top.v:832` (`.i_source_update_valid`), direct raw connection to the characterization CDC instance (C07, cluster ②) -- no intervening Top logic. Cluster ② owns this row pe | **2026-09-16重建（G-FP-01独立复核批次1收尾）**：Top自身边界端口。Top边界输入（`ppg_control_top.v:106`，1）→ 表征CDC.i_source_update_valid（`ppg_control_top.v:842`；声明`ppg_characterization_control_cdc.v:52`）。位宽1-bit，与子模块声明数值一致 | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1376 | `:544` | ~~`:544`~~ | **当前`:557`** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1395 | `:655` | ~~`:655`~~ | **当前`:673`** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1399 | `:426` | ~~`:426`~~ | **当前`:439`** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1415 | `:505` | ~~`:505`~~ | **当前`:518`** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1453 | ppg_control_top.v:72-75 | ~~**Pre-acknowledged documentation gap, not newly found**: `ppg_control_top.v:72-75`'s own header comment states "C01自身§4.1未列出此顶层边界输入" (C01's own §4.1 does not list this top-level boundary input) and justifies it via C03 | **2026-09-16重建（G-FP-01独立复核批次1收尾）**：Top自身边界端口。Top边界输入（`ppg_control_top.v:122`，1）→ wrapper.i_analog_ready（`ppg_control_top.v:737`；声明`ppg_active_v4_control_plane_integration.v:65`）。位宽1-bit，与子模块声明数值一致；C01§4.1至今未列此顶层边界输入（0字面命 | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1473 | ppg_sar9_sar15_safe_selection_wrapper.v:134 | ~~Producer: SSW (cluster ②) `o_en_test` at `ppg_sar9_sar15_safe_selection_wrapper.v:134` -> `ppg_control_top.v:1032,1434`. Consumer: chip boundary. Cluster ② owns this row. New row (gap fill).~~ | **2026-09-16重建（G-FP-01独立复核批次1收尾）**：Top自身边界端口。Top边界输出（`ppg_control_top.v:141`，1）← Top `:1447` `o_en_test = ssw_en_test_o`←SSW.o_en_test（`ppg_control_top.v:1042`；声明`ppg_sar9_sar15_safe_selection_wrapper.v:136`）。位宽1-bit，与子模 | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1486 | `:217` | ~~`:217`~~ | **当前`:219`（分组文字行，端口名不在该行）** | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:1504 | ppg_control_top.v:1064,1517 | ~~Producer: SSW (cluster ②) `o_transaction_mismatch_sticky` at `ppg_sar9_sar15_safe_selection_wrapper.v:168` -> `ppg_control_top.v:1064,1517` (`ssw_transaction_mismatch_sticky_o`). Consumer: chip boundary. Cluster ② owns | **2026-09-16重建（G-FP-01独立复核批次1收尾）**：Top自身边界端口。Top边界输出（`ppg_control_top.v:224`，1）← Top `:1530` `o_ssw_transaction_mismatch_sticky = ssw_transaction_mismatch_sticky_o`←SSW.o_transaction_mismatch_sticky（`ppg_control_top.v:10 | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:2097 | ppg_adc_measurement_idac_integration.v:2377 | ~~Consumer: `ppg_adc_measurement_idac_integration.v:2377` (`flag_idac_amb_seq_busy`) -> AMI-level `o_amb_sequence_busy` (part of the AMB_RECHECK output group -- but this specific signal doesn't appear on AMI's own port l | **2026-09-28独立审计(批次3)勘误**：锚点行号系统性少15（见本合同末尾整体说明），正确例化连接行为`ppg_adc_measurement_idac_integration.v:2392`。且grep核实`flag_idac_amb_seq_busy`全文件仅出现2次（声明`:593`+该例化连接`:2392`），此后再未被读取——是真正悬空、从未被消费的wire，并非"consumed only inside AMI" | 旧条目已被同格后续条目取代，属裁定③，保留原文 |
| 矩阵:2104 | ppg_adc_measurement_idac_integration.v:2384 | ~~Consumer: `ppg_adc_measurement_idac_integration.v:2384` (`flag_idac_dcs_revalidate_busy`), consumed only inside AMI.~~ | **2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2399`。grep核实`flag_idac_dcs_revalidate_busy`全文件仅出现2次（声明`:556`+该例化连接`:2399`），此后未被读取，属真正悬空wire，非"consumed only inside AMI"。Cluster ③ self-contained. | 旧条目已被同格后续条目取代，属裁定③，保留原文 |

## ①删除线内、无接续条目：全部（8条）

| 位置 | 旧锚点 | 删除线内原文 |
|---|---|---|
| 别名表:150 | ppg_400hz_frame_calibration_scheduler.v:424,452,455,461 |  `ppg_400hz_frame_calibration_scheduler.v:424,452,455,461 |
| 别名表:164 | ppg_sar9_sar15_safe_selection_wrapper.v:93,390,438 |  `ppg_sar9_sar15_safe_selection_wrapper.v:93,390,438 |
| 别名表:164 | ppg_400hz_frame_calibration_scheduler.v:484-485 |  `ppg_sar9_sar15_safe_selection_wrapper.v:93,390,438`; `ppg_400hz_frame_calibration_scheduler.v:484-485 |
| 别名表:165 | PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:655-670 |  `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:655-670 |
| 别名表:165 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 |  `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:655-670`; `PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 |
| 别名表:173 | PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:662,664 |  `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:662,664 |
| 别名表:173 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 |  `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:662,664`; `PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 |
| 别名表:189 | ppg_amb_recheck_scheduler.v:177 |  `ppg_idac_code_controller.v`: `ST_AMB_RECHECK`(285行,5'd9,已打RRC-01标签,与SID共用同一FSM状态,412-413/657-659行); `ppg_amb_recheck_scheduler.v:177 |

## ③类候选但未明示取代（uncertain，已转换）：全部（98条）

其中第一轮已转换49条，第二轮由带日期叙述新转换49条。“后续条目”取锚点之后同一格中第一个带日期的勘误或补记片段。

| 位置 | 旧锚点 | 新文本 | 后续带日期条目（摘录） |
|---|---|---|---|
| 矩阵:1198 | C01:3 | C01 文件头 | 2026-09-02; remapped +2 for the 2026-09-30 V1.15 erratum; ~~a pre-existing +2 drift from the 2026-09-05 V1.14 erratum is |
| 矩阵:1198 | C01:95 | C01 §2.1 | 2026-09-02; remapped +2 for the 2026-09-30 V1.15 erratum; ~~a pre-existing +2 drift from the 2026-09-05 V1.14 erratum is |
| 矩阵:1198 | C01:103 | C01 §2.1 | 2026-09-02; remapped +2 for the 2026-09-30 V1.15 erratum; ~~a pre-existing +2 drift from the 2026-09-05 V1.14 erratum is |
| 矩阵:1571 | ppg_control_top.v:292 | `ppg_control_top.v` `o_s2_raw` | 2026-09-30 SID-05合同同步补记（C01块末尾说明）**：SID-05没有新增Top端口，只新增Top内部网`sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`， |
| 矩阵:1571 | `:1598` | `ppg_control_top.v` `o_s2_raw`、`sched_cal_owner_deadline_event_o` | 2026-09-30 SID-05合同同步补记（C01块末尾说明）**：SID-05没有新增Top端口，只新增Top内部网`sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`， |
| 矩阵:1571 | ppg_control_top.v:1372 | `ppg_control_top.v` `o_s2_raw` | 2026-09-30 SID-05合同同步补记（C01块末尾说明）**：SID-05没有新增Top端口，只新增Top内部网`sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`， |
| 矩阵:1571 | ppg_adc_measurement_idac_integration.v:402 | `ppg_adc_measurement_idac_integration.v` `o_s2_raw` | 2026-09-30 SID-05合同同步补记（C01块末尾说明）**：SID-05没有新增Top端口，只新增Top内部网`sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`， |
| 矩阵:1571 | ppg_control_top.v:553 | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | 2026-09-30合同补记批次2（C01块末尾说明）**：C01 V1.16勘误已把`o_s1_calibration_applied`、`o_s1_raw`、`o_s2_raw`写进第4.2节，把calibration-loss注入端口 |
| 矩阵:1571 | `:963` | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | 2026-09-30合同补记批次2（C01块末尾说明）**：C01 V1.16勘误已把`o_s1_calibration_applied`、`o_s1_raw`、`o_s2_raw`写进第4.2节，把calibration-loss注入端口 |
| 矩阵:1571 | `:1151` | `ppg_control_top.v` `sched_cal_owner_deadline_event_o` | 2026-09-30合同补记批次2（C01块末尾说明）**：C01 V1.16勘误已把`o_s1_calibration_applied`、`o_s1_raw`、`o_s2_raw`写进第4.2节，把calibration-loss注入端口 |
| 矩阵:1924 | ppg_400hz_frame_calibration_scheduler.v:203 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_frame_start_event`、`o_startup_idac_safe | 2026-09-05**, not a TBD pending DBG_OUT/glue-top design (see `o_macro_frame_start_event`'s row above for the full citati |
| 矩阵:1924 | ppg_control_top.v:962 | `ppg_control_top.v` `o_macro_frame_start_event`、`o_startup_idac_safe_boundary` | 2026-09-05**, not a TBD pending DBG_OUT/glue-top design (see `o_macro_frame_start_event`'s row above for the full citati |
| 矩阵:2036 | ppg_adc_measurement_idac_integration.v:2331 | `ppg_adc_measurement_idac_integration.v` `i_idac_mode` | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:201`为`IDAC配置接口`分组注释行，`:202`为首个端口`i_idac_mode`的声明行（组内20个端口声明在`:202`-`:221`）。旧`:197`偏移为+4 |
| 矩阵:2036 | ppg_idac_code_controller.v:81 | `ppg_idac_code_controller.v` `i_idac_mode` | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:201`为`IDAC配置接口`分组注释行，`:202`为首个端口`i_idac_mode`的声明行（组内20个端口声明在`:202`-`:221`）。旧`:197`偏移为+4 |
| 矩阵:2036 | `:201-202` | `ppg_adc_measurement_idac_integration.v` `i_idac_mode` | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:201`为`IDAC配置接口`分组注释行，`:202`为首个端口`i_idac_mode`的声明行（组内20个端口声明在`:202`-`:221`）。旧`:197`偏移为+4 |
| 矩阵:2097 | ppg_idac_code_controller.v:656-659 | `ppg_idac_code_controller.v` `o_amb_sequence_busy` | 2026-09-28独立审计(批次3)勘误**：锚点行号系统性少15（见本合同末尾整体说明），正确例化连接行为`ppg_adc_measurement_idac_integration.v:2392`。且grep核实`flag_idac_a |
| 矩阵:2104 | ppg_idac_code_controller.v:663-668 | `ppg_idac_code_controller.v` `o_dcs_revalidate_busy` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2399`。grep核实`flag_idac_dcs_revalidate_busy`全文件仅出现2次（声明`:556`+该例化连接`:2399`），此后未被读取， |
| 矩阵:2113 | ppg_idac_code_controller.v:615 | `ppg_idac_code_controller.v` `o_amb_code_update` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2408`。grep核实`amb_code_update_o`在AMI文件出现3次（声明`:803`、该例化连接`:2408`、`:1066` `assign o_ |
| 矩阵:2114 | ppg_idac_code_controller.v:616 | `ppg_idac_code_controller.v` `o_dcs_r_code_update` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2409`。grep核实`dcs_r_code_update_o`出现3次（声明`:804`、连接`:2409`、`:1067` `assign o_dcs_r_c |
| 矩阵:2115 | ppg_idac_code_controller.v:617 | `ppg_idac_code_controller.v` `o_dcs_ir_code_update` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2410`。grep核实`dcs_ir_code_update_o`出现3次（声明`:805`、连接`:2410`、`:1068` `assign o_dcs_ir |
| 矩阵:2116 | ppg_idac_code_controller.v:618 | `ppg_idac_code_controller.v` `o_dcs_r_track_adjust` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2411`。grep核实`dcs_r_track_adjust_o`出现3次（声明`:806`、连接`:2411`、`:1069` `assign o_dcs_r_ |
| 矩阵:2117 | ppg_idac_code_controller.v:619 | `ppg_idac_code_controller.v` `o_dcs_ir_track_adjust` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2412`。grep核实`dcs_ir_track_adjust_o`出现3次（声明`:807`、连接`:2412`、`:1070` `assign o_dcs_i |
| 矩阵:2118 | ppg_idac_code_controller.v:620 | `ppg_idac_code_controller.v` `o_amb_search_done` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2413`。grep核实`amb_search_done_o`出现3次（声明`:808`、连接`:2413`、`:1071` `assign o_amb_searc |
| 矩阵:2119 | ppg_idac_code_controller.v:621 | `ppg_idac_code_controller.v` `o_dcs_r_search_done` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2414`。grep核实`dcs_r_search_done_o`出现3次（声明`:809`、连接`:2414`、`:1072` `assign o_dcs_r_s |
| 矩阵:2120 | ppg_idac_code_controller.v:622 | `ppg_idac_code_controller.v` `o_dcs_ir_search_done` | 2026-09-28独立审计(批次3)勘误**：锚点少15，正确连接行为`:2415`。grep核实`dcs_ir_search_done_o`出现3次（声明`:810`、连接`:2415`、`:1073` `assign o_dcs_ir |
| 矩阵:2147 | ppg_idac_code_controller.v:671-682 | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28独立审计(批次3)勘误**：正确连接行为`:2442`（见下方整体说明）。C17 now 122/122; cluster ③ complete for this contract. **2026-09-28独立审计（批 |
| 矩阵:2147 | `:2442` | `ppg_adc_measurement_idac_integration.v` `idac_idle_o` | 2026-09-28独立审计（批次3，G-FP-01批次2-9独立复核）结论**：独立重建C17全部122个端口的事实库（`ppg_idac_code_controller.v:67-207`声明区+`ppg_adc_measurement |
| 矩阵:2147 | ppg_idac_code_controller.v:67-207 | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:602-682` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2306` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2427` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2306` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2321` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2427` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2147 | `:2442` | `ppg_idac_code_controller.v` `o_idac_idle` | 2026-09-28通过一个独立编写并经空跑验证的脚本（数据直接从RTL源码正则提取，非凭矩阵文本推断；运行后`port_not_found`/`citation_token_not_found`均为0）统一订正为"N+15"，不再需要读者 |
| 矩阵:2182 | ppg_amb_recheck_scheduler.v:208 | `ppg_amb_recheck_scheduler.v` `o_calibration_sample_valid` | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:1357-1371`是仲裁寄存器`calibration_sample_valid_o`的`always`块（块首说明注释在`:1356`，"周期重检请求具有更高仲裁优先级" |
| 矩阵:2182 | ppg_precision_window_integration.v:1016 | `ppg_precision_window_integration.v` `calibration_sample_valid_o` | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:1357-1371`是仲裁寄存器`calibration_sample_valid_o`的`always`块（块首说明注释在`:1356`，"周期重检请求具有更高仲裁优先级" |
| 矩阵:2182 | ppg_adc_measurement_idac_integration.v:1357-1371 | `ppg_adc_measurement_idac_integration.v` `calibration_sample_valid_o`、`flag_recheck_reques | 2026-09-30订正(批次3遗留项，详见报告附录四)**：`:1357-1371`是仲裁寄存器`calibration_sample_valid_o`的`always`块（块首说明注释在`:1356`，"周期重检请求具有更高仲裁优先级" |
| 矩阵:2185 | ppg_amb_recheck_scheduler.v:211 | `ppg_amb_recheck_scheduler.v` `o_calibration_precision_mode` | 2026-09-30订正（合同补记批次2独立复核）：PWI把它转发到自身输出`o_calibration_precision_mode`（`ppg_precision_window_integration.v:458`），但AMI例化PWI |
| 矩阵:2185 | ppg_precision_window_integration.v:1019 | `ppg_precision_window_integration.v` `calibration_precision_mode_o` | 2026-09-30订正（合同补记批次2独立复核）：PWI把它转发到自身输出`o_calibration_precision_mode`（`ppg_precision_window_integration.v:458`），但AMI例化PWI |
| 矩阵:2195 | ppg_amb_recheck_scheduler.v:224 | `ppg_amb_recheck_scheduler.v` `o_scheduler_idle` | 2026-09-28独立审计(批次3)勘误**：拆分数算错，按本表上方2148-2195行逐行Direction列实际统计为**32 in + 16 out**（与`ppg_amb_recheck_scheduler.v:55-116`独立 |
| 矩阵:2195 | ppg_precision_window_integration.v:1029 | `ppg_precision_window_integration.v` `scheduler_idle_o` | 2026-09-28独立审计(批次3)勘误**：拆分数算错，按本表上方2148-2195行逐行Direction列实际统计为**32 in + 16 out**（与`ppg_amb_recheck_scheduler.v:55-116`独立 |
| 矩阵:2196 | ppg_adc_measurement_idac_integration.v:197 | `ppg_adc_measurement_idac_integration.v` `i_idac_mode`、`i_amb_enable` | 2026-09-30订正（合同补记批次2独立复核）：此句对其中3个端口不成立。`i_idac_mode`、`i_amb_enable`、`i_dcs_enable`除接C17（`ppg_adc_measurement_idac_integr |
| 矩阵:2196 | `:2316` | `ppg_idac_code_controller.v` `i_idac_mode` | 2026-09-30订正（合同补记批次2独立复核）：此句对其中3个端口不成立。`i_idac_mode`、`i_amb_enable`、`i_dcs_enable`除接C17（`ppg_adc_measurement_idac_integr |
| 矩阵:2843 | ppg_normal_transaction_fork.v:127 | `ppg_normal_transaction_fork.v` `o_track_valid` | 2026-09-30订正(批次3收尾)**：`:912`是`assign flag_normal_track_qualified`定义行的旧行号，该处实际偏移为+7（不是+15），现为`:919`；门控赋值`flag_track_branc |
| 矩阵:2843 | `:919` | `ppg_adc_measurement_idac_integration.v` `flag_normal_track_qualified` | 2026-09-30订正(批次3收尾)**：`:912`是`assign flag_normal_track_qualified`定义行的旧行号，该处实际偏移为+7（不是+15），现为`:919`；门控赋值`flag_track_branc |
| 矩阵:2860 | ppg_normal_transaction_fork.v:146 | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28独立审计(批次3)勘误**：拆分数算错，按本表上方2787-2860行逐行Direction列实际统计为**34 in + 40 out**（与`ppg_normal_transaction_fork.v:61-146` |
| 矩阵:2860 | ppg_normal_transaction_fork.v:61-146 | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:61-146` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:1972` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:2005` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:1972` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:1987` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:1983` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:1998` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28通过脚本统一订正为"+15"。~~2799-2858内散落的其余引用（如2820行`i_measurement_ready`一格里"AMI `:2005,2092`"的第二个数字`:2092`，实际指向AMI内`ppg_ |
| 矩阵:2860 | `:2005` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2025` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2020` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2040` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2071` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2090` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2092` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2086` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2105` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2107` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2074` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2135` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2359` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2374` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2374` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2389` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:1336` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:1351` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:912` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:919` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:912` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:1336` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2005,2092` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:2860 | `:2092,2005` | `ppg_normal_transaction_fork.v` `o_local_empty` | 2026-09-28补充**：本子模块全部74行的第5列"Verbatim declaration anchor"已一并从RTL源码提取补全。详见`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md`。  |
| 矩阵:3189 | ppg_idac_code_controller.v:2314 | `ppg_adc_measurement_idac_integration.v` `i_idac_code_safe_boundary` | 2026-09-30 SID-05合同同步补记（C10台账末尾汇总说明）**：SID-05新增端口`i_cal_owner_deadline_event`（AMI RTL V1.15，声明`ppg_adc_measurement_idac_ |
| 矩阵:3189 | ppg_precision_window_integration.v:994,1002 | `ppg_precision_window_integration.v` `i_normal_frame_complete_event`、`i_calibration_frame_ | 2026-09-30 SID-05合同同步补记（C10台账末尾汇总说明）**：SID-05新增端口`i_cal_owner_deadline_event`（AMI RTL V1.15，声明`ppg_adc_measurement_idac_ |
| 矩阵:3189 | ppg_adc_measurement_idac_integration.v:153 | `ppg_adc_measurement_idac_integration.v` `i_cal_owner_deadline_event` | 2026-09-30合同补记批次2（C10台账末尾汇总说明）**：C10 V2.3第6.7节新补的P2S遥测输出`o_s1_calibration_applied`、`o_s1_raw[9:0]`、`o_s2_raw[9:0]`（AMI R |
| 别名表:62 | ppg_idac_code_controller.v:638 | `ppg_idac_code_controller.v` `o_controller_fault_blocking` | 2026-09-28工作线D独立复核订正:原引用2428-2429已因该文件后续编辑整体下移3行漂移,真实位置见新引用,语义/连接关系本身未变**) / `PPG_CONTRACT_CLOSURE_MATRIX.md:872` / |
| 别名表:62 | ppg_adc_measurement_idac_integration.v:2431-2432 | `ppg_adc_measurement_idac_integration.v` `o_controller_fault_blocking`、`o_controller_fault | 2026-09-28工作线D独立复核订正:原引用2428-2429已因该文件后续编辑整体下移3行漂移,真实位置见新引用,语义/连接关系本身未变**) / `PPG_CONTRACT_CLOSURE_MATRIX.md:872` / |
| 别名表:66 | ppg_adc_measurement_idac_integration.v:92 | `ppg_adc_measurement_idac_integration.v` `C_RUN_GENERATION_WIDTH` | 2026-09-28工作线D独立复核订正:声明行90→92、PWI透传2457→2460、IDAC透传2313→2316、用于1157→1160均因该文件后续编辑整体下移漂移,真实位置见新引用,声明/透传/使用关系本身逐条核实无误**) / |
| 别名表:67 | ppg_precision_window_controller.v:269,672-684 | `ppg_precision_window_controller.v` `flag_lifecycle_cancel`、`flag_fault_hold` | 2026-09-28工作线D独立复核订正:原引用"674独立于675-676"已漂移,真实的复位/discard两个独立分支在670-682号always块内,语义——reset与flag_lifecycle_cancel是同一个alway |
| 别名表:77 | ppg_adc_measurement_idac_integration.v:2512 | `ppg_adc_measurement_idac_integration.v` `i_peak_valley_config_valid` | 2026-09-28工作线D独立复核订正:该文件后续编辑致行号从2509下移到2512,内容/标签核实未变**) / `PPG_CONTRACT_CLOSURE_MATRIX.md:3349` — **原文无此分段,本次新增,且修复了一处V |
| 别名表:89 | PPG_CONTRACT_CLOSURE_MATRIX.md:3463-3524 | PPG_CONTRACT_CLOSURE_MATRIX.md §12.12–§12.12a | 2026-09-10 Stage2 B_TAG_MISSING批次1订正:原3352-3365现已漂移进12.12b节SSW D03内容,与本ID无关——本节之后的§13.1/13.2新增内容把行号整体下移;真实批次4记录段落现在是3463 |
| 别名表:90 | PPG_CONTRACT_CLOSURE_MATRIX.md:3419-3524 | PPG_CONTRACT_CLOSURE_MATRIX.md §12.12–§12.12a | 2026-09-10同上订正,同一行号漂移原因)——D01汇总关系本身核实无误:12.14节仍确认D01`CLOSED`,3591行"D01 V5 chain"收尾行状态字样与之一致,汇总关系未过期** / |
| 别名表:109 | PPG_CONTRACT_CLOSURE_MATRIX.md:3033 | PPG_CONTRACT_CLOSURE_MATRIX.md §12.5 C15行 | 2026-09-10 Stage2批次1订正:2968现指向G-FP-01港口账12.5节`o_measurement_result_discard_color_ir`行,与本ID无关——矩阵12.6节`G-FP-05/06`等新增内容使行 |
| 别名表:110 | PPG_CONTRACT_CLOSURE_MATRIX.md:3035 | PPG_CONTRACT_CLOSURE_MATRIX.md §12.5 C15行 | 2026-09-10 Stage2批次1订正,同上行原因:2970同样落在12.5节G-FP-01港口账里,真实证据行是3035)** / |
| 别名表:111 | ppg_precision_window_controller.v:139 | `ppg_precision_window_controller.v` `o_mode_fault_active` | 2026-09-28工作线D独立复核订正:原引用2560-2561现已漂移到该文件同一实例化块内一组无关的calibration_sample端口连接,与本ID无关；真实的`o_mode_fault_active`等cause 8'h04承 |
| 别名表:111 | ppg_precision_window_integration.v:960-961 | `ppg_precision_window_integration.v` `o_mode_fault_event`、`o_mode_fault_active` | 2026-09-28工作线D独立复核订正:原引用2560-2561现已漂移到该文件同一实例化块内一组无关的calibration_sample端口连接,与本ID无关；真实的`o_mode_fault_active`等cause 8'h04承 |
| 别名表:111 | ppg_adc_measurement_idac_integration.v:2576-2583 | `ppg_adc_measurement_idac_integration.v` `o_mode_fault_active`、`o_mode_fault_identity_vali | 2026-09-28工作线D独立复核订正:原引用2560-2561现已漂移到该文件同一实例化块内一组无关的calibration_sample端口连接,与本ID无关；真实的`o_mode_fault_active`等cause 8'h04承 |
| 别名表:114 | ppg_control_top.v:1099-1106 | `ppg_control_top.v` `C_FRAME_ID_WIDTH`、`C_SAMPLE_INDEX_WIDTH`、`C_CONFIG_EPOCH_WIDTH`、`C_CO | 2026-09-28工作线D独立复核订正:Top侧原引用1085-1092已漂移到SSW故障端口连接段,与本ID无关；真实的AMI例化`#(...)`参数列表现在1099-1106,逐项同名绑定`C_FRAME_ID_WIDTH/C_SAM |
| 别名表:114 | ppg_adc_measurement_idac_integration.v:92 | `ppg_adc_measurement_idac_integration.v` `C_RUN_GENERATION_WIDTH` | 2026-09-28工作线D独立复核订正:Top侧原引用1085-1092已漂移到SSW故障端口连接段,与本ID无关；真实的AMI例化`#(...)`参数列表现在1099-1106,逐项同名绑定`C_FRAME_ID_WIDTH/C_SAM |
| 别名表:115 | PPG_CONTRACT_CLOSURE_MATRIX.md:3121 | PPG_CONTRACT_CLOSURE_MATRIX.md §12.5 C10行 | 2026-09-28工作线D独立复核订正:AMI侧原引用2432-2446已因该文件后续编辑下移,真实的PWI例化`#(...)`参数列表现在2446-2461,逐项计数确认恰好15个绑定,与PWI自身18个声明参数(55-72行)数量差3 |
| 别名表:116 | ppg_config_cdc_bridge.v:66-190 | `ppg_config_cdc_bridge.v` | 2026-09-13 Stage3 Item4a逐行核实订正:"双触发器"字面表述有歧义,容易误读成对整条总线(该实例`ppg_active_v4_control_plane_integration.v:379`以`C_CONFIG_WID |
