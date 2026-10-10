# V18 SSW 逐拍期望规则（M1 初稿）

日期：2026-10-10。基线：main `4863ec6e8f1298a7a9d543b3cd1a82e7a3d08fcb`。分支：`v18-ssw-golden`。

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

SAR9 包络 `[-256,+18)` => RED `[44,318)`、IR `[204,478)`；SAR15 `[-273,+8)` => RED `[27,308)`、IR `[187,468)`，与 C09 §4.3 一致。AMB_CAL 按 C09 §6.1，中心 266、包络 `[10,284)`，不能从 NORMAL 的静态输出覆盖规则推导。

## 3. 全部 28 组模拟输出

表内 N9/N15 为相对对应颜色 Q3 中心的窗口；0 表示整段保持零。AMB 列为绝对子帧拍。N9/N15 两色脉冲做并集；码总线按各色窗口取各自快照码，不以使能窗口代替码窗口。STATIC 为 C09 §8.5 原始静态值。除特别指出外均非“RTL派生条文”。

| 输出 | N9 相对窗口/值 | N15 相对窗口/值 | AMB_CAL local | STATIC | 原始依据 |
|---|---|---|---|---|---|
| `o_en_tia_low` | `[-17,+3)` | `[-34,+5)` | 0 | 0 | 模板 `CTRL_EN_TIA`、`R_EN_TIA_*`；C09 §6.1/8.5 |
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
| `o_en_15sar_low` | 0 | **Q02待确认**：模板 `i_enable=1` 时恒1 | 0 | 0 | N15 `CTRL_EN_15SAR`、C09 §8.1/8.5 |
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
3. **AMB_CAL**：严格采用上表专用 local 窗口；TIA输出静态0、DC输出全部0、LED全关、Q2全关；不把 NORMAL TIA高电平套过来（C09 §6.1/6.2）。
4. **DCS_CAL**：固定SAR9、AMB已确认码+当前色DC候选码，仅当前色 LED，Q3 local 266（C09 §4.4/4.7/5.5）；逐信号模板选择列 Q01，确认前不宣称完整黄金已确定。
5. **owner**：上下文先于 owner；只向最早 pending 槽提交；身份逐位一致且 ready=1。RED/IR/CAL 最晚 283/443/248 当拍提交，之后无owner时抑制 Q1/Q2/Q3、LED有效采样，已开始的预建立安全结束；不移动 Q3、不用 ADC idle 或固定延迟冒充DONE（C09 §4.5/5.3、C08 §10）。LEDDAC是否也属于“LED有效采样”抑制范围列 Q03。
6. **STOP**：禁止新上下文/owner，已开始包络安全运行至原末沿；未提交owner的槽不得产生Q1/Q2/Q3；已提交owner丢弃挂起，真实匹配 `success=0` DONE才释放（C09 §8.2）。不能凭STOP强制截断已开始脉冲。STOP早于首边沿的已接管槽是否继续进入预建立列 Q04。
7. **abort/reset**：abort撤销槽与pending，下一个控制更新进入活动核 disable 安全向量；reset立即清空可撤销控制与数字身份。模板动态向量 disable 时为全0，`o_clk_2m`仍转发；EN_TEST/MUX须隔离迟到控制提交（C09 §8.3、SSW-23/25/32）。
8. **CHARACTERIZATION**：光电只允许 RED_ONLY、固定SAR9/15，复用NORMAL RED窗口；固定电流 BOTH/RED/IR、固定精度，EN_TEST=1、LED/LEDDAC=0、S=0，保留所选精度AMB/DC码窗口（C09 §8.4）。拒绝校准和OFF非法组合。
9. **STATIC_BIAS**：只允许profile=CHARACTERIZATION、static=1、input_source=1；逐位按静态列，所有Q/LED/码总线0；MUX仅用已提交值，不接受波形/owner（C09 §8.5）。模板历史静态覆盖与此不同，静态黄金以合同为准。
10. **先断后通/精度切换**：只在固定接管点改变解释，至少一个注册边沿没有两个精度同时驱动，当前帧快照不被实时精度请求改写（C09 §8.1/5.1）。

## 5. RTL派生条文标记

以下黄金/协议规则依赖 V1.11 补记/改写，明确标记为“RTL派生条文”，不能视为完全独立的规范发现：owner还需帧/子帧绑定（§5.3 L-1）、RUN代际与lost event释放（§5.3/7.6 R3）、local385迟到只置非阻断sticky（§5.4/7.8/SSW-18 S1）、abort与匹配完成同拍完成优先（§8.3 F-035）、START恢复残留未提交槽及停止挂起（§8.3a L-6）。NORMAL窗口和AMB专用数字窗口不是这类V1.11补记推导。

## 6. 问题清单（确认前不拟合SSW输出）

| ID | 问题 | 影响/当前处理 |
|---|---|---|
| Q01 | DCS_CAL RED/IR选哪个SAR9模板？是否展开单色相对窗口并移到266，IR不保留160偏移？ | 按任务书§1.2通过用户转问统筹；DCS黄金待定 |
| Q02 | N15 `o_en_15sar_low` 在整个RUN恒1，还是仅对应包络为1？模板 enable 时恒1，C09未给单独窗口。 | 已转问统筹；其他N15输出可以独立确定 |
| Q03 | 无owner时除LEDEN/Q1/Q2/Q3外，LEDDAC码窗是否必须为0？“LED有效采样”没有逐端口定义。 | 保留明确Q/LEDEN规则，LEDDAC相关拍标不确定 |
| Q04 | STOP在上下文接管后、首边沿前到达，是否允许随后预建立？§8.2只说“已开始包络”。 | 必须区分未开始和已开始，记录待确认 |
| Q05 | STATIC MUX提交事件未出现在C09 §7端口表；是否直接驱动经CDC已提交的 `i_test_mux_ctrl` 而无额外event端口？ | TB只接表中端口；只送已提交稳定值，不模拟SPI shadow |

可选 Spectre 参数复核：尚未进行，未收到网表路径；不据此等待或推迟其他里程碑。
