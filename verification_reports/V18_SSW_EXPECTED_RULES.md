# V18 SSW 逐拍期望规则（统筹答复已纳入）

日期：2026-10-10。基线：main `4863ec6e8f1298a7a9d543b3cd1a82e7a3d08fcb`。分支：`v18-ssw-golden`。

本表已纳入统筹对`9044d3a`的后续订正：STOP按owner是否已提交分支处理，截止截短统一列KNOWN-OWNER-DEADLINE，所有动态波形的TIA与TIAEN相同（STATIC例外）。最新用户确认优先于旧答复和旧合同表，不从SSW输出反推规则。

## 1. 独立性与来源

全新克隆目录；未阅读 SSW 目录中的任何文件内容（包括 RTL、单元 TB、综合脚本），未阅读禁读的闭合矩阵、别名表或其他报告。SSW 仅可作为仿真器输入。没有使用旧工作树记忆。

实际阅读的设计依据：

- `verification_reports/V18_SSW_GOLDEN_BRIEF_20261010.md`（main）。
- `verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md`（main，V18 与相关阶段段落）。
- `contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`（仅 origin/b-merge-batch，V1.11）。
- `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`（main，V1.12，端口/相位/事务协议）。
- `rtl/ppg_timing_sar9/ppg_timing_sar9.v`。
- `rtl/ppg_timing_sar15/ppg_timing_sar15.v`。
- `rtl/ppg_timing_sar9/ppg_timing_sar9_3200hz.v`。
- `rtl/ppg_timing_sar15/ppg_timing_sar15_3200hz.v`。

工程流程另读：根 `CLAUDE.md`、`.claude/skills/erie-verilog-generator/SKILL.md` 和该技能 `references/workflows/verilog_dispatcher.md`。实际新增读取项将在最终报告逐一登记。会话开始时只列出了旧空仓库中的文件名，未读其报告内容。

## 2. 坐标与窗口定义

时钟 2 MHz，每拍 0.5 us；宏帧 5000 拍，校准子帧 625 拍。以下全部为左闭右开 `[start,end)`，数字逻辑电平直接取 0/1，不根据 `_low` 猜电气极性。

两种早期时序模板的 RED Q3 中心均为 34（SAR15 从 LED/Q3 `[30,38)` 的中心计算）。NORMAL 把模板 RED 平移 +266 到中心 300；模板 IR 中心 194 平移 +266 到 460。跨帧窗口先展开为负坐标，例如 SAR9 `5000-222` 相对 Q3 为 -256。单光仍用同一中心，关闭另一颜色。3200 Hz 变体只是例化相同核心并设 `C_FRAME_TICKS=625`，没有独立窗口定义。

SAR9 包络 `[-256,+18)` => RED `[44,318)`、IR `[204,478)`；SAR15 `[-273,+8)` => RED `[27,308)`、IR `[187,468)`，与 C09 §4.3 一致。AMB_CAL中心266、包络 `[10,284)`，除用户已作废的TIA静态0一行外，其余采用C09 §6.1专用表。

## 3. 全部 28 组模拟输出

表内 N9/N15 为相对对应颜色 Q3 中心的窗口；0 表示整段保持零。AMB 列为绝对子帧拍。N9/N15 两色脉冲做并集；码总线按各色窗口取各自快照码，不以使能窗口代替码窗口。STATIC 为 C09 §8.5 原始静态值。除特别指出外均非“RTL派生条文”。

| 输出 | N9 相对窗口/值 | N15 相对窗口/值 | AMB_CAL local | STATIC | 原始依据 |
|---|---|---|---|---|---|
| `o_en_tia_low` | `[-17,+3)`，同TIAEN | `[-34,+5)`，同TIAEN | `[249,269)`，同TIAEN | 0 | **用户确认（10-10）最新F04规则**；C09 §6.1原“始终0”作废；STATIC仍§8.5 |
| `o_leddac[7:0]` | `[-2,+1)` LED快照 | `[-5,+4)` LED快照 | 0 | 0 | 模板 `R_LED_CODE_*`；C09 §5.1/6.2/8.4/8.5 |
| `o_leden1_low` | RED `[-1,+1)` | RED `[-4,+4)` | 0 | 0 | 模板 `R_LED_*`；C09 §4.6/6.2 |
| `o_leden2_low` | IR `[-1,+1)` | IR `[-4,+4)` | 0 | 0 | 模板 `IR_LED_*`；C09 §4.6/6.2 |
| `o_en_test` | 光电输入0，固定电流1 | 同N9 | 0 | 1 | C09 §7.7/8.4/8.5 |
| `o_clk_buf_low` | 0 | 0 | 0 | 1 | 模板固定输出；C09 §6.1/8.5 |
| `o_clk_2m` | 与 `i_clk` 同相 | 同N9 | 同N9 | 同N9 | C09 §7.7、SSW-25，复位也转发 |
| `o_clk_iref_idac_low` | `[-37,+3)` | `[-54,+6)` | `[229,269)` | 1 | 模板 `R_IDAC_CLOCK_*`；C09 §6.1/8.5 |
| `o_clk_9q1_low` | `[-7,+2)` | 0 | `[259,268)` | 0 | N9 `R_Q1_*`；C09 §6.1 |
| `o_clk_15q1_low` | 0 | `[-16,+5)` | 0 | 0 | N15 `R_Q1_*`；C09 §6.1 |
| `o_clk_aferst_low` | `[-17,-5)` | `[-34,-14)` | `[249,261)` | 1 | 模板 `R_AFERST_*`；C09 §6.1/8.5 |
| `o_clk_iref_idac_sar9_low` | `[-256,+18)` | 0 | `[10,284)` | 1 | N9 `R_SAR9_IREF_*`；C09 §4.6/6.1/8.5 |
| `o_clk_iref_idac_sar15_low` | 0 | `[-273,+8)` | 0 | 1 | N15 `R_SHARED_IREF_START/CONTROL_END`；C09 §4.6 |
| `o_clk_q2_low` | `[-4,-2)` | `[-13,-5)` | 0 | 0 | 模板 `R_Q2_*`；C09 §6.1，AMB禁Q2 |
| `o_clk_q3_low` | `[-1,+1)` | `[-4,+4)` | `[265,267)` | 0 | 模板 `R_LED_*`；C09 §4.2/6.1 |
| `o_clk_tiaen_low` | `[-17,+3)` | `[-34,+5)` | `[249,269)` | 1 | 模板 `CTRL_CLK_TIAEN`；C09 §6.1/8.5 |
| `o_en_15sar_low` | 0 | 跟随已提交精度，RUN整帧保持1，包括波形外；回CONFIG为0 | 0 | 0 | **用户确认（10-10）Q02**；模板 `CTRL_EN_15SAR`；STATIC例外C09 §8.5 |
| `o_en_sar9_amb_low` | `[-44,+10)` | 0 | `[222,276)` | 1 | N9 `R_ENABLE_CODE_*`；C09 §4.6/6.1 |
| `o_en_sar9_dc_low` | `[-44,+10)` | 0 | 0 | 1 | N9 `R_ENABLE_CODE_*`；C09 §4.6/6.1 |
| `o_en_sar9_iref` | `[-64,+8)` | 0 | `[202,274)` | 0 | N9 `R_ENABLE_IREF_*`；C09 §4.6/6.1 |
| `o_en_sar15_amb_low` | 0 | `[-253,+8)` | 0 | 1 | N15 `R_SHARED_ENABLE_START/CONTROL_END`；C09 §4.6 |
| `o_en_sar15_dc_low` | 0 | `[-253,+8)` | 0 | 1 | N15同上；C09 §4.6 |
| `o_en_sar15_iref` | 0 | `[-273,+6)` | 0 | 0 | N15 `R_SHARED_IREF_START/END`；C09 §4.6 |
| `o_idac_sar9ambn_low[7:0]` | `[-42,+10)` AMB快照 | 0 | `[224,276)` AMB候选快照 | 0 | N9 `R_IDAC_AMB_*`；C09 §4.7/6.1 |
| `o_idac_sar9dcn_low[7:0]` | `[-34,+10)` 当前色DC快照 | 0 | 0 | 0 | N9 `R_IDAC_DC_*`；C09 §4.7 |
| `o_idac_sar15ambn_low[7:0]` | 0 | `[-97,+8)` AMB快照 | 0 | 0 | N15 `R_IDAC_AMB_START/CODE_END`；C09 §4.7 |
| `o_idac_sar15dcn_low[7:0]` | 0 | `[-149,+8)` 当前色DC快照 | 0 | 0 | N15 `R_IDAC_DC_START/CODE_END`；C09 §4.7 |
| `o_s_in[4:0]` | 0 | 0 | 0 | 已提交MUX | C09 §7.7/8.5，五位同沿更新 |

C09 §7.7 实际列出 28 组输出（总线按组）；计划中的“32路”不作为删减接口的依据，全部28组/67位均纳入比对。

## 4. 组合、抑制和生命周期规则

1. **NORMAL**：只有固定 tick 0/160 成功握手的颜色槽才能产生窗口；SAR9/SAR15 各自专属输出和未选精度码总线强制隔离。波形快照冻结所有码、epoch、输入源、光学模式、颜色、精度、帧号（C09 §4.7/5.1/5.2）。实时输入中途变化不污染快照。
2. **双光**：SAR9 仅参考时钟可跨色连续 `[44,478)`，其三个使能分别按颜色窗口并集，不得由另一色预热阶段覆盖；SAR15 仅参考时钟及 IREF/AMB/DC 三个使能允许跨色连续（C09 §4.6）。两 LED 恒互斥。
3. **AMB_CAL**：按专用local窗口，TIA与TIAEN同为 `[249,269)`，受owner资格同时抑制；DC输出全部0、LED全关、Q2全关。**用户确认（10-10）**取代C09 §6.1 TIA静态0行。
4. **DCS_CAL**：固定SAR9、AMB已确认码+当前色DC候选码，仅当前色 LED，Q3 local 266（C09 §4.4/4.7/5.5）。统筹确认Q01：取SAR9模板RED单色相对窗口平移到266，RED/IR同样local包络 `[10,284)`；颜色只决定LED1/2和DC快照，不保留160拍偏移。逐端口即上表N9列加266，另一颜色LED为0。AMB仍独立采用§6.1。
5. **owner**：上下文先于 owner；只向最早 pending 槽提交；身份逐位一致且 ready=1。RED/IR/CAL 最晚 283/443/248 当拍提交，之后无owner时抑制 Q1/Q2/Q3、LED有效采样，已开始的预建立安全结束；不移动 Q3、不用 ADC idle 或固定延迟冒充DONE（C09 §4.5/5.3、C08 §10）。**用户确认（10-10）Q03：该槽LEDDAC同样保持 `8'h00`**，不得把“LEDEN=0”当作允许码总线非零的理由。
6. **STOP（Q04订正）**：禁止新上下文/owner。**owner已在STOP之前提交**的槽应完整运行原模板包络，即使首个预热边沿尚未出现；结果丢弃，真实匹配 `success=0` DONE才释放。**owner未提交且首边沿之前STOP**的槽不再启动，之后不得出现该波形边沿；已开始但未提交owner的预建立仍安全收尾，采样相关窗口整槽抑制。行为manager等待安全末沿和物理ADC空闲后回CONFIG；新增未提交场景保守保持RUN至预约末沿，避免外部强制CONFIG掩盖错误。此前未区分owner的F06判断撤回。
7. **abort/reset**：abort撤销槽与pending，下一个控制更新进入活动核 disable 安全向量；reset立即清空可撤销控制与数字身份。模板动态向量 disable 时为全0，`o_clk_2m`仍转发；EN_TEST/MUX须隔离迟到控制提交（C09 §8.3、SSW-23/25/32）。
8. **CHARACTERIZATION**：光电只允许 RED_ONLY、固定SAR9/15，复用NORMAL RED窗口；固定电流 BOTH/RED/IR、固定精度，EN_TEST=1、LED/LEDDAC=0、S=0，保留所选精度AMB/DC码窗口（C09 §8.4）。拒绝校准和OFF非法组合。
9. **STATIC_BIAS**：只允许profile=CHARACTERIZATION、static=1、input_source=1；逐位按静态列，所有Q/LED/码总线0；MUX跟随已提交 `i_test_mux_ctrl`，五位同拍变化，不接受波形/owner（C09 §7.3/8.5）。统筹确认Q05：`static_test_commit_event`是上游CDC事件，不是SSW端口。模板历史静态覆盖与此不同，静态黄金以合同为准。
10. **先断后通/精度切换**：只在固定接管点改变解释，至少一个注册边沿没有两个精度同时驱动，当前帧快照不被实时精度请求改写（C09 §8.1/5.1）。

## 5. RTL派生条文标记

以下黄金/协议规则依赖 V1.11 补记/改写，明确标记为“RTL派生条文”，不能视为完全独立的规范发现：owner还需帧/子帧绑定（§5.3 L-1）、RUN代际与lost event释放（§5.3/7.6 R3）、local385迟到只置非阻断sticky（§5.4/7.8/SSW-18 S1）、abort与匹配完成同拍完成优先（§8.3 F-035）、START恢复残留未提交槽及停止挂起（§8.3a L-6）。NORMAL窗口和AMB专用数字窗口不是这类V1.11补记推导。

## 6. 五项问题的确认记录

| ID | 问题 | 确认与处理 |
|---|---|---|
| Q01 | DCS_CAL模板和IR偏移 | 已确认：SAR9 RED相对窗口，local Q3=266，颜色不改时序 |
| Q02 | N15精度选择电平保持范围 | 用户确认（10-10）：跟随已提交精度，4760提交，经输出寄存捕获后切换，RUN整帧保持；CAL/CONFIG/STATIC为0 |
| Q03 | 无owner时LEDDAC抑制 | 用户确认（10-10）：与LEDEN一起清零 |
| Q04 | 首个预热边沿之前STOP | **后续订正**：已提交owner完整运行并丢弃；未提交owner才禁止启动 |
| Q05 | STATIC MUX是否有SSW提交事件 | 已确认：无额外端口；跟随经上游CDC已提交输入，五位原子更新 |

Q02的刺激/采样约定：已提交精度在对应tick的低相预置，下一上升沿由SSW输出寄存捕获，CSV在该沿后1ns观察；因此该CSV行代表已发生寄存捕获的输出。真实上游若在4760沿后发布提交值，消费者下一上升沿才看到它。重跑时不能靠任意移位实际波形来消除差异。

## 7. M3规则边界 Q06的用户确认与已知问题

owner错过截止后，`o_en_tia_low`、`o_clk_aferst_low`、`o_clk_tiaen_low`与Q1/Q2/Q3、LEDEN、LEDDAC一样，**整槽不出现**。这些受owner控制的窗口必须按模板完整出现，或整槽关闭；模拟侧不接受窗口被截短。此条由用户（模拟设计者）**2026-10-10确认**，不是SSW实际输出反推。

黄金按整槽最终按时提交资格选择完整窗口；不能把owner到达之后的残余窗口当作合法模板。未按时提交则这三项及原采样控制全部为0；已经开始的非采样预建立控制仍按安全末沿收尾。

上述完整窗口规则用于正常执行、owner截止抑制与STOP安全收尾。control_abort和复位仍按C09 §8.3撤销；被撤销的样本只走受控丢弃，不能当作合法完整转换结果。

统筹统一命名 **KNOWN-OWNER-DEADLINE**：包括SAR15 RED275/IR435提交的截短、两精度在当前283/443截止点同拍提交的截短；原F07并入已知项，**不计为新发现**。当前main仍用C09的283/443作历史基线。修复轮将两精度NORMAL截止统一提前到RED265、IR425，并规定截止当拍允许提交、受owner控制的边沿最早下一拍开始。

脚本新增`--normal-red-owner-deadline`、`--normal-ir-owner-deadline`，RC1时run.py和collect.py同时传265/425。截止点场景随参数调整；历史275/435探针若已超新截止，不发送非法owner提交，按错过截止整槽抑制检查，同时保留requested_owner记录。该参数准备不代表本机已运行修复后的RTL。

## 8. 最新TIA统一规则

**用户确认（10-10）**：NORMAL、CHARACTERIZATION、AMB_CAL、DCS_CAL及owner错过截止时，`o_en_tia_low == o_clk_tiaen_low`，使用相同完整窗口和相同抑制资格。唯一例外STATIC_BIAS为TIA=0、TIAEN=1。原报告把AMB TIA=0当作正确的判断作废；按新规则重新运行所有AMB场景。

可选 Spectre 参数复核：尚未进行，未收到网表路径；不据此等待或推迟其他里程碑。
