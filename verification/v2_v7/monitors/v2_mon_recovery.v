`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Recovery Monitor
// Module Name:     v2_mon_recovery
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 3
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md V1.13 sections 8.3, 16.2, 16.3;
//                  contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md V1.6 section 1 (5000-cycle drain watchdog)
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Three recovery bounds. (a) STOP acknowledge to lifecycle CONFIG within C_STOP_CONFIG_MAX cycles unless a fault was recorded meanwhile; the default 5000 is the supervisor drain-watchdog window (C17 section 1): T-lost 4500 plus the longest analog-safe wait still fits, and any longer drain must be reported by the watchdog, so a longer silent drain is a failure. (b) START acknowledge to the first macro-frame start within C_START_FRAME_MAX cycles; the contracts give conditions (C08 8.3/16.2) but no number, so the default is one macro frame and the measured maximum is reported. (c) With i_expect_result, the first formal result within C_RESULT_MAX cycles of that first frame start; the default is one macro frame because a healthy NORMAL frame delivers RED by Q3 300 plus conversion and pipeline. Synthesizable checker core.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻恢复检查监视器
// 模块名称:        v2_mon_recovery
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第3项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md V1.13第8.3、16.2、16.3节；
//                  PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md V1.6第1节（5000拍排空看门狗）
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。三条恢复界限。(a) STOP确认到生命周期回CONFIG不超过C_STOP_CONFIG_MAX拍，期间记录过故障除外；默认5000取supervisor排空看门狗窗口（C17第1节）：T-lost 4500加最长analog_safe等待仍在其内，更长的排空必须由看门狗上报，所以更长的静默排空判FAIL。(b) START确认到首个宏帧起点不超过C_START_FRAME_MAX拍；合同只给条件（C08第8.3/16.2节）没有数值，默认取一个宏帧，并报告实测最大值。(c) i_expect_result时，首个正式结果须在该首帧起点后C_RESULT_MAX拍内出现；默认一个宏帧，因为健康NORMAL帧的RED在Q3 300加转换与流水线内即可交付。可综合检查核心。

// 恢复检查：STOP到CONFIG、START到首帧、首帧到首个正式结果三条界限
module v2_mon_recovery
#(
	parameter integer C_STOP_CONFIG_MAX = 5000, // STOP确认到CONFIG的最大拍数
	parameter integer C_START_FRAME_MAX = 5000, // START确认到首个宏帧起点的最大拍数
	parameter integer C_RESULT_MAX = 5000 // 首帧起点到首个正式结果的最大拍数
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	input i_stop_ack,                       // 调度器收到的STOP确认单拍
	input i_life_config,                    // 生命周期处于CONFIG
	input i_fault_record,                   // 本拍有故障记录或阻断保持
	input i_start_ack,                      // 管理器START被调度器接受的单拍，重新起算首帧时限
	input i_frame_start,                    // 本拍宏帧起点
	input i_result,                         // 本拍正式结果握手
	input i_expect_result,                  // 当前RUN应产生正式结果
	output [31:0] o_stop_count,             // 已检查的STOP次数
	output [31:0] o_stop_fail,              // STOP后静默超界次数
	output [31:0] o_stop_max,               // STOP到CONFIG实测最大拍数
	output [31:0] o_start_count,            // 完成起帧计时的RUN数目
	output [31:0] o_start_fail,             // START后一个时限内未起帧的RUN数目
	output [31:0] o_start_max,              // 各RUN从START到首帧的最长实测间隔
	output [31:0] o_result_count,           // 首帧后拿到首个正式样本的RUN数目
	output [31:0] o_result_fail,            // 首帧后时限内没有正式样本的RUN数目
	output [31:0] o_result_max,             // 首帧到首个正式样本的最长实测间隔
	output o_fail_event                     // 本拍新判定一次恢复超界
);

	//---------------计数信号---------------//
	// 三条界限的计时、次数与最大值
	reg [31:0] cnt_stop_wait;               // STOP后已等待拍数
	reg [31:0] cnt_start_wait;              // 起帧计时器，START后逐拍累加
	reg [31:0] cnt_result_wait;             // 样本计时器，首帧后逐拍累加
	reg [31:0] cnt_stop_checked;            // 排空检查完成数寄存
	reg [31:0] cnt_stop_bad;                // 静默排空超时累计寄存
	reg [31:0] cnt_stop_peak;               // 排空时长历史峰值寄存
	reg [31:0] cnt_start_checked;           // 起帧检查完成数寄存
	reg [31:0] cnt_start_bad;               // 起帧超时累计寄存
	reg [31:0] cnt_start_peak;              // 起帧延迟历史峰值寄存
	reg [31:0] cnt_result_checked;          // 样本检查完成数寄存
	reg [31:0] cnt_result_bad;              // 样本超时累计寄存
	reg [31:0] cnt_result_peak;             // 样本延迟历史峰值寄存

	//---------------标志信号---------------//
	// 三条界限的武装与故障豁免
	reg flag_stop_armed;                    // 正在等待STOP后回CONFIG
	reg flag_stop_faulted;                  // 本次STOP等待期间记录过故障
	reg flag_stop_reported;                 // 本次STOP超界已计数
	reg flag_start_armed;                   // 正在等待START后首帧
	reg flag_start_reported;                // 防止同一RUN的起帧超时重复计数
	reg flag_result_armed;                  // 正在等待首个正式结果
	reg flag_result_reported;               // 防止同一首帧的样本超时重复计数
	wire flag_stop_over;                    // 本拍STOP首次静默超界
	wire flag_start_over;                   // 本拍START首次超界
	wire flag_result_over;                  // 本拍首结果首次超界

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 超界判定
	assign flag_stop_over = flag_stop_armed && !i_life_config && !flag_stop_faulted && !i_fault_record && !flag_stop_reported && (cnt_stop_wait >= C_STOP_CONFIG_MAX); // 无故障记录且排空未结束
	assign flag_start_over = flag_start_armed && !i_frame_start && !flag_start_reported && (cnt_start_wait >= C_START_FRAME_MAX); // START后迟迟不起帧
	assign flag_result_over = flag_result_armed && !i_result && !flag_result_reported && (cnt_result_wait >= C_RESULT_MAX); // 首帧后迟迟无结果

	//-------------输出信号连线-------------//
	// 各计数送出
	assign o_stop_count = cnt_stop_checked; // 排空检查完成数送汇总行
	assign o_stop_fail = cnt_stop_bad;      // 静默排空超时数送结论
	assign o_stop_max = cnt_stop_peak;      // 排空最长时长送汇总行
	assign o_start_count = cnt_start_checked; // 起帧检查完成数送汇总行
	assign o_start_fail = cnt_start_bad;    // 起帧超时数送结论
	assign o_start_max = cnt_start_peak;    // 起帧最长延迟送汇总行
	assign o_result_count = cnt_result_checked; // 样本检查完成数送汇总行
	assign o_result_fail = cnt_result_bad;  // 样本超时数送结论
	assign o_result_max = cnt_result_peak;  // 样本最长延迟送汇总行
	assign o_fail_event = flag_stop_over || flag_start_over || flag_result_over; // 任一界限新超界

	//-------------主要任务处理区域-------------//
	// STOP等待武装：STOP确认武装，回CONFIG解除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stop_armed <= 1'b0;            // 复位不等待
		end else if(i_stop_ack == 1'b1)begin
			flag_stop_armed <= 1'b1;            // STOP确认开始计时
		end else if(i_life_config == 1'b1)begin
			flag_stop_armed <= 1'b0;            // 回到CONFIG结束本次检查
		end else begin
			flag_stop_armed <= flag_stop_armed; // 排空期间保持
		end
	end

	// STOP等待期间故障豁免
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stop_faulted <= 1'b0;          // 复位无豁免
		end else if(i_stop_ack == 1'b1)begin
			flag_stop_faulted <= i_fault_record; // 新STOP按当拍故障记录初始化
		end else if(flag_stop_armed && i_fault_record)begin
			flag_stop_faulted <= 1'b1;          // 排空期间出现故障记录即豁免
		end else begin
			flag_stop_faulted <= flag_stop_faulted; // 保持到下次STOP
		end
	end

	// STOP超界已报告
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stop_reported <= 1'b0;         // 复位未报告
		end else if(i_stop_ack == 1'b1)begin
			flag_stop_reported <= 1'b0;         // 新STOP允许再报
		end else if(flag_stop_over == 1'b1)begin
			flag_stop_reported <= 1'b1;         // 同一STOP只计一次
		end else begin
			flag_stop_reported <= flag_stop_reported; // 保持
		end
	end

	// STOP等待拍数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_stop_wait <= 32'd0;             // 复位清等待
		end else if(i_stop_ack == 1'b1)begin
			cnt_stop_wait <= 32'd0;             // STOP确认拍记0
		end else if(flag_stop_armed == 1'b1)begin
			cnt_stop_wait <= cnt_stop_wait + 32'd1; // 排空中逐拍累加
		end else begin
			cnt_stop_wait <= cnt_stop_wait;     // 结束后保留最近值
		end
	end

	// 排空检查完成：从STOP确认走到CONFIG算一次
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_stop_checked <= 32'd0;          // 复位清STOP次数
		end else if(flag_stop_armed && i_life_config)begin
			cnt_stop_checked <= cnt_stop_checked + 32'd1; // 回CONFIG即完成一次检查
		end else begin
			cnt_stop_checked <= cnt_stop_checked; // 未完成保持
		end
	end

	// 无故障记录却排空过久的累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_stop_bad <= 32'd0;              // 复位清STOP超界
		end else if(flag_stop_over == 1'b1)begin
			cnt_stop_bad <= cnt_stop_bad + 32'd1; // 静默超界加一
		end else begin
			cnt_stop_bad <= cnt_stop_bad;       // 无超界保持
		end
	end

	// 排空时长峰值：每次回到CONFIG时比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_stop_peak <= 32'd0;             // 复位清STOP峰值
		end else if(flag_stop_armed && i_life_config && (cnt_stop_wait > cnt_stop_peak))begin
			cnt_stop_peak <= cnt_stop_wait;     // 本次排空更长时刷新
		end else begin
			cnt_stop_peak <= cnt_stop_peak;     // 否则保持
		end
	end

	// START等待武装：START确认武装，首帧解除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_start_armed <= 1'b0;           // 复位不等待首帧
		end else if(i_start_ack == 1'b1)begin
			flag_start_armed <= 1'b1;           // 管理器放行新RUN，进入等首帧阶段
		end else if((i_frame_start == 1'b1) || (i_stop_ack == 1'b1))begin
			flag_start_armed <= 1'b0;           // 起帧或再次STOP结束检查
		end else begin
			flag_start_armed <= flag_start_armed; // 等待期间保持
		end
	end

	// 起帧超时的单次计数闩
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_start_reported <= 1'b0;        // 复位未报告START超界
		end else if(i_start_ack == 1'b1)begin
			flag_start_reported <= 1'b0;        // 新RUN开始时解除起帧超时闩
		end else if(flag_start_over == 1'b1)begin
			flag_start_reported <= 1'b1;        // 起帧超时只记一次
		end else begin
			flag_start_reported <= flag_start_reported; // START超界报告状态保持
		end
	end

	// 起帧计时：START确认拍清零后累加
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_start_wait <= 32'd0;            // 上电时起帧计时器归零
		end else if(i_start_ack == 1'b1)begin
			cnt_start_wait <= 32'd0;            // 新RUN从零开始量起帧延迟
		end else if(flag_start_armed == 1'b1)begin
			cnt_start_wait <= cnt_start_wait + 32'd1; // 等首帧期间累加
		end else begin
			cnt_start_wait <= cnt_start_wait;   // 起帧后保留最近值
		end
	end

	// 起帧检查完成：START后首个宏帧起点出现
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_start_checked <= 32'd0;         // 上电时起帧检查完成数归零
		end else if(flag_start_armed && i_frame_start)begin
			cnt_start_checked <= cnt_start_checked + 32'd1; // 起帧即完成一次START检查
		end else begin
			cnt_start_checked <= cnt_start_checked; // 未起帧保持
		end
	end

	// START后迟迟不起帧的累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_start_bad <= 32'd0;             // 上电时起帧超时累计归零
		end else if(flag_start_over == 1'b1)begin
			cnt_start_bad <= cnt_start_bad + 32'd1; // START超界加一
		end else begin
			cnt_start_bad <= cnt_start_bad;     // 本拍未新增起帧超时
		end
	end

	// 起帧延迟峰值：每次首帧起点时比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_start_peak <= 32'd0;            // 上电时起帧延迟峰值归零
		end else if(flag_start_armed && i_frame_start && (cnt_start_wait > cnt_start_peak))begin
			cnt_start_peak <= cnt_start_wait;   // 本次起帧更晚时刷新
		end else begin
			cnt_start_peak <= cnt_start_peak;   // START峰值保持
		end
	end

	// 首结果等待武装：START后首帧武装，首结果或STOP解除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_result_armed <= 1'b0;          // 复位不等待结果
		end else if(flag_start_armed && i_frame_start && i_expect_result)begin
			flag_result_armed <= 1'b1;          // START后首帧开始等结果
		end else if((i_result == 1'b1) || (i_stop_ack == 1'b1) || (i_start_ack == 1'b1))begin
			flag_result_armed <= 1'b0;          // 结果到达或生命周期变化结束检查
		end else begin
			flag_result_armed <= flag_result_armed; // 等待期间保持武装
		end
	end

	// 样本超时的单次计数闩
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_result_reported <= 1'b0;       // 复位未报告首结果超界
		end else if(flag_start_armed && i_frame_start)begin
			flag_result_reported <= 1'b0;       // 新首帧允许再报
		end else if(flag_result_over == 1'b1)begin
			flag_result_reported <= 1'b1;       // 同一首帧只计一次
		end else begin
			flag_result_reported <= flag_result_reported; // 首结果超界报告状态保持
		end
	end

	// 样本计时：首帧起点清零后累加
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_result_wait <= 32'd0;           // 复位清首结果等待
		end else if(flag_start_armed && i_frame_start)begin
			cnt_result_wait <= 32'd0;           // 首帧起点记0
		end else if(flag_result_armed == 1'b1)begin
			cnt_result_wait <= cnt_result_wait + 32'd1; // 等结果期间累加
		end else begin
			cnt_result_wait <= cnt_result_wait; // 结果到达后保留最近值
		end
	end

	// 样本检查完成：首帧后第一笔正式结果握手
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_result_checked <= 32'd0;        // 复位清首结果次数
		end else if(flag_result_armed && i_result)begin
			cnt_result_checked <= cnt_result_checked + 32'd1; // 结果到达完成一次检查
		end else begin
			cnt_result_checked <= cnt_result_checked; // 未到达保持
		end
	end

	// 首帧后迟迟无正式样本的累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_result_bad <= 32'd0;            // 复位清首结果超界
		end else if(flag_result_over == 1'b1)begin
			cnt_result_bad <= cnt_result_bad + 32'd1; // 首结果超界加一
		end else begin
			cnt_result_bad <= cnt_result_bad;   // 无首结果超界保持
		end
	end

	// 样本延迟峰值：每次首个正式结果时比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_result_peak <= 32'd0;           // 复位清首结果峰值
		end else if(flag_result_armed && i_result && (cnt_result_wait > cnt_result_peak))begin
			cnt_result_peak <= cnt_result_wait; // 本次结果更晚时刷新
		end else begin
			cnt_result_peak <= cnt_result_peak; // 首结果峰值保持
		end
	end

endmodule
