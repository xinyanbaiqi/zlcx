# 阶段3 TB标签改名证明（2026-10-09）

前提：回归机基线（`ea60432`，Vivado 2022.2）与参考值一致：系统20/20、PASS 1250行、芯片20/0、模块级28/28；
`index.tsv`中49个TB全部rc=0、verdict PASS、`$finish`各1次。核对通过后才执行本次改名。

改名脚本：`tools/b_merge_tools/tb_rename.py`（每处替换都断言出现次数）。改动范围：

| 文件 | 字符串改动 | 文件头 |
|---|---|---|
| `tb_ppg_400hz_frame_calibration_scheduler.v` | `check_fsc`打印`SCHT-n`（原`FSC-n`），两行总横幅同步；`check_fsc`实参不变（交接书Q3） | V1.10→V1.11 |
| `tb_ppg_system_fault_abort_supervisor.v` | SUP03A→CLRBLK、SUP06A→EPICLS、SUP09A→WDIDLE、SUP10A→EPI2ND；总横幅只列实际检查的SUP条目 | V1.4→V1.5 |
| `tb_ppg_adc_dc_recovery.v` | `drive_and_check`的FAIL行打印`DCRT-n`；PASS横幅不再宣称DCR-01..DCR-22（`test_id`参与激励，未改） | V1.1→V1.2 |
| `tb_ppg_sar9_sar15_safe_selection_wrapper.v` | 用例SSW-18→CAL-ODL | V1.8→V1.9 |
| `tb_ppg_adc_measurement_idac_integration.v` | 检查AMI-13→FORK-HOLD；总横幅注明例外 | V1.14→V1.15 |
| `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` | LFA-11a→AUTOABT-QUIET（3行打印），另有2处注释同步 | V1.4→V1.5 |
| `tools/run_unit_tb_regression.sh` | 调度器、DCR、AMI、supervisor四个TB的横幅判据正则同步（交接书Q3） | — |

完整diff：`tb_rename_diff.txt`。

## 证明

1. **`strip_compare.txt`**：`strip_compare.py --strings 7a8eabf`（去掉注释和字符串内容）6个TB全部IDENTICAL。
   不加`--strings`时全部DIFFERENT（标签字符串确实改了）。
   负对照：把supervisor TB中CLRBLK检查的`1'b1`改为`1'b0`，结果报DIFFERENT；恢复后IDENTICAL。
   本次给`strip_compare.py`加了一条规则：只含空白的行不参与比较。原因是新增的整行修订记录注释去掉后会留下空行。
   加规则后重跑f8986b3的RTL注释证明，仍为IDENTICAL。
2. **`tb_gate_compare.txt`**：skill的deliverable gate在基线副本和改后副本上各跑一次（`tb_gate_baseline_7a8eabf.*`、`tb_gate_branch.*`）。
   这些TB在基线上本来就不满足strict（715个error：COMMENT_COMMENT_PLACEMENT 714、VG000 1），因此判据是“不新增发现”。
   按文件和规则计数，两边逐项相同。按（文件、规则、级别、去掉行号的消息）比对，唯一的差异是VG000消息里的临时目录名（tbbase/tbnew），属于副本目录名不同，不是新发现。
   比对脚本：`tools/b_merge_tools/gate_compare.py`。

## 别名表

`tools/b_merge_tools/alias_draft_renamed.md`（`affd3e3`）的两小节已写入`contracts/PPG_ALIAS_MAPPING_TABLE.md`“B合同合并批次新增映射”一节，与TB改名同一提交：
57行合同FSC-nn ↔ TB本地SCHT-n，以及SUP/DCR/SSW-18/AMI-13/LFA-11各行。
旧行中引用改名标签的LFA-11、P03、P09、N06四行，已在原文旁注明新名。

anchor_check：新写入各行的符号锚点和`@satisfies`锚点全部通过。别名表剩下的报错是746个旧行号锚点（阶段4转换）和第118行的`§9.2.2`，与写入前相同。
