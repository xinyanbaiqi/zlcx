# PPG Item 4b Phase 2 —— 跨域读取候选检测

检测范围：同一模块内的直接读取、经一跳组合 assign 的间接读取两类（严格按 Verilog 模块作用域，见脚本 docstring 的范围边界说明；不做跨模块数据流追踪；曾经尝试过的『组合直通到输出端口』第三类已因真实验证为纯噪音而移除，见脚本 docstring）。

## 扫描范围统计

- 真实扫描的非白名单模块数：24
- 白名单 IP 模块（跳过，理由见脚本 docstring）：ppg_config_cdc_bridge, ppg_pulse_cdc_sync, ppg_reset_sync
- 主候选（未门控/无法判定门控，Phase 2 验收口径的『候选』）总数：0
- 门控候选（已被独立条件门控，留给 Phase 3 判断门控信号本身是否安全）总数：1

## Phase 2 验证用例结果（依据 changelog 重建的合成负例 + 真实 V1.3 现状对照）

- [PASS] 合成负例（依据changelog重建，非真实历史文件）：V1.2无门控写法产出未门控主候选：主候选=1项, 门控候选=0项, 命中未门控reg_diag_snapshot被reg_diag_sync_meta读取的候选=True
- [PASS] 真实V1.3当前代码：reg_diag_snapshot_gated读取reg_diag_snapshot已从主候选消失，改列门控候选：是否仍在主候选=False（应为False）, 是否在门控候选=True（应为True）

**声明**：上面『合成负例』这个用例的输入文件是本次依据 `ppg_spi_register_file.v` V1.3 版本头 changelog 对 V1.2 旧实现的完整文字描述重建的最小片段（`ppg_system_integration/cross_reference_tools/_phase2_synthetic_v1_2_negative.v（运行期临时生成，运行后自动删除，不是长期留存的项目文件）`），**不是真实历史文件**——项目本身不是 git 仓库，V1.2 的真实源码不存在于任何快照目录里（同一结论 Phase 1 已经核实过，见规划文档）。

## 主候选列表（未门控/无法判定门控）

（无）

## 门控候选列表（已被独立条件门控，Phase 3 需要判断门控信号本身是否安全）

- [direct_always_read] `ppg_spi_register_file`.`reg_diag_snapshot`（写入域 CLK_2M）
  - 被同模块 line 548-554 的 SPI_SCLK 域 always 块门控读取
  - 证据行：`reg_diag_snapshot_gated <= reg_diag_snapshot; // 门控为真的这一拍，源端早已稳定多拍，安全整体捕获`
