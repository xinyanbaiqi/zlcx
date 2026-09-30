# legacy/ —— 已退役的testbench与脚本

这里的文件已经不再属于当前回归，原样保留（`git mv` 移入，历史可追溯），不删除。目录结构保持原来的相对路径：`legacy/rtl/...` 对应原来的 `rtl/...`，`legacy/tools/...` 对应原来的 `tools/...`。

退役依据见 `verification_reports/REGRESSION_BASELINE_20260930.md`（§6.3、§6.4）与 `verification_reports/TB_MAINTENANCE_20260930.md`。

| 文件 | 原位置 | 退役原因 |
|---|---|---|
| `rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller_wave.v` | `rtl/ppg_idac_code_controller/` | 2026-07-23/24 为 IDAC 控制器 **V1.0 接口**写的波形演示 TB（`i_analog_ready`、`i_cfg_shadow_*`、`o_idac_code` 等）。这套接口在 08-07 的 V2.0 重构中被整体替换，现在 xelab 报 19 个 `cannot find port`、4 个参数不存在，无法机械适配。它以 `$stop` 结尾停在 GUI，没有 `$finish`，本来就是给人看波形的演示，不是回归用例。当前控制器的自检回归是 `rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v`。 |
| `rtl/ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration.v` | `rtl/ppg_system_integration/` | 2026-08-16/17 的 scheduler+SSW+AMI 三模块联合 TB（文件头 V1.5）。它的职责已由 `rtl/ppg_control_top/` 下的 19-TB 主回归继承（19-TB 共用的 JNT 前缀 `tb_ppg_jnt_baseline_prefix.vh` 就源自这份 TB）。它落后于 RTL：3 个模块的 `i_run_generation`、scheduler 的 `i_owner_q3_window_closed`、AMI 的 `i_cal_owner_deadline_event` 等 14 个 08-17 之后新增的输入没有连接；JNT-08 仍然断言 STOP 拦截的在途 owner `success==1`，与合同规定矛盾（`.vh` 已修正，此处未回移）。另外，`$fopen` 在第 1713/5967/6456 行（外加第 6438 行的路径字符串）**写死了原始开发树 `D:/PPG/verilog/jxa/ppg_system_integration/` 的绝对路径**，在别的机器上无法正确运行。 |
| `tools/run_v1_3_scenarios.ps1` | `tools/` | 上面那份联合 TB 的逐场景驱动脚本：用 `--testplusarg SCENARIO1..11` 跑一个预先 elaborate 好的 snapshot。默认的 `OutputDir` 和 xsim 路径都写死了本机的绝对路径（`D:\PPG\verilog\jxa\...`、`C:\Xilinx\...`）。随联合 TB 一起退役。 |
| `tools/aggregate_v1_3_results.py` | `tools/` | 汇总上面脚本逐场景产出的 `tb_scenario_result.log`，只服务于这份联合 TB。随联合 TB 一起退役。 |
| `tools/aggregate_v1_3_results.ps1` | `tools/` | 同上的 PowerShell 版本，默认路径同样写死 jxa。随联合 TB 一起退役。 |

如果以后要恢复其中某一份，需要先按当前 RTL 接口适配端口、改掉绝对路径，再重新建基线；不要直接移回原处。
