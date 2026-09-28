# PPG Item 4b Phase 3 —— 白名单IP识别 + 手搓跨域结构性判定

## 验证用例结果（5个规划点名用例 + 1个真实断言）

- [PASS] 验证用例1：ppg_config_cdc_bridge.v真实门控模式=判定安全
- [PASS] 验证用例2：Phase2合成V1.2无门控负例（依据changelog重建，非真实历史文件）=判定高风险
- [PASS] 验证用例3：ppg_pulse_cdc_sync.v自身单bit两级同步=判定安全
- [PASS] 验证用例4：ppg_chip_digital_top.v的w_source_rstn借用w_rstn模式=判定安全（Class 2特例）
- [PASS] 验证用例5：门控信号本身是未经白名单IP、无门控手搓跨域的合成陷阱=判定高风险（不能因表面有门控就放行）
- [PASS] 附加真实断言：Phase2唯一真实门控候选最终归类为Class 3(a)门控捕获，安全

## 白名单自洽性检查

- `ppg_pulse_cdc_sync_internal_chain`: class=1, verdict=SAFE
- `ppg_reset_sync_is_definition_itself`: class=2a, verdict=SAFE_IP_VERIFIED
- `ppg_config_cdc_bridge_internal_gated_capture`: class=3a, verdict=SAFE_GATED_CAPTURE

## Class 1 外部异步源信号同步深度审计（真实全部EXTERNAL_ASYNC信号）

- `ppg_adc_async_stage_capture`.`i_clk_stage1_dout_low_async`（port）：深度=2，链=i_clk_stage1_dout_low_async -> flag_stage1_done_meta -> flag_stage1_done_sync，判定=SAFE
- `ppg_adc_async_stage_capture`.`i_clk_stage2_dout_low_async`（port）：深度=2，链=i_clk_stage2_dout_low_async -> flag_stage2_done_meta -> flag_stage2_done_sync，判定=SAFE
- `ppg_adc_measurement_idac_integration`.`i_clk_stage1_dout_low_async`（port）：判定=NOT_CONSUMED_IN_THIS_MODULE（该信号在本模块内只是端口直通给子实例，未被本模块任何always块读取；真实同步链在被例化的子模块内，见该子模块自己的独立审计条目）
- `ppg_adc_measurement_idac_integration`.`i_clk_stage2_dout_low_async`（port）：判定=NOT_CONSUMED_IN_THIS_MODULE（该信号在本模块内只是端口直通给子实例，未被本模块任何always块读取；真实同步链在被例化的子模块内，见该子模块自己的独立审计条目）
- `ppg_chip_digital_top`.`w_idle_mux_async`（decl）：深度=2，链=w_idle_mux_async -> reg_idle_sync_meta -> reg_idle_sync_stable，判定=SAFE
- `ppg_control_top`.`i_clk_stage1_dout_low_async`（port）：判定=NOT_CONSUMED_IN_THIS_MODULE（该信号在本模块内只是端口直通给子实例，未被本模块任何always块读取；真实同步链在被例化的子模块内，见该子模块自己的独立审计条目）
- `ppg_control_top`.`i_clk_stage2_dout_low_async`（port）：判定=NOT_CONSUMED_IN_THIS_MODULE（该信号在本模块内只是端口直通给子实例，未被本模块任何always块读取；真实同步链在被例化的子模块内，见该子模块自己的独立审计条目）

## Class 2 复位释放审计（真实顶层ppg_chip_digital_top）

### (a) 标准ppg_reset_sync白名单实例
- 实例`ppg_reset_sync_clk2m_Inst`：class=2a, verdict=SAFE_IP_VERIFIED

### (b) 借用已同步常跑域复位的特例形态
- `w_source_rstn = w_rstn`：class=2b, verdict=SAFE_DOCUMENTED_BORROW

## Phase 2候选的Class 3最终分类（真实项目：0主候选 + 1门控候选）

（Phase2汇总：主候选0项，门控候选1项）

- `ppg_spi_register_file`.`reg_diag_snapshot`（direct_always_read）：class=3a, verdict=SAFE_GATED_CAPTURE
  - 门控信号`w_diag_snapshot_gate_event`：safe=True，追溯到白名单IP `ppg_pulse_cdc_sync` 实例 `ppg_pulse_cdc_sync_diag_ready_Inst` 的输出端口 `o_dest_pulse`，视为已经过安全CDC机制处理的信号
