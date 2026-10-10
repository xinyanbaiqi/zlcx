# V18 SSW 全部模拟输出逐拍黄金试验报告

日期：2026-10-10（Asia/Shanghai）。分支：`v18-ssw-golden`。本版按统筹对`9044d3a`的核对意见订正；旧版分类统计已被本版替代。

基线main：`4863ec6e8f1298a7a9d543b3cd1a82e7a3d08fcb`；按任务书，RTL/TB与`7a8eabf`相同。C09取origin/b-merge-batch `66bebdfabe9e1cb173c34a0ce44e48ba4230398d` 的唯一指定接口合同V1.11。

## 1. 结论

已完成155个场景、816240行真实采集。最终规则下17个PASS、138个MISMATCH，黄金待确认输出拍数为0。当前基线未达到逐拍零差异的通过标准。

F02、F03、F05为统筹确认的SSW缺陷；F04按用户更新的全动态状态TIA=TIAEN规则判定；F01为已登记SSW-C1的独立复现。原F07及SAR15截短统一列KNOWN-OWNER-DEADLINE。原F06未区分owner提交状态的结论撤回，已提交owner的完整续跑不再作为STOP差异。新增未提交owner的STOP覆盖与观测另列，未修改任何RTL或既有TB。

全部计划波形/owner握手次数与实际一致；没有协议错误或身份错配sticky。时钟高低两相转发检查、上升沿后与下降沿后的控制稳定性检查均0失败。这里的稳定性是两点采样检查，不是连续模拟毛刺或PVT证明。

正式帧及硬复位共进行22837360次输出组逐拍比较（28组/67位），差异组拍累计166430。正式帧前四拍配置准备期不判定未定义的配置接管延迟；硬复位四拍仍完整比较。

## 2. 独立性声明

使用全新克隆：`C:/Users/DAWN/.codex/visualizations/2026/10/10/01a123ce-417a-79f0-b6cb-53ac3801aef4/zlcx`。原Documents目录为无提交的空仓库，无法写入新目录/FETCH_HEAD，故采用本会话另一授权可写目录。仅枚举过旧目录的文件名，未读其验证报告内容。

SSW目录中RTL、单元TB与综合脚本均未读取给代理、模型、端口提取器或黄金发生器；SSW RTL仅作为Vivado编译器的路径参数。未读取闭合矩阵、别名表、禁读分支报告或其他既有验证证据。未查看SSW层级内部状态。波形黄金先生成并冻结，再运行采集；不会用实际波形移动、缩短或补偿期望窗口。

实际直接读取的设计文件如下（除所列C09外均main）：

- `verification_reports/V18_SSW_GOLDEN_BRIEF_20261010.md`。
- `verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md` 的V18与相关阶段段落；其中已披露SSW-C1，本次不声称首次发现该问题。
- `contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`，只读origin/b-merge-batch V1.11。
- `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`，main V1.12的接口/相位/事务/安全边界段落。
- `contracts/ppg_system_config_manager_semantic_contract.md` 的端口和STOPPING排空段落（本次复核追加；未打开其引用的矩阵或实现）。
- `rtl/ppg_timing_sar9/ppg_timing_sar9.v`。
- `rtl/ppg_timing_sar15/ppg_timing_sar15.v`。
- `rtl/ppg_timing_sar9/ppg_timing_sar9_3200hz.v`。
- `rtl/ppg_timing_sar15/ppg_timing_sar15_3200hz.v`。

另读取用户在本会话转达的Q01～Q06答复；它们属于新增规范输入。Q02/Q03/Q06明确标为用户确认（10-10）。V1.11 owner绑定、lost/generation释放、local385迟到、abort同拍完成优先、START恢复条文标为RTL派生条文；不将这类条文当作完全独立的实现证明。

工程流程直接读取根`CLAUDE.md`与以下Erie技能资料：

- `.claude/skills/erie-verilog-generator/SKILL.md`。
- `references/workflows/verilog_dispatcher.md`、`references/workflows/workflow-contracts.md`。
- `references/rules/verilog-code-comment-naming-standard.md`、`verilog-comment-placement.md`、`erie-style.md`、`testbench-patterns.md`。
- `references/checklists/verilog-readability-gate.md`、`references/corpus/verilog-style-observations.md`。
- `assets/verilog_style_rules.json`、`assets/verilog_formatter_config/profiles/formatting.json`。
- `scripts/python/quality/formatter_ast.py`、`quality_gate.py`、`deliverable_gate.py`，`scripts/python/validation/verilog_generated_deliverable_gate.py`。
- `scripts/python/quality/formatter_backend/control_node_parse_mixin.py`、`control_parse_mixin.py`、`models.py`（用于定位新TB的formatter兼容性和行号问题）。

主机工程资料：plugin-management的SKILL.md（检查GitHub可用访问方式）、本机`D:/vivado/2019.2/bin/xsim.bat`；没有使用GitHub连接器读取设计内容。执行工具还读取技能运行库、依赖配置与版本信息；其Verilog审查入口仅为新TB。新建的黄金、脚本、TB、场景、期望/采集CSV、工具日志与本任务证据均作自检读取。上述工程资料未作为模拟窗口真源。

## 3. 环境和采集约定

- Windows；PowerShell 7.6.5；Python 3.12.14（本机捆绑运行库，无第三方Python依赖）。
- Vivado Simulator 2019.2：xvlog、xelab、xsim真实执行。另一个可复用后端为iverilog/vvp，本机未运行该后端，不声称交叉工具通过。
- 下载/推送用捆绑Git 2.53.0.windows.3；所有推送仅更新v18-ssw-golden。
- 输出时钟2 MHz，每拍500ns；宏帧5000拍，校准子帧625拍；所有窗口为左闭右开。
- 输入在低相预置，提交沿前采样ready，输出在上升沿后1ns观察；下降沿后1ns检查源时钟转发和非时钟控制稳定性。代码不读取SSW端口声明，全部映射来自C09 §7。
- 行为ADC完成旁带由独立预定日程返回；不根据DUT的Q3、包络末沿或idle伪造DONE。该单元边界试验不是ADC数值、AMS或SPICE联合仿真。
- xelab有一个未连接诊断状态`o_calibration_wave_active`的警告；28组模拟输出全部连接采集，全部输入显式驱动，未连接的是可选状态。编译和展开均成功。
- 新TB严格Erie deliverable gate：0 error / 0 strict warning。技能依赖预检没有远程SSH/厂商路由技能，本任务书明确使用本机仿真；未安装依赖、未进行远程工作，也未将SSW传入分析/修复流程。

时序模板RED Q3中心为34（SAR15由[30,38)中心计算）。NORMAL平移+266，RED/IR中心300/460；DCS单色平移到266，IR不保留160拍偏移；AMB采用C09 §6.1，但TIA静态0一行已被用户作废，改为与TIAEN同为[249,269)。SAR9/SAR15展开包络分别[-256,+18)、[-273,+8)，与合同核对一致。3200 Hz变体仅以625拍参数例化相同核心。

## 4. 场景矩阵

| 组合 | 场景数 | 覆盖 |
|---|---:|---|
| NORMAL三光学模式×两精度×四码图样 | 24 | AMB/DC A5、5A、00、FF；双光tick200～320交界全部采样 |
| AMB、DCS RED、DCS IR×四码图样 | 12 | 每场景连续8子帧，Q3间隔625 |
| 校准候选序列 | 1 | A5→5A→00→FF，随后再重复，epoch随子帧更新 |
| 精度切换两方向 | 2 | 切换前后两宏帧，在4760给已提交精度 |
| owner缺失 | 5 | SAR9/SAR15 RED和IR各一、AMB CAL一个；LED/LEDDAC及前端整槽抑制 |
| owner恰在截止点 | 3 | 两精度NORMAL 283/443、CAL local248 |
| CHARACTERIZATION | 8 | 光电RED SAR9/15；固定电流BOTH/RED/IR×两精度 |
| STATIC_BIAS | 1 | 原始静态向量，MUX 10101→01010同拍更新 |
| NORMAL STOP/abort | 48 | 两精度×RED/IR×两动作×六边沿位置 |
| CAL STOP/abort | 36 | AMB/DCS RED/DCS IR×两动作×六边沿位置 |
| 无valid实时载荷扰动 | 2 | 两精度的码/epoch/LEDDAC载荷在预热后改变，冻结快照不得污染 |
| LEDDAC四图样跨帧 | 2 | 各精度4宏帧，RED/IR分别覆盖00、FF、A5、5A |
| RED/IR不同DC码 | 2 | 同帧RED=3C、IR=C3，检验颜色码归属 |
| KNOWN-OWNER-DEADLINE显式中途提交 | 2 | RED275、IR435，落在前端开始与现行截止之间 |
| 首边沿前STOP且owner未提交（补充） | 7 | 两色×两精度NORMAL，以及AMB/DCS RED/DCS IR；计划提交均晚于STOP，实际owner fire为0 |

六个动作位置为首预热边沿前后、Q1前、Q3期间、Q3后、包络结束前。STOP之前已提交owner则槽完整运行、结果丢弃；尚未提交且未开始预热才禁止启动。abort/reset按C09 §8.3撤销，被丢弃样本不当作合法完整转换。

## 5. 发现清单

按场景×信号的首不符拍、期望/实际和差异拍数完整保存在`verification/v18_ssw_golden/scenarios/evidence/signal_comparison.csv`；以下为去重后的规则差异。没有根据名字推断电气极性或提出RTL补丁。

| ID | 分类和行为 | 代表证据 | 依据 |
|---|---|---|---|
| V18-F01 | 已登记SSW-C1的独立复现：双光SAR9 RED的三个使能消失 | normal_both_sar9_a5：IREf [236,308)期望1/实际0（72拍）；AMB/DC各[256,310)期望1/实际0（各54拍）。同码单光RED对应窗口正确。 | C09 §4.6、SAR9 R_ENABLE_IREF/CODE窗口；允许读取的收尾计划§V18 |
| V18-F02 | NORMAL光电LEDEN早一拍；SAR9/SAR15均存在 | SAR9 RED tick298期望0/实际1，IR458；SAR15 RED295、IR455。Q3本身仍按中心300/460，LEDEN多出的首拍与模板不一致。 | SAR9 R_LED [33,35)、SAR15 R_LED [30,38)，C09 §4.2/4.6 |
| V18-F03 | SAR15选择电平没有在RUN整帧保持已提交精度 | normal_both_sar15_a5从tick0期望1/实际0，累计4958拍；选择电平实际仅跟随两段Q1，共42拍为1。两向4760提交和波形间空闲也检查。 | 用户确认（10-10）Q02；C09 §8.5 STATIC例外 |
| V18-F04 | 用户更新规则下AMB/DCS的TIA控制为0，与TIAEN不一致 | cal_amb_a5、cal_dcs_red_a5、cal_dcs_ir_a5：local [249,269)期望TIA=1/实际0，TIAEN实际为1；每个完整8子帧场景160拍。STATIC TIA=0/TIAEN=1是保留的例外。 | 用户确认（10-10）最新F04规则；C09 §6.1 TIA静态0行作废 |
| V18-F05 | DCS_CAL LEDDAC缺少码窗首拍 | DCS RED local264期望A5/实际00；IR期望5A/实际00；每子帧缺一拍。其LEDEN/Q3窗口仍正确。 | 用户/统筹Q01；SAR9 R_LED_CODE平移到[264,267) |
| V18-STOP-UNCOMMITTED | 补充未提交owner分支：STOP后仍有预建立/码窗活动，单列待统筹核对 | 新增七项stop_unowned场景实际owner fire=0、STOP时inflight=0；例如RED SAR9于43 STOP，44的参考时钟期望0/实际1。RUN保守保持至预约末沿，未用外部CONFIG提前强制关闭输出。 | 最新Q04未提交owner且首边沿前STOP不得启动；完整观测和身份审计见后文 |

| 分类 | 涉及场景 | 场景×信号项 | 差异组拍 |
|---|---:|---:|---:|
| V18-F01 | 13 | 39 | 2880 |
| V18-F02 | 74 | 92 | 108 |
| V18-F03 | 52 | 52 | 152737 |
| V18-F04 | 44 | 44 | 2795 |
| V18-F05 | 26 | 26 | 82 |
| V18-STOP-UNCOMMITTED | 9 | 61 | 7654 |
| KNOWN-OWNER-DEADLINE | 4 | 12 | 174 |

### 统筹已确认的SSW缺陷

| ID | 确认意图 | 当前证据 |
|---|---|---|
| F02 | LEDDAC先于LEDEN一拍开窗，LEDEN以模板为准 | NORMAL两精度LEDEN提前一拍 |
| F03 | EN_15SAR在RUN中保持已提交精度 | 波形外没有保持高电平 |
| F05 | DCS LEDDAC从local264开始 | 当前缺首拍 |

### 已知问题

| 标识 | 包含证据 |
|---|---|
| SSW-C1（F01） | 双光SAR9三个RED使能消失的独立复现 |
| KNOWN-OWNER-DEADLINE | SAR15中途/截止提交截短，以及原F07的SAR9截止提交截短 |

F04是最新用户TIA规则下的输出不符；V18-STOP-UNCOMMITTED是补充身份分支观测。机器证据新增review_status字段，分别标注已确认缺陷、已知问题、用户规则不符、补充STOP观测；原F06/F07不再作为新发现统计。


场景可能同时包含多类差异，上表各场景数不能相加。码总线另外记录逐bit XOR差异数，精度未选总线和STATIC零码均逐拍检查。

## 6. KNOWN-OWNER-DEADLINE（已知，不计新发现）

按统筹明确要求构造RED tick275、IR tick435提交。两者均真实接纳，位于前端窗口开始266/426与截止283/443之间。观察到前端各窗口被截短，输出如下：

| 场景/信号 | 模板完整窗口 | 实际窗口 |
|---|---|---|
| RED275：TIA / TIAEN | [266,305) | [276,305) |
| RED275：AFERST | [266,286) | [276,286) |
| IR435：TIA / TIAEN | [426,465) | [436,465) |
| IR435：AFERST | [426,446) | [436,446) |

截止点当拍SAR15提交场景也复现该问题：RED窗口实际从284开始、IR从444开始。原F07的SAR9截止当拍提交同样少首拍，已全部并入KNOWN-OWNER-DEADLINE：四个场景、12个前端比较项、174个差异组拍。已知场景中的LEDEN早拍、EN_15SAR保持错误仍按各自已确认缺陷记录。

未来RC1将NORMAL两精度截止统一提前至RED265/IR425，截止当拍允许提交，受owner控制的边沿最早下一拍。本阶段仍在原main的283/443上采集，不提前把未修复RTL当作新截止版本。run.py和collect.py新增对应deadline参数，截止场景自动跟随；超新截止的历史275/435请求不发送非法提交，转为缺owner整槽抑制检查。

## 6.1 F06撤回与STOP身份审计

撤回旧F06的统一判定：owner已提交的RED及CAL槽即使STOP早于预热，也必须完整运行、真实DONE success=0释放，SSW的完整续跑符合订正规则。原F06不再出现在当前差异分类中。

身份审计同时显示旧IR-only首边沿前场景原本计划owner在350提交，晚于STOP，实际owner fire=0；它们不能按已提交owner分支消除观测。补充七项明确未提交owner的场景，RUN保守保持至预约末沿，以隔离SSW自身STOP行为；未强制提前CONFIG。其实际提交次数、STOP前/时inflight状态及每组输出差异均入机器证据。这组补充观测使用独立标识V18-STOP-UNCOMMITTED，不延用旧F06结论，也未将它冒称统筹已确认的F02/F03/F05。

补充场景是SSW接口级延迟排空压力输入；没有例化manager/AMI来证明该RUN保持序列在系统中的可达性。统筹可据此核对系统STOPPING的run_enable/相位条件。它不会被当作已经确认的系统级缺陷。

| 补充场景 | STOP拍 | STOP前owner fire | STOP时inflight | 首个不符信号/拍 |
|---|---:|---:|---:|---|
| stop_unowned_red_sar9_before_preheat | 43 | 0 | 0 | o_clk_iref_idac_sar9_low / 44 |
| stop_unowned_ir_sar9_before_preheat | 203 | 0 | 0 | o_clk_iref_idac_sar9_low / 204 |
| stop_unowned_red_sar15_before_preheat | 26 | 0 | 0 | o_clk_iref_idac_sar15_low / 27 |
| stop_unowned_ir_sar15_before_preheat | 186 | 0 | 0 | o_clk_iref_idac_sar15_low / 187 |
| stop_unowned_cal_amb_before_preheat | 9 | 0 | 0 | o_clk_iref_idac_sar9_low / 10 |
| stop_unowned_cal_dcs_red_before_preheat | 9 | 0 | 0 | o_clk_iref_idac_sar9_low / 10 |
| stop_unowned_cal_dcs_ir_before_preheat | 9 | 0 | 0 | o_clk_iref_idac_sar9_low / 10 |

## 7. 驱动校验、黄金更新与问题清单

Q01～Q06均已由用户转达答复并纳入规则表，没有未确定输出拍。Q02/Q03/Q06是用户确认意图，其余依据合同。C09现有正文的澄清由统筹负责，本分支没有改合同。

修正并重跑的驱动问题：只有真实提交消耗sample index；STOP/abort后不再发布IDAC候选提交边界；行为manager等待预建立安全末沿、真实owner释放、物理ADC空闲后再延迟两拍返回CONFIG。它们是TB驱动修正，未作为SSW发现。

本次重跑32项受影响场景（包含七项补充STOP），其余已有迹线按刺激SHA256完全一致才重用。最新规则对全部155个场景重生成黄金并重比；没有用实际输出调整窗口。全部场景均有真实xsim采集、行数顺序检查和采集PASS日志。

比较器8项完整性控制通过：正确迹线正对照、单IDAC bit翻转、提前一拍LED边沿、X值、缺一行、重复行、错误低相时钟、两边沿控制变化。七个主动错误都被正确判失败，单bit和首差异位置也核对。

协议错误/身份错配sticky累计0拍。排空相关场景记录到`o_wrapper_fault_blocking`为1的6119拍；该状态单独保存，不把瞬态排空阻断当作协议sticky，也不以它反推期望波形。

尚未进行可选Spectre pulse参数核对（未收到网表路径）；没有运行RC1/Vivado 2022.2重跑、芯片顶层引脚复核或AMS/PVT联合验证。以上属于后续验证范围，不是黄金已拟合或当前SSW已闭合的证明。

## 8. 脚本复用与证据

Python 3.10+；Windows/Linux使用同一入口。模拟器、仓库、SSW路径、SAR9/SAR15模板路径、场景文件和输出目录均可参数化。移入legacy后必须给run.py与collect.py提供新模板路径。

```powershell
python -B verification/v18_ssw_golden/scripts/run.py --repo . --simulator xsim --simulator-bin D:/Xilinx/Vivado/2022.2/bin --jobs 4 --normal-red-owner-deadline 265 --normal-ir-owner-deadline 425 --sar9-template legacy/rtl/ppg_timing_sar9/ppg_timing_sar9.v --sar15-template legacy/rtl/ppg_timing_sar15/ppg_timing_sar15.v --out verification/v18_ssw_golden/_runs/rc1
python -B verification/v18_ssw_golden/scripts/collect.py --repo . --normal-red-owner-deadline 265 --normal-ir-owner-deadline 425 --sar9-template legacy/rtl/ppg_timing_sar9/ppg_timing_sar9.v --sar15-template legacy/rtl/ppg_timing_sar15/ppg_timing_sar15.v --runs verification/v18_ssw_golden/_runs/rc1 --out verification/v18_ssw_golden/_runs/rc1_final
python -B verification/v18_ssw_golden/scripts/run.py --repo . --simulator iverilog --simulator-bin C:/iverilog/bin --out verification/v18_ssw_golden/_runs/icarus
```

示例legacy路径应按RC1实际目录填写；该示例不声称目录现已迁移。用`--ssw-rtl`指定移动后的SSW，`--select`筛选场景，`--generate-only`单独冻结黄金。存在比对差异时run.py退出码为1，仍会把全部场景结果落盘；采集PASS不能替代黄金PASS。

提交的机器证据均位于`verification/v18_ssw_golden/scenarios/evidence/`：

- `trial_results.json`：每场景全部28组的首差异、差异拍数、逐bit差异、最后差异拍、归类、握手、迹线SHA256。
- `signal_comparison.csv`：155×28=4340个场景×信号比较项。
- `window_provenance.json`：获准模板参数、相对窗口、文本SHA256和包络核对。
- `owner_window_ranges.json`：两精度截止点及SAR15中途owner提交的完整/实际窗口。
- `deliverable_gate.json`：新TB严格门禁0 error / 0 strict warning。
- `comparator_checks.json`：比较器正负对照。

- `delivery_checks.json`：155场景、4340比较项、465个迹线SHA256与报告表格一致性核验。

本机原始逐拍CSV、刺激、仿真快照和日志保留于`verification/v18_ssw_golden/_runs/`，未提交大体积WDB/工具快照。`_runs/final`是按最终规则重比的完整逐拍证据；仓库中的结果和哈希可用于复跑核对。

## 9. 逐场景结果

下表的PASS/MISMATCH为最终全部模拟输出比对。首差异细节和每项差异拍数见机器CSV；各行的分类只列本行实际出现的差异。所有行均握手数量正确且待确认拍数0。

| 场景 | 采集行数 | 最终结果 | 差异组拍 | 分类 |
|---|---:|---|---:|---|
| normal_both_sar9_a5 | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| normal_both_sar9_5a | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| normal_both_sar9_00 | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| normal_both_sar9_ff | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| normal_red_sar9_a5 | 5008 | MISMATCH | 1 | V18-F02 |
| normal_red_sar9_5a | 5008 | MISMATCH | 1 | V18-F02 |
| normal_red_sar9_00 | 5008 | MISMATCH | 1 | V18-F02 |
| normal_red_sar9_ff | 5008 | MISMATCH | 1 | V18-F02 |
| normal_ir_sar9_a5 | 5008 | MISMATCH | 1 | V18-F02 |
| normal_ir_sar9_5a | 5008 | MISMATCH | 1 | V18-F02 |
| normal_ir_sar9_00 | 5008 | MISMATCH | 1 | V18-F02 |
| normal_ir_sar9_ff | 5008 | MISMATCH | 1 | V18-F02 |
| normal_both_sar15_a5 | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| normal_both_sar15_5a | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| normal_both_sar15_00 | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| normal_both_sar15_ff | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| normal_red_sar15_a5 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_red_sar15_5a | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_red_sar15_00 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_red_sar15_ff | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_ir_sar15_a5 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_ir_sar15_5a | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_ir_sar15_00 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| normal_ir_sar15_ff | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| cal_amb_a5 | 5008 | MISMATCH | 160 | V18-F04 |
| cal_amb_5a | 5008 | MISMATCH | 160 | V18-F04 |
| cal_amb_00 | 5008 | MISMATCH | 160 | V18-F04 |
| cal_amb_ff | 5008 | MISMATCH | 160 | V18-F04 |
| cal_dcs_red_a5 | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_red_5a | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_red_00 | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_red_ff | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_ir_a5 | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_ir_5a | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_ir_00 | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| cal_dcs_ir_ff | 5008 | MISMATCH | 168 | V18-F04, V18-F05 |
| precision_switch_0_1 | 10008 | MISMATCH | 5382 | V18-F01, V18-F02, V18-F03 |
| precision_switch_1_0 | 10008 | MISMATCH | 4902 | V18-F01, V18-F02, V18-F03 |
| owner_miss_red | 5008 | MISMATCH | 181 | V18-F01, V18-F02 |
| owner_miss_ir | 5008 | MISMATCH | 181 | V18-F01, V18-F02 |
| owner_miss_cal | 5008 | PASS | 0 | — |
| owner_at_deadline_normal9 | 5008 | MISMATCH | 188 | KNOWN-OWNER-DEADLINE, V18-F01, V18-F02 |
| owner_at_deadline_normal15 | 5008 | MISMATCH | 5068 | KNOWN-OWNER-DEADLINE, V18-F02, V18-F03 |
| owner_at_deadline_cal | 5008 | MISMATCH | 160 | V18-F04 |
| char_photodiode_red_sar9 | 5008 | MISMATCH | 1 | V18-F02 |
| char_current_both_sar9 | 5008 | MISMATCH | 180 | V18-F01 |
| char_current_red_sar9 | 5008 | PASS | 0 | — |
| char_current_ir_sar9 | 5008 | PASS | 0 | — |
| char_photodiode_red_sar15 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| char_current_both_sar15 | 5008 | MISMATCH | 4958 | V18-F03 |
| char_current_red_sar15 | 5008 | MISMATCH | 4979 | V18-F03 |
| char_current_ir_sar15 | 5008 | MISMATCH | 4979 | V18-F03 |
| static_bias | 5008 | PASS | 0 | — |
| cal_amb_candidate_sequence | 5008 | MISMATCH | 160 | V18-F04 |
| stop_red_sar9_before_preheat | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar9_after_preheat | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar9_before_q1 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar9_in_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar9_after_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar9_before_end | 5008 | MISMATCH | 1 | V18-F02 |
| abort_red_sar9_before_preheat | 5008 | PASS | 0 | — |
| abort_red_sar9_after_preheat | 5008 | PASS | 0 | — |
| abort_red_sar9_before_q1 | 5008 | PASS | 0 | — |
| abort_red_sar9_in_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| abort_red_sar9_after_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| abort_red_sar9_before_end | 5008 | MISMATCH | 1 | V18-F02 |
| stop_ir_sar9_before_preheat | 5008 | MISMATCH | 590 | V18-STOP-UNCOMMITTED |
| stop_ir_sar9_after_preheat | 5008 | PASS | 0 | — |
| stop_ir_sar9_before_q1 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_ir_sar9_in_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_ir_sar9_after_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| stop_ir_sar9_before_end | 5008 | MISMATCH | 1 | V18-F02 |
| abort_ir_sar9_before_preheat | 5008 | PASS | 0 | — |
| abort_ir_sar9_after_preheat | 5008 | PASS | 0 | — |
| abort_ir_sar9_before_q1 | 5008 | PASS | 0 | — |
| abort_ir_sar9_in_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| abort_ir_sar9_after_q3 | 5008 | MISMATCH | 1 | V18-F02 |
| abort_ir_sar9_before_end | 5008 | MISMATCH | 1 | V18-F02 |
| stop_red_sar15_before_preheat | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| stop_red_sar15_after_preheat | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| stop_red_sar15_before_q1 | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| stop_red_sar15_in_q3 | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| stop_red_sar15_after_q3 | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| stop_red_sar15_before_end | 5008 | MISMATCH | 317 | V18-F02, V18-F03 |
| abort_red_sar15_before_preheat | 5008 | MISMATCH | 26 | V18-F03 |
| abort_red_sar15_after_preheat | 5008 | MISMATCH | 28 | V18-F03 |
| abort_red_sar15_before_q1 | 5008 | MISMATCH | 283 | V18-F03 |
| abort_red_sar15_in_q3 | 5008 | MISMATCH | 285 | V18-F02, V18-F03 |
| abort_red_sar15_after_q3 | 5008 | MISMATCH | 285 | V18-F02, V18-F03 |
| abort_red_sar15_before_end | 5008 | MISMATCH | 287 | V18-F02, V18-F03 |
| stop_ir_sar15_before_preheat | 5008 | MISMATCH | 1592 | V18-F03, V18-STOP-UNCOMMITTED |
| stop_ir_sar15_after_preheat | 5008 | MISMATCH | 470 | V18-F03 |
| stop_ir_sar15_before_q1 | 5008 | MISMATCH | 492 | V18-F02, V18-F03 |
| stop_ir_sar15_in_q3 | 5008 | MISMATCH | 492 | V18-F02, V18-F03 |
| stop_ir_sar15_after_q3 | 5008 | MISMATCH | 492 | V18-F02, V18-F03 |
| stop_ir_sar15_before_end | 5008 | MISMATCH | 492 | V18-F02, V18-F03 |
| abort_ir_sar15_before_preheat | 5008 | MISMATCH | 186 | V18-F03 |
| abort_ir_sar15_after_preheat | 5008 | MISMATCH | 188 | V18-F03 |
| abort_ir_sar15_before_q1 | 5008 | MISMATCH | 443 | V18-F03 |
| abort_ir_sar15_in_q3 | 5008 | MISMATCH | 445 | V18-F02, V18-F03 |
| abort_ir_sar15_after_q3 | 5008 | MISMATCH | 445 | V18-F02, V18-F03 |
| abort_ir_sar15_before_end | 5008 | MISMATCH | 447 | V18-F02, V18-F03 |
| snapshot_payload_changes_sar9 | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| snapshot_payload_changes_sar15 | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| cal_lifecycle_stop_amb_before_preheat | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_amb_after_preheat | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_amb_before_q1 | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_amb_in_q3 | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_amb_after_q3 | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_amb_before_end | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_abort_amb_before_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_amb_after_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_amb_before_q1 | 5008 | MISMATCH | 9 | V18-F04 |
| cal_lifecycle_abort_amb_in_q3 | 5008 | MISMATCH | 17 | V18-F04 |
| cal_lifecycle_abort_amb_after_q3 | 5008 | MISMATCH | 19 | V18-F04 |
| cal_lifecycle_abort_amb_before_end | 5008 | MISMATCH | 20 | V18-F04 |
| cal_lifecycle_stop_dcs_red_before_preheat | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_red_after_preheat | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_red_before_q1 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_red_in_q3 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_red_after_q3 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_red_before_end | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_red_before_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_dcs_red_after_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_dcs_red_before_q1 | 5008 | MISMATCH | 9 | V18-F04 |
| cal_lifecycle_abort_dcs_red_in_q3 | 5008 | MISMATCH | 18 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_red_after_q3 | 5008 | MISMATCH | 20 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_red_before_end | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_before_preheat | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_after_preheat | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_before_q1 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_in_q3 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_after_q3 | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_stop_dcs_ir_before_end | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_ir_before_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_dcs_ir_after_preheat | 5008 | PASS | 0 | — |
| cal_lifecycle_abort_dcs_ir_before_q1 | 5008 | MISMATCH | 9 | V18-F04 |
| cal_lifecycle_abort_dcs_ir_in_q3 | 5008 | MISMATCH | 18 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_ir_after_q3 | 5008 | MISMATCH | 20 | V18-F04, V18-F05 |
| cal_lifecycle_abort_dcs_ir_before_end | 5008 | MISMATCH | 21 | V18-F04, V18-F05 |
| normal_led_patterns_sar9 | 20008 | MISMATCH | 728 | V18-F01, V18-F02 |
| normal_color_codes_sar9 | 5008 | MISMATCH | 182 | V18-F01, V18-F02 |
| normal_led_patterns_sar15 | 20008 | MISMATCH | 19840 | V18-F02, V18-F03 |
| normal_color_codes_sar15 | 5008 | MISMATCH | 4960 | V18-F02, V18-F03 |
| owner_miss_red_sar15 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| owner_miss_ir_sar15 | 5008 | MISMATCH | 4980 | V18-F02, V18-F03 |
| known_sar15_deadline_red_275 | 5008 | MISMATCH | 5010 | KNOWN-OWNER-DEADLINE, V18-F02, V18-F03 |
| known_sar15_deadline_ir_435 | 5008 | MISMATCH | 5010 | KNOWN-OWNER-DEADLINE, V18-F02, V18-F03 |
| stop_unowned_red_sar9_before_preheat | 5008 | MISMATCH | 590 | V18-STOP-UNCOMMITTED |
| stop_unowned_ir_sar9_before_preheat | 5008 | MISMATCH | 590 | V18-STOP-UNCOMMITTED |
| stop_unowned_red_sar15_before_preheat | 5008 | MISMATCH | 1714 | V18-F03, V18-STOP-UNCOMMITTED |
| stop_unowned_ir_sar15_before_preheat | 5008 | MISMATCH | 1874 | V18-F03, V18-STOP-UNCOMMITTED |
| stop_unowned_cal_amb_before_preheat | 5008 | MISMATCH | 492 | V18-STOP-UNCOMMITTED |
| stop_unowned_cal_dcs_red_before_preheat | 5008 | MISMATCH | 590 | V18-STOP-UNCOMMITTED |
| stop_unowned_cal_dcs_ir_before_preheat | 5008 | MISMATCH | 590 | V18-STOP-UNCOMMITTED |

## 10. 里程碑与边界

M1 `77491f2`：规则表初稿和问题清单；M2 `9f0711e`：独立黄金与NORMAL双光SAR9真实比对；M3 `37e9a04`：完整矩阵、最终确认规则和分类证据；M4：本报告。每个里程碑分别提交并仅推送任务分支。

相对于基线main仅新增`verification/v18_ssw_golden/`与`verification_reports/V18_*.md`，不修改任何原有文件、不登记回归、不合并分支。报告由统筹核实发现、重复项、规范意图和RC1修复后状态；本次是流片前验证证据，不能代替芯片签核。
