# SSW-18 / tick 385 疑点仿真调查（只读，2026-10-06）

起因：用户对续报告`517ab78`第1.4节的复核（经“Erie Verilog Generator 配置”会话转达）。本次只在仓库外用临时TB做xsim仿真，没有改任何RTL、TB、合同、矩阵、别名表或tools文件。

- **被测版本**：`517ab78`，RTL与`2a90a69`相同；由`git archive`导出到仓库外，没有使用共享工作区（其中有ABCD会话未提交的改动）。
- **证据目录**：`D:\PPG\verilog\ppg_regression_runs\ssw18_tick385_20261006\`，含临时TB、生成脚本、文件清单和6份xsim日志。
- **工具**：Vivado 2022.2 xsim。

## 0. 结论先行

- **(a) 读码**：用户的两点分析都成立，第2点还需要一处细化（见第1节）。
  1. `calibration_timeout_sticky`是死逻辑。它的置位条件含`flag_cal_context_valid`，而该标志只在local tick 0的校准上下文fire时置1（`ppg_sar9_sar15_safe_selection_wrapper.v:953-955`），在local tick 283（`flag_cal_wave_last`，`:407`）清0（`:950-951`）。所以到tick 385时它一定是0，sticky永远不会置1。仿真证实：三个迟到变体在tick 385处都是`ctx_valid=0`、`has_owner=1`，正是sticky本想抓住的“385时结果仍未回来”，却被已清零的上下文挡掉。
  2. IDAC控制器确实没有任何与tick 385、提交时刻或超时相关的逻辑，C09:373要求的“阶段失败”没有实现。但系统别处另有一道防护，见下一条。
- **(b) 迟到结果（结果最终到达）不会造成旧码被当作新搜索样本**。三个迟到变体分别是：local tick 406、下一子帧tick 106、两个子帧后tick 106。在这三种情况下：
  - 迟到结果都作为**它自己那笔码**的合格样本被消费（`sample_snapshot == current`，`qualified=1`），这本身是正确的；
  - 下一候选码改在结果到达之后的第一个tick-385边界提交；
  - 中间的子帧没有任何校准事务，没有用旧码另做一次转换；
  - 没有任何模块报告阶段失败或进入故障，所有sticky都保持0；
  - 唯一的可见后果是：该校准宏帧内有效候选减少，搜索整体推迟。
  
  起防护作用的是三处现有机制：
  - AMI在结果被消费前不发下一笔请求；
  - IDAC只接受代码快照与当前码一致的样本（`ppg_idac_code_controller.v:467-484`）；
  - IDAC只在安全边界提交新候选（`:583-591`）。
- **(b′) 结果永远不回来时有两个新问题**（超出用户问题，属于同类前提的延伸，作为RTL疑点交用户裁定）：
  - **N-1 跨宏帧重发与错绑**：校准宏帧末尾若owner仍在途，调度器把已经提交成owner的请求当作“未成功提交”重新挂起（`ppg_400hz_frame_calibration_scheduler.v:821-823`）。下一校准宏帧的子帧0因此发出一个注定拿不到owner的新校准波形。SSW因为旧owner仍在途，`flag_cal_has_owner=1`（`:433`），不触发tick 249截止抑制（`:436`），新波形的Q3照常执行。之后到来的`CLK_DOUT`被记成旧owner（上一宏帧子帧1、sample index 1）的完成。
  - **N-2 静默停滞**：ADC完全不再应答时，启动搜索永久停住。仿真跑了4个校准宏帧（约10 ms），每帧子帧0都重发一次无owner的波形，但没有任何sticky、故障或耗尽标志，连调度器的owner截止sticky也被在途owner屏蔽而保持0。系统停在RUN、永远不进入NORMAL资格，软件看不到任何原因。
- **(c) 修复选项**：见第4节。
  - 迟到结果这一路：系统已经挡住了旧码复用，建议**修复或删除死sticky，并把真实防护写进C09**，替换C09:373的“阶段失败”要求，或由用户决定是否真的要实现阶段失败。
  - 丢失完成这一路（N-1/N-2）：没有挡住，列为RTL疑点，附A/B证据，交用户裁定修法。

## 1. 读码核实（(a)）

| 位置 | 内容 |
|---|---|
| SSW `:308` | `reg flag_cal_context_valid` |
| SSW `:396` | `flag_context_is_cal_raw = flag_cal_context_point && !flag_cal_context_valid && …`；`flag_cal_context_point`要求`i_calibration_local_tick == 10'd0`（`:390`） |
| SSW `:407` | `flag_cal_wave_last = i_calibration_local_tick == 10'd283` |
| SSW `:944-956` | 复位或abort清0；`flag_cal_wave_last`清0；只有`flag_context_fire && flag_context_is_cal`置1 |
| SSW `:433` | `flag_cal_has_owner = adc_owner_inflight_o && !reg_owner_abort_seen && (reg_owner_slot == SLOT_CAL)`：只看全局在途owner及其槽位，不区分属于哪个上下文 |
| SSW `:436` | `flag_cal_timeout = flag_cal_context_valid && (local_tick == C_CAL_OWNER_DEADLINE + 1) && !flag_cal_has_owner` |
| SSW `:546-547` | `calibration_timeout_sticky_o`置位：`flag_cal_context_valid && (local_tick == CAL_COMMIT_TICK(385)) && !flag_cal_has_owner`。因为`:950-951`，第一项在385时恒为0 |
| IDAC `:467-484` | AMB/DCS样本合格条件：类型、校准资格、config epoch、**AMB/DC码快照与epoch等于当前committed值**、非双饱和；没有任何时刻条件 |
| IDAC `:583-591`、`:719` | 候选码只在`i_frame_safe_boundary`提交 |
| 调度器 `:821-823` | 校准宏帧末拍：`if(B_CAL_REQ_PENDING \|\| B_CAL_WAVE_PENDING \|\| B_INFLIGHT) B_CAL_REQ_PENDING = 1`，注释为“未成功提交的请求跨宏帧保留”。`B_INFLIGHT`说明请求早已成为owner，却也被重新挂起 |
| 调度器 `:469` | `flag_cal_owner_deadline`要求`!B_INFLIGHT`：旧owner在途时，新波形的截止事件与sticky被屏蔽 |

对用户第1点的细化：死逻辑的直接原因是“上下文在283清零”。即使只去掉`flag_cal_context_valid`这一项，当前`flag_cal_has_owner`的定义也只能表达“385时有校准owner在途”，而不能区分是本子帧的owner迟到，还是上一宏帧遗留的owner（见N-1）。所以修复时要连同“owner属于哪个子帧/上下文”一起考虑。

## 2. 实验设计（(b)）

临时TB `tb_ssw18_late_completion.v`由`make_tb.py`从`tb_ppg_control_top_startup_idac_calibration.v`（517ab78）生成：
- 在原主流程的`run_jnt_baseline_01_09`之前插入实验段，以`$finish`结束，原阶段不执行；
- 加一组只读监视器，打印owner提交、AMI校准请求握手、ADC完成、IDAC样本消费（快照码、当前码、是否合格）、IDAC提交新码、校准宏帧完成、每个子帧tick 385处SSW的`flag_cal_context_valid`/`flag_cal_has_owner`，以及13个sticky/故障位的任何变化。

实验段：
- 提交SEARCH_TRACK配置并START；
- 依次处理6个AMB候选，每个候选在Q3释放后用TB原有的`task_drive_amb_toward_target`（目标码64）驱动真实`CLK_DOUT`；
- 只对第2个候选按plusarg推迟完成。

| 组 | plusarg | 第2个候选的完成时刻 |
|---|---|---|
| 对照 | 无 | Q3释放后立即（local tick 274） |
| A | `LATE385` | 同一子帧local tick ≥ 400 |
| B | `LATENEXT` | 下一子帧local tick ≥ 100 |
| C | `LATE2SF` | 两个子帧之后local tick ≥ 100 |
| D | `NODONE` | 不驱动；之后的候选照常 |
| E | `DEADADC` | 从第2个候选起都不驱动 |

## 3. 结果

### 3.1 对照组与迟到组（A/B/C）

| 事件 | 对照 | A LATE385 | B LATENEXT | C LATE2SF |
|---|---|---|---|---|
| 候选2的owner | sf1 lt1，idx 1，码65 | 同 | 同 | 同 |
| 候选2的完成 | sf1 lt274 | **sf1 lt406** | **sf2 lt106** | **sf3 lt106** |
| 该样本 | 快照65=当前65，合格 | 快照65=当前65，合格 | 同 | 同 |
| 下一码提交 | sf1 lt386 →36 | **sf2 lt386** →36 | sf2 lt386 →36 | **sf3 lt386** →36 |
| 下一个owner | sf2 lt1，码36 | **sf3** lt1，码36 | sf3 lt1，码36 | **sf4** lt1，码36 |
| 中间子帧的校准事务 | — | sf2：无 | sf2：无 | sf2、sf3：无 |
| tick 385处SSW | sf1：ctx 0/owner 0 | **sf1：ctx 0/owner 1** | sf1：ctx 0/owner 1 | sf1、sf2：ctx 0/owner 1 |
| sticky/故障变化 | 0次 | 0次 | 0次 | 0次 |
| 结束状态 | 码63，所有sticky/故障为0 | 同 | 同 | 同 |

结论：
- 迟到结果被正确归属到它自己的码；
- 旧码没有被另做一次转换后当作新样本，中间子帧没有校准事务；
- 没有任何阶段失败或故障；
- `calibration_timeout_sticky`始终为0；
- 在tick 385处，“owner仍在途”（`has_owner=1`）的情况确实出现了，但因为`ctx_valid=0`而没有被记录。

### 3.2 丢失完成（D、E）

**D NODONE**：候选2（sf1，idx 1，码65）不驱动完成。
- 本宏帧的sf2~7：没有请求，没有事务；tick 385处`ctx 0/owner 1`；没有任何sticky。
- 宏帧完成后进入下一校准宏帧，sf0出现Q3，但**没有新的owner提交**。TB对这个Q3驱动的`CLK_DOUT`被记成**旧owner idx 1**的完成：`MON DONE … sf=0 lt=274`，紧接着`AMBSMP sample_snapshot=65`。
- 旧owner随之释放，新波形的owner-pending在下一拍触发调度器owner截止：`sch_owner_dl`在lt 276从0变为1，这是全程唯一一次sticky变化。随后搜索恢复（`AMBCOMMIT`→36）。
- 本例中两次转换用的是同一个码（65），所以数值上无害；但正式完成的身份（帧号、sample index）属于上一宏帧的owner，而物理转换来自本宏帧子帧0。

**E DEADADC**：从候选2起不再驱动任何完成。
- 4个校准宏帧（2.5 s→10.0 s仿真时间，约10 ms真实时间）中，每帧sf0都出现一次Q3，但没有owner、没有完成。
- AMB码停在65，`search_done=0`，`exhausted=0`，所有故障为0，**13个sticky位全程0次变化**。
- 调度器owner截止sticky也被在途owner屏蔽（`:469`的`!B_INFLIGHT`）。
- 系统停在RUN，启动搜索永不完成，NORMAL资格永不建立，没有任何诊断。

## 4. 结论与修复选项（(c)，只建议，未实施）

### 4.1 死sticky与迟到结果（系统已挡住旧码复用）

| 选项 | 内容 | 影响 |
|---|---|---|
| S1（推荐） | 修复sticky，使它表达“本子帧的校准owner在local tick 385仍未完成”：去掉`flag_cal_context_valid`项，改用“当前在途owner属于本子帧”的判据（需记录owner提交时的子帧号或上下文序号，不能只用`flag_cal_has_owner`，见第1节细化）。同步订正C09:373/:602/SSW-18：说明迟到结果由“单请求在途 + IDAC快照/epoch资格 + 边界提交”保证不复用旧码，sticky是非阻断诊断，不终止burst。补一个SSW单元断言和一个control_top级迟到用例（可直接复用本实验构造） | SSW一处RTL；C09合同；1个SSW检查与1个系统检查 |
| S2 | 删除sticky及其端口链（SSW→control_top→芯片顶层→SPI寄存器），C09相应条目改为描述真实防护 | 跨SSW/Top/芯片顶层/SPI读地图，改动面大，且丢失一个有用的诊断 |
| S3 | 按C09:373原意实现IDAC“阶段失败”：385时未回的结果使当前搜索阶段失败（阻断） | IDAC控制器增加时刻输入或事件；本实验显示迟到结果本身是有效样本，判失败会把ADC偶发迟到升级为阻断故障，需用户权衡 |

### 4.2 丢失完成（没有挡住，RTL疑点，交用户裁定）

| 编号 | 现象 | A/B证据 | 修法选项 |
|---|---|---|---|
| N-1 | 宏帧末拍把在途owner对应的请求重新挂起，下一宏帧发出拿不到owner的波形；SSW因旧owner在途而不抑制Q3；之后的`CLK_DOUT`被错记为旧owner的完成 | 对照：每次完成都对应本子帧owner。D：下一宏帧sf0的Q3无`MON OWNER`，`MON DONE sf=0 lt=274`绑定idx 1，随后`sch_owner_dl` 0→1 | ① 调度器`:821-823`去掉`B_INFLIGHT`项（在途时不重新挂起），owner完成后由AMI重新发请求；② SSW的`flag_cal_has_owner`改为绑定上下文/子帧，旧owner不能代替新上下文；③ AMI/调度器对“跨宏帧仍在途的校准owner”做显式丢弃或超时。①+②最小 |
| N-2 | ADC不再应答时，启动/周期校准永久停滞，没有任何诊断 | E：4个宏帧内13个sticky位0变化，`search_done=0`、`exhausted=0`、无故障 | ① 校准owner完成超时（例如以子帧或宏帧计）→ 非阻断sticky加阶段失败；② 复用supervisor看门狗的思路，把“RUN中owner长时间在途”纳入。与SID-05、F-020同一类前提（ADC异常），建议与F-020的修复（ABCD方案c4）一起裁定 |

## 5. 合并批次清单补记（用户本次决定）

1. **FSC-19/23/24/27/44补检查，不接受缺口**：时机在ABCD会话第二轮（F-009）推送之后。调度器TB在两轮RTL修复中都会改动，而且FSC-23/24的检查依赖F-009修复后的帧边界时序。补检查本身不在本次任务内。
   - **FSC-27的做法**：在调度器单元级直接运行真实的16位配置，让帧号和样本序号两个计数器都跨过回绕点（双光时样本序号约3.3万帧就会回绕，早于帧号）。先实测单元级仿真速度，只有跑不动时才退到调小位宽参数，并写明“调小位宽后仿真的是另一个设计，不能直接证明16位配置”的局限。
2. **FSC-35改判为“部分”**（订正续报告`517ab78`第2节的“已有”）：RAW-12（10秒内两色各4000帧）分辨不出5000拍和5001拍的帧周期，F-009存在时同样通过，所以证明不了“各自400 Hz、无漂移”。F-009修复、TB的FSC-14（对应合同FSC-03）收紧为严格5000拍之后，才有完整证据。续报告第0节“已有证据5条”相应改为4条（FSC-20、21、43、47），“部分”改为8条（加FSC-35）。
3. **SSW-18**：先不改合同。处置按本报告第4.1节由用户选定S1/S2/S3后再进入合并批次。
4. **N-1/N-2**：待用户裁定。如需修复，属于RTL轮，不属于编号或合同批次。

## 附录 临时TB生成脚本

运行方式（在`git archive 517ab78`导出目录的`rtl/ppg_control_top/`下）：

```bash
python make_tb.py
sed 's/tb_ppg_control_top_startup_idac_calibration.v/tb_ssw18_late_completion.v/' xsim_startup_idac_calibration_filelist.f > ssw18.f
xvlog -f ssw18.f -i .
xelab tb_ssw18_late_completion -s snap_ssw18 -timescale 1ns/1ps
xsim snap_ssw18 -runall [-testplusarg LATE385|LATENEXT|LATE2SF|NODONE|DEADADC] -log run_<组>.log
```

```python
"""Build the out-of-repo experiment TB for the SSW-18 / tick-385 investigation.
Copies tb_ppg_control_top_startup_idac_calibration.v (snapshot 517ab78), inserts an experiment right before
run_jnt_baseline_01_09 (ending in $finish, so the original phases never run), and adds passive monitors.
Plusargs (no '=' allowed under xsim on Windows): LATE385 / LATENEXT / LATE2SF select the delayed-completion
variant for AMB candidate #2; no plusarg = control group (every completion right after Q3 release)."""
import os
D = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ppg_control_top_startup_idac_calibration.v')
dst = os.path.join(D, 'snap', 'rtl', 'ppg_control_top', 'tb_ssw18_late_completion.v')
t = open(src, encoding='utf-8').read()
t = t.replace('module tb_ppg_control_top_startup_idac_calibration', 'module tb_ssw18_late_completion', 1)

SCH = 'ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst'
AMI = 'ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst'
IDC = AMI + '.ppg_idac_code_controller_Inst'
SSW = 'ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst'

exp = f'''
		//===================<SSW-18 experiment (out-of-repo)>===================//
		begin : ssw18_experiment
			integer k;
			integer mode;
			reg [2:0] sf0;
			integer n_sf_change;
			reg [2:0] sf_prev;
			reg rr;
			mode = 0;
			if($test$plusargs("LATE385")) mode = 1;
			if($test$plusargs("LATENEXT")) mode = 2;
			if($test$plusargs("LATE2SF")) mode = 3;
			if($test$plusargs("NODONE")) mode = 4;
			if($test$plusargs("DEADADC")) mode = 5;
			$display("EXP mode=%0d (0=on-time control,1=done after local tick 400,2=next subframe tick 100,3=two subframes later)", mode);
			task_build_search_track_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("EXP FAIL commit");
				$finish;
			end
			task_pulse_start;
			for(k = 1; k <= 6; k = k + 1) begin
				wait_q3_release(rr);
				if(!rr) begin
					$display("EXP candidate %0d: no Q3 within watchdog (t=%0t)", k, $time);
				end else begin
					if((k >= 2) && (mode == 5)) begin
						$display("EXP candidate %0d: ADC dead, no DONE (t=%0t sf=%0d lt=%0d)", k, $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
					end else if((k == 2) && (mode == 4)) begin
						$display("EXP candidate %0d: DONE deliberately never driven (owner committed in sf=%0d)", k, {SCH}.o_calibration_subframe_index);
					end else if((k == 2) && (mode != 0)) begin
						sf0 = {SCH}.o_calibration_subframe_index;
						if(mode == 1) begin
							while({SCH}.o_calibration_local_tick < 10'd400) @(negedge i_clk);
						end else begin
							n_sf_change = 0;
							sf_prev = sf0;
							while(n_sf_change < (mode - 1)) begin
								@(negedge i_clk);
								if({SCH}.o_calibration_subframe_index != sf_prev) begin
									n_sf_change = n_sf_change + 1;
									sf_prev = {SCH}.o_calibration_subframe_index;
								end
							end
							while({SCH}.o_calibration_local_tick < 10'd100) @(negedge i_clk);
						end
						$display("EXP candidate %0d: delayed DONE driven at sf=%0d lt=%0d (owner was committed in sf=%0d)", k,
							{SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, sf0);
					end
					if(!((k == 2) && (mode == 4)) && !((k >= 2) && (mode == 5))) task_drive_amb_toward_target(reg_exp_last_owner_amb, 64);
				end
			end
			repeat(3000) @(posedge i_clk);
			$display("EXP END amb_code=%0d epoch=%0d search_done=%b exhausted=%b amb_fault=%b ctrl_fault=%b idac_proto=%b ami_proto=%b sch_owner_dl=%b sch_mismatch=%b sch_proto=%b sch_launch=%b ssw_cal_timeout=%b ssw_owner_dl=%b sys_fault=%b",
				{IDC}.o_amb_code, {IDC}.o_amb_code_epoch, {IDC}.o_amb_search_done, {IDC}.o_amb_search_exhausted, {IDC}.o_amb_fault,
				{IDC}.o_controller_fault_blocking, {IDC}.o_protocol_error_sticky, {AMI}.o_integration_protocol_error_sticky,
				{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky, {SCH}.o_launch_timeout_sticky,
				{SSW}.o_calibration_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky, o_system_fault_blocking);
			$finish;
		end
'''
anchor = '\t\trun_jnt_baseline_01_09;'
assert t.count(anchor) == 1
t = t.replace(anchor, exp + anchor, 1)

mon = f'''
	//===================<SSW-18 experiment monitors (passive)>===================//
	reg [7:0] reg_exp_last_owner_amb = 8'd0;
	reg [15:0] reg_exp_sticky_prev = 16'd0;
	wire [15:0] w_exp_sticky = {{{SSW}.o_calibration_timeout_sticky, {SSW}.o_owner_deadline_timeout_sticky,
		{SCH}.o_owner_deadline_timeout_sticky, {SCH}.o_completion_mismatch_sticky, {SCH}.o_protocol_error_sticky, {SCH}.o_launch_timeout_sticky,
		{IDC}.o_protocol_error_sticky, {IDC}.o_amb_fault, {IDC}.o_amb_search_exhausted, {IDC}.o_controller_fault_blocking,
		{AMI}.o_integration_protocol_error_sticky, o_system_fault_blocking, {IDC}.o_amb_search_done, 3'b000}};
	always @(posedge i_clk) begin
		if({SCH}.adc_owner_commit_event_o) begin
			reg_exp_last_owner_amb <= {SCH}.o_adc_owner_amb_code_snapshot;
			$display("MON OWNER   t=%0t sf=%0d lt=%0d idx=%0d amb_snapshot=%0d", $time, {SCH}.o_calibration_subframe_index,
				{SCH}.o_calibration_local_tick, {SCH}.o_adc_owner_sample_index, {SCH}.o_adc_owner_amb_code_snapshot);
		end
		if({AMI}.o_calibration_sample_valid && {AMI}.i_calibration_sample_ready)
			$display("MON CALREQ  t=%0t sf=%0d lt=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
		if({AMI}.o_adc_transaction_complete_event)
			$display("MON DONE    t=%0t sf=%0d lt=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick);
		if({IDC}.i_search_amb_valid && {IDC}.o_search_amb_ready)
			$display("MON AMBSMP  t=%0t sf=%0d lt=%0d sample_snapshot=%0d current=%0d qualified=%b", $time, {SCH}.o_calibration_subframe_index,
				{SCH}.o_calibration_local_tick, {IDC}.i_search_amb_code_snapshot, {IDC}.o_amb_code, {IDC}.flag_amb_sample_qualified);
		if({IDC}.o_amb_code_update)
			$display("MON AMBCOMMIT t=%0t sf=%0d lt=%0d new_code=%0d", $time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, {IDC}.o_amb_code);
		if({SCH}.o_calibration_frame_complete_event)
			$display("MON CALFRAME_COMPLETE t=%0t", $time);
		if({SCH}.o_calibration_frame_active && ({SCH}.o_calibration_local_tick == 10'd385))
			$display("MON T385    t=%0t sf=%0d ssw_cal_ctx_valid=%b ssw_cal_has_owner=%b", $time, {SCH}.o_calibration_subframe_index,
				{SSW}.flag_cal_context_valid, {SSW}.flag_cal_has_owner);
		if(w_exp_sticky != reg_exp_sticky_prev)
			$display("MON STICKY  t=%0t sf=%0d lt=%0d vec=%b (ssw_cal_to,ssw_own_dl,sch_own_dl,sch_mism,sch_proto,sch_launch,idc_proto,amb_fault,amb_exh,ctrl_fault,ami_proto,sys_fault,amb_done)",
				$time, {SCH}.o_calibration_subframe_index, {SCH}.o_calibration_local_tick, w_exp_sticky[15:3]);
		reg_exp_sticky_prev <= w_exp_sticky;
	end
'''
anchor2 = '\t//---------------真实ADC完成响应任务---------------//'
assert t.count(anchor2) == 1
t = t.replace(anchor2, mon + '\n' + anchor2, 1)
open(dst, 'w', encoding='utf-8', newline='\n').write(t)
print('written', dst)
```
