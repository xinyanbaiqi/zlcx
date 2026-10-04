`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/07/23
// Design Name:     PPG Reset Synchronizer
// Module Name:     ppg_reset_sync
// Description:     Description/ppg_reset_sync_Design.pdf
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
// 设计名称:        PPG 复位同步器
// 模块名称:        ppg_reset_sync
// 模块说明:        Description/ppg_reset_sync_Design.pdf
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

// 将全局低有效复位转换为指定时钟域的同步释放复位
module ppg_reset_sync
(
	//---------------全局信号---------------//
	input i_clk,                                     // 接收域中用于释放复位的工作时钟
	input i_async_rstn,                              // 允许异步拉低的全局位低有效复位

	//---------------用户接口---------------//
	output o_rstn                                    // 经两级触发器同步释放的域内复位
);

	//--------------寄存器信号--------------//
	// 复位释放链中的两级状态
	reg reg_reset_meta = 1'b0;                      // 第一级采样异步复位的释放状态

	//---------------输出信号---------------//
	// 第二级仅在接收域时钟边沿进入非复位状态
	reg rstn_o = 1'b0;                               // 域内低有效复位的输出寄存器

	//-------------输出信号连线-------------//
	// 将同步释放结果连接到模块端口
	assign o_rstn = rstn_o;                         // 输出异步置低且同步置高的复位

	//-----------输出信号处理区域-----------//
	// 第二级触发器在首级稳定后释放域内复位
	always@(posedge i_clk or negedge i_async_rstn)begin
		if(i_async_rstn == 1'b0)begin
			rstn_o <= 1'b0;                             // 全局复位拉低时立即保持域内复位
		end else begin
			rstn_o <= reg_reset_meta;                   // 仅传递经首级时钟化的释放电平
		end
	end

	//-----------主要任务处理区域-----------//
	// 首级触发器为后级提供一个完整时钟周期的稳定时间
	always@(posedge i_clk or negedge i_async_rstn)begin
		if(i_async_rstn == 1'b0)begin
			reg_reset_meta <= 1'b0;                    // 异步复位期间清除同步链首级
		end else begin
			reg_reset_meta <= 1'b1;                    // 开始向后级传递复位释放请求
		end
	end

endmodule
