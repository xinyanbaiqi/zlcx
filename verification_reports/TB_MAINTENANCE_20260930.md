# 模块级TB维护（任务A）报告（2026-09-30）

## 0. 结论先行

- **最终结果**：从 `18b748c` 用 `git archive` 导出到仓库外，**只用入库的入口脚本** `tools/run_unit_tb_regression.sh` 跑全部模块级 TB：**28/28 PASS**（芯片层级内 24/24，孤立模块 4/4）。summary 28 行都是单行；导出目录里没有产生任何 xsim 产物。28 份的 PASS/FAIL 行、结论横幅、`$finish` 时刻与参照**逐行相同**（未改动的 23 份对照 `REGRESSION_BASELINE_20260930` 的运行，改动过的 5 份对照 commit 2 的验证运行）。
- 基线报告中"6 份模块级 TB 落后于 RTL"的问题全部处理完毕：**4 份正式适配**（scheduler、idac_code_controller、amb_recheck、PWI），**2 份退役归档**（idac_wave、scheduler_ssw_ami 联合 TB）。另把 SID-05 新增的端口在 scheduler 与 AMI 两份单元 TB 里显式连上，没有加新断言。
- **没有改任何 RTL**（非 TB 的 `.v`），没有改 19-TB 的任何文件，也没有改 `contracts/` 和已有的 `verification_reports/` 报告。适配过程中没有发现 RTL 本身的问题，每份 TB 的失败根因都是"TB 落后"。
- 仿真器：本机 Vivado 2022.2 xsim（SW Build 3671981）；交叉验证用 Icarus Verilog 12.0。对比基线为 `REGRESSION_BASELINE_20260930.md`（被测 `e769a67`）。

## 1. Commit 清单（每个都可单独审阅、单独回退）

| # | commit | 内容 |
|---|---|---|
| 1 | `ba1c90e` | 回归脚本：修复 summary.tsv 计数拆行 bug；Vivado 路径改为可用 `VIVADO_BIN` 覆盖 |
| 2 | `9488360` | 4 份落后于 RTL 的模块级 TB 正式适配，并在 scheduler/AMI 单元 TB 中显式连接 SID-05 新端口 |
| 3 | `50a2b88` | 2 份退役 TB 与 3 个配套脚本 `git mv` 到 `legacy/`，新增 `legacy/README.md`，更新根 `README.md` |
| 4 | `18b748c` | 新增模块级统一入口 `tools/run_unit_tb_regression.sh` 与 `.gitignore`，并在根 `README.md` 补上用法 |
| 5 | （本报告） | `verification_reports/TB_MAINTENANCE_20260930.md` |

期间另一会话（SID-05 合同补记）在同一克隆中推送了 `a471fb8`（只含 `contracts/` 与一份新报告）。每次提交前都用 `ListAgents`/`SendMessage` 与它协调过，只 `git add` 具体文件。

## 2. Commit 1：回归脚本修复（`ba1c90e`）

- 文件：`rtl/ppg_control_top/run_xsim_regression.sh`、`rtl/ppg_chip_digital_top/run_xsim_regression.sh`。
- pass/fail/finished 三处计数：`x=$(grep -c … || echo 0)` 改为 `x=$(grep -c … 2>/dev/null); x=${x:-0}`。原写法在 0 匹配时，`grep -c` 先打印 `0` 并返回 1，于是又追加一个 `0`，变量变成 `"0\n0"`，把 summary 拆成两行。
- `export PATH="${VIVADO_BIN:-/c/Xilinx/Vivado/2022.2/bin}:$PATH"`，默认值不变。
- 验证（不涉及 TB/RTL，所以没有重跑 19-TB 全套）：
  1. 从修好的脚本里原样抽出这 3 行计数逻辑，套到 `e769a67_20260930` 那次留下的 19 份 `xsim.log` 上：19 行都是单行、字段全为数字，合计 **1208 / 0 / finished 19**；对空日志得到 `0/0/0`。
  2. 芯片顶层脚本在仓库外的导出目录中完整运行两次（默认路径一次、显式设置 `VIVADO_BIN` 一次）：都是 **6 PASS / 0 FAIL / finished 1**，summary 为单行。反向检查：把 `VIVADO_BIN` 指向不存在的目录时找不到 `xvlog.bat`，说明覆盖值确实生效。

## 3. Commit 2：4 份 TB 适配 + SID-05 端口显式化（`9488360`）

每份 TB 都在文件头的中英双语 changelog 里新增了一条版本记录，并更新了版本号与修订日期。xsim 与 iverilog 结果一致；改动后的结果与基线报告中的诊断副本逐行相同。

| TB | 新版本 | 改动 | 语义理由 | PASS：历史 → 基线 → 诊断副本 → 本次 |
|---|---|---|---|---|
| `tb_ppg_400hz_frame_calibration_scheduler.v` | V1.5→**V1.6** | `.i_owner_q3_window_closed(1'b1)`；`o_cal_owner_deadline_event` 接观察用 wire（新声明） | 接 1 等于恢复 scheduler 合同 V1.8（08-30，LFA-06）之前"在途 owner 的 Q3 窗口随时算已关闭"的行为，而 FSC 全部用例正是按这个环境写的。Q3 门控本身的覆盖在 19-TB 的 LFA-06 证据里，单元 TB 不重复测。附带效果：端口浮空时 FSC-34（`cnt_normal_complete==0`）属于空过，现在是真实检查 | 文件头 FSC-01~59（59）→ 58/1 → 59/0 → **59/0**（`FSC-01 through FSC-59: pass=59 fail=0`，`$finish` 10389750 ns 不变） |
| `tb_ppg_idac_code_controller.v` | V2.1→**V2.2** | 新增 `C_RUN_GENERATION_WIDTH=8` 并显式传参；新增 reg `i_run_generation`，初值 0、全程不变，接到 DUT | 控制器 RTL V2.2（08-22）新增的代际端口，此前一直悬空，X 污染了 pending 候选的代际锁存与比较。本 TB 没有用例测跨代际拒绝，所以用固定代际。测试注入输入有意保持不连（`C_ENABLE_TEST_INJECTION` 默认 0，已被门控屏蔽） | changelog 无计数 → 67 行 PASS / 34 行 FAIL（33 errors）→ 148/0（仅接 `i_run_generation`）→ **148/0** |
| `tb_ppg_amb_recheck_scheduler.v` | V1.0→**V1.1** | `.i_adc_idle(i_adc_idle)` → `.i_precision_takeover_safe(i_adc_idle)` | RTL V1.1（08-23）是纯端口改名，逻辑不变；TB 侧激励 reg 保持原名 | changelog 无计数 → xelab 失败 → 35/0 → **35/0**（34 条检查 + 1 条最终汇总） |
| `tb_ppg_precision_window_integration.v`（PWI） | V1.0→**V1.1** | 删除 `.i_stop_ack_event`、`.i_control_abort_event` 两处连接（RTL V1.1 已删除这两个端口）；`.i_adc_idle` 改名为 `.i_precision_takeover_safe`；`.i_sample_valid(1'b1)`；`i_run_generation`、`i_detection_discard_*` 整组（15 个）和两个测试注入输入显式接位宽正确的非活动常量 | `i_sample_valid` 是 RTL V1.1 新增的"独立样本资格"，为 0 时事务只释放握手、不进入算法历史。本 TB 驱动的每笔 NORMAL 事务都是合格样本，所以接 1，即该端口加入之前的行为。本 TB 不测代际清空，所以代际/discard 组接非活动常量（诊断副本就是在这个条件下 5/5 通过的；如果只做前三项，这些端口会继续悬空成 X）。TB 侧的 stop/abort 寄存器保留，但已不再使用 | 历史 5（PWI-01~05）→ xelab 失败 → 5/5 → **5/5**（`ALL PWI-01 THROUGH PWI-05 PASS count=5`） |
| `tb_ppg_adc_measurement_idac_integration.v`（AMI 单元 TB） | V1.8→**V1.9** | 新增 reg `i_cal_owner_deadline_event`，在初始化块中置 0（放在 `i_system_fault_discard_event` 旁），接到 DUT | SID-05（09-18）新增的输入，原来悬空；浮空的 Z 在本 TB 中只等价于 0（基线 §6.6 的 tie-0 探针已经证明过）。本 TB 没有 scheduler，不可能出现截止事件。**不加新断言**，tick-248 的专门测试留给任务 C | 48（09-08）→ 48 → — → **48**，与基线**逐行相同**（`$finish` 103420 ns 不变） |

**PWI 的 5 条检查确实在执行（负向对照）**：这 5 条检查断言的都是必须真实发生的正向事件（`cnt_fine_start_event==1`、`cnt_return_event==1`、`o_fir_history_full_r/ir`、斜率保持等）。用准备提交的这版文件做对照，只把 `.i_sample_valid(1'b1)` 改成 `1'b0` 重跑：结果 `FAIL PWI-01..05 … mode=0 fine=0 cross=0 peak=0 valley=0 return=0 recheck=0`，`PWI REGRESSION FAIL pass=0 fail=5`。样本一旦不进入算法历史，5 条就全部失败，所以它们不是空过。

**SID-05 端口对账**（应 SID-05 合同补记会话请求在此写明，对应它的报告 `CONTRACT_SYNC_SID05_20260930.md` 第 7.2 节，以及批次 2 报告第 7.3 节）：
- scheduler 单元 TB：`o_cal_owner_deadline_event` 已接到 wire `o_cal_owner_deadline_event`，仅观察，没有断言。
- AMI 单元 TB：`i_cal_owner_deadline_event` 由初值 0 的 reg 显式驱动，没有断言。

**适配后仍然悬空的输入**（iverilog `-Wall` 普查）：只剩 idac TB 的 `i_test_inject_enable`/`i_test_saturation_inject_valid`，以及 AMI TB 的 6 个 `i_test_*` 注入端口。它们都被 `C_ENABLE_TEST_INJECTION=0` 门控屏蔽，属于有意保留；scheduler、amb、PWI 三份已经没有任何悬空输入。xelab 剩下的警告只有悬空的**输出**（如 `o_scheduler_fault_valid`、`o_detection_datapath_empty`），无害。

## 4. Commit 3：退役归档（`50a2b88`）

用 `git mv` 就地移入 `legacy/`（不留副本），保持原来的相对路径：

| 文件 | 新位置 | 退役原因 |
|---|---|---|
| `tb_ppg_idac_code_controller_wave.v` | `legacy/rtl/ppg_idac_code_controller/` | 07-23/24 为 IDAC 控制器 V1.0 接口写的波形演示 TB。接口在 08-07 的 V2.0 重构中被整体替换，xelab 报 19 个端口不存在；以 `$stop` 结尾停在 GUI、没有 `$finish`，本来就不是回归用例 |
| `tb_ppg_scheduler_ssw_ami_integration.v` | `legacy/rtl/ppg_system_integration/` | 08 月的三模块联合 TB，职责已由 19-TB 继承（JNT 前缀源自此 TB）。14 个新输入未连接；JNT-08 仍断言 `success==1`，与合同矛盾；`$fopen` 写死了 jxa 绝对路径 |
| `run_v1_3_scenarios.ps1` | `legacy/tools/` | 上面联合 TB 的逐场景（`--testplusarg SCENARIO1..11`）驱动脚本，默认输出目录与 xsim 路径写死了 jxa/`C:\Xilinx` |
| `aggregate_v1_3_results.py`、`aggregate_v1_3_results.ps1` | `legacy/tools/` | 只汇总上面脚本的逐场景结果；ps1 的默认路径同样写死 jxa |

- `legacy/README.md` 逐个写明了退役原因。
- 根 `README.md`：目录树加上 `legacy/`；`rtl/` 段落中"`rtl/ppg_system_integration/` 只含一份跨模块联合testbench"改为说明它已退役及去向；`tools/` 段落删除对 v1_3 脚本的描述并说明去向；新增 `legacy/` 一节。
- 移走之后 `rtl/ppg_system_integration/` 成了空目录，已删除。

### 4.1 仓库中对已归档文件的引用（只列出，未改）

按**文件名**精确搜索（不含 `legacy/` 自身）。`ppg_system_integration/` 这个目录名在 `contracts/` 中出现上千次，但绝大多数指的是原始开发树里同名目录下的合同与报告，不是这份 TB，所以不计入。

| 位置 | 引用 |
|---|---|
| `contracts/PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md:420` | `tb_ppg_scheduler_ssw_ami_integration.v` |
| `verification_reports/CONTRACT_SYNC_SID05_20260930.md:299` | `tb_ppg_scheduler_ssw_ami_integration.v` |
| `verification_reports/JNT_01_09_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md:7, 26` | `tb_ppg_scheduler_ssw_ami_integration.v` |
| `verification_reports/REGRESSION_BASELINE_20260930.md:126, 135, 150, 177, 181` | `tb_ppg_idac_code_controller_wave`、`tb_ppg_scheduler_ssw_ami_integration(.v)` |
| `rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh:47, 198`（19-TB 文件，按边界不改） | `tb_ppg_scheduler_ssw_ami_integration.v`（JNT 前缀来源的历史注释） |
| `tools/cross_reference_tools/cdc_domain_reachability_report.md:90, 98`（另有同名 `.json`） | 两份 TB 各 1 处（历史 CDC 扫描报告中的文件清单） |
| `_build_manifest.tsv:94, 182, 183, 208, 209` | 5 个文件都在（打包清单，记录了当时的原位置） |

以上引用中，合同与报告交由合同会话处理；`tb_ppg_jnt_baseline_prefix.vh`、CDC 历史报告和 `_build_manifest.tsv` 都是历史记录性质的引用，本次没有改动。

## 5. Commit 4：模块级统一入口（`18b748c`）

**位置**：`tools/run_unit_tb_regression.sh`（放在 `tools/` 下：它跨越所有 `rtl/` 子目录，不属于某一个模块）。git 文件模式与现有两个 `run_xsim_regression.sh` 一致（100644），用 `bash` 调用。

**用法**：

```bash
bash tools/run_unit_tb_regression.sh [-o OUT_DIR] [-g hier|orphan|all] [TB_NAME ...]
VIVADO_BIN=/opt/Xilinx/Vivado/2022.2/bin bash tools/run_unit_tb_regression.sh -g orphan
```

- 仓库根由脚本自身位置推出（`$(dirname "$0")/..`），不含任何 jxa 或盘符路径；Windows 下传给 Vivado 的路径用 `cygpath -m` 转成 `D:/…` 形式（这正是上次临时 runner 踩过的坑）。在 Windows 上调用 `xvlog.bat` 等，在 Linux 上调用 `xvlog`。
- `VIVADO_BIN` 覆盖 Vivado 路径，默认 `/c/Xilinx/Vivado/2022.2/bin`。
- 输出目录：`-o` 指定；默认为 `<仓库同级>/ppg_unit_tb_runs/<YYYYmmdd_HHMMSS>`。指向仓库内的目录会被拒绝，而且判断发生在创建目录**之前**：自测时 `./rtl/x`、`D:/…/repo/x`、`D:\…\repo\x`、`../repo/x` 四种写法都返回 2，并且没有留下任何目录。第一版是先 `mkdir` 再判断，会留下一个空目录，已在提交前修正。
- 每份 TB 的依赖文件清单写在脚本的 `TB_TABLE` 里，是用 `iverilog -y <各 rtl 目录> -M` 由真实工具推出的**精确编译闭包**（`tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence` 是自包含的算术等价自检，不依赖任何 RTL）。分组标注为 `hier`（24 份）和 `orphan`（4 份：dual_precision_top、timing_sar9、timing_sar15、timing_3200hz）。
- 通过判据与基线一致：xvlog/xelab/xsim 返回码都为 0；有 `$finish called`；没有 `^FAIL`/`^[FAIL]`/`[t] ID FAIL`/`ERROR:`/`FATAL`；TB 自己的结论横幅（每份 TB 一条锚定的 ERE，计数部分用 `[0-9]+`）存在。
- `unit_summary.tsv` 每个 TB 一行，列为：group、tb、三步返回码、finish、fail_lines、banner、verdict、dur_s、banner_line。计数一律采用"先取值、为空补 0"的写法，不会再拆行。退出码：全过为 0，有失败为 1，用法错误为 2。
- 负向自测：把脚本复制到旧的 `e769a67` 导出树里跑 scheduler/idac/amb/supervisor，结果前三份判 FAIL（分别是仿真 FAIL + 缺横幅、xelab=1、34 行 FAIL），supervisor 判 PASS，退出码 1。说明判据确实能判出失败。
- `.gitignore`：忽略 `xsim.dir/`、`*.jou`、`*.pb`、`*.log`、`*.wdb`、`*.str`、`xsim_regression_*/`、`.Xil/`、`webtalk*`、`*.vvp`、`*.vcd` 等。用 `git ls-files -ci --exclude-standard` 核对过：没有命中任何已跟踪文件。

## 6. 最终验证：干净导出 + 入库入口脚本

- 做法：`git archive 18b748c | tar -x` 导出到 `D:\PPG\verilog\ppg_regression_runs\tbmaint_final_plainarchive_18b748c\`，在该目录内执行 `bash tools/run_unit_tb_regression.sh -o D:\PPG\verilog\ppg_regression_runs\tbmaint_final_unit_18b748c`（19:44:00 → 19:51:38）。
- 关于导出时的行尾：这次有意用**普通的** `git archive`（不加 `-c core.autocrlf=false`），也就是使用者最可能的做法。该克隆设置了 `core.autocrlf=true`，所以导出的 `.sh` 是 CRLF；Git for Windows 的 bash 可以直接执行，结果正常。在 Linux 上通常不开 autocrlf，得到的本来就是 LF。
- 结果：**run=28 pass=28 fail=0**，退出码 0；导出树中 xsim 产物数量为 0。

| group | TB | xvlog/xelab/xsim | finish | fail_lines | 结论横幅 | 耗时 s |
|---|---|---|---|---|---|---|
| hier | tb_ppg_400hz_frame_calibration_scheduler | 0/0/0 | 1 | 0 | `ALL FSC-01 THROUGH FSC-59 PASSED` | 10 |
| hier | tb_ppg_active_v4_control_plane_integration | 0/0/0 | 1 | 0 | `ALL AV4C-01 THROUGH AV4C-22 PASSED` | 9 |
| hier | tb_ppg_adc_async_stage_capture | 0/0/0 | 1 | 0 | `PASS ppg_adc_async_stage_capture explicit-frame checks` | 8 |
| hier | tb_ppg_adc_dc_recovery | 0/0/0 | 1 | 0 | `PASS ppg_adc_dc_recovery DCR-01..DCR-22` | 9 |
| hier | tb_ppg_adc_measurement_idac_integration | 0/0/0 | 1 | 0 | `AMI-01 through AMI-47 plus N08-01 PASS: 48 real comparisons` | 14 |
| hier | tb_ppg_adc_pipeline_overlap_corrector | 0/0/0 | 1 | 0 | `PASS … OVL-01..OVL-17 and 1024-code sweep` | 15 |
| hier | tb_ppg_adc_programmable_reconstructor | 0/0/0 | 1 | 0 | `PASS … PR-01..PR-14 and 1024-code sweep` | 94 |
| hier | tb_ppg_adc_result_router | 0/0/0 | 1 | 0 | `PASS ppg_adc_result_router RTR-01..RTR-13` | 8 |
| hier | tb_ppg_adc_s1_programmable_calibrator | 0/0/0 | 1 | 0 | `PASS … CAL-01..CAL-17` | 39 |
| hier | tb_ppg_adc_s1_redundancy_corrector | 0/0/0 | 1 | 0 | `PASS … integrated exhaustive checks` | 54 |
| hier | tb_ppg_amb_recheck_scheduler | 0/0/0 | 1 | 0 | `PASS: ppg_amb_recheck_scheduler completed scheduler regression` | 9 |
| hier | tb_ppg_characterization_control_cdc | 0/0/0 | 1 | 0 | `ALL CCC-01 TO CCC-26 PASS (26 checks)` | 8 |
| hier | tb_ppg_coarse_detection_fir | 0/0/0 | 1 | 0 | `PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=103` | 10 |
| hier | tb_ppg_dynamic_baseline_cross_detector | 0/0/0 | 1 | 0 | `ALL BSL-01 … OPTC-02 PASS count=65` | 10 |
| hier | tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence | 0/0/0 | 1 | 0 | `PHASE_A_ARITH_EQV PASS vectors=20005` | 9 |
| hier | tb_ppg_idac_code_controller | 0/0/0 | 1 | 0 | `PASS: ppg_idac_code_controller V2.1 periodic sequence and IDT regression completed` | 12 |
| hier | tb_ppg_normal_transaction_fork | 0/0/0 | 1 | 0 | `PASS: … FFK-01 through FFK-09` | 9 |
| hier | tb_ppg_peak_valley_window_detector | 0/0/0 | 1 | 0 | `PVW-01 through PVW-48 ALL PASS: 54 checks` | 13 |
| hier | tb_ppg_precision_window_controller | 0/0/0 | 1 | 0 | `PWC-01 through PWC-41 ALL PASS pass=48 fail=0` | 9 |
| hier | tb_ppg_precision_window_integration | 0/0/0 | 1 | 0 | `ALL PWI-01 THROUGH PWI-05 PASS count=5` | 13 |
| hier | tb_ppg_sar9_sar15_safe_selection_wrapper | 0/0/0 | 1 | 0 | `ALL SSW-01 THROUGH SSW-52 PASS` | 11 |
| hier | tb_ppg_system_active_config_unpack | 0/0/0 | 1 | 0 | `PASS: … all checks passed` | 8 |
| hier | tb_ppg_system_config_manager | 0/0/0 | 1 | 0 | `PASS: … MGR-01 through MGR-24 all directed checks passed` | 11 |
| hier | tb_ppg_system_fault_abort_supervisor | 0/0/0 | 1 | 0 | `SUP-01 through SUP-10 PASS: 14 real comparisons` | 8 |
| orphan | tb_ppg_dual_precision_top | 0/0/0 | 1 | 0 | `PASS: ppg_dual_precision_top CDC and frame-safe timing contract verified` | 10 |
| orphan | tb_ppg_timing_sar9 | 0/0/0 | 1 | 0 | `PASS: ppg_timing_sar9 … modes matched.` | 9 |
| orphan | tb_ppg_timing_sar15 | 0/0/0 | 1 | 0 | `PASS: ppg_timing_sar15 … modes matched.` | 9 |
| orphan | tb_ppg_timing_3200hz | 0/0/0 | 1 | 0 | `PASS: 3200 Hz frame, 80 us R/IR offsets, and Q3-center alignment verified.` | 10 |

与基线对比：基线的模块级是 30 份中 24 份通过；本次是在册的 28 份全部通过，另外 2 份已退役。

## 7. 留给后续的事项（本任务范围外）

- 19-TB 中 4 份（injection/lifecycle/owner_identity/startup）打开了 `C_ENABLE_TEST_INJECTION=1`，却让 `i_test_calibration_loss_inject_valid` 悬空，存在潜在 X 风险（基线 §6.6）。按约定留给任务 C，与 tick-248 修复合并处理，再做一次全套回归。
- §4.1 列出的合同/报告对已归档文件的引用，由合同会话决定是否修改。
- `tb_ppg_idac_code_controller.v` 的最终横幅文字仍写着 "V2.1"（打印的字符串，未改，以免改动判据字符串）；入口脚本的横幅判据是按这个原文写的。

## 8. 产物位置（仓库外，未提交）

- commit 1 验证：`D:\PPG\verilog\ppg_regression_runs\tbmaint_c1_scriptfix_20260930\`
- commit 2 验证（5 份 TB 的 xsim 运行、PWI 负向对照）：`D:\PPG\verilog\ppg_regression_runs\tbmaint_c2_adapt_20260930\`
- 入口脚本负向自测：`D:\PPG\verilog\ppg_regression_runs\tbmaint_c4_negtest\`
- 最终验证：导出树 `tbmaint_final_plainarchive_18b748c\`，输出 `tbmaint_final_unit_18b748c\`（含 `unit_summary.tsv`），驱动日志 `tbmaint_final_driver.log`
