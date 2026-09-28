# PPG Item 4b Phase 1 —— 时钟域传播标注 + 真实可达性范围界定

真实顶层模块：`ppg_chip_digital_top`

## 范围统计

- 候选文件全集（`collect_real_source_files`）：93
- canonical 模块（文件名与内部声明模块名一致）：42
- 真实可达模块类型数：30
- 真实可达例化节点总数（同一模块类型多次例化分别计数）：37

## 域标注统计（寄存器/always 块目标）

- CLK_2M: 401
- MULTI(CLK_2M | SPI_SCLK): 4
- N/A(no-clock-field-on-always-block): 29
- SPI_SCLK: 18

## 人工抽查交叉核对（Phase 1 退出标准点名的真实案例）

| 模块 | 目标 | 期望域 | 实际域 | 结果 |
|---|---|---|---|---|
| ppg_spi_register_file | reg_diag_snapshot | CLK_2M | CLK_2M | PASS |
| ppg_spi_register_file | reg_diag_snapshot_gated | SPI_SCLK | SPI_SCLK | PASS |
| ppg_spi_register_file | reg_diag_sync_stable | SPI_SCLK | SPI_SCLK | PASS |
| ppg_chip_digital_top | w_idle_mux_async | EXTERNAL_ASYNC | EXTERNAL_ASYNC | PASS |

## 真实孤立的RTL模块（架构层面的发现，不是TB，共 7 个）

- `ppg_digital_esd_shell` — ppg_digital_esd_shell/ppg_digital_esd_shell.v
- `ppg_digital_shell` — ppg_digital_shell/ppg_digital_shell.v
- `ppg_dual_precision_top` — ppg_dual_precision_top/ppg_dual_precision_top.v
- `ppg_timing_sar15_3200hz` — ppg_timing_sar15/ppg_timing_sar15_3200hz.v
- `ppg_timing_sar15_3200hz_new` — ppg_timing_sar15/ppg_timing_sar15_3200hz_new.v
- `ppg_timing_sar9_3200hz` — ppg_timing_sar9/ppg_timing_sar9_3200hz.v
- `ppg_timing_sar9_3200hz_new` — ppg_timing_sar9/ppg_timing_sar9_3200hz_new.v

## 顶层TB文件（预期如此，不计入CDC分析范围，非发现，共 5 个）

- `tb_ppg_active_v4_control_plane_integration` — ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v
- `tb_ppg_adc_measurement_idac_integration` — ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v
- `tb_ppg_adc_pipeline_overlap_corrector` — ppg_adc_pipeline_overlap_corrector/tb_ppg_adc_pipeline_overlap_corrector.v
- `tb_ppg_real_raw_generator_selfcheck` — ppg_control_top/tb_ppg_real_raw_generator_selfcheck.v
- `tb_ppg_system_active_config_unpack` — ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v

## 真实可达但内容解析失败的文件（需要人工核查，无法确认CDC域标注，共 0 个）

这一类与上面两类都不同：文件本身 `formatter_ast` 解析失败，但轻量核对（直接查真实可达模块类型自己的 `instances` 列表）确认它真的被至少一个真实可达模块实例化——内容无法分析，但引用关系是真实的，不能归入「孤立RTL」或「顶层TB」，也不能笼统留在「解析失败」名单里不做区分。

（无——本次核实确认全部解析失败文件都不被任何真实可达模块实例化，包括 `ppg_timing_sar9`/`ppg_timing_sar15` 家族里 `control parser strict failure` 的那 6 个变体：它们只被孤儿模块 `ppg_dual_precision_top`（本身不可达）和/或各自的 TB 单独实例化用于单元测试，两者都不构成真实可达；此前「确认可达」的表述不准确，已用本节的真实核对结果订正。）

## 非 canonical 文件（文件名与内部声明模块名不一致，共 0 个，不纳入可达性解析）


## 候选文件解析失败（51 个，绝大多数是 TB 文件，formatter_ast 对 TB 的宽松写法支持有限属已知局限）

- ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v: > ERR: [Python] always header normalization failed.
- ppg_adc_async_stage_capture/tb_ppg_adc_async_stage_capture.v: > ERR: [Python] always header normalization failed.
- ppg_adc_dc_recovery/tb_ppg_adc_dc_recovery.v: > ERR: [Python] only single module sources are currently supported.
- ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v: > ERR: [Python] always header normalization failed.
- ppg_adc_result_router/tb_ppg_adc_result_router.v: > ERR: [Python] always header normalization failed.
- ppg_adc_s1_programmable_calibrator/tb_ppg_adc_s1_programmable_calibrator.v: > ERR: [Python] always header normalization failed.
- ppg_adc_s1_redundancy_corrector/tb_ppg_adc_s1_redundancy_corrector.v: > ERR: [Python] always header normalization failed.
- ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v: > ERR: [Python] always header normalization failed.
- ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v: > ERR: [Python] only single module sources are currently supported.
- ppg_chip_digital_top/tb_ppg_chip_digital_top.v: > ERR: [Python] only single module sources are currently supported.
- ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v: > ERR: [Python] always header normalization failed.
- ppg_control_top/tb_diag_algo_probe.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_adc_numeric_scoreboard.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_baseline_cross.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top_fir_tail_isolation.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_injection.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v: > ERR: [Python] control parser strict failure.; unclosed_block_comment
- ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_long_10_cycles.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top_longrun.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top_no_recheck_control.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_normal_slow_tracking.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_peak_valley_return.v: > ERR: [Python] Strict mode [unsupported_construct]: time reg_measurement_start_time; // accepted START事件锁存的time类型起点. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.
- ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v: > ERR: [Python] control parser strict failure.
- ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v: > ERR: [Python] control parser strict failure.
- ppg_dual_precision_top/tb_ppg_dual_precision_top.v: > ERR: [Python] only single module sources are currently supported.
- ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v: > ERR: [Python] only single module sources are currently supported.
- ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence.v: > ERR: [Python] only single module sources are currently supported.
- ppg_idac_code_controller/tb_ppg_idac_code_controller.v: > ERR: [Python] always header normalization failed.
- ppg_idac_code_controller/tb_ppg_idac_code_controller_wave.v: > ERR: [Python] only single module sources are currently supported.
- ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v: > ERR: [Python] only single module sources are currently supported.
- ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v: > ERR: [Python] only single module sources are currently supported.
- ppg_precision_window_controller/tb_ppg_precision_window_controller.v: > ERR: [Python] always header normalization failed.
- ppg_precision_window_integration/tb_ppg_precision_window_integration.v: > ERR: [Python] only single module sources are currently supported.
- ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v: > ERR: [Python] only single module sources are currently supported.
- ppg_system_config_manager/tb_ppg_system_config_manager.v: > ERR: [Python] control parser strict failure.
- ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v: > ERR: [Python] always header normalization failed.
- ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration.v: > ERR: [Python] Strict mode [unsupported_construct]: time time_run_reset_assert; // time-typed independent reset timestamp. Suggestion: > ERR: [Python] Move this statement into a supported declaration, assign, always block, or instance block.; unclosed_block_comment
- ppg_timing_3200hz_validation/tb_ppg_timing_3200hz.v: > ERR: [Python] only single module sources are currently supported.
- ppg_timing_sar15/ppg_timing_sar15.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar15/ppg_timing_sar15_6667hz_v1.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar15/ppg_timing_sar15_new.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar15/ppg_timing_sar15_v1.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar15/tb_ppg_timing_sar15.v: > ERR: [Python] only single module sources are currently supported.
- ppg_timing_sar9/ppg_timing_sar9.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar9/ppg_timing_sar9_new.v: > ERR: [Python] control parser strict failure.
- ppg_timing_sar9/tb_ppg_timing_sar9.v: > ERR: [Python] only single module sources are currently supported.

解析失败的文件既进不了 canonical 登记表也进不了 noncanonical 列表——为了不让它们从范围界定报告里悄悄消失，这里显式核对：例化展开过程中记录的全部 `instance_issues` 里，有没有任何一个引用的模块名恰好等于某个解析失败文件的文件名（本项目 canonical 惯例是文件名等于模块名）。

全部 51 个解析失败文件都不在任何 `instance_issues` 的引用名单里——即 0 个未解析的例化点指向它们，确认它们都不是真实可达例化树需要的依赖（不是假设，是本次扫描 instance_issues 为空的直接推论）。这条结论与下方「真实可达但内容解析失败的文件」小节用另一条独立路径（直接扫描 30 个真实可达模块类型自己的 `instances` 列表，不依赖 BFS 过程中偶然记录的instance_issues）得到的结论一致，互为交叉验证。

## 候选文件全集核对（109 = canonical + ambiguous + noncanonical + 解析失败，必须对得上）

- candidate_files_total=93, canonical=42, ambiguous_file_entries=0, noncanonical=0, parse_errors=51, 四类之和=93, 与候选全集一致=True

## 同一模块类型多例化域不一致的真实案例（不合并，分别列出）

- `ppg_pulse_cdc_sync`.`flag_source_toggle` （本地时钟名 `i_source_clk`）：
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_start_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_stop_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_clear_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_abort_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_capture_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_dbg_select_Inst: SPI_SCLK
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_ready_Inst: CLK_2M
- `ppg_pulse_cdc_sync`.`flag_dest_sync_meta` （本地时钟名 `i_dest_clk`）：
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_start_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_stop_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_clear_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_abort_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_capture_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_dbg_select_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_ready_Inst: SPI_SCLK
- `ppg_pulse_cdc_sync`.`flag_dest_sync_stable` （本地时钟名 `i_dest_clk`）：
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_start_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_stop_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_clear_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_abort_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_capture_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_dbg_select_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_ready_Inst: SPI_SCLK
- `ppg_pulse_cdc_sync`.`flag_dest_sync_prev` （本地时钟名 `i_dest_clk`）：
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_start_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_stop_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_clear_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_abort_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_capture_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_dbg_select_Inst: CLK_2M
  - ppg_chip_digital_top/ppg_spi_register_file_Inst/ppg_pulse_cdc_sync_diag_ready_Inst: SPI_SCLK
