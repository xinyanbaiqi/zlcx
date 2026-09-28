`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/09/06
// Design Name:     PPG Single-Pulse Toggle CDC Synchronizer
// Module Name:     ppg_pulse_cdc_sync
// Description:     Description/ppg_pulse_cdc_sync_Design.pdf
// Simulations:     ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// Referrences:     ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md section 3
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/09/06
// History:
//     Time          Version     Revised by     Contents
// 2026/09/06        V1.0        Erie          Create file. Generic one-shot toggle-based pulse CDC: a source-domain single-cycle pulse flips a toggle flop, a destination-domain two-stage synchronizer observes it, and an edge detector regenerates a clean single destination-domain-cycle pulse. Reused five times by ppg_chip_digital_top for i_start_event/i_stop_event/i_diag_clear_event/i_control_abort_event (which ppg_control_top's own port comments mark "already synchronized", meaning no internal bridge exists for them) and for the SPI read-side capture trigger, avoiding five near-identical inline always-block groups in the same file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年09月06日
// 设计名称:        PPG单脉冲翻转握手CDC同步器
// 模块名称:        ppg_pulse_cdc_sync
// 模块说明:        Description/ppg_pulse_cdc_sync_Design.pdf
// 仿真工程:        ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// 参考资料:        ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md第3节
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年09月06日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年09月06日   V1.0        Erie          创建文件。通用一次性翻转握手脉冲CDC：源域单周期脉冲翻转一个标志触发器，目标域两级同步器观察其电平，边沿检测器在目标域重新生成一个干净的单周期脉冲。供ppg_chip_digital_top复用五次：i_start_event/i_stop_event/i_diag_clear_event/i_control_abort_event（ppg_control_top自己的端口注释标注"已同步"，说明这四个端口内部没有现成桥接）各一次，以及SPI读方向捕获触发一次，避免同一文件里出现五组几乎相同的内联always块。

// 源域单周期脉冲经翻转标志跨时钟域，目标域重新生成单周期脉冲
module ppg_pulse_cdc_sync
(
	//---------------全局信号---------------//
	//-------------源时钟域-------------//
	input i_source_clk,                 // 发起单周期脉冲的源域时钟
	input i_source_rstn,                // 源域低有效复位
	input i_source_pulse,               // 源域单周期触发脉冲

	//---------------用户接口---------------//
	//-------------目标时钟域-------------//
	input i_dest_clk,                     // 接收重生脉冲的目标域时钟
	input i_dest_rstn,                    // 目标域低有效复位
	output o_dest_pulse                   // 目标域单周期重生脉冲
);

	//---------------标志信号---------------//
	// 源域翻转标志与目标域两级同步及历史比较标志
	reg flag_source_toggle;                 // 源域每次触发脉冲翻转一次的代际标志
	(* ASYNC_REG = "TRUE" *)
	reg flag_dest_sync_meta;                // 目标域第一级同步状态，隔离亚稳态
	(* ASYNC_REG = "TRUE" *)
	reg flag_dest_sync_stable;              // 目标域第二级同步状态，供边沿比较
	reg flag_dest_sync_prev;                // 目标域上一拍稳定同步值，用于边沿检测

	//-------------输出信号连线-------------//
	// 稳定同步值与其上一拍不同即为一次真实翻转事件
	assign o_dest_pulse = flag_dest_sync_stable != flag_dest_sync_prev; // 电平翻转当拍即为目标域单周期脉冲

	//-----------主要任务处理区域-----------//
	// 源域每次触发脉冲翻转代际标志，不做忙碌互斥
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			flag_source_toggle <= 1'b0;     // 源域复位归零代际标志
		end else if(i_source_pulse == 1'b1)begin
			flag_source_toggle <= ~flag_source_toggle; // 每次触发脉冲翻转一次
		end else begin
			flag_source_toggle <= flag_source_toggle; // 无触发时保持代际不变
		end
	end

	// 目标域第一级同步只隔离跨域亚稳态风险
	always@(posedge i_dest_clk or negedge i_dest_rstn)begin
		if(i_dest_rstn == 1'b0)begin
			flag_dest_sync_meta <= 1'b0;    // 目标域复位清除同步链首级
		end else begin
			flag_dest_sync_meta <= flag_source_toggle; // 首级触发器只采样跨域电平
		end
	end

	// 目标域第二级同步为边沿检测提供稳定输入
	always@(posedge i_dest_clk or negedge i_dest_rstn)begin
		if(i_dest_rstn == 1'b0)begin
			flag_dest_sync_stable <= 1'b0;  // 目标域复位使稳定值归零
		end else begin
			flag_dest_sync_stable <= flag_dest_sync_meta; // 将经一拍稳定的电平传入边沿比较器
		end
	end

	// 保存上一拍稳定值，供本拍边沿比较使用
	always@(posedge i_dest_clk or negedge i_dest_rstn)begin
		if(i_dest_rstn == 1'b0)begin
			flag_dest_sync_prev <= 1'b0;    // 目标域复位使历史值归零
		end else begin
			flag_dest_sync_prev <= flag_dest_sync_stable; // 每拍推进历史值，供下一拍边沿判断
		end
	end

endmodule
