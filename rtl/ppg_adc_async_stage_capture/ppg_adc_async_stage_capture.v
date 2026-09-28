`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/24
// Design Name:        PPG ADC Asynchronous Stage Capture
// Module Name:        ppg_adc_async_stage_capture
// Description:        Description/ppg_adc_async_stage_capture_Design.pdf
// Simulations:        TestBench/Vivado/2021.1/ppg_adc_async_stage_capture
//
// Referrences:        PPG_NEW_CHAT_CONTEXT.md, PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// Dependencies:       None
//
// Version:            V1.0
// Revision Date:      2026/07/30
// History:
//    Time               Version       Revised by            Contents
// 2026/07/24            V1.0          Erie                  Create file.
// 2026/07/25            V1.0          Erie                  Match the real dual-stage ADC result-valid interface.
// 2026/07/30            V1.0          Erie                  Latch frame mode only after both DONE levels return low.
// 2026/07/30            V1.0          Erie                  Use an explicit ADC transaction-start boundary.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年07月24日
// 设计名称:           PPG ADC异步双级结果捕获
// 模块名称:           ppg_adc_async_stage_capture
// 模块说明:           Description/ppg_adc_async_stage_capture_Design.pdf
// 仿真工程:           TestBench/Vivado/2021.1/ppg_adc_async_stage_capture
//
// 参考资料:           PPG_NEW_CHAT_CONTEXT.md、PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// 依赖文件:           None
//
// 当前版本:           V1.0
// 修订日期:           2026年07月30日
// 修订历史:
//    时间               版本          修订人                修订内容
// 2026年07月24日        V1.0          Erie                  创建文件
// 2026年07月25日        V1.0          Erie                  适配真实双级ADC结果有效接口
// 2026年07月30日        V1.0          Erie                  仅在两级DONE回低后锁存帧模式
// 2026年07月30日        V1.0          Erie                  改用显式ADC事务开始边界

// 在显式ADC事务边界锁存精度，并按对应异步完成电平捕获保持稳定的两级物理码
module ppg_adc_async_stage_capture
#(
	parameter integer C_RAW_WIDTH = 10              // 单级Pipeline-SAR ADC物理输出码位宽
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，释放应由系统上层同步

	//-------------事务控制接口-------------//
	input i_adc_transaction_start,          // ADC_RST完成且DONE清零后、转换开始前的单周期脉冲
	input i_precision_mode_committed,       // ADC_RST前已锁定的事务精度，低9-bit、高15-bit

	//-------------异步ADC接口-------------//
	input [C_RAW_WIDTH - 1:0]i_dout_stage1_low, // 第一级末位完成后保持到ADC_RST的物理码
	input i_clk_stage1_dout_low_async,     // 第一级转换完成后拉高的异步结果有效电平
	input [C_RAW_WIDTH - 1:0]i_dout_stage2_low, // 第二级末位完成后保持到ADC_RST的物理码
	input i_clk_stage2_dout_low_async,     // 仅高精度事务使用的第二级异步完成电平

	//-------------结果接收接口-------------//
	input i_capture_ready,                  // 下游允许在当前时钟沿接收已缓存结果
	output [C_RAW_WIDTH - 1:0]o_capture_stage1_raw, // 两种精度模式均有效的第一级物理码
	output [C_RAW_WIDTH - 1:0]o_capture_stage2_raw, // 仅15-bit事务有效的第二级物理码
	output o_capture_precision_mode,        // 与当前缓存载荷原子对齐的精度模式快照
	output o_capture_valid                  // 缓存结果有效并保持至ready消费完成
);

	//--------------寄存器信号--------------//
	// 事务开始脉冲把顶层已提交模式保存为本次捕获的固定上下文
	reg reg_capture_mode;                   // 当前ADC事务等待S1或S2完成的模式快照

	//---------------标志信号---------------//
	// 两套同步链分别隔离两个模拟完成电平的亚稳态传播
	reg flag_stage1_done_meta;              // 第一级CLK_DOUT进入数字域的同步首级
	reg flag_stage1_done_sync;              // 第一级结果有效电平的稳定数字域副本
	reg flag_stage2_done_meta;              // 高精度S2完成电平的亚稳态隔离采样级
	reg flag_stage2_done_sync;              // 决定15-bit载荷接纳时刻的S2稳定副本
	reg flag_capture_pending;               // 事务开始后允许对应DONE触发且仅触发一次
	// 捕获控制区分输出消费、缓冲可用、模式选择和新结果接纳
	wire flag_output_transfer;              // valid与ready同拍成立的结果消费事件
	wire flag_buffer_available;             // 缓存为空或旧结果将在本拍被下游取走
	wire flag_selected_done_sync;           // 当前精度模式对应的同步完成电平
	wire flag_capture_accept;               // 所选完成电平有效时的唯一载荷锁存使能

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// 单元素弹性缓存保存两级RAW、精度属性和下游所有权
	reg [C_RAW_WIDTH - 1:0]capture_stage1_raw_o; // 反压期间保持稳定的第一级物理码
	reg [C_RAW_WIDTH - 1:0]capture_stage2_raw_o; // 高精度事务对应的第二级物理码
	reg capture_precision_mode_o;           // 防止模式切换改变已缓存结果的解释方式
	reg capture_valid_o;                    // 指示当前输出寄存器拥有未消费事务

	//-------------其他信号连线-------------//
	// 接收握手仅在缓存确有有效事务时消费当前结果
	assign flag_output_transfer = capture_valid_o && i_capture_ready; // 标记下游取得当前缓存事务
	assign flag_buffer_available = (capture_valid_o == 1'b0) || i_capture_ready; // 支持消费旧结果时开放写入
	assign flag_selected_done_sync = reg_capture_mode ? flag_stage2_done_sync : flag_stage1_done_sync; // 9-bit等待S1，15-bit等待S2
	assign flag_capture_accept = flag_selected_done_sync && flag_capture_pending && flag_buffer_available && (i_adc_transaction_start == 1'b0); // 事务开始拍禁止旧DONE触发；flag_capture_pending在正式完成后已清零，任何重复或跨代际陈旧DONE都在物理capture层被安全丢弃，不产生第二次完成/结果/owner @satisfies: LFA-05, LFA-07, OIB-05

	//-------------输出信号连线-------------//
	// 输出桥接保持顶层端口与内部时序寄存器职责分离
	assign o_capture_stage1_raw = capture_stage1_raw_o; // 输出已跨域保存的第一级物理结果
	assign o_capture_stage2_raw = capture_stage2_raw_o; // 输出高精度事务的第二级物理结果
	assign o_capture_precision_mode = capture_precision_mode_o; // 传递载荷所属的精度快照
	assign o_capture_valid = capture_valid_o; // 声明输出缓存当前包含完整ADC事务

	//-----------输出信号处理区域-----------//
	// 所选完成电平到达后锁存第一级物理码，两种精度模式均执行该操作
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			capture_stage1_raw_o <= {C_RAW_WIDTH{1'b0}}; // 复位清除不可用的第一级历史码
		end else if(flag_capture_accept == 1'b1)begin
			capture_stage1_raw_o <= i_dout_stage1_low; // 延迟同步窗口后采集稳定的S1总线
		end else begin
			capture_stage1_raw_o <= capture_stage1_raw_o; // 无新事务时保持当前输出载荷
		end
	end

	// 15-bit事务保存第二级物理码，9-bit事务明确标记该级数据无效
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			capture_stage2_raw_o <= {C_RAW_WIDTH{1'b0}}; // 复位移除第二级历史转换结果
		end else if(flag_capture_accept == 1'b1)begin
			if(reg_capture_mode == 1'b1)begin
				capture_stage2_raw_o <= i_dout_stage2_low; // S2完成时原子锁存两级物理码
			end else begin
				capture_stage2_raw_o <= {C_RAW_WIDTH{1'b0}}; // 粗精度事务不携带伪造S2数据
			end
		end else begin
			capture_stage2_raw_o <= capture_stage2_raw_o; // 反压期间维持第二级载荷不变
		end
	end

	// 精度快照与RAW在同一个接纳沿更新，后续帧切换不会重解释旧结果
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			capture_precision_mode_o <= 1'b0; // 复位默认采用9-bit载荷解释
		end else if(flag_capture_accept == 1'b1)begin
			capture_precision_mode_o <= reg_capture_mode; // 保存触发当前捕获的事务精度
		end else begin
			capture_precision_mode_o <= capture_precision_mode_o; // 缓存占用期间保持属性稳定
		end
	end

	// 新结果优先于同拍旧结果消费，保证单元素缓存允许无气泡替换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			capture_valid_o <= 1'b0;        // 复位后禁止报告虚假ADC事务
		end else if(flag_capture_accept == 1'b1)begin
			capture_valid_o <= 1'b1;        // 两级RAW与精度属性已经完整写入缓存
		end else if(flag_output_transfer == 1'b1)begin
			capture_valid_o <= 1'b0;        // 下游消费后释放单元素缓存所有权
		end else begin
			capture_valid_o <= capture_valid_o; // 空闲或反压阶段维持当前有效状态
		end
	end

	//-----------主要任务处理区域-----------//
	// 每次ADC事务开始时锁存顶层已在ADC_RST前提交的精度模式
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_capture_mode <= 1'b0;       // 数字复位后默认采用9-bit捕获上下文
		end else if(i_adc_transaction_start == 1'b1)begin
			reg_capture_mode <= i_precision_mode_committed; // 显式事务边界固定本次精度
		end else begin
			reg_capture_mode <= reg_capture_mode; // DONE同步和结果保持期间禁止模式漂移
		end
	end

	// 第一级同步首级只承担亚稳态隔离，不得直接驱动功能逻辑
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage1_done_meta <= 1'b0;  // 复位清除第一级异步采样历史
		end else if(i_adc_transaction_start == 1'b1)begin
			flag_stage1_done_meta <= 1'b0;  // 新事务开始时丢弃上一转换同步历史
		end else begin
			flag_stage1_done_meta <= i_clk_stage1_dout_low_async; // 采样模拟S1结果有效电平
		end
	end

	// 第一级同步末级为9-bit事务提供稳定完成状态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage1_done_sync <= 1'b0;  // 复位阻止粗精度捕获条件成立
		end else if(i_adc_transaction_start == 1'b1)begin
			flag_stage1_done_sync <= 1'b0;  // 显式边界清除上一笔S1完成状态
		end else begin
			flag_stage1_done_sync <= flag_stage1_done_meta; // 输出隔离后的S1完成电平
		end
	end

	// 第二级同步首级吸收高精度完成电平可能产生的亚稳态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage2_done_meta <= 1'b0;  // 复位清除第二级异步采样历史
		end else if(i_adc_transaction_start == 1'b1)begin
			flag_stage2_done_meta <= 1'b0;  // 新事务开始时刷新第二级同步入口
		end else begin
			flag_stage2_done_meta <= i_clk_stage2_dout_low_async; // 捕获高精度末级转换完成指示
		end
	end

	// 第二级同步末级只在15-bit事务中成为最终捕获边界
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stage2_done_sync <= 1'b0;  // 复位阻止精细结果提前进入缓存
		end else if(i_adc_transaction_start == 1'b1)begin
			flag_stage2_done_sync <= 1'b0;  // 新事务撤销旧高精度捕获资格
		end else begin
			flag_stage2_done_sync <= flag_stage2_done_meta; // 建立15-bit结果的最终接纳条件
		end
	end

	// 事务开始后建立一次捕获所有权，成功锁存结果后等待下一事务脉冲
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_capture_pending <= 1'b0;   // 数字复位期间不存在可接纳事务
		end else if(i_adc_transaction_start == 1'b1)begin
			flag_capture_pending <= 1'b1;   // ADC事务开始后等待对应完成电平
		end else if(flag_capture_accept == 1'b1)begin
			flag_capture_pending <= 1'b0;   // 完整结果锁存后关闭本次触发权限
		end else begin
			flag_capture_pending <= flag_capture_pending; // 反压期间保持等待且不丢失事务
		end
	end

endmodule
