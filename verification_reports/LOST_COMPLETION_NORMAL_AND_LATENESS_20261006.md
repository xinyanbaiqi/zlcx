# ADC完成丢失与迟到：NORMAL测量侧仿真、校准侧合法迟到上限、L-2需求选项（只读，2026-10-06）

接`verification_reports/SSW18_TICK385_INVESTIGATION_20261006.md`（`7364916`，下称“SSW-18报告”）。本次只在仓库外用临时TB做xsim仿真，没有改任何RTL、TB、合同、矩阵、别名表或tools文件。

- **被测版本**：`517ab78`导出，RTL与`7364916`相同。推送时`origin/main`为`817c4e9`：ABCD会话的TB轮（`4085a02`）只改了TB、`.vh`和脚本，RTL仍与`517ab78`相同，所以结论适用于当前HEAD；但本报告的临时TB是基于`517ab78`版的TB生成的。
- **证据目录**：`D:\PPG\verilog\ppg_regression_runs\lost_completion_20261006\`，含两份临时TB、生成脚本、文件清单和xsim日志。
- **工具**：Vivado 2022.2 xsim。

## 编号对应与订正

- SSW-18报告中的N-1/N-2，与ABCD复核报告已有的N-1（AMI诊断清除不检查blocking）撞号，按用户决定改称：
  - **L-1**：跨宏帧重挂与错绑（原N-1）；
  - **L-2**：丢失完成后静默停滞（原N-2）。
- 已推送的SSW-18报告不改，本报告及以后统一使用L编号。
- 本报告新发现两项，续编为L-3、L-4（见第0节）。
- 行号订正：L-1的调度器条件在`ppg_400hz_frame_calibration_scheduler.v:821`（`if(… || state_current[B_INFLIGHT])`），赋值在`:822`。复核意见中写的`:820-822`差一行；`:467-468`（RED/IR owner截止带`!B_INFLIGHT`）无误。

## 0. 结论先行

- **(a) NORMAL测量侧**（control_top层，双光MANUAL，前3个宏帧正常后注入；对照组10帧、22个owner、22个正式结果、10次NORMAL帧完成）：

| 组 | 注入 | 正式结果 | 结束状态 | 关键现象 |
|---|---|---|---|---|
| 对照 | 无 | 22 | RUN，eligible=1 | 无任何sticky |
| DROPIR | 丢1次IR完成 | 20 | RUN，eligible=1 | **L-1在NORMAL下发生，并输出了身份错误的正式结果**：下一帧IR的Q3在旧IR owner名下执行，它的`CLK_DOUT`完成了旧owner；正式结果标为“帧3、IR、idx 7”，实际是帧4的转换。全程只有两个非阻断sticky |
| DROPRED | 丢1次RED完成 | 6 | **STOPPING永久不出来**，eligible=0 | 下一帧RED的Q3在旧RED owner名下执行，完成旧owner之后，调度器在**同一拍**既判RED截止又提交新RED owner（macro tick 309，Q3早已结束）→ SSW identity/owner协议错误`8'h21` → supervisor abort+STOP → 新owner永远等不到转换，STOP排空永久卡住；supervisor看门狗因`i_adc_physical_idle=1`不计数（**L-4**） |
| DEAD | 从帧3起ADC不再应答 | 6 | RUN，eligible=1，在途=1 | **L-2在NORMAL下同样成立**：此后每帧RED的Q3都在旧owner名下执行，正式结果停止输出，系统停在RUN。只有SSW非阻断owner截止sticky置位，调度器截止被`!B_INFLIGHT`屏蔽（`:467-468`），没有任何阻断故障 |

- **(b) 校准侧合法迟到上限**：
  - RTL对迟到没有任何时间上限。只要owner仍在途、期间没有新的转换，迟到结果就按它自己的码作为合格样本消费。实测最晚到子帧7 local tick 606仍被合格消费。
  - 但迟到超过本子帧tick 385就会让下一候选推迟一个子帧。**若发生在校准宏帧最后一个子帧（sf7）的tick 385之后，启动搜索永久死锁（L-3）**：IDAC停在`ST_AMB_APPLY`，有pending候选、等待安全边界；调度器没有请求就不开新的校准宏帧，没有宏帧就没有边界。没有任何诊断。
  - 迟到跨过本宏帧末尾、到了下一宏帧时，会出现L-1错绑。
- **(c) L-2需求选项**：见第4节。
  - 阈值要大于“合法迟到”，但必须小于“下一次同槽位接管”，否则先发生L-1错绑。
  - 任何处置都必须包含**释放在途的旧owner**，否则STOP排空会像L-4那样卡死。这与现行“abort后保留最小身份、只等真实DONE释放”的合同规则冲突，需要用户先定新规则。

## 1. 实验设计

### 1.1 NORMAL侧临时TB `tb_lost_done_normal.v`

- 由`make_tb_normal.py`从`tb_ppg_control_top.v`（517ab78）生成。
- 后台ADC响应进程（`bg_responder`，只在真实Q3释放后才驱动`CLK_DOUT`）增加三个开关：只丢下一笔NORMAL RED完成、只丢下一笔IR完成、从此不再响应。
- 实验段插在原SMOKE序列之前，以`$finish`结束：
  - 提交双光MANUAL配置（`task_build_normal_manual_dual_config`）并START；
  - 正常运行到帧3开始，再按plusarg（`DROPRED`/`DROPIR`/`DEAD`）注入；
  - 之后运行40000拍（8个宏帧）。
- 只读监视器打印：owner提交、AMI完成、正式结果（含帧号、序号、颜色）、每次Q3上升时调度器在途状态和SSW各槽位的owner、NORMAL帧完成、12个sticky/故障位的变化、生命周期变化、supervisor的故障记录与abort/STOP、STOP合并请求，以及STOPPING期间的排空条件。

### 1.2 校准侧

沿用SSW-18报告的`tb_ssw18_late_completion.v`，新增：
- `LATE6SF`：第2个候选的完成推迟到子帧7 local tick 600；
- 结束时打印IDAC状态、pending、请求，以及调度器帧状态。

## 2. NORMAL侧结果（(a)）

### 2.1 DROPIR：L-1在NORMAL下发生，正式结果身份错误

| 时刻 | 事件 |
|---|---|
| 帧3 mt1 / mt309 | RED owner idx6 / IR owner idx7 提交 |
| 帧3 mt460 | IR的Q3；响应进程**跳过**这次完成 |
| 帧4 mt285 | SSW owner截止sticky置位：帧4 RED因旧IR owner在途无法提交，被SSW抑制 |
| 帧4 mt460 | 帧4 IR的Q3上升，`ssw_ir_owner=1`（旧owner，槽位IR） |
| 帧4 mt468 | `DONE idx=7`：帧4的转换完成了帧3的owner |
| 帧4 mt470 | 调度器owner截止sticky置位（旧owner释放后，帧4 IR的pending超过443） |
| 帧4 mt473 | **`RESULT result_frame=3 result_idx=7 color_ir=1 sample_valid=1`**：正式输出标为帧3，实际为帧4的样本 |
| 帧5起 | 恢复正常 |

- 帧3、帧4都没有NORMAL帧完成事件。
- 没有阻断故障。

### 2.2 DROPRED：L-4，同拍截止与提交，STOP排空永久卡住

| 时刻 | 事件 |
|---|---|
| 帧3 mt1 | RED owner idx6 提交 |
| 帧3 mt300 | RED的Q3；响应进程**跳过**这次完成 |
| 帧3 mt445 | SSW owner截止sticky置位（帧3 IR因旧RED owner在途无法提交，被抑制） |
| 帧4 mt300 | 帧4 RED的Q3上升，`ssw_red_owner=1`（旧owner） |
| 帧4 mt308 | `DONE idx=6`：帧4的转换完成了帧3的owner |
| 帧4 mt309 | `OWNER color_ir=0 idx=7`：调度器在RED截止（283）之后提交帧4 RED owner。`transaction_start_valid_o`（`:455`）没有截止门控，而同拍`flag_red_owner_deadline`（`:467`、`:739-742`）也成立 |
| 帧4 mt310 | SSW阻断故障，`MON SUPIN ssw fault record cause=21`（C24:82，SSW identity/owner protocol error） |
| 帧4 mt311 | supervisor system abort和system STOP request；随后合并STOP送manager，生命周期进入STOPPING（`11`） |
| 之后约450 µs | `MON DRAIN episode=1 adc_phys_idle=1 datapath_empty=0 idac_idle=1 analog_safe=1 sched_idle=0 inflight=1 sys_blocking=1`，直到仿真结束都不变 |

- 新owner idx7在Q3之后才提交，永远不会有对应的转换。按abort规则它保留最小身份、等待真实DONE，所以排空永远完成不了。
- supervisor看门狗只在“STOP episode期间且物理ADC非idle”时计数（C24第6节），这里物理ADC是idle，所以不触发。
- 结果：系统永久停在STOPPING，`eligible=0`，阻断故障为1，只有复位才能恢复。

### 2.3 DEAD：L-2在NORMAL下成立

- 帧3 RED owner idx6在途后，ADC不再应答。
- 帧4~10每帧RED的Q3都上升且`ssw_red_owner=1`（旧owner），但没有完成。
- 正式结果停在6个（对照组为22个），NORMAL帧完成停在3次。
- 唯一的sticky变化是帧3 mt445的SSW owner截止（IR被抑制）。调度器的RED/IR截止被`!B_INFLIGHT`屏蔽（`:467-468`）。
- 结束时生命周期为RUN（`10`）、`eligible=1`、在途=1，没有阻断故障。系统对外显示一切正常，但已经不再产出测量结果。

### 2.4 小结

- 所有NORMAL变体中，旧owner都会在下一次同槽位接管时掩盖SSW的截止抑制。原因是SSW的`flag_red_has_owner`/`flag_ir_has_owner`（`ppg_sar9_sar15_safe_selection_wrapper.v:431-432`）只看全局在途owner及其槽位，不区分属于哪一帧。
- 另一槽位则会被SSW按截止抑制（`ssw_own_dl`），所以丢一笔完成至少会损失下一帧的另一色。

## 3. 校准侧合法迟到上限（(b)）

| 完成时刻（候选2，owner在sf1提交） | 样本 | 下一码提交 | 损失 | 来源 |
|---|---|---|---|---|
| sf1 lt274（对照） | 合格，码65 | sf1 lt386 | 无 | SSW-18报告 |
| sf1 lt406 | 合格，码65 | sf2 lt386 | 1个子帧 | SSW-18报告 |
| sf2 lt106 | 合格，码65 | sf2 lt386 | 1个子帧 | SSW-18报告 |
| sf3 lt106 | 合格，码65 | sf3 lt386 | 2个子帧 | SSW-18报告 |
| **sf7 lt606** | **合格，码65** | **永不提交** | **启动搜索永久死锁（L-3）** | 本报告 |
| 下一宏帧sf0 lt274（NODONE） | 合格，但绑定的是上一宏帧的owner | 下一宏帧sf0 lt386 | L-1错绑 | SSW-18报告 |

L-3的结束状态（`EXP STATE`）：
- LATE6SF：`idac_state=2(ST_AMB_APPLY) amb_pending=1 amb_request=0 ami_cal_valid=0 sch_frame_active=0 cal_frame_active=0 cal_req_pending=0 sch_idle=1`，之后约11 ms仿真时间内没有任何请求、Q3或码提交；
- 对照：`idac_state=3(ST_AMB_WAIT) amb_request=1 cal_frame_active=1`。

机理：
- IDAC只在`i_frame_safe_boundary`提交候选（`ppg_idac_code_controller.v:583-591`、`:719`）；
- 校准帧内这个边界在每个子帧的local tick 385；
- sf7的385已过、宏帧随即结束（`:814`起的末拍处理）；
- 调度器开新宏帧要求校准请求pending或NORMAL资格成立（`flag_frame_start_eligible`，`:436`，在`:754`使用），启动搜索未完成时后者不成立；
- IDAC在候选提交前不发请求；
- 两边互相等待。

结论：
- “被当作有效样本消费”在RTL中没有时间上限，只要owner仍在途、没有新转换夹在中间就会消费；
- 但对系统无害的迟到上限是“本子帧的local tick 385”。超过它，每晚一个子帧损失一个候选时隙；在sf7超过它则死锁；跨过宏帧末尾则L-1错绑。
- 正常节拍下完成在local tick 274左右（Q3结束267后约7拍），所以从正常完成算起的余量约111拍（55 µs）。
- 这个上限的前提与SSW-18报告第0节相同：ADC在Q3时刻（tick 266）已完成采样，迟到的只是读出和完成信号，仿真证明不了这一点。

## 4. L-2需求选项（(c)，供用户裁定）

### 4.1 阈值候选

| 候选 | 校准侧 | NORMAL侧 | 说明 |
|---|---|---|---|
| T-late（迟到） | owner在途跨过本子帧local tick 385 | RED owner在途跨过IR owner截止443；IR owner在途跨过宏帧末拍 | 第一个“已有代价”的时刻，适合非阻断诊断。相当于修好后的SSW-18 sticky（S1）的推广 |
| T-lost（丢失） | owner在途到下一子帧tick 0（下一次接管） | owner在途到下一帧同色的接管点（RED tick 0 / IR tick 160） | **必须在此之前或此刻处理**，否则下一次同槽位Q3会在旧owner名下执行（L-1）。比合法迟到上限（385）大约1.5个子帧 / 1帧 |
| T-dead（失联） | 连续k次T-lost（例如k=2，即约2个子帧） | 连续k个宏帧T-lost（例如k=2，约5 ms） | 区分“偶发丢一笔”与“ADC失联” |

### 4.2 处置候选

| 选项 | 内容 | 对L-1/L-3/L-4 | 对SID-05/F-020已有机制 |
|---|---|---|---|
| D1 只置诊断 | T-late/T-lost置非阻断sticky，不动owner | 不解决：L-1仍会错绑，L-2仍停滞，L-4仍卡死 | 无影响。单独使用不足 |
| D2 释放旧owner并丢弃（推荐作为基础） | 到T-lost时以原身份产生一次“丢弃”释放（不是success=1，也不伪造DONE），调度器、SSW、AMI三方同步清除在途；置非阻断sticky；校准侧同时释放AMI的`flag_calibration_request_inflight`，并按SID-05路径重新握手同一候选 | 解决L-1（不再有旧owner可以掩盖接管）；NORMAL恢复正常节拍；L-4不再出现（不会有“过截止提交”的前提）；需另外修同拍截止与提交（见下） | **与现行合同冲突**：C10 AMI-39/40、C25 LFA-04要求abort后保留最小身份、只由真实DONE以success=0释放，D2等于新增“无DONE超时释放”规则，需用户批准并修订C10/C25/C08/C09。与SID-05是同一模式（截止事件→AMI释放在途→重握手），可以复用`o_cal_owner_deadline_event`链路，或者新增一个`owner_completion_timeout`事件。F-020（周期重检在途不释放）需同时接入这个事件，与ABCD方案c4合并实现 |
| D3 阶段失败 | 校准侧到T-dead时IDAC当前搜索阶段失败（走现有exhausted/fault阻断路径）；NORMAL侧无对应概念 | 需配合D2，否则失败后在途owner仍卡住排空 | IDAC的fault由STOP/abort清除（V2.3），之后的恢复走既有流程 |
| D4 系统故障并STOP | 到T-dead时报supervisor阻断故障（新cause），走abort+STOP | **单独使用会复现L-4**：排空等在途owner。必须同时以D2释放owner，或扩展supervisor看门狗（RUN中也计数，或不再以物理ADC非idle为条件） | supervisor新增cause编码与C24第5/6节修订；看门狗语义改变会影响P05/N06/SUP-06的既有证据 |

同时必须处理的两点：
- **L-4的同拍截止与提交**：RED/IR和校准一样，需要“截止当拍不得提交”的门控。V1.9只给校准截止事件的对外输出加了`!adc_owner_commit_event_o`（`:569`）；`transaction_start_valid_o`（`:455`）对所有槽位都没有截止门控。
- **L-3**：IDAC有pending候选而调度器空闲时，需要一个边界来源。例如：调度器在启动搜索未完成时，帧末发现IDAC pending就自动续开校准帧；或允许调度器在空闲时为IDAC发一次安全边界。这与阈值无关，属于独立缺陷。

推荐组合：D2（T-lost）+ D1（T-late诊断，即S1的推广）+ D3或D4（T-dead，由用户在“阶段失败”与“系统STOP”之间选），并修L-3、L-4。需要用户先定：
1. T-lost与T-dead的具体取值；
2. 是否批准“无DONE超时释放”这条新规则（D2）；
3. T-dead升级到阶段失败还是系统STOP。

## 5. 合并批次与RTL轮清单补记

| 编号 | 类别 | 内容 | 去向 |
|---|---|---|---|
| L-1 | RTL缺陷 | 校准：宏帧末重挂在途owner的请求（`:821-822`）；NORMAL与校准：SSW以旧owner掩盖下一次同槽位截止（`:431-433`），之后的`CLK_DOUT`错绑旧owner；**NORMAL下正式结果带错误帧号输出（DROPIR）** | ABCD“ADC异常下owner生命周期”轮 |
| L-2 | 合同缺需求 | 丢失完成或ADC失联时静默停滞，校准与NORMAL都成立（C24第6节看门狗只管STOP排空） | 用户先定第4节需求，再进RTL轮与合同批次 |
| L-3 | RTL缺陷（新） | 校准结果在sf7 local tick 385之后到达 → 启动搜索永久死锁 | 同上RTL轮；建议补一个control_top级单元检查（复用`LATE6SF`构造） |
| L-4 | RTL缺陷（新） | NORMAL旧owner释放后，同拍截止与提交使owner在Q3之后提交 → SSW `8'h21` → STOP → 排空永久卡住 | 同上RTL轮；与SID-05同类（截止与提交同拍），修法参照V1.9 |
| S1 | 已定 | SSW-18 sticky修复（绑定本子帧owner）；C09:373改写为三道真实防护，并明文写出“ADC在tick 266已完成采样、迟到的只是读出”的前提 | RTL轮+合并批次（用户已定） |

## 附录 临时TB生成脚本

校准侧`make_tb.py`在SSW-18报告附录基础上增加了`NODONE`、`DEADADC`、`LATE6SF`三个变体和结束状态打印，完整版本见证据目录。NORMAL侧`make_tb_normal.py`如下。运行方式：在`517ab78`导出目录的`rtl/ppg_control_top/`下执行

```bash
python make_tb_normal.py
sed 's/tb_ppg_control_top.v$/tb_lost_done_normal.v/' xsim_main_filelist.f > lost.f
xvlog -f lost.f -i .
xelab tb_lost_done_normal -s snap_lost -timescale 1ns/1ps
xsim snap_lost -runall [-testplusarg DROPRED|DROPIR|DEAD] -log nrun_<组>.log
```

```python
"""Build the out-of-repo NORMAL-measurement lost-completion experiment TB (L-1/L-2 in NORMAL).
Base: tb_ppg_control_top.v at 517ab78. The background ADC responder gets three experiment flags:
  flag_exp_drop_red / flag_exp_drop_ir : skip exactly one NORMAL RED / IR completion, then respond normally;
  flag_exp_dead                        : from that moment on never respond again (ADC dead).
The experiment runs right after reset (before the original SMOKE sequence) and ends with $finish.
Plusargs: DROPRED / DROPIR / DEAD ; none = control (every completion delivered)."""
import os
D = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ppg_control_top.v')
dst = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_lost_done_normal.v')
t = open(src, encoding='utf-8').read()
t = t.replace('module tb_ppg_control_top', 'module tb_lost_done_normal', 1)
SCH = 'ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst'
AMI = 'ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst'
SSW = 'ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst'

# 1) responder: skip hook (wraps the original hold/drive section in an else branch)
a1 = "\t\t\t\tif(flag_hold_next_adc_response == 1'b1) begin"
a2 = "\t\t\t\tcnt_adc_response = cnt_adc_response + 1;"
assert t.count(a1) == 1 and t.count(a2) == 1
skip = f'''				if(flag_exp_dead || (!flag_response_is_calibration && ((flag_exp_drop_red && !reg_response_color_ir) || (flag_exp_drop_ir && reg_response_color_ir)))) begin
					$display("EXP responder SKIPS this completion t=%0t color_ir=%b cal=%b inflight_idx=%0d macro_tick=%0d", $time, reg_response_color_ir,
						flag_response_is_calibration, {SCH}.o_adc_owner_sample_index, {SCH}.macro_tick_o);
					flag_exp_drop_red = 1'b0;
					flag_exp_drop_ir = 1'b0;
				end else begin
'''
t = t.replace(a1, skip + a1, 1)
t = t.replace(a2, a2 + '\n\t\t\t\tend', 1)

# 2) experiment flags + monitors, placed before the responder declarations
a3 = '\t//---------------后台ADC响应暂停控制信号---------------//'
assert t.count(a3) == 1
mon = f'''	//===================<lost-completion experiment flags and monitors (out-of-repo)>===================//
	reg flag_exp_drop_red = 1'b0;
	reg flag_exp_drop_ir = 1'b0;
	reg flag_exp_dead = 1'b0;
	reg reg_exp_q3_prev = 1'b0;
	reg [1:0] reg_exp_life_prev = 2'b00;
	reg [15:0] reg_exp_sticky_prev = 16'd0;
	wire [15:0] w_exp_sticky = {{{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky,
		{SCH}.o_launch_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky, {SSW}.o_calibration_timeout_sticky, {SSW}.o_transaction_mismatch_sticky,
		{AMI}.o_integration_protocol_error_sticky, {AMI}.o_wrapper_fault_blocking, o_system_fault_blocking, {SCH}.o_scheduler_local_fault_blocking,
		{SSW}.o_wrapper_fault_blocking, 4'b0000}};
	always @(posedge i_clk) begin
		if({SCH}.adc_owner_commit_event_o)
			$display("MON OWNER  t=%0t frame=%0d mt=%0d color_ir=%b cal=%b idx=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o,
				{SCH}.o_adc_owner_color_ir, !{SCH}.o_adc_owner_frame_type[1], {SCH}.o_adc_owner_sample_index);
		if({AMI}.o_adc_transaction_complete_event)
			$display("MON DONE   t=%0t frame=%0d mt=%0d success=%b idx=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o,
				{AMI}.o_adc_transaction_success, {AMI}.o_adc_complete_sample_index);
		if(o_measurement_result_valid && i_measurement_result_ready)
			$display("MON RESULT t=%0t frame=%0d mt=%0d result_frame=%0d result_idx=%0d color_ir=%b sample_valid=%b", $time, {SCH}.o_current_frame_id,
				{SCH}.macro_tick_o, o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_sample_valid);
		if(o_clk_q3_low && !reg_exp_q3_prev)
			$display("MON Q3RISE t=%0t frame=%0d mt=%0d inflight=%b inflight_idx=%0d ssw_red_owner=%b ssw_ir_owner=%b", $time, {SCH}.o_current_frame_id,
				{SCH}.macro_tick_o, {SCH}.o_transaction_inflight, {SCH}.o_adc_owner_sample_index, {SSW}.flag_red_has_owner, {SSW}.flag_ir_has_owner);
		reg_exp_q3_prev <= o_clk_q3_low;
		if({SCH}.o_normal_frame_complete_event)
			$display("MON NFRAME_COMPLETE t=%0t frame=%0d", $time, {SCH}.o_current_frame_id);
		if(w_exp_sticky != reg_exp_sticky_prev)
			$display("MON STICKY t=%0t frame=%0d mt=%0d vec=%b (sch_own_dl,sch_mism,sch_proto,sch_launch,ssw_own_dl,ssw_cal_to,ssw_mism,ami_proto,ami_wrap_fault,sys_fault,sch_local_fault,ssw_wrap_fault)",
				$time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o, w_exp_sticky[15:4]);
		reg_exp_sticky_prev <= w_exp_sticky;
		if(o_lifecycle_state != reg_exp_life_prev)
			$display("MON LIFE   t=%0t lifecycle=%b", $time, o_lifecycle_state);
		reg_exp_life_prev <= o_lifecycle_state;
	end
	// supervisor / drain visibility
	integer cnt_exp_status = 0;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_fault_valid_o) $display("MON SUPIN  t=%0t scheduler fault record cause=%h", $time, ppg_control_top_Inst.sched_fault_cause_o);
		if(ppg_control_top_Inst.ssw_fault_valid_o) $display("MON SUPIN  t=%0t ssw fault record cause=%h", $time, ppg_control_top_Inst.ssw_fault_cause_o);
		if(ppg_control_top_Inst.ami_fault_valid_o) $display("MON SUPIN  t=%0t ami fault record cause=%h", $time, ppg_control_top_Inst.ami_fault_cause_o);
		if(ppg_control_top_Inst.supervisor_system_abort_event_o) $display("MON SUPOUT t=%0t system abort event", $time);
		if(ppg_control_top_Inst.supervisor_system_stop_request_event_o) $display("MON SUPOUT t=%0t system STOP request", $time);
		if(ppg_control_top_Inst.flag_stop_request_event) $display("MON STOPREQ t=%0t merged STOP request to manager", $time);
		cnt_exp_status = cnt_exp_status + 1;
		if((o_lifecycle_state == 2'b11) && (cnt_exp_status % 20000 == 0))
			$display("MON DRAIN  t=%0t episode=%b adc_phys_idle=%b datapath_empty=%b idac_idle=%b analog_safe=%b sched_idle=%b inflight=%b sys_blocking=%b",
				$time, ppg_control_top_Inst.flag_stop_episode_active, ppg_control_top_Inst.flag_adc_physical_idle, ppg_control_top_Inst.ami_datapath_empty_o,
				ppg_control_top_Inst.ami_idac_idle_o, ppg_control_top_Inst.ssw_analog_safe_o, o_scheduler_idle,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight, o_system_fault_blocking);
	end

'''
t = t.replace(a3, mon + a3, 1)

# 3) experiment body before the original first commit
a4 = '\t\ttask_build_normal_manual_config; // 构造第一笔'
assert t.count(a4) == 1
exp = f'''		begin : lost_done_experiment
			integer mode;
			integer cnt_wait;
			mode = 0;
			if($test$plusargs("DROPRED")) mode = 1;
			if($test$plusargs("DROPIR")) mode = 2;
			if($test$plusargs("DEAD")) mode = 3;
			$display("EXP mode=%0d (0=control,1=drop one RED completion,2=drop one IR completion,3=ADC dead)", mode);
			task_build_normal_manual_dual_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("EXP FAIL commit");
				$finish;
			end
			task_pulse_start;
			// let 3 NORMAL macro frames run with every completion delivered
			cnt_wait = 0;
			while(({SCH}.o_current_frame_id < 3) && (cnt_wait < 40000)) begin
				@(posedge i_clk);
				cnt_wait = cnt_wait + 1;
			end
			$display("EXP fault injection point t=%0t frame=%0d mt=%0d", $time, {SCH}.o_current_frame_id, {SCH}.macro_tick_o);
			if(mode == 1) flag_exp_drop_red = 1'b1;
			if(mode == 2) flag_exp_drop_ir = 1'b1;
			if(mode == 3) flag_exp_dead = 1'b1;
			repeat(40000) @(posedge i_clk); // 8 more macro frames
			$display("EXP END t=%0t frame=%0d lifecycle=%b eligible=%b inflight=%b inflight_idx=%0d sticky_vec=%b results_total=%0d",
				$time, {SCH}.o_current_frame_id, o_lifecycle_state, {AMI}.o_normal_measurement_eligible, {SCH}.o_transaction_inflight,
				{SCH}.o_adc_owner_sample_index, w_exp_sticky[15:4], cnt_measurement_result_valid);
			$finish;
		end
'''
t = t.replace(a4, exp + a4, 1)
open(dst, 'w', encoding='utf-8', newline='\n').write(t)
print('written', dst)
```
