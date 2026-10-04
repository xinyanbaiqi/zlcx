`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/14 00:00:00
// Design Name: 	PPG Characterization Control CDC
// Module Name: 	ppg_characterization_control_cdc
// Description: 	Description/ppg_characterization_control_cdc_Design.pdf
// Dependencies:
// ppg_config_cdc_bridge.v
// Simulations:		ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v
//
// Referrences:		PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//
//
// Version:			V1.0
// Revision Date:	2026/08/14 00:00:00
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/14          V1.0        Erie           Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月14日
// 设计名称: 		PPG Characterization Control CDC
// 模块名称: 		ppg_characterization_control_cdc
// 模块说明:		Description/ppg_characterization_control_cdc_Design.pdf
// 依赖文件:
// ppg_config_cdc_bridge.v
// 仿真工程: 		ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v
//
// 参考资料:		PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.0
// 修订日期:		2026年08月14日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月14日      V1.0        Erie           创建文件
module ppg_characterization_control_cdc
(
	//-----------------全局信号-----------------//
	input i_source_clk,                         // SPI配置源时钟，仅驱动source握手状态
	input i_source_rstn,                        // SPI源域低有效复位，和系统复位共同断言
	input i_clk,                                // 2 MHz目标域时钟，提交表征控制快照
	input i_rstn,                               // 2 MHz目标域低有效复位，清除已提交控制

	//-------------SPI源域控制接口--------------//
	input i_source_update_valid,                // 保持型source更新请求，直到握手接受
	input i_source_static_characterization_enable, // 待传输的STATIC_BIAS模式使能bit
	input [4:0]i_source_test_mux_ctrl,          // 待传输的五位模拟测试MUX选择码

	//-----------2 MHz目标域控制接口------------//
	input i_run_enable,                         // V4控制平面RUN资格，用于冻结模式使能
	input i_diag_clear_event,                   // 系统域诊断清除脉冲，只影响sticky状态

	//-------------SPI源域状态接口--------------//
	output o_source_update_ready,               // CDC邮箱可接收下一笔source快照的资格

	//-----------2 MHz目标域状态接口------------//
	output o_static_characterization_enable,    // 已提交的STATIC_BIAS模式控制值
	output [4:0]o_test_mux_ctrl,                // 已提交的测试MUX控制值
	output o_control_valid,                     // 复位后已经存在一笔合法提交控制
	output o_control_update_event,              // 完整控制快照被目标域接受的单拍事件
	output o_control_reject_event,              // 运行期非法快照被整体拒绝的单拍事件
	output o_protocol_error_sticky              // 记录运行期模式变更违反合同的sticky诊断
);

	//---------------配置参数区域---------------//
	//表征控制快照采用固定的使能位加五位MUX码布局
	localparam [2:0]CONTROL_WIDTH = 3'd6;       // 原子传输总位宽，禁止拆分为单bit同步器

	//--------------模块实例化信号--------------//
	//ppg_config_cdc_bridge--用户接口
	wire [CONTROL_WIDTH - 1:0]wire_bridge_destination_config; // 请求稳定后被bridge原子捕获的配置快照

	//----------------寄存器信号----------------//
	reg reg_source_update_armed;                // 只有valid撤销后才允许发起下一次source事务

	//-----------------标志信号-----------------//
	wire flag_bridge_destination_update;        // bridge报告一笔source快照已到达的目标域脉冲
	wire flag_source_bridge_busy;               // 应答返回前阻止覆盖source锁存快照的占用标志
	wire flag_source_fire;                      // source valid与CDC就绪同时成立时的唯一接受条件
	wire flag_destination_static_enable_match;  // RUN中传入使能位与已提交模式是否一致
	wire flag_destination_control_accept;       // 目标域允许整笔提交当前bridge快照的判断结果
	wire flag_destination_control_reject;       // 目标域必须保持旧控制并上报错误的判断结果

	//-----------------其他信号-----------------//
	//由source待提交字段拼接而成，并在整个CDC握手期间保持稳定的六位控制快照
	wire [CONTROL_WIDTH - 1:0]wire_source_control_snapshot; // 固定bit顺序的source原子控制载荷

	//-----------------输出信号-----------------//
	//2 MHz目标域状态接口
	reg static_characterization_enable_o;       // 为SSW提供的已提交静态表征使能缓存
	reg [4:0]test_mux_ctrl_o;                   // 为STATIC_BIAS S[4:0]提供的同步MUX缓存
	reg control_valid_o;                        // 表示目标域已经接受过至少一笔完整配置
	reg control_update_event_o;                 // 记录合法配置提交边沿的目标域脉冲寄存器
	reg control_reject_event_o;                 // 记录非法运行期配置被丢弃的目标域脉冲寄存器
	reg protocol_error_sticky_o;                // 持续保存模式切换违规诊断直到软件清除

	//---------------其他信号连线---------------//
	//其他信号连线
	assign flag_source_fire = i_source_update_valid && o_source_update_ready; // 仅在可用邮箱上锁存一笔source快照
	assign flag_destination_static_enable_match = wire_bridge_destination_config[5] == static_characterization_enable_o; // 比较运行中模式使能，防止动态切换STATIC_BIAS
	assign wire_source_control_snapshot = {i_source_static_characterization_enable, i_source_test_mux_ctrl}; // 将使能固定在bit5并保持MUX位序
	assign flag_destination_control_accept = flag_bridge_destination_update && ((i_run_enable == 1'b0) || ((control_valid_o == 1'b1) && (flag_destination_static_enable_match == 1'b1))); // 同时限定传输到达和运行期配置资格
	assign flag_destination_control_reject = flag_bridge_destination_update && (flag_destination_control_accept == 1'b0); // 任何到达但未获准的完整快照整体拒绝

	//---------------输出信号连线---------------//
	//SPI源域状态接口
	assign o_source_update_ready = !flag_source_bridge_busy && (reg_source_update_armed == 1'b1); // 仅在bridge空闲且valid已重新武装时接收新事务

	//2 MHz目标域状态接口
	assign o_static_characterization_enable = static_characterization_enable_o; // 以目标域寄存器隔离异步source模式位
	assign o_test_mux_ctrl = test_mux_ctrl_o;   // 以完整提交快照驱动STATIC_BIAS测试MUX；S[4:0]只在CDC提交后原子更新；ILM-14 i_clk是2MHz目标域时钟(48行)，142行five位一次性整体替换wire_bridge_destination_config[4:0]，同一2MHz边沿原子生效，非提交周期(144行)维持旧值不受扰动 @satisfies: TOP-08, ILM-14
	assign o_control_valid = control_valid_o;   // 向顶层公开已完成首次合法提交的状态
	assign o_control_update_event = control_update_event_o; // 输出合法快照实际应用的单周期确认
	assign o_control_reject_event = control_reject_event_o; // 输出整笔拒绝事件供系统诊断汇总
	assign o_protocol_error_sticky = protocol_error_sticky_o; // 输出可读且可清除的协议错误保持位

	//-------------输出信号处理区域-------------//
	//2 MHz目标域状态接口
	//目标域只在合法整笔快照到达时改写STATIC_BIAS模式寄存器
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			static_characterization_enable_o <= 1'b0; // 复位后保证不意外进入纯静态模拟向量
		end else if(flag_destination_control_accept == 1'b1)begin
			static_characterization_enable_o <= wire_bridge_destination_config[5]; // 合法提交时原子取用固定bit5模式位
		end else begin
			static_characterization_enable_o <= static_characterization_enable_o; // 拒绝、停止和shadow变化均保持旧模式值
		end
	end

	//目标域在与模式位相同的时钟沿更新完整五位测试MUX码
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			test_mux_ctrl_o <= 5'b00000;        // 复位后将模拟MUX选择恢复为安全零码
		end else if(flag_destination_control_accept == 1'b1)begin
			test_mux_ctrl_o <= wire_bridge_destination_config[4:0]; // 接受快照时五位同时替换，禁止逐bit跨域变化
		end else begin
			test_mux_ctrl_o <= test_mux_ctrl_o; // 非提交周期维持已观测节点的稳定选择
		end
	end

	//首次或后续合法提交均建立可供STATIC_BIAS启动资格检查的valid状态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			control_valid_o <= 1'b0;            // 复位后没有任何测试控制可作为静态启动依据
		end else if(flag_destination_control_accept == 1'b1)begin
			control_valid_o <= 1'b1;            // 完整快照通过运行规则后永久建立目标域有效性
		end else begin
			control_valid_o <= control_valid_o; // STOP、abort与诊断清除不擦除已提交配置状态
		end
	end

	//合法提交只以一个目标域时钟周期通知上层，不能代替START或SAR fire
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			control_update_event_o <= 1'b0;     // 复位释放前禁止产生伪提交事件
		end else if(flag_destination_control_accept == 1'b1)begin
			control_update_event_o <= 1'b1;     // 每笔通过检查的桥接快照报告一次应用事件
		end else begin
			control_update_event_o <= 1'b0;     // 其余目标域周期保持事件输出为低
		end
	end

	//非法模式切换使用独立单拍事件，不得与合法提交事件同时出现
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			control_reject_event_o <= 1'b0;     // 复位清除历史拒绝脉冲，避免误诊断
		end else if(flag_destination_control_reject == 1'b1)begin
			control_reject_event_o <= 1'b1;     // RUN中使能位变化或无首笔配置时报告拒绝
		end else begin
			control_reject_event_o <= 1'b0;     // 正常空闲和合法提交周期不保留拒绝脉冲
		end
	end

	//sticky错误以拒绝优先于软件清除，保留最近一次违反模式冻结规则的信息
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			protocol_error_sticky_o <= 1'b0;    // 复位后清空表征CDC协议错误历史
		end else if(flag_destination_control_reject == 1'b1)begin
			protocol_error_sticky_o <= 1'b1;    // 非法整笔快照到达时立即锁存违规状态
		end else if(i_diag_clear_event == 1'b1)begin
			protocol_error_sticky_o <= protocol_error_sticky_o;    // 仅软件明确清除事件可以撤销已记录诊断
		end else begin
			protocol_error_sticky_o <= protocol_error_sticky_o; // 无新错误或清除请求时保持诊断可读
		end
	end

	//-------------主要任务处理区域-------------//
	//source侧等待valid撤销后重新武装，避免持续valid在ready恢复时重复发送
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_source_update_armed <= 1'b1;    // source复位后允许第一笔表征控制快照进入邮箱
		end else if(i_source_update_valid == 1'b0)begin
			reg_source_update_armed <= 1'b1;    // 上层撤销valid后明确允许下一次独立提交
		end else if(flag_source_fire == 1'b1)begin
			reg_source_update_armed <= 1'b0;    // 当前valid已经被接受，禁止等待应答期间重复消费
		end else begin
			reg_source_update_armed <= reg_source_update_armed; // 保持当前武装状态直到valid或握手发生变化
		end
	end

	//--------------模块实例化区域--------------//
	//通用请求应答桥负责稳定6-bit数据跨域与返回应答，不承担运行期合法性判断
	ppg_config_cdc_bridge #(.C_CONFIG_WIDTH(CONTROL_WIDTH))ppg_config_cdc_bridge_Inst_characterization( // 绑定合同规定的六位原子控制载荷宽度
		.i_source_clk(i_source_clk),            // 使用SPI域时钟锁存source配置快照
		.i_source_rstn(i_source_rstn),          // 使用source域复位复原请求代际
		.i_source_config(wire_source_control_snapshot), // 传输固定bit序的使能与MUX组合快照
		.i_source_update(flag_source_fire),     // 仅source握手沿触发bridge请求翻转
		.o_source_busy(flag_source_bridge_busy), // 应答返回前向ready逻辑报告邮箱占用
		.i_destination_clk(i_clk),              // 在2 MHz域同步请求并采样稳定多bit数据
		.i_destination_rstn(i_rstn),            // 使用目标域复位清空bridge接收状态
		.o_destination_config(wire_bridge_destination_config), // 提供完整到达快照给目标域资格检查
		.o_destination_update(flag_bridge_destination_update) // 指示bridge已经完成一次目标域数据捕获
	);

endmodule
