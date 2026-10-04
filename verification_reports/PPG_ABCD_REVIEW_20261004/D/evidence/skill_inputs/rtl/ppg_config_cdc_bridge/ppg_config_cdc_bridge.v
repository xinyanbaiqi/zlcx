`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/23
// Design Name:     PPG Configuration CDC Bridge
// Module Name:     ppg_config_cdc_bridge
// Description:     Description/ppg_config_cdc_bridge_Design.pdf
// Simulations:     ../ppg_dual_precision_top/tb_ppg_dual_precision_top.v
//
// Referrences:     ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/07/23
// History:
//     Time          Version     Revised by     Contents
// 2026/07/23        V1.0        Erie          Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年07月23日
// 设计名称:        PPG 配置跨时钟域桥
// 模块名称:        ppg_config_cdc_bridge
// 模块说明:        Description/ppg_config_cdc_bridge_Design.pdf
// 仿真工程:        ../ppg_dual_precision_top/tb_ppg_dual_precision_top.v
//
// 参考资料:        ../ppg_system_integration/PPG_NEW_CHAT_CONTEXT.md
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年07月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年07月23日   V1.0        Erie          创建文件

// 使用请求应答翻转握手原子传输 SPI 域的多比特 PPG 配置
module ppg_config_cdc_bridge
#(
	parameter C_CONFIG_WIDTH = 123 // 原子配置快照的总位宽
)
(
	//---------------全局信号---------------//
	//-------------SPI 源时钟域-------------//
	input i_source_clk,                     // SPI_SCLK 域内的源时钟
	input i_source_rstn,                    // SPI_SCLK 域内同步释放的低有效复位
	input [C_CONFIG_WIDTH - 1:0]i_source_config, // 寄存器组提供的完整配置总线
	input i_source_update,                  // 请求锁存并发送当前配置的单周期脉冲
	output o_source_busy,                   // 指示上一个配置事务尚未被系统域确认

	//---------------用户接口---------------//
	//-------------2 MHz 目标时钟域----------//
	input i_destination_clk,                 // PPG 数字控制使用的 2 MHz 目标时钟
	input i_destination_rstn,                // 2 MHz 目标域同步释放的低有效复位
	output [C_CONFIG_WIDTH - 1:0]o_destination_config, // 在握手完成边沿更新的稳定多比特配置
	output o_destination_update              // 通知系统域新配置已原子接收的单周期脉冲
);

	//--------------寄存器信号--------------//
	// 源域在整个请求应答期间保持配置总线不变
reg [C_CONFIG_WIDTH - 1:0]reg_source_config; // 向目标域提供建立时间的源域快照

	//---------------标志信号---------------//
	// 源域请求与目标域应答各自只在所属时钟域翻转
reg flag_source_request;                    // 源域发起一次新配置事务的翻转标志
(* ASYNC_REG = "TRUE" *)
reg flag_ack_sync_meta;                     // 应答返回源域时的第一级同步状态
(* ASYNC_REG = "TRUE" *)
reg flag_ack_sync;                          // 源域可安全比较的应答翻转状态
(* ASYNC_REG = "TRUE" *)
reg flag_request_sync_meta;                 // 请求进入目标域时的第一级同步状态
(* ASYNC_REG = "TRUE" *)
reg flag_request_sync;                      // 目标域用于检测新事务的请求翻转状态
reg flag_destination_ack;                   // 目标域已接收最近一笔配置的应答状态
wire flag_source_busy;                      // 请求与同步应答不一致时的源域忙标志

	//---------------其他信号---------------//

	//---------------输出信号---------------//
// 目标域只在检测到新请求时改写配置快照
reg [C_CONFIG_WIDTH - 1:0]destination_config_o; // 系统域已确认的原子配置总线
reg destination_update_o;                   // 系统域新配置接收事件的脉冲寄存器

	//-------------其他信号连线-------------//
	// 忙状态在请求与返回应答一致后立即清除
	assign flag_source_busy = flag_source_request != flag_ack_sync; // 比较当前请求与已同步应答的事务代际

	//-------------输出信号连线-------------//
	// 源域与目标域状态通过明确输出桥提供给上层
	assign o_source_busy = flag_source_busy; // 暴露源域不得覆盖快照的占用状态
	assign o_destination_config = destination_config_o; // 输出经请求应答保护的多比特数据
	assign o_destination_update = destination_update_o; // 输出新配置到达 2 MHz 域的事件

	//-----------输出信号处理区域-----------//
	// 目标域在新请求被确认后产生一拍更新指示
	always@(posedge i_destination_clk or negedge i_destination_rstn)begin
		if(i_destination_rstn == 1'b0)begin
			destination_update_o <= 1'b0;   // 目标域复位期间禁止上报伪更新事件
		end else if(flag_request_sync != flag_destination_ack)begin
			destination_update_o <= 1'b1;   // 仅在首次看到新事务时拉高一个目标时钟
		end else begin
			destination_update_o <= 1'b0;   // 其余周期保持更新输出为低
		end
	end

	// 目标域仅在源数据已稳定两级同步延迟后捕获整条总线
	always@(posedge i_destination_clk or negedge i_destination_rstn)begin
		if(i_destination_rstn == 1'b0)begin
			destination_config_o <= {C_CONFIG_WIDTH{1'b0}}; // 目标域复位时清除已接收配置
		end else if(flag_request_sync != flag_destination_ack)begin
			destination_config_o <= reg_source_config; // 在对应请求到达后原子捕获稳定快照
		end else begin
			destination_config_o <= destination_config_o; // 无新事务时保持上一笔已确认配置
		end
	end

	//-----------主要任务处理区域-----------//
	// 源域仅在桥空闲时接受一个新的多比特配置快照
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_source_config <= {C_CONFIG_WIDTH{1'b0}}; // 源域复位时将稳定配置总线清零
		end else if((i_source_update == 1'b1) && (flag_source_busy == 1'b0))begin
			reg_source_config <= i_source_config; // 在翻转请求前锁存完整寄存器组内容
		end else begin
			reg_source_config <= reg_source_config; // 直到应答返回前保持总线绝对稳定
		end
	end

	// 源域在接受快照的同一时钟边沿翻转请求代际
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			flag_source_request <= 1'b0;    // 将握手请求代际恢复到零相位
		end else if((i_source_update == 1'b1) && (flag_source_busy == 1'b0))begin
			flag_source_request <= ~flag_source_request; // 每个被接受的更新仅产生一次代际翻转
		end else begin
			flag_source_request <= flag_source_request; // 忙期间不重复发起或合并新事务
		end
	end

	// 应答信号返回 SPI_SCLK 域的第一级同步处理
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			flag_ack_sync_meta <= 1'b0;     // 源域复位时清除应答同步链首级
		end else begin
			flag_ack_sync_meta <= flag_destination_ack; // 首级触发器只采样跨域应答电平
		end
	end

	// 应答返回链的第二级为忙状态比较提供稳定输入
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			flag_ack_sync <= 1'b0;          // 源域复位时使请求和应答保持初始一致
		end else begin
			flag_ack_sync <= flag_ack_sync_meta; // 将经一拍稳定的应答传入事务比较器
		end
	end

	// 请求信号进入 2 MHz 域的第一级同步处理
	always@(posedge i_destination_clk or negedge i_destination_rstn)begin
		if(i_destination_rstn == 1'b0)begin
			flag_request_sync_meta <= 1'b0; // 目标域复位时清除请求同步链首级
		end else begin
			flag_request_sync_meta <= flag_source_request; // 首级触发器隔离异步请求的亚稳态风险
		end
	end

	// 请求同步链的第二级为事务检测提供稳定代际
	always@(posedge i_destination_clk or negedge i_destination_rstn)begin
		if(i_destination_rstn == 1'b0)begin
			flag_request_sync <= 1'b0;      // 目标域复位时将请求代际归零
		end else begin
			flag_request_sync <= flag_request_sync_meta; // 向事务检测器提供第二级同步结果
		end
	end

	// 目标域捕获配置后更新应答代际以允许下一笔事务
	always@(posedge i_destination_clk or negedge i_destination_rstn)begin
		if(i_destination_rstn == 1'b0)begin
			flag_destination_ack <= 1'b0;   // 目标域复位时恢复初始应答相位
		end else if(flag_request_sync != flag_destination_ack)begin
			flag_destination_ack <= flag_request_sync; // 用已接收请求代际确认当前配置
		end else begin
			flag_destination_ack <= flag_destination_ack; // 没有新事务时保持应答状态不变
		end
	end

endmodule
