# 验收编号治理核查续：待定项定论、FSC/SUP缺口的系统级证据、需订正的PASS声明（2026-10-05）

接`verification_reports/ID_GOVERNANCE_AUDIT_20261005.md`（`085d214`，以下称“主报告”）。只读核查，快照仍为`2a90a69`：`085d214`只新增了主报告，合同、RTL、TB均无变化。本报告没有改任何RTL、TB、合同、矩阵、别名表或tools文件。主报告§13的T1~T5以本报告为准；主报告§5.2总表中AMI-13一行的“待定”改判为B（见§1.1）。

用户对主报告的决定（经“Erie Verilog Generator 配置”会话转达）：
- FSC-58~62不在C08新登记；
- 合并批次改名规则：TB检查与合同条目**含义完全一致**的，标签直接改成该合同编号；部分一致、错位或无对应条目的，改成TB本地名；
- 对应关系记在别名表里，不在C08新建对照表；
- 改名放到ABCD会话三轮完成后的合并批次统一做。

本报告只为该批次准备输入。

## 0. 结论先行

- **T1 AMI-13 → B**。AMI的结果双分支fork是AMI自身代码（`ppg_adc_measurement_idac_integration.v:958-959`，“空槽或同沿完全释放允许零气泡”）。任何TB都没有在AMI层构造“两分支最后消费与新事务装入同拍”。单元TB的AMI-13实测的是“反压5拍后同一结果仍保持”（`tb_ppg_adc_measurement_idac_integration.v:1244`）。子模块层面的同拍替换（FFK-05、DCR-16、CAL-12、PR-10）不能代替AMI自有fork的证据。合同AMI-13**无动态证据**。
- **T2 MGR-12的0x05 → 不可达，合同条目文字过时**。`ERROR_ENUM_ENCODING = 8'h05`只在`ppg_system_config_manager.v:113`声明，固定优先级编码器（`:468-492`）从不选它；IDAC保留编码走`ERROR_RESERVED_IDAC_MODE = 8'h15`（`:129`、`:318`、`:475`，即MGR-20）。
- **T3 IDC2-17 → C17过时，RTL与C16/C10/C08/C25一致**。周期AMB在窗口内时，RTL无条件进入`ST_DCS_REVALIDATE_WAIT`（`ppg_idac_code_controller.v:733`、`:794`），而`o_dcs_revalidate_request`就等于这个状态（`:662`）。因此C17 IDC2-17“不请求DCS重验”和C17第503行“AMB码未实际改变时不得产生`o_dcs_revalidate_request`”都与RTL相反。C16 AMR-10、C10 AMI-18、C08 FSC-21、C25 RRC-06（系统级证据RRC-06）与RTL一致。
- **T4 SSW-18 → 无证据，合同文字与RTL职责不符**。SSW只在“校准上下文有效、local tick 385、仍无owner”时置`calibration_timeout_sticky`（`ppg_sar9_sar15_safe_selection_wrapper.v:546-547`），不终止burst。按C09:373，“未能支持下一候选码”由IDAC控制器报告阶段失败。全仓没有任何TB断言该sticky变为1：只有`tb_ppg_control_top_baseline_cross.v:1892`和`tb_ppg_control_top_fir_tail_isolation.v:1696`打印INFO，SSW-37只断言它保持0。
- **T5/(b) 15条FSC缺口加SUP-05/08的系统级证据**：

| 结论 | 条目 |
|---|---|
| 已有证据 | FSC-20、21、35、43、47 |
| 部分证据 | FSC-18、34、48、53、57，SUP-05，SUP-08 |
| 无证据 | FSC-19、23、24、27、44 |

  逐条见§2。
- **(c) PASS声明需订正的位置**：主动声明当前PASS的状态类文字**6处**（C01:38；核对表:16、:43、:44、:45、:420），门禁/要求类文字与表格范围不一致或当前不满足的**7处**，别名表/矩阵对SUP06A的误引**2处**，历史叙述**5处**（按用户决定不改，只列出）。见§3。

## 1. 待定项定论

### 1.1 T1 AMI-13（输出同拍替换）

- 合同C10:1228：“旧事务两个分支最后消费与新事务装入同拍，无空泡和覆盖。”
- RTL：AMI自身的结果fork用`flag_measurement_pending`/`flag_detection_pending`持有所有权（`:466-467`）。各分支的传输条件见`:954`、`:957`；`flag_result_fork_all_released`（`:958`）在两分支同沿释放时成立，`flag_dc_result_ready`（`:959`）据此允许下一笔零气泡装入，`reg_result_fork_payload`在`:1748`原子装入。这条路径属于AMI，不是子模块。
- TB：
  - AMI单元TB先把`i_measurement_result_ready`拉低，启动sample 102，等结果出现后检查AMI-12（`:1242`）；再等5拍检查AMI-13（`:1244`）。两次都只比较`o_measurement_result_valid && (o_result_sample_index == 16'd102)`，期间没有第二笔事务。
  - 全仓搜索“same-cycle/同拍替换”，命中的都在子模块TB（async capture、DCR-16、OVL-04、PR-10、CAL-12、S1 redundancy、FFK-05）。
  - 系统级的OIB-03只证明“反压期间持有、释放后及时消费”，没有构造同拍替换。
- **定论**：TB AMI-13与合同AMI-13同号不同义（B），因为TB的检查实为反压保持，属于AMI-12的“仍pending分支载荷保持”。合同AMI-13只有RTL结构（`:958-959`），无动态证据。
- **合并批次**：按改名规则，TB AMI-13不是“完全一致”，改为TB本地名；合同AMI-13记为证据缺口。

### 1.2 T2 MGR-12错误码0x05

- 合同C02:349把0x05列入配置拒绝矩阵。
- RTL：
  - `:113`声明`ERROR_ENUM_ENCODING = 8'h05`，全文件没有其他引用；
  - `:468-492`是唯一的错误码选择链，其中枚举检查一项（`:475`）输出`ERROR_RESERVED_IDAC_MODE`（`8'h15`，`:129`）；
  - `flag_snapshot_enum_valid`（`:318`）只检查`idac_mode != 2'b11`，注释写明“V4.9起归类为ERROR_RESERVED_IDAC_MODE”。
- **定论**：0x05在当前RTL中不可达。合同MGR-12应删除0x05，或注明它已改判为0x15并由MGR-20覆盖。TB的MGR-12（覆盖0x03/0x04/0x06/0x08/0x09/0x0e/0x0f）对可达码完整，改判为A。RTL中残留一个未使用的localparam，不影响功能；是否清理留给RTL注释清理轮。

### 1.3 T3 C17 IDC2-17的DCS重验语义

- C17：
  - IDC2-17（:670）写“周期AMB在窗口 / done单拍，AMB码/epoch不变，不请求DCS重验”；
  - §8.4第503行写“AMB码未实际改变时不得产生`o_dcs_revalidate_request`”。
- RTL：
  - `ST_AMB_WAIT`在`flag_search_in_window`且为重检起源时，以及`ST_AMB_RECHECK`在`flag_search_in_window`时，只要`i_dcs_enable`为1，都进入`ST_DCS_REVALIDATE_WAIT`（`:733`、`:794`）；注释为“周期三帧序列无条件进入两色DC重新验证”“当前AMB合格也必须继续三帧DC重新验证；RRC-05……”；
  - `o_dcs_revalidate_request = (state_current == ST_DCS_REVALIDATE_WAIT)`（`:662`）。
- 其他合同：C16 AMR-10“AMB码未改变……仍依次请求DC_R和DC_IR校准样本”，C10 AMI-18，C08 FSC-21，C25 RRC-06“in-window unchanged AMB……still requires DC_R and DC_IR revalidation”。
- 证据：
  - IDAC单元TB：`PASS: PERIODIC unchanged AMB still requests DCS revalidation`、`PASS: PERIODIC in-window revalidation preserves all codes and epochs`；
  - 系统级：`PASS RRC-06 in-window AMB check preserved code/epoch while the state trace still visited DC_R/DC_IR revalidation`。
- **定论**：不是两套机制，就是同一个握手。C17的IDC2-17与第503行过时（是“AMB未变不重验”旧设计的残留），应订正为与RTL及C16/C10/C08/C25一致。RTL无需修改。

### 1.4 T4 SSW-18（tick 385）

- C09:835 SSW-18“tick 385前未准备下一码则终止burst并置sticky”；C09:373“若当前结果未能在local tick 385前支持下一候选码准备，IDAC控制器必须报告阶段失败”；C09:602把`o_calibration_timeout_sticky`定义为“校准结果未能在下一候选码准备截止前完成”。
- RTL：
  - `CAL_COMMIT_TICK = 10'd385`（`:210`）；
  - `calibration_timeout_sticky_o`只在`flag_cal_context_valid && (i_calibration_local_tick == CAL_COMMIT_TICK) && !flag_cal_has_owner`时置1（`:546-547`），复位、空闲START或空闲诊断清除时清0（`:539-544`）；
  - SSW内部没有任何“终止burst”的动作。owner截止由另一路`flag_cal_timeout`在local tick 249处理（`:436`、`:562`）。
- TB：
  - SSW单元TB只在SSW-37（`:898`）断言该sticky为0，SSW-18场景实测的是owner截止sticky（主报告§6.4）；
  - 系统级`tb_ppg_control_top_baseline_cross.v:1892`、`tb_ppg_control_top_fir_tail_isolation.v:1696`只在它为1时打印INFO，不构成断言。
- **定论**：
  - 合同SSW-18无证据；
  - 合同文字与RTL职责不符：SSW只置诊断sticky，且条件是“385时仍无owner”，而不是“结果未支持下一码”；终止burst属于IDAC控制器阶段失败。
  - **建议**：合并批次把SSW-18订正为“local tick 385时校准上下文仍无owner则置`o_calibration_timeout_sticky`（非阻断诊断）；burst终止由IDAC阶段失败负责（C09:373）”，并补一个断言该sticky置1的单元检查。是否要求SSW自己终止burst，属于功能决定，需用户裁定。

## 2. 15条FSC缺口与SUP-05/08的系统级证据（T5/(b)）

查找范围：
- f485cbc的19-TB日志（`…\f485cbc_20261001\rtl\ppg_control_top\xsim_regression_20260906\*\xsim.log`）及对应TB代码，包括每个系统级TB都执行的JNT前缀（`tb_ppg_jnt_baseline_prefix.vh`）；
- 别名表和矩阵。FSC不在别名表和核对脚本范围内，没有登记行。

| 合同条目 | 合同含义 | 结论 | 证据位置 / 缺口 |
|---|---|---|---|
| FSC-18 | IDAC子周期提交边界不触发精度或重检提交 | 部分 | 消费侧有AMI单元TB的AMI-26（快速校准IDAC边界不进入precision/recheck/safe-frame上下文）。调度器侧“校准子周期只发IDAC边界、不发宏帧边界”无系统级断言；SID TB未比较宏帧边界计数 |
| FSC-19 | 阶段超过8笔时同阶段延长到下一宏帧，不伪造完成 | 无 | 19-TB日志与代码中无构造 |
| FSC-20 | AMB成功后固定DC_R、DC_IR，禁止跳序 | 已有 | 周期序列：`PASS RRC-05 real recheck sequence visited AMB, then DC_R, then DC_IR, strictly in that order`。启动序列：系统级SID-02只证明首阶段为AMB，完整顺序由IDAC单元TB的`PASS: STARTUP requests red DCS before infrared`/`STARTUP infrared follows red DCS`证明 |
| FSC-21 | AMB码未改变仍做两色DC重验证 | 已有 | `PASS RRC-06 …still visited DC_R/DC_IR revalidation` |
| FSC-23 | 单光完成事件：唯一颜色完成后仅一拍 | 无 | 19-TB中只有RRC-01统计`sched_normal_frame_complete_event_o`，且为双光；单光的完成事件脉宽与次数无断言 |
| FSC-24 | 校准物理完成：宏帧结束事件与阶段成功严格区分 | 无 | 19-TB中无对校准帧完成事件与阶段成功的区分断言 |
| FSC-27 | frame/sample 16-bit自然回绕 | 无 | 最长的longrun只有4000帧；19-TB中出现的16'hFFFF只用作注入的错误sample index，不是回绕 |
| FSC-34 | 随机ready/valid：无丢失、无重复、无颜色/epoch交叉 | 部分 | OIB族用诱导的反压而不是随机激励：`PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across 35 real transfers`，`OWNER_IDENTITY_BACKPRESSURE_TB_PASS … order_violation_count=0` |
| FSC-35 | 长时间回归：RED/IR各自400 Hz，完成事件和计数无漂移 | 已有 | `PASS RAW-12 post-START run covers real_red=4000 real_ir=4000 elapsed_ns=10000000499`（`tb_ppg_control_top_longrun`，10 s内两色各4000帧即各400 Hz）；另有NRE-06“1627 captured results / 1655 owner commits结果序连续” |
| FSC-43 | 连续校准接管点严格相隔625周期 | 已有 | `PASS SID-04 AMB stage converged to target code 64 with real physical candidates 625 ticks apart` |
| FSC-44 | local tick 0之后到达的校准请求只能等下一子帧 | 无 | 19-TB中无构造 |
| FSC-47 | IR并行预建立：macro tick 160接管IR波形时允许RED owner在途 | 已有 | JNT前缀`jnt_check_case("JNT-02-IR-PREESTABLISH", flag_jnt02_ir_context_while_red_inflight)`（`tb_ppg_jnt_baseline_prefix.vh:638`，2026-09-17补回），每个系统级TB的JNT基线都执行并PASS |
| FSC-48 | 只有真实RED DONE释放owner，IR在deadline 443前原子提交 | 部分 | JNT-02B（RED完成success、sample 0）→ JNT-03A（IR owner、sample 1、身份匹配）证明先后与原子性；deadline 443未断言（LFA-09/OIB-02只覆盖RED截止） |
| FSC-53 | SAR15跨色白名单 | 部分 | 只有SSW单元TB的SSW-41；系统级TOP-15的PASS行是“single-in-flight monitor”，不检查白名单 |
| FSC-57 | SAR9跨色白名单 | 部分 | 只有SSW单元TB的SSW-44；系统级无 |
| SUP-05 | 外部/系统STOP合并幂等 | 部分 | Top合并`flag_stop_request_event <= i_stop_event \|\| supervisor_system_stop_request_event_o \|\| flag_abort_drain_stop_request`（`ppg_control_top.v:375`）只有静态论证（矩阵P03行）。动态证据有：manager重复STOP幂等（MGR-07，FAIL标签“MGR-07 idempotent stop”）、supervisor同一episode不重发（SUP01B）。外部STOP与系统STOP同拍或相继到达的系统级场景未构造 |
| SUP-08 | 最终Top证明mismatch进入STOPPING并可合法重启 | 部分 | 重启半句已有：`PASS INJ-02 re-commit after LFA-08 recovery`、`PASS INJ-02 next legal transaction after LFA-08 recovery completed cleanly`，以及LFA-12(a)(b)(c)。mismatch到STOPPING半句：INJ-02与LFA-02b都由TB自己调用`task_pulse_stop`，没有TB断言supervisor自发的STOP请求把生命周期带进STOPPING（19-TB中`ST_STOPPING`没有被用于比较） |

## 3. 需订正的PASS声明位置（(c)）

以下行号均为`2a90a69`（= `085d214`）版本。

### 3.1 状态声明：主动宣称当前PASS，与核查结果不符

| # | 位置 | 原文要点 | 不符之处 |
|---|---|---|---|
| P1 | C01:38 | “Scheduler FSC-01～57、AMI AMI-01～45和SSW SSW-01～52均已有当前单模块PASS证据” | FSC-2~57同号不同义（主报告§6.1）；SSW-18同号不同义；AMI-13同号不同义（§1.1） |
| P2 | 核对表:16 | 同P1（“均记录为当前单模块PASS”） | 同P1 |
| P3 | 核对表:43 | “FSC-01～FSC-57当前RTL/TB/XSim匹配，全部PASS，证据完整” | 同P1的FSC部分 |
| P4 | 核对表:44 | “AMI-01～AMI-45当前PASS” | AMI-13为B，27条为部分覆盖 |
| P5 | 核对表:45 | “SSW-01～SSW-52当前PASS” | SSW-18为B |
| P6 | 核对表:420 | “Scheduler的FSC-01～FSC-57、AMI的AMI-01～AMI-45和SSW的SSW-01～SSW-52均为当前单模块PASS” | 同P1 |

核对表第8行状态格已由合同补记批次3改为“本表为control_top实现前的设计快照，后续状态见§15”。P2~P6是快照正文，订正方式可以是在§15追加一条说明，而不改快照原文；这由合并批次决定。

### 3.2 门禁/要求类：范围与表格不一致，或当前不满足

| # | 位置 | 原文 | 问题 |
|---|---|---|---|
| G1 | C08:1206 | “自检TB必须真实覆盖FSC-01至FSC-57” | 要求本身没错，但当前不满足（主报告§6.1，本报告§2） |
| G2 | C09:878（§10验收要求） | “Vivado xsim：SSW-01至SSW-52全部真实PASS” | SSW-18当前不满足 |
| G3 | C18:659（§14门禁） | “xsim中PWI-01至PWI-07全部真实比较PASS” | 表格到PWI-08，范围不一致；当前TB只有PWI-01~05 |
| G4 | C10:1282（§18门禁） | “xsim中AMI-01至AMI-52全部真实比较PASS” | 表格到AMI-54，范围不一致；单元TB没有AMI-46~52（已改名或不在单元TB） |
| G5 | C10:27、C10:1340 | “AMI-01至AMI-45已完成45项真实比较且全部PASS” | 字面成立（45个检查都通过），但AMI-13同号不同义，27条只覆盖部分。建议加限定语 |
| G6 | C03:325（§13工具验证要求） | “AV4C-01～AV4C-19全部由真实信号比较通过” | 表格已到AV4C-22；内容一致，只是范围滞后 |
| G7 | C21:563、:613、:614、:665 | “BSL-01至BSL-28”“OPT-01至OPT-24” | C20的BSL表已到BSL-40，C21门禁仍写BSL-01~28；OPT与表格一致。内容一致，范围滞后，低优先级 |

主报告§3.2的S1~S3（C10:30/:1340“AMI-46至AMI-55”、C19“FIR-01~36”、C18“PWI-06至PWI-10”）属于同类范围问题，一并订正。

### 3.3 证据引用错误

| # | 位置 | 问题 |
|---|---|---|
| R1 | 别名表P05行（:466） | 把“SUP06A/B/C”列为5000周期看门狗证据；SUP06A实测的是episode关闭后阻断解除，不是看门狗 |
| R2 | 矩阵:927（P05行） | “SUP06A/B/C (shortened-threshold watchdog timeout, cause fixed `8'h31`)”，同R1 |

### 3.4 历史叙述（只列出，按用户决定不改）

| # | 位置 | 内容 |
|---|---|---|
| H1 | 矩阵:947、:3724、:3731、:3736 | 以旧编号“AMI-46/47”“AMI-01 through AMI-47”指AMI单元TB改名前的discard检查 |
| H2 | 别名表:483、:545 | 同上（N08行与AMI-47叙述） |
| H3 | C08:1253 | V1.3历史日志FSC-01～57 PASS，已自注为非规范证据 |
| H4 | C09:17 | V1.3.1“SSW-01至SSW-48已有历史回归证据”（含SSW-18） |
| H5 | C07:13 | “once reported CCC-01 through CCC-26 as passing”（CCC内容一致，无影响） |

### 3.5 TB侧横幅（主报告§4已列，随TB改名一并处理）

`ALL FSC-01 THROUGH FSC-62 PASSED`、`SUP-01 through SUP-10 PASS`、`PASS ppg_adc_dc_recovery DCR-01..DCR-22`、`PASS: ppg_system_config_manager MGR-01 through MGR-24 …`等区间横幅；`tools/run_unit_tb_regression.sh`中对应的判据要同步修改。

## 4. 为合并批次准备的提示（按用户的改名规则）

- **调度器TB**：按“含义完全一致才改为合同编号”逐条看主报告§5.2的FSC各行，**完全一致的只有TB FSC-32（=合同FSC-30：错误sample index不完成在途事务并置sticky）**。TB FSC-2与FSC-3合起来接近FSC-55，但单独看都只覆盖一部分；其余均为部分覆盖或无对应，应改为本地名。所以改名后FSC前缀的检查会很少，调度器TB的大多数检查将以本地名加别名表对照行的形式存在。
- **AMI-13**：改为本地名（§1.1）。
- **MGR-12**：只订正合同（§1.2），TB不动。
- **IDC2-17与C17第503行**：只订正合同（§1.3）。
- **SSW-18**：TB场景改为本地名，或并入SSW-37/38的子标签；合同SSW-18按§1.4订正，并补一个置1检查。是否要求SSW终止burst，需用户裁定。
- **无证据的FSC-19/23/24/27/44**：需补断言，或接受缺口并在合同中注明，由用户决定。

## 附录 使用的命令要点

- 待定项：直接读快照RTL的对应行（行号见正文），并全仓grep TB中的同拍替换检查和`calibration_timeout_sticky`比较。
- (b)：在19-TB日志中按关键词（whitelist/wrap/late/preheat/frame_complete/idempotent/restart/order/625）检索PASS行；对命中的标签回读TB代码（`jnt_check_case`、INJ-02恢复序列）确认是真实比较。
- (c)：`claims.py`（逻辑：合同行同时含“FAM-aa至/～/through/..bb”区间与PASS/证据/覆盖类关键词即列出），再逐行读上下文，区分状态声明、门禁要求和历史叙述：

```python
import re, sys, os, glob
ROOT = sys.argv[1]
RANGE = re.compile(r'(?<![A-Za-z0-9_-])([A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*)-(\d{1,2})\s*(?:至|到|~|～|through|THROUGH|to|TO|\.\.|-)\s*(?:\1-)?(\d{1,2})(?!\d)')
KEY = re.compile(r'PASS|通过|证据完整|全部|覆盖|evidence|covered|匹配', re.I)
for p in sorted(glob.glob(os.path.join(ROOT, 'contracts', '*.md'))):
    f = os.path.basename(p)
    for n, line in enumerate(open(p, encoding='utf-8').read().split('\n'), 1):
        rs = [m for m in RANGE.finditer(line) if m.group(1) not in ('C', 'V', 'SAR', 'Q')]
        if rs and KEY.search(line):
            print('%s:%d\t%s\t%s' % (f, n, ','.join(m.group(0) for m in rs)[:120], line.strip()[:160]))
```
