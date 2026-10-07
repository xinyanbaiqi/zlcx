# owner生命周期轮 第二步（实现）交接（2026-10-07，分支 `wip/owner-lifecycle`）

本轮（F-020、S1、L-1~L-5，方案甲）的设计与RTL实现已在本机完成，第三步（验证）改在云端会话进行（用户2026-10-07经"Erie Verilog Generator 配置"会话安排，并在本会话确认）。

- **基线**：origin/main `0ffb439`（RTL与`05a31cf`相同）。本分支RTL提交为`bddf70e`。
- **分支规则**：本分支不合并到main。合并前必须同时满足：第三步全部完成；本机xsim全套回归（19-TB、芯片、模块级）与05a31cf逐TB比对通过。
- **设计文档**：`verification_reports/OWNER_LIFECYCLE_DESIGN_20261007.md`。第0~9节为设计，第10~11节为用户两轮裁定及附加要求（逐条）。本文件不重复设计，只列交接事项。

## (a) 已完成内容

### a.1 用户裁定（摘要，细节见设计文档§10、§11）
| 项 | 裁定 |
|---|---|
| T-lost | 4500拍（按owner自start fire起的年龄计；须大于实测最晚合法迟到4355拍，且小于NORMAL下一帧同色接管4717拍） |
| k | 2，**按槽位**（RED/IR/CAL）分别计连续作废，只有同槽位与owner匹配的真实完成清零；截止撤销不计 |
| 原因码 | measurement discard `2'b11`=COMPLETION_LOST；cause `8'h06`（同槽位连续丢失，source 4'h1，summary bit 9）；cause `8'h07`（ADC在owner在途时≥9000拍不回物理空闲，source 4'h1，summary bit 10） |
| 发起方 | AMI发起作废（唯一裁决点）；作废拍复用`o_adc_complete_sample_index`送序号 |
| sticky | 放AMI：`o_owner_lost_sticky`→control_top `o_ami_owner_lost_sticky`→SPI 0x0108 bit6；清除规则同N-1（复位清；诊断清除在lane 06未保持或"RUN已由STOP结束且排空"时可清；START不清；新作废优先于同拍清除） |
| L-5 | 本轮修复：lane 01/02/03/06/07增加"`flag_run_context_ended && o_datapath_empty`"清零；置位优先；`flag_integration_blocking`生命周期不变 |
| 捕获模块 | 不改`ppg_adc_async_stage_capture`；作废条件在AMI同拍原子判断（物理idle、`!flag_capture_valid`、`!flag_adc_completion_pending`）；同步链约2拍不可消除窗口写为合同前提 |

### a.2 改动文件（9个RTL + 4个TB接地）
| 文件 | 版本 | 改动 |
|---|---|---|
| `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v` | V1.16→V1.17 | 作废判定、owner年龄计数、按槽位k计数、lane 06/07及分发、discard 11、lost sticky、撤销合并（SID-05+校准作废→`flag_calibration_request_inflight`与PWI）、L-5 lane清零 |
| `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v` | V1.10→V1.11 | 作废匹配释放、L-4过期候选屏蔽、L-1去掉宏帧末`B_INFLIGHT`重挂、L-3空闲IDAC边界 |
| `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v` | V1.6→V1.7 | 作废释放；owner与帧/子帧绑定（`flag_red/ir/cal_has_owner`）；S1 sticky改写 |
| `rtl/ppg_precision_window_integration/ppg_precision_window_integration.v` | V1.4→V1.5 | 撤销事件透传（F-020） |
| `rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v` | V1.1→V1.2 | 撤销清`flag_sample_inflight`（F-020） |
| `rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v` | V1.0→V1.1 | summary映射加06→bit9、07→bit10 |
| `rtl/ppg_control_top/ppg_control_top.v` | V1.6→V1.7 | 连线；新输出`o_ami_owner_lost_sticky` |
| `rtl/ppg_chip_digital_top/ppg_chip_digital_top.v` | V1.2→V1.3 | 连线 |
| `rtl/ppg_spi_register_file/ppg_spi_register_file.v` | V1.4→V1.5 | 0x0108 bit6 |
| TB（仅新输入接地，见a.5） | — | scheduler、SSW、PWI、重检调度器单元TB |

### a.3 端口/信号/标签增删改（按符号锚点）
- **新增端口**：
  - AMI：`o_adc_transaction_lost_event`、`o_owner_lost_sticky`；新参数`C_ADC_COMPLETION_LOST_CYCLES=4500`、`C_ADC_COMPLETION_LOST_LIMIT=2`。
  - 调度器：`i_adc_transaction_lost_event`、`i_idac_boundary_request`。
  - SSW：`i_adc_transaction_lost_event`。
  - PWI、重检调度器：`i_calibration_request_withdraw_event`。
  - control_top：`o_ami_owner_lost_sticky`。
  - SPI：`i_ami_owner_lost_sticky`。
- **端口语义扩展**：AMI `o_adc_complete_sample_index`在作废拍也有效（全部RTL接收方已核对：调度器`flag_completion_match`/`flag_owner_lost_match`、SSW`flag_owner_release`/`flag_done_mismatch`都以事件限定；control_top只转发；OIB TB以`complete_event && success`限定）。
- **端口新接线**：control_top原悬空的AMI `o_amb/dcs_r/dcs_ir_pending_valid`现合并为`flag_idac_boundary_request`。
- **新增内部信号**：
  - AMI：`cnt_owner_age`、`cnt_lost_red/ir/cal`、`flag_owner_lost_fault_hold`(lane 06)、`flag_adc_busy_fault_hold`(lane 07)、`flag_ami_fault_pending_06/07`、`flag_ami_fault_dispatch_06/07`、`flag_owner_lost_fire`、`flag_adc_busy_fault_fire`、`flag_owner_slot_red/ir/cal`、`flag_owner_alive_completion`、`flag_owner_lost_limit_reached`、`flag_calibration_request_withdraw`、`flag_recheck_request_withdraw`、`flag_run_context_drained`、`adc_transaction_lost_event_o`、`owner_lost_sticky_o`；localparam `DISCARD_REASON_COMPLETION_LOST`、`ADC_BUSY_FAULT_CYCLES`。
  - 调度器：`flag_owner_lost_match`、`flag_candidate_expired`、`flag_idle_idac_safe_boundary`。
  - SSW：`reg_owner_cal_subframe`。
  - control_top：`ami_adc_transaction_lost_event_o`、`ami_amb/dcs_r/dcs_ir_pending_valid_o`、`flag_idac_boundary_request`、`ami_owner_lost_sticky_o`。
- **语义改变的既有信号**：
  - SSW `flag_red/ir/cal_has_owner`（加绑定）、`calibration_timeout_sticky_o`（S1）；
  - AMI `o_wrapper_fault_blocking`、`o_ami_fault_active`（加lane 06/07）、lane 01/02/03（加RUN结束排空清零）、`flag_calibration_request_inflight`清零源；
  - 调度器`transaction_start_valid_o`、`idac_code_safe_boundary_o`、宏帧末重挂条件。
- **新增`@satisfies`锚点**：
  - AMI：作废判定/作废事件→AMI-39, LFA-04；在途释放→AMI-40；lane清零与sticky→AMI-24；lane 06→SUP-08；撤销合并→SID-05。
  - 调度器：作废匹配→FSC-54；L-4→FSC-46, FSC-49, FSC-50；L-3→FSC-19；L-1→FSC-17。
  - SSW：绑定→SSW-38, SSW-34；作废释放/错配→SSW-42；S1→SSW-18。
  - 重检调度器：SID-05。supervisor：P09。
- **删除/改名**：无。

## (b) 门禁与-Wall前后对比
- **deliverable gate**：9个RTL文件修改前（`gate_before_r2`，取自0ffb439）与修改后的问题集逐条相同，只有行号移动。
  - 调度器、重检调度器、supervisor、SPI：0/0。
  - AMI：错误2/strict 1，既有。
  - PWI：strict 1，既有。
  - SSW：错误10，既有。
  - control_top：VG031×1，既有。
  - 芯片顶层：VG010×46，既有。
  - 修改过程中gate抓到的新增问题已全部改正：VG060注释列对齐38处；VG066近似重复注释7处，已改写为各自独立的语义。
- **iverilog -Wall**：芯片全层次（`-s ppg_chip_digital_top`，filelist中除tb_外全部文件），修改前0条，修改后0条。
- 模块级TB -Wall新旧对比未做，列入第三步（脚本`workflow_scripts/unitwall.py`，需改路径）。

## (c) 本机检查点结果
见文末"本机检查点回归"一节。结论：模块级28/28、smoke与05a31cf逐行一致。唯一变化是L-5的有意改变，现有检查没有被破坏。

## (d) 第三步待做清单（云端）

**d.1 单元级断言与负对照**
- 每条都要满足：修复前或去掉修复项时FAIL，修复后PASS。
- 一律用TB本地名，注明服务的F/L号；不接合同族编号，也不在TB最后一个编号上+1。
- 起名前grep对应合同验收表和全仓库，确认无撞号。
- 注意check_case标签位宽：AMI 11字符、supervisor 6、PVW 16、SSW 8，打印用`%0s`。

| 模块TB | 检查 | 负对照 |
|---|---|---|
| 调度器 | ①作废匹配释放`B_INFLIGHT`、置帧失败、不置RED/IR_DONE；②不匹配作废→`B_COMPLETION_MISMATCH`；③L-1：宏帧末`B_INFLIGHT`时不重挂；④L-4：RED/IR/CAL过期不提交、截止当拍仍提交、过期拍截止收尾；⑤L-3：空闲边界单拍，NORMAL资格成立时不出现，本拍将开帧时不出现，`STARTUP_PENDING`时不出现 | 分别恢复旧逻辑 |
| SSW | ①作废释放；②旧owner跨入下一帧同色上下文时不驱动Q3、截止sticky照常置位；③S1：迟到置、按时不置、上一子帧owner不置、帧号不同不置 | 去绑定项；恢复旧sticky条件 |
| AMI | ①作废条件各项（年龄、idle、`capture_valid`、`completion_pending`、同拍discard推迟）；②discard 11及身份字段；③**作废与完成永不同拍的逐拍断言**；④按槽位计数：RED连续2次→lane 06/cause 06，RED丢一次后正常完成清零、IR计数独立；⑤9000拍忙→lane 07/cause 07，只报一次；⑥撤销合并（截止撤销、校准作废）清在途并重发，周期重检来源转PWI；⑦L-5：STOP结束排空后lane落下；HIST-RERUN期望从"空闲期fault-active=1"改为0（设计有意改变，见设计文档§11.1）；⑧lost sticky清除规则（START不清、阻断时诊断清除无效、同拍新作废优先）；⑨三窗口测试（窗口前、窗口内、窗口后，见设计§11.4） | 逐项去掉修复项 |
| 重检调度器/PWI | F-020：撤销后重发请求（原探针f020场景） | 去撤销分支 |
| supervisor | 06→bit9、07→bit10 | 去映射行 |
| 芯片TB | DIAG-MAP38期望更新：0x0108 bit6、0x0114原因位、0x010B=06/07、0x0113 bit1/bit2；并实测一个作废与一个T-dead场景 | 去SPI映射 |

**d.2 永久系统TB `tb_ppg_control_top_adc_anomaly.v`**
- 来源：在本分支`wip/owner_lifecycle_scratch/b_temp_tb/`的两份临时TB基础上改成永久回归。
- 加入`run_xsim_regression.sh`与filelist。
- 场景（全部来自设计文档§8、§10.7、§11.1、§11.3、§11.4）：
  - ①单次RED、IR丢失各一次：作废后下一帧正常。RED作废时刻=提交后4500拍，且早于下一帧RED接管，逐拍断言。
  - ②合法迟到（LATE385、LATENEXT、LATE2SF、LATE6SF）不作废，S1报迟到。
  - ③NORMAL与校准各一组连续丢失→cause 06→STOP→诊断清除→START，不复位，START被接受；排空完成时supervisor blocking与AMI fault-active为0。
  - ④STOP排空中丢失不卡死。
  - ⑤作废后旧DONE：排空中、空闲期、下一RUN首个start前，三种情况都有记录，之后都可重启。
  - ⑥L-1（NODONE、DROPIR）、L-3（LATE6SF）、L-4（DROPRED）、L-5原场景（连续丢失→故障→abort→排空中迟到旧DONE→STOP结束→诊断清除→START）。
  - ⑦校准丢失且下一宏帧为NORMAL（周期重检路径）时不错绑。
  - ⑧只有RED一路持续丢失，第2次RED作废报故障；RED丢一次后正常完成计数清零。
  - ⑨ADC卡忙：
    - RED owner卡忙超过4717拍时，下一帧RED的Q3被压掉；ADC恢复后不错绑。
    - 9000拍报07→abort+STOP→看门狗0x31→ADC恢复→作废→排空结束→诊断清除→START。
    - ADC永不恢复：停在STOPPING并已报07与0x31，不静默。
  - ⑩捕获窗口内完成：作废先发生，迟到完成被拒并报故障，STOP后可重启。
- 活性监视器：RUN或STOPPING中，连续3帧（15000拍）既无完成、作废、正式结果、IDAC码提交、生命周期变化，也无故障记录 → FAIL。

**d.3 全套回归**
- 提交后用`git -c core.autocrlf=false archive`导出到仓库外运行。
- 19-TB分3~4组，在各自独立导出副本中并行跑（脚本输出目录固定）；芯片与模块级另跑。
- 与05a31cf逐TB比对排序后的PASS行和`$finish`时刻（不用summary.tsv）；每一处变化都要解释。基线摘录见`wip/owner_lifecycle_scratch/baseline_05a31cf/`。
- 第一次并行运行时，要核对并行结果与串行结果逐行一致。

**d.4 预期会有变化、需重点解释的既有检查（读码预判，未实测）**
- AMI单元TB HIST-RERUN：L-5修复后空闲期`o_ami_fault_active`由1变0，为有意改变。
- SSW单元TB中若有校准owner在tick 385仍在途的场景，S1 sticky会开始置位。
- 凡在途owner挂起≥4500拍且物理idle的场景会发生作废：SMOKE-09只挂约3300拍，不受影响。
- STOP/abort排空中DONE永不到达、原先永久卡在STOPPING的场景（若有）现在会结束。

## (e) 本机才有的材料（已复制到`wip/owner_lifecycle_scratch/`）
| 子目录 | 内容 | 来源 |
|---|---|---|
| `b_temp_tb/lost_completion_20261006/` | NORMAL侧临时TB（`make_tb_normal.py`、`tb_lost_done_normal.v`，DROPRED/DROPIR/DEAD）与校准侧（`make_tb.py`、`tb_ssw18_late_completion.v`，含LATE6SF/NODONE/DEADADC），以及filelist | B会话`D:\PPG\verilog\ppg_regression_runs\lost_completion_20261006\`（报告9049adc） |
| `b_temp_tb/ssw18_tick385_20261006/` | 校准侧早期版本（LATE385/LATENEXT/LATE2SF/NODONE/DEADADC） | B会话`ssw18_tick385_20261006\`（报告7364916） |
| `workflow_scripts/` | `add_changelog.py`（CL_DATE环境变量）、`gate_summary.py`、`run_ctrl_tb.sh`、`run_chip_tb.sh`、`logdiff.py`、`unitwall.py`、`mutrun.py`、`compare_runs.py`、`run_all_05a31cf.sh` | ABCD会话`abcd_20261004\phase2\`、`probes\mut\`、`taskc_20261001\` |
| `olr_patch_scripts/` | 本轮RTL改动的补丁脚本与注释列对齐脚本（可用于审阅改动） | 本会话 |
| `baseline_05a31cf/` | 05a31cf回归每个TB的排序PASS行与`$finish`行：ctrl19（1210行PASS）、chip、unit（28个） | `ppg_regression_runs\05a31cf_20261006(_unit)` |

注意：
- 脚本中写死了`D:/PPG/...`、`/c/Xilinx/Vivado/2022.2/bin`、`D:/iverilog`等Windows路径，云端使用时需改。
- 临时TB基于517ab78版TB生成，需按当前TB重新生成或手工移植。
- gate在skill目录下运行：`python -m scripts.python.validation.verilog_generated_deliverable_gate <文件> --json ... --markdown ...`；本轮的"之前"基线即0ffb439版文件。

## (f) 给B的合同交接清单（符号锚点新规；均为一级合同内容）
1. **C10（AMI）**：
   - AMI-39/AMI-40及"只有真实DONE释放owner"相关正文加入超时作废规则：条件、AMI为唯一裁决点、作废拍序号语义、作废后旧DONE按无owner捕获拒绝并升级；
   - §6.10丢弃原因表加`2'b11` COMPLETION_LOST，注明"2位字段最后一个空位，以后新增原因需加宽字段"，以及作废discard身份取owner启动快照、`sample_valid=0`、对校准owner也发；
   - §6.11故障分发器扩为七路（06、07）；
   - §15.1新增`o_owner_lost_sticky`清除规则；
   - §15.2与§6：lane"保持到本RUN结束"的实现（STOP结束且排空即落下，L-5），三个lane注释改动同步；
   - 公开端口表加`o_adc_transaction_lost_event`、`o_owner_lost_sticky`、两个参数；
   - **不可消除窗口前提**：同步链约2拍内到达的完成会先被作废，随后按错配拒绝并升级，可经STOP→诊断清除→START恢复；
   - **物理前提**：作废后下一笔start之后到达的旧DONE与新事务不可区分。
2. **C25 LFA-04**：同AMI-39，加超时作废例外。
3. **C24（supervisor）**：
   - §3原因表加`8'h06`（同槽位连续完成丢失，k=2按槽位）与`8'h07`（ADC在owner在途时≥9000拍不回物理空闲），source 4'h1，summary bit 9/10；
   - §5 AMI active fault下降条件补"abort、START或RUN结束排空"；
   - §6看门狗保持"不伪造"原则，补"超时作废不属于伪造"，写RUN中/排空中丢失与长期忙的处理及不卡死保证；
   - SUP-08补本轮证据（第三步完成后）。
4. **C09（SSW）**：
   - SSW-18、:373、:602按S1改写，明文写出"ADC在tick 266已采样、迟到的只是读出"前提；
   - SSW-16/17/42加作废释放；
   - owner与帧/子帧绑定写入SSW-34/38相关正文；
   - 端口表加`i_adc_transaction_lost_event`。
5. **C08（调度器）**：
   - L-1（宏帧末不重挂在途owner请求，FSC-17相关）；
   - L-4（截止与提交互斥：截止当拍可提交，越过截止只收尾，FSC-46/49/50）；
   - L-3（第4种IDAC边界：启动搜索空闲边界，FSC-19/38~41相关）；
   - F-010滚动受生命周期撤销屏蔽（第一轮遗留）；
   - 作废释放（FSC-54）；
   - 端口表加两个输入；
   - 注明调度器sticky按§16.2在新START清除，而AMI历史诊断在新START不清，两套规则并存。
6. **C18/C16（PWI/重检）**：新输入与F-020撤销规则。
7. **C01（control_top）与芯片顶层合同SPI地图**：
   - 新输出`o_ami_owner_lost_sticky`；
   - 0x0108 bit6=AMI owner lost sticky（bit7仍保留）；
   - SPI诊断地图逐位写明每个诊断位的清除方式。
8. **既有条目订正**：C10 §15.2关于L-5"需主机ABORT"的当前限制说明（第一轮交接）改为已修复。
9. **已知限制**（写进合同）：同一槽位间歇丢失、从不连续丢两次时不升级，每次都有discard 11和lost sticky可见。

## 本机检查点回归（2026-10-07，Vivado 2022.2 xsim，副本`phase2/rtl2`）
- **模块级**：`tools/run_unit_tb_regression.sh -g all`，28/28 PASS。
  - 每个TB排序后的PASS行与`$finish`时刻都与05a31cf逐行一致（基线摘录见`baseline_05a31cf/unit/`）。
  - 变更模块的6个TB（调度器、SSW、AMI、PWI、重检、supervisor）另做全日志diff（去运行元数据），唯一差异：
    ```
    AMI TB: HIST_STOP_ONLY blocking=1 ami_fault_active=1 → ami_fault_active=0
    ```
    这是L-5修复的有意改变（设计文档§11.1）：只以STOP结束、AMI全链排空后，lane 02落下。
  - **HIST-RERUN仍为PASS，但已不再检验其注释所写的内容**：它在空闲期重新注入一次协议错误后立即采样`o_ami_fault_active===1`，正好落在lane 02重新置位那一拍；下一拍新的"RUN结束排空"清零即生效。第三步须按设计§11.1改写为：注入后lane置位，排空后落下，START被接受，并做负对照（去掉清零项FAIL）。本次没有改任何测试期望。
- **smoke（`tb_ppg_control_top.v`）**：73 PASS，与05a31cf逐行一致，`$finish`同为1655973500 ps，0 FAIL。
- **其余18个系统TB与芯片TB**：本机未跑，留第三步全套回归。
- **未做**：本轮各项修复的单元断言与负对照、永久系统TB、全套回归，全部列在(d)。
