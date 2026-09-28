`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/24
// Design Name:        Deterministic PPG RAW Generator Standalone Self-Check
// Module Name:        tb_ppg_real_raw_generator_selfcheck
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//
// Dependencies:       tb_ppg_real_raw_generator.vh (Phase 3 Stage 1 generator
//                      model). No DUT is instantiated; this checks the
//                      generator model in isolation before it is wired into
//                      tb_ppg_control_top.v's bg_responder in Stage 2.
//
// Version:            V1.1
// Revision Date:      2026/08/24
// History:
//    Time               Version       Revised by            Contents
// 2026/08/24            V1.0          Erie                  Create file. Phase 3 Stage 1 standalone self-check for tb_ppg_real_raw_generator.vh: RGC-01/02 confirm the fast-rise then slow-decay shape ordering, RGC-03 confirms the dicrotic notch is a genuine local minimum with bounded rebound (not just a monotone tail), RGC-04 confirms the cycle returns near its trough before the next rise, RGC-05 confirms the baseline-drift triangle actually trends across widely separated frames, RGC-06 confirms noise stays within its configured bound and is bit-identical on repeated evaluation of the same (color,frame), RGC-07 exercises the clamp primitive directly with deliberately extreme values because the frozen default parameters never naturally reach the clamp boundary in normal operation, RGC-08 sweeps a representative frame range across all four drift/pulse quadrants for both colors confirming target_code always stays inside [8,503] and the whole pipeline (unclamped value included) is bit-identical across repeated calls for the same (color,frame). No RTL is exercised; this is a pure testbench-model check.
// 2026/08/24            V1.1          Erie                  Follows tb_ppg_real_raw_generator.vh V1.2's profile-selectable refactor. RGC-01~08 updated to the new task signatures (profile params resolved via task_select_raw_profile_params before calling the now-pure-math task_generate_pulse_shape/task_generate_baseline_drift, task_generate_raw_target_code's first argument is profile_id) and rerun with explicit C_RAW_PROFILE_NORMAL -- same expected values as V1.0/V1.1 since NORMAL's resolved parameters are unchanged. Added RGC-09~15 for the seven new corner profiles added to answer the user's pre-Stage-2 coverage question: RGC-09 confirms FLAT's pulse contribution is exactly zero at every sampled phase (only drift+noise remain); RGC-10 confirms LOW_AMPLITUDE and HIGH_AMPLITUDE_SATURATED bracket NORMAL's amplitude on the correct side for both colors; RGC-11 confirms HIGH_AMPLITUDE_SATURATED actually reaches the real clamp boundary during an ordinary one-period frame sweep through the full pipeline, not only via RGC-07's synthetic out-of-range call; RGC-12 confirms STRONG_DRIFT's drift swing is larger than NORMAL's while the full pipeline still never leaves the legal window (bounded, not saturating); RGC-13 confirms FAST_PERIOD/SLOW_PERIOD bracket NORMAL's period and produce the corresponding higher/lower complete-cycle count over a fixed 4000-frame span; RGC-14 confirms WEAK_NOTCH's notch dip magnitude is much smaller than NORMAL's; RGC-15 generalizes RGC-08's in-window/reproducibility sweep to all seven non-NORMAL profiles instead of only NORMAL. No RTL is exercised; this remains a pure testbench-model check.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月24日
// 设计名称:           确定性PPG RAW生成器独立自检
// 模块名称:           tb_ppg_real_raw_generator_selfcheck
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//
// 依赖文件:           tb_ppg_real_raw_generator.vh（Phase 3 Stage 1生成器模型）。
//                      本文件不例化任何DUT，只在生成器模型本身接入
//                      tb_ppg_control_top.v的bg_responder（Stage 2）之前独立核对。
//
// 当前版本:           V1.1
// 修订日期:           2026年08月24日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月24日        V1.0          Erie                  创建文件。针对tb_ppg_real_raw_generator.vh的Phase 3 Stage 1独立自检：RGC-01/02核对快升后紧接慢降的先后顺序；RGC-03核对重搏切迹确实是一个有界回弹的局部最小值，不是单调尾段的错觉；RGC-04核对周期末尾确实回落到接近谷值，为下一周期快升做铺垫；RGC-05核对基线漂移三角波在跨度足够大的帧之间确实呈现出漂移趋势；RGC-06核对噪声始终落在配置的有界范围内，且对同一(颜色,帧)重复求值逐位相同；RGC-07直接用刻意构造的极端值单独驱动clamp原语——因为冻结的默认参数在正常运行下永远不会自然触达clamp边界；RGC-08对两种颜色各扫一段覆盖漂移/脉搏四个象限的代表性帧区间，核对target_code始终落在[8,503]内，且整条流水线（含clamp前原始值）对同一(颜色,帧)重复调用逐位相同。本文件不驱动任何RTL，是纯testbench模型自检。
// 2026年08月24日        V1.1          Erie                  跟随tb_ppg_real_raw_generator.vh V1.2的档位可选架构重构。RGC-01~08改用新任务签名（先经task_select_raw_profile_params解析出参数，再传给已经变成纯数学任务的task_generate_pulse_shape/task_generate_baseline_drift；task_generate_raw_target_code第一个参数是profile_id）并显式传C_RAW_PROFILE_NORMAL重跑——因为NORMAL解析出的参数和之前完全一样，预期数值不变。为回答用户在Stage 2接线前提出的覆盖度问题，新增七个角落档位对应的RGC-09~15：RGC-09核对FLAT在各个采样相位的脉搏贡献恒为0（只剩漂移+噪声）；RGC-10核对LOW_AMPLITUDE和HIGH_AMPLITUDE_SATURATED相对NORMAL幅度分别落在正确的两侧；RGC-11核对HIGH_AMPLITUDE_SATURATED在一个完整周期的正常帧扫描里、走完整条流水线真的触达clamp边界，不只是RGC-07那种人为构造的越界调用；RGC-12核对STRONG_DRIFT的漂移摆幅确实比NORMAL大，同时整条流水线在扫描中依然从未越出合法窗口（有界，不会常态饱和）；RGC-13核对FAST_PERIOD/SLOW_PERIOD相对NORMAL周期分别落在两侧，且在固定4000帧跨度内产生对应更多/更少的完整周期数；RGC-14核对WEAK_NOTCH的切迹下探幅度明显小于NORMAL；RGC-15把RGC-08的窗口内+可复现性扫描推广到全部七个非NORMAL档位，不再只测NORMAL。本文件不驱动任何RTL，仍是纯testbench模型自检。
//
// 只调用生成器task本身，不例化DUT，逐条核对第3/4节要求的每个分量是否真实存在
// 且clamp、确定性、有界性全部成立
module tb_ppg_real_raw_generator_selfcheck();

	`include "tb_ppg_real_raw_generator.vh"

	//---------------自检累计计数---------------//
	integer cnt_error; // 累计FAIL数
	integer idx_i; // 通用循环变量

	//---------------RGC-01/02：快升后紧接慢降---------------//
	task check_rise_then_decay;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude;
		integer notch_top_pct;
		integer notch_depth_pct;
		integer notch_rebound_pct;
		integer drift_amplitude_unused;
		integer pulse_period_frames;
		integer rise_end_frame;
		integer notch_start_frame;
		integer pulse_start;
		integer pulse_rise_mid;
		integer pulse_rise_end;
		integer pulse_early_decay_end;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude,
				notch_top_pct, notch_depth_pct, notch_rebound_pct, drift_amplitude_unused, pulse_period_frames);
			rise_end_frame = (pulse_period_frames * C_RAW_RISE_PCT) / 100;
			notch_start_frame = (pulse_period_frames * C_RAW_NOTCH_START_PCT) / 100;
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, 32'd0, pulse_start);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, rise_end_frame / 2, pulse_rise_mid);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, rise_end_frame - 1, pulse_rise_end);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, notch_start_frame - 1, pulse_early_decay_end);
			if((pulse_start < pulse_rise_mid) && (pulse_rise_mid < pulse_rise_end)) begin
				$display("PASS RGC-01 color=%0d monotonic fast rise start=%0d mid=%0d end=%0d", color_ir, pulse_start, pulse_rise_mid, pulse_rise_end);
			end else begin
				$display("FAIL RGC-01 color=%0d fast rise not monotonic start=%0d mid=%0d end=%0d", color_ir, pulse_start, pulse_rise_mid, pulse_rise_end);
				cnt_error = cnt_error + 1;
			end
			if(pulse_early_decay_end < pulse_rise_end) begin
				$display("PASS RGC-02 color=%0d slow decay follows peak peak=%0d decay_end=%0d", color_ir, pulse_rise_end, pulse_early_decay_end);
			end else begin
				$display("FAIL RGC-02 color=%0d value did not fall after peak peak=%0d decay_end=%0d", color_ir, pulse_rise_end, pulse_early_decay_end);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-03：重搏切迹局部最小值+有界回弹---------------//
	task check_dicrotic_notch;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude;
		integer notch_top_pct;
		integer notch_depth_pct;
		integer notch_rebound_pct;
		integer drift_amplitude_unused;
		integer pulse_period_frames;
		integer notch_start_frame;
		integer notch_end_frame;
		integer notch_mid_frame;
		integer pulse_notch_start;
		integer pulse_notch_mid;
		integer pulse_notch_end;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude,
				notch_top_pct, notch_depth_pct, notch_rebound_pct, drift_amplitude_unused, pulse_period_frames);
			notch_start_frame = (pulse_period_frames * C_RAW_NOTCH_START_PCT) / 100;
			notch_end_frame = (pulse_period_frames * C_RAW_NOTCH_END_PCT) / 100;
			notch_mid_frame = (notch_start_frame + notch_end_frame) / 2;
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, notch_start_frame, pulse_notch_start);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, notch_mid_frame, pulse_notch_mid);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, notch_end_frame - 1, pulse_notch_end);
			if((pulse_notch_mid < pulse_notch_start) && (pulse_notch_mid < pulse_notch_end) && (pulse_notch_end < pulse_notch_start)) begin
				$display("PASS RGC-03 color=%0d dicrotic notch is a bounded-rebound local minimum start=%0d mid=%0d end=%0d", color_ir, pulse_notch_start, pulse_notch_mid, pulse_notch_end);
			end else begin
				$display("FAIL RGC-03 color=%0d notch shape wrong start=%0d mid=%0d end=%0d", color_ir, pulse_notch_start, pulse_notch_mid, pulse_notch_end);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-04：周期末尾回落到谷值附近---------------//
	task check_return_to_trough;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude;
		integer notch_top_pct;
		integer notch_depth_pct;
		integer notch_rebound_pct;
		integer drift_amplitude_unused;
		integer pulse_period_frames;
		integer notch_end_frame;
		integer pulse_notch_end;
		integer pulse_cycle_end;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude,
				notch_top_pct, notch_depth_pct, notch_rebound_pct, drift_amplitude_unused, pulse_period_frames);
			notch_end_frame = (pulse_period_frames * C_RAW_NOTCH_END_PCT) / 100;
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, notch_end_frame, pulse_notch_end);
			task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, pulse_period_frames - 1, pulse_cycle_end);
			if((pulse_cycle_end < pulse_notch_end) && (pulse_cycle_end >= 0)) begin
				$display("PASS RGC-04 color=%0d late decay returns near trough notch_end=%0d cycle_end=%0d", color_ir, pulse_notch_end, pulse_cycle_end);
			end else begin
				$display("FAIL RGC-04 color=%0d late decay did not return near trough notch_end=%0d cycle_end=%0d", color_ir, pulse_notch_end, pulse_cycle_end);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-05：基线漂移三角波趋势---------------//
	task check_baseline_drift_trend;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude_unused;
		integer notch_top_pct_unused;
		integer notch_depth_pct_unused;
		integer notch_rebound_pct_unused;
		integer drift_amplitude;
		integer pulse_period_frames_unused;
		integer drift_trough;
		integer drift_peak;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude, pulse_period_frames_unused);
			task_generate_baseline_drift(drift_amplitude, 32'd0, drift_trough);
			task_generate_baseline_drift(drift_amplitude, C_RAW_DRIFT_PERIOD_FRAMES / 2, drift_peak);
			if(drift_trough < drift_peak) begin
				$display("PASS RGC-05 color=%0d baseline drift trends across frames trough=%0d peak=%0d", color_ir, drift_trough, drift_peak);
			end else begin
				$display("FAIL RGC-05 color=%0d baseline drift shows no trend trough=%0d peak=%0d", color_ir, drift_trough, drift_peak);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-06：确定性噪声有界+可复现---------------//
	task check_noise_bounded_deterministic;
		input color_ir;
		integer noise_amplitude;
		integer noise_first;
		integer noise_second;
		integer cnt_local_fail;
		begin
			noise_amplitude = (color_ir == C_RAW_COLOR_IR) ? C_RAW_NOISE_AMPLITUDE_IR : C_RAW_NOISE_AMPLITUDE_RED;
			cnt_local_fail = 0;
			for(idx_i = 0; idx_i < 1000; idx_i = idx_i + 1) begin
				task_generate_deterministic_noise(color_ir, idx_i, noise_first);
				task_generate_deterministic_noise(color_ir, idx_i, noise_second);
				if((noise_first < -noise_amplitude) || (noise_first > noise_amplitude)) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
				if(noise_first !== noise_second) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
			end
			if(cnt_local_fail == 0) begin
				$display("PASS RGC-06 color=%0d noise bounded to +/-%0d and bit-identical across 1000 repeated frame evaluations", color_ir, noise_amplitude);
			end else begin
				$display("FAIL RGC-06 color=%0d noise bound or determinism violated count=%0d", color_ir, cnt_local_fail);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-07：clamp原语极端值检验---------------//
	task check_clamp_extremes;
		reg [9:0] clamped_low;
		reg [9:0] clamped_high;
		reg [9:0] clamped_mid;
		begin
			task_clamp_to_target_code_window(-32'sd100000, clamped_low);
			task_clamp_to_target_code_window(32'sd100000, clamped_high);
			task_clamp_to_target_code_window(32'sd250, clamped_mid);
			if((clamped_low == C_RAW_TARGET_CODE_MIN) && (clamped_high == C_RAW_TARGET_CODE_MAX) && (clamped_mid == 10'd250)) begin
				$display("PASS RGC-07 clamp pins extreme values low=%0d high=%0d and leaves in-window value unchanged mid=%0d", clamped_low, clamped_high, clamped_mid);
			end else begin
				$display("FAIL RGC-07 clamp did not behave as required low=%0d high=%0d mid=%0d", clamped_low, clamped_high, clamped_mid);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-08：NORMAL档位完整流水线窗口内+可复现性扫描---------------//
	task check_full_pipeline_sweep;
		input color_ir;
		reg [9:0] target_code_first;
		reg [9:0] target_code_second;
		integer raw_unclamped_first;
		integer raw_unclamped_second;
		integer cnt_local_fail;
		integer frame_probe;
		begin
			cnt_local_fail = 0;
			// 步长31与NORMAL周期400、漂移周期4000互质，能在4000帧范围内扫过脉搏和
			// 漂移的各个相位组合，不需要真的跑满全部4000帧
			for(frame_probe = 0; frame_probe < 4000; frame_probe = frame_probe + 31) begin
				task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, color_ir, frame_probe, target_code_first, raw_unclamped_first);
				task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, color_ir, frame_probe, target_code_second, raw_unclamped_second);
				if((target_code_first < C_RAW_TARGET_CODE_MIN) || (target_code_first > C_RAW_TARGET_CODE_MAX)) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
				if((target_code_first !== target_code_second) || (raw_unclamped_first !== raw_unclamped_second)) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
			end
			if(cnt_local_fail == 0) begin
				$display("PASS RGC-08 color=%0d NORMAL full pipeline stays in [%0d,%0d] and is bit-identical across repeated calls over swept frame range", color_ir, C_RAW_TARGET_CODE_MIN, C_RAW_TARGET_CODE_MAX);
			end else begin
				$display("FAIL RGC-08 color=%0d NORMAL full pipeline sweep violation count=%0d", color_ir, cnt_local_fail);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-09：FLAT档位脉搏贡献恒为0（PRC-01）---------------//
	task check_flat_profile_zero_pulse;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude;
		integer notch_top_pct;
		integer notch_depth_pct;
		integer notch_rebound_pct;
		integer drift_amplitude_unused;
		integer pulse_period_frames;
		integer pulse_probe;
		integer cnt_local_fail;
		integer frame_probe;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_FLAT, color_ir, dc_offset_unused, pulse_amplitude,
				notch_top_pct, notch_depth_pct, notch_rebound_pct, drift_amplitude_unused, pulse_period_frames);
			cnt_local_fail = 0;
			for(frame_probe = 0; frame_probe < pulse_period_frames; frame_probe = frame_probe + 37) begin
				task_generate_pulse_shape(pulse_amplitude, notch_top_pct, notch_depth_pct, notch_rebound_pct, pulse_period_frames, frame_probe, pulse_probe);
				if(pulse_probe != 0) cnt_local_fail = cnt_local_fail + 1;
			end
			if((pulse_amplitude == 0) && (cnt_local_fail == 0)) begin
				$display("PASS RGC-09 color=%0d FLAT profile has zero pulse contribution at every sampled phase", color_ir);
			end else begin
				$display("FAIL RGC-09 color=%0d FLAT profile produced nonzero pulse contribution count=%0d", color_ir, cnt_local_fail);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-10：LOW/HIGH_AMPLITUDE分居NORMAL两侧（PRC-02/03）---------------//
	task check_amplitude_profiles_bracket_normal;
		input color_ir;
		integer dc_offset_unused;
		integer amp_normal;
		integer amp_low;
		integer amp_high;
		integer notch_top_pct_unused;
		integer notch_depth_pct_unused;
		integer notch_rebound_pct_unused;
		integer drift_amplitude_unused;
		integer pulse_period_frames_unused;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, amp_normal,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, pulse_period_frames_unused);
			task_select_raw_profile_params(C_RAW_PROFILE_LOW_AMPLITUDE, color_ir, dc_offset_unused, amp_low,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, pulse_period_frames_unused);
			task_select_raw_profile_params(C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED, color_ir, dc_offset_unused, amp_high,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, pulse_period_frames_unused);
			if((amp_low < amp_normal) && (amp_normal < amp_high)) begin
				$display("PASS RGC-10 color=%0d amplitude profiles bracket NORMAL low=%0d normal=%0d high=%0d", color_ir, amp_low, amp_normal, amp_high);
			end else begin
				$display("FAIL RGC-10 color=%0d amplitude profiles do not bracket NORMAL low=%0d normal=%0d high=%0d", color_ir, amp_low, amp_normal, amp_high);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-11：HIGH_AMPLITUDE_SATURATED正常扫描真实触达clamp（PRC-03）---------------//
	task check_high_amplitude_reaches_clamp;
		input color_ir;
		reg [9:0] target_code_probe;
		integer raw_unclamped_probe;
		integer frame_probe;
		integer flag_saw_clamp_max;
		begin
			flag_saw_clamp_max = 0;
			for(frame_probe = 0; frame_probe < C_RAW_PULSE_PERIOD_FRAMES; frame_probe = frame_probe + 5) begin
				task_generate_raw_target_code(C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED, color_ir, frame_probe, target_code_probe, raw_unclamped_probe);
				if(target_code_probe == C_RAW_TARGET_CODE_MAX) flag_saw_clamp_max = 1;
			end
			if(flag_saw_clamp_max) begin
				$display("PASS RGC-11 color=%0d HIGH_AMPLITUDE_SATURATED reaches real clamp max during ordinary one-period sweep", color_ir);
			end else begin
				$display("FAIL RGC-11 color=%0d HIGH_AMPLITUDE_SATURATED never reached clamp max during sweep", color_ir);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-12：STRONG_DRIFT摆幅更大但仍有界（PRC-04）---------------//
	task check_strong_drift_bounded;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude_unused;
		integer notch_top_pct_unused;
		integer notch_depth_pct_unused;
		integer notch_rebound_pct_unused;
		integer drift_normal;
		integer drift_strong;
		integer pulse_period_frames_unused;
		reg [9:0] target_code_probe;
		integer raw_unclamped_probe;
		integer cnt_local_fail;
		integer frame_probe;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_normal, pulse_period_frames_unused);
			task_select_raw_profile_params(C_RAW_PROFILE_STRONG_DRIFT, color_ir, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_strong, pulse_period_frames_unused);
			cnt_local_fail = 0;
			for(frame_probe = 0; frame_probe < 4000; frame_probe = frame_probe + 131) begin
				task_generate_raw_target_code(C_RAW_PROFILE_STRONG_DRIFT, color_ir, frame_probe, target_code_probe, raw_unclamped_probe);
				if((target_code_probe < C_RAW_TARGET_CODE_MIN) || (target_code_probe > C_RAW_TARGET_CODE_MAX)) cnt_local_fail = cnt_local_fail + 1;
			end
			if((drift_strong > drift_normal) && (cnt_local_fail == 0)) begin
				$display("PASS RGC-12 color=%0d STRONG_DRIFT swing normal=%0d strong=%0d stays within legal window across sweep", color_ir, drift_normal, drift_strong);
			end else begin
				$display("FAIL RGC-12 color=%0d STRONG_DRIFT check failed normal=%0d strong=%0d out_of_window_count=%0d", color_ir, drift_normal, drift_strong, cnt_local_fail);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-13：FAST/SLOW_PERIOD分居NORMAL两侧且周期数符合预期（PRC-06）---------------//
	task check_period_profiles_bracket_normal;
		integer dc_offset_unused;
		integer pulse_amplitude_unused;
		integer notch_top_pct_unused;
		integer notch_depth_pct_unused;
		integer notch_rebound_pct_unused;
		integer drift_amplitude_unused;
		integer period_normal;
		integer period_fast;
		integer period_slow;
		integer cycles_normal;
		integer cycles_fast;
		integer cycles_slow;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, C_RAW_COLOR_RED, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, period_normal);
			task_select_raw_profile_params(C_RAW_PROFILE_FAST_PERIOD, C_RAW_COLOR_RED, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, period_fast);
			task_select_raw_profile_params(C_RAW_PROFILE_SLOW_PERIOD, C_RAW_COLOR_RED, dc_offset_unused, pulse_amplitude_unused,
				notch_top_pct_unused, notch_depth_pct_unused, notch_rebound_pct_unused, drift_amplitude_unused, period_slow);
			cycles_normal = 4000 / period_normal;
			cycles_fast = 4000 / period_fast;
			cycles_slow = 4000 / period_slow;
			if((period_fast < period_normal) && (period_normal < period_slow) && (cycles_fast > cycles_normal) && (cycles_normal > cycles_slow)) begin
				$display("PASS RGC-13 periods bracket NORMAL fast=%0d(cycles=%0d) normal=%0d(cycles=%0d) slow=%0d(cycles=%0d) over 4000 frames", period_fast, cycles_fast, period_normal, cycles_normal, period_slow, cycles_slow);
			end else begin
				$display("FAIL RGC-13 periods do not bracket NORMAL as expected fast=%0d normal=%0d slow=%0d", period_fast, period_normal, period_slow);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-14：WEAK_NOTCH下探幅度明显小于NORMAL（PRC-07）---------------//
	task check_weak_notch_shallow;
		input color_ir;
		integer dc_offset_unused;
		integer pulse_amplitude;
		integer notch_top_pct_normal;
		integer notch_depth_pct_normal;
		integer notch_rebound_pct_normal;
		integer drift_amplitude_unused;
		integer pulse_period_frames;
		integer notch_top_pct_weak;
		integer notch_depth_pct_weak;
		integer notch_rebound_pct_weak;
		integer pulse_period_frames_weak;
		integer pulse_amplitude_weak;
		integer dip_normal;
		integer dip_weak;
		begin
			task_select_raw_profile_params(C_RAW_PROFILE_NORMAL, color_ir, dc_offset_unused, pulse_amplitude,
				notch_top_pct_normal, notch_depth_pct_normal, notch_rebound_pct_normal, drift_amplitude_unused, pulse_period_frames);
			task_select_raw_profile_params(C_RAW_PROFILE_WEAK_NOTCH, color_ir, dc_offset_unused, pulse_amplitude_weak,
				notch_top_pct_weak, notch_depth_pct_weak, notch_rebound_pct_weak, drift_amplitude_unused, pulse_period_frames_weak);
			// 切迹下探幅度 = notch_top_level - notch_bottom_level = pulse_amplitude*notch_depth_pct/100
			dip_normal = (pulse_amplitude * notch_depth_pct_normal) / 100;
			dip_weak = (pulse_amplitude_weak * notch_depth_pct_weak) / 100;
			if(dip_weak < (dip_normal / 4)) begin
				$display("PASS RGC-14 color=%0d WEAK_NOTCH dip is much shallower than NORMAL normal_dip=%0d weak_dip=%0d", color_ir, dip_normal, dip_weak);
			end else begin
				$display("FAIL RGC-14 color=%0d WEAK_NOTCH dip not shallow enough normal_dip=%0d weak_dip=%0d", color_ir, dip_normal, dip_weak);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------RGC-15：全部非NORMAL档位窗口内+可复现性扫描---------------//
	task check_non_normal_profiles_pipeline_sweep;
		input color_ir;
		input [2:0] profile_id;
		input [199:0] profile_name; // 仅用于打印诊断，不参与判定；宽度覆盖最长档位名HIGH_AMPLITUDE_SATURATED
		reg [9:0] target_code_first;
		reg [9:0] target_code_second;
		integer raw_unclamped_first;
		integer raw_unclamped_second;
		integer cnt_local_fail;
		integer frame_probe;
		begin
			cnt_local_fail = 0;
			for(frame_probe = 0; frame_probe < 4000; frame_probe = frame_probe + 131) begin
				task_generate_raw_target_code(profile_id, color_ir, frame_probe, target_code_first, raw_unclamped_first);
				task_generate_raw_target_code(profile_id, color_ir, frame_probe, target_code_second, raw_unclamped_second);
				if((target_code_first < C_RAW_TARGET_CODE_MIN) || (target_code_first > C_RAW_TARGET_CODE_MAX)) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
				if((target_code_first !== target_code_second) || (raw_unclamped_first !== raw_unclamped_second)) begin
					cnt_local_fail = cnt_local_fail + 1;
				end
			end
			if(cnt_local_fail == 0) begin
				$display("PASS RGC-15 color=%0d profile=%0d(%0s) stays in [%0d,%0d] and is bit-identical across repeated calls", color_ir, profile_id, profile_name, C_RAW_TARGET_CODE_MIN, C_RAW_TARGET_CODE_MAX);
			end else begin
				$display("FAIL RGC-15 color=%0d profile=%0d(%0s) sweep violation count=%0d", color_ir, profile_id, profile_name, cnt_local_fail);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------主自检序列---------------//
	initial begin
		cnt_error = 0;
		check_rise_then_decay(C_RAW_COLOR_RED);
		check_rise_then_decay(C_RAW_COLOR_IR);
		check_dicrotic_notch(C_RAW_COLOR_RED);
		check_dicrotic_notch(C_RAW_COLOR_IR);
		check_return_to_trough(C_RAW_COLOR_RED);
		check_return_to_trough(C_RAW_COLOR_IR);
		check_baseline_drift_trend(C_RAW_COLOR_RED);
		check_baseline_drift_trend(C_RAW_COLOR_IR);
		check_noise_bounded_deterministic(C_RAW_COLOR_RED);
		check_noise_bounded_deterministic(C_RAW_COLOR_IR);
		check_clamp_extremes;
		check_full_pipeline_sweep(C_RAW_COLOR_RED);
		check_full_pipeline_sweep(C_RAW_COLOR_IR);

		check_flat_profile_zero_pulse(C_RAW_COLOR_RED);
		check_flat_profile_zero_pulse(C_RAW_COLOR_IR);
		check_amplitude_profiles_bracket_normal(C_RAW_COLOR_RED);
		check_amplitude_profiles_bracket_normal(C_RAW_COLOR_IR);
		check_high_amplitude_reaches_clamp(C_RAW_COLOR_RED);
		check_high_amplitude_reaches_clamp(C_RAW_COLOR_IR);
		check_strong_drift_bounded(C_RAW_COLOR_RED);
		check_strong_drift_bounded(C_RAW_COLOR_IR);
		check_period_profiles_bracket_normal;
		check_weak_notch_shallow(C_RAW_COLOR_RED);
		check_weak_notch_shallow(C_RAW_COLOR_IR);
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_FLAT, "FLAT");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_FLAT, "FLAT");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_LOW_AMPLITUDE, "LOW_AMPLITUDE");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_LOW_AMPLITUDE, "LOW_AMPLITUDE");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED, "HIGH_AMPLITUDE_SATURATED");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_HIGH_AMPLITUDE_SATURATED, "HIGH_AMPLITUDE_SATURATED");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_STRONG_DRIFT, "STRONG_DRIFT");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_STRONG_DRIFT, "STRONG_DRIFT");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_FAST_PERIOD, "FAST_PERIOD");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_FAST_PERIOD, "FAST_PERIOD");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_SLOW_PERIOD, "SLOW_PERIOD");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_SLOW_PERIOD, "SLOW_PERIOD");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_RED, C_RAW_PROFILE_WEAK_NOTCH, "WEAK_NOTCH");
		check_non_normal_profiles_pipeline_sweep(C_RAW_COLOR_IR, C_RAW_PROFILE_WEAK_NOTCH, "WEAK_NOTCH");

		// 汇总并干净退出
		if(cnt_error == 0) begin
			$display("RAWGEN_SELFCHECK_PASS");
		end else begin
			$display("RAWGEN_SELFCHECK_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
