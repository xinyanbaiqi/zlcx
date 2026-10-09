# 基线`7a8eabf`回归证据（本机Vivado 2019.2，部分完成）

- 机器：i7-10510U笔记本，Windows 11 + Git Bash，`VIVADO_BIN=/d/vivado/2019.2/bin`。导出方式按交接书§6.8：`git -c core.autocrlf=false archive 7a8eabf | tar -x`，导出到仓库外目录。
- 分组：系统TB分4组并行，只改各组本地运行副本的`ORDER=(...)`数组（见进度文件条目2）。芯片TB与模块级`-g all`同时运行。
- 每个TB两个文件：
  - `<tb>.pass_sorted.txt`：按交接书§6.8口径（`grep -E '\bPASS\b'`，排除含`pass=`的行）提取后排序；
  - `<tb>.finish.txt`：`$finish`行，绝对路径已缩成文件名，便于不同机器、不同目录之间比对。
- 汇总在`index.tsv`。

## 结果

| 部分 | 本机结果 | 参考值（统筹机器，`545abfd`，Vivado 2022.2） |
|---|---|---|
| 系统TB | 16/20完成，全部rc=0、0 FAIL、`$finish`各1次，PASS 985行 | 20/20，1250行 |
| 芯片 | 20/0，PASS 20行 | 20/0 |
| 模块级 | 27/28 PASS | 28/28 |

**未完成的系统TB（4份）**：本机Claude进程退出时（2026-10-09约14:22），后台仿真被一并结束。
- `tb_ppg_control_top_baseline_cross`（g1，已运行约10分钟，中断）
- `tb_ppg_control_top_robustness_corner_waveforms`（g4，已运行约1小时40分钟，中断）
- `tb_ppg_control_top_startup_idac_calibration`（g4，未开始）
- `tb_ppg_control_top_adc_anomaly`（g4，未开始）

这4份改在另一台机器上补跑，见`../BASELINE_RERUN_REQUEST.md`。

**模块级失败1份：`tb_ppg_coarse_detection_fir`**
- xvlog通过；xelab在"Completed static elaboration"之后崩溃（`ERROR: [XSIM 43-3294] Signal EXCEPTION_ACCESS_VIOLATION received`，栈在`ISIMC::VlogCompiler::transform`）。
- 无其它负载时单独重跑两次（默认设置；`-mt off`），都在同一位置崩溃（退出码127）。判定为Vivado 2019.2 xelab对该TB的确定性工具缺陷，与并行负载无关。
- 按用户规则，没有为迁就版本改RTL/TB。该TB在本机无法得到PASS行，须在Vivado 2022.2上运行。
