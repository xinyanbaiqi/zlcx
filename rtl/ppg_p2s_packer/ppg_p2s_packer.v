`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/09/06
// Design Name:     PPG P2S Fixed-Packet Telemetry Packer
// Module Name:     ppg_p2s_packer
// Description:     Description/ppg_p2s_packer_Design.pdf
// Simulations:     ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// Referrences:     ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md section 8.4
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/09/06
// History:
//     Time          Version     Revised by     Contents
// 2026/09/06        V1.0        Erie          Create file. Fixed 161-bit, 12-field P2S packet packer with a depth-2 result queue, per PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md V1.9 section 8.4. Queue holds the front entry non-destructively in reg_queue_front and reads it out through a variable bit-select index (cnt_tx_bit), avoiding a separate transmit shift register so the design stays at exactly 2x161=322 flip-flops of queue storage, matching section 8.4.4's stated budget. P2S_CLK itself is not generated here -- the parent glue top drives it as a pure CLK_2M passthrough per section 8.4.1, so this module only needs i_clk for its own sequencing.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年09月06日
// 设计名称:        PPG P2S定长包遥测打包器
// 模块名称:        ppg_p2s_packer
// 模块说明:        Description/ppg_p2s_packer_Design.pdf
// 仿真工程:        ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// 参考资料:        ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md第8.4节
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年09月06日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年09月06日   V1.0        Erie          创建文件。按PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md V1.9第8.4节实现固定161-bit、12字段P2S包打包器，内含深度2结果排队。排队队首条目非破坏性保存在reg_queue_front里，用可变位选下标（cnt_tx_bit）直接读出，不额外建立发送移位寄存器，队列存储正好维持2x161=322个触发器，和第8.4.4节给出的预算逐位吻合。P2S_CLK本身不在本模块产生——父级glue顶层按第8.4.1节把它做成CLK_2M纯直连，本模块只需要i_clk驱动自己的时序。

// 12字段固定161-bit结果排入深度2队列，按到达顺序串行外发
module ppg_p2s_packer
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字系统域工作时钟，P2S_CLK由父级直接同源驱动
	input i_rstn,                           // 2 MHz域低有效复位

	//-------------AMI正式结果消费接口-------------//
	input i_result_valid,                          // 保持型正式结果有效，直到本模块回应ready
	output o_result_ready,                         // 队列未满时接受新结果

	//---------------12字段payload输入---------------//
	input [15:0] i_frame_id,                         // 字段1：本笔结果物理帧号
	input [15:0] i_sample_index,                     // 字段2：本笔结果全局序号
	input i_color_ir,                                // 字段3：本笔结果颜色身份
	input [1:0] i_frame_type,                        // 字段4：本笔结果帧类型编码
	input i_result_precision_mode,                   // 字段5：本笔结果精度快照
	input signed [23:0] i_coarse_ppg_value,          // 字段6：DC恢复后粗PPG值
	input i_coarse_valid,                            // 字段6：粗结果有效资格
	input i_coarse_recovery_calibrated,              // 字段6：粗结果正式恢复资格
	input signed [23:0] i_fine_ppg_value,            // 字段7：DC恢复后精细PPG值
	input i_fine_valid,                              // 字段7：精细结果有效资格
	input i_fine_recovery_calibrated,                // 字段7：精细结果正式恢复资格
	input [7:0] i_amb_code_snapshot,                 // 字段8：本笔结果AMB码快照
	input [7:0] i_dc_code_snapshot,                  // 字段8：本笔结果颜色DC码快照
	input [3:0] i_amb_code_epoch,                    // 字段9：本笔结果AMB码版本
	input [3:0] i_dc_code_epoch,                     // 字段9：本笔结果颜色DC码版本
	input signed [11:0] i_calibrated_s1_value,       // 字段10：正式Stage1校准残差
	input signed [14:0] i_programmable_15_code,      // 字段11：正式可编程15-bit残差
	input i_programmable_15_valid,                   // 字段11：可编程精细结果资格
	input i_s1_calibration_applied,                  // 字段12：Stage1校准资格，DC恢复原子载荷重新导出版本
	input [9:0] i_stage1_raw,                        // 字段12：Stage1物理判决位，DC恢复原子载荷重新导出版本
	input [9:0] i_stage2_raw,                        // 字段12：第二级冗余物理判决位，DC恢复原子载荷重新导出版本

	//---------------P2S物理引脚接口---------------//
	output o_p2s_data,                             // 161拍串行数据，MSB-first
	output o_p2s_frame                             // 覆盖整个161拍数据包的帧指示，背靠背包间至少落低1拍
);

	//-------------状态参数区域-------------//
	// 打包器只有排空等待和串行发送两个真实状态
	localparam ST_IDLE = 1'b0;              // 等待队列出现新条目
	localparam ST_SEND = 1'b1;              // 正在串行输出队首161-bit条目

	//---------------计数信号---------------//
	// 排队深度与队首发送进度各自独立计数
	reg [1:0] cnt_queue_depth;              // 当前排队条目数，取值0/1/2
	reg [7:0] cnt_tx_bit;                   // 队首条目已发送的比特下标，0~160
	wire [1:0] cnt_after_pop;               // 扣除本拍出队后的排队条目数，供入队目标槽位判定

	//-------------状态机信号-------------//
	// 三段式FSM的当前态与次态
	reg state_current;                    // 当前拍打包器真实状态
	reg state_next;                       // 下一拍打包器目标状态

	//--------------寄存器信号--------------//
	// 深度2队列固定占用2x161=322个触发器，不额外建立发送移位寄存器
	reg [160:0] reg_queue_front;            // 队首条目，当前正在发送或即将发送
	reg [160:0] reg_queue_tail;             // 队尾条目，等待队首发送完成后前移

	//---------------标志信号---------------//
	// 入队与出队各自独立判定，同一拍可以同时发生
	wire flag_push;                         // 本拍存在被接受的新结果
	wire flag_pop;                          // 本拍队首条目发送完最后一比特
	wire flag_load;                         // 本拍从IDLE进入SEND，需要复位比特计数
	wire flag_queue_not_full;               // 队列未满，允许接受下一笔结果

	//---------------其他信号---------------//
	// 组合拼装的161-bit新条目及两个队列槽位各自的下一拍目标值
	wire [160:0] payload_next;              // 本拍若发生入队，即将写入队列的完整条目，字段顺序即合同8.4.2节表格序号顺序，MSB-first
	wire [160:0] front_next;                // 队首槽位下一拍目标值：二条目出队前移、队首直接补位或保持不变
	wire [160:0] tail_next;                 // 队尾槽位下一拍目标值：新条目排到队尾或保持不变

	//---------------输出信号---------------//
	// 全部端口均由组合assign直接导出，不需要额外的_o输出桥接寄存器

	//-------------其他信号连线-------------//
	// 12个字段按合同顺序从高位到低位拼接成完整161-bit条目
	assign payload_next = {i_frame_id, i_sample_index, i_color_ir, i_frame_type, i_result_precision_mode, i_coarse_ppg_value, i_coarse_valid, i_coarse_recovery_calibrated, i_fine_ppg_value, i_fine_valid, i_fine_recovery_calibrated, i_amb_code_snapshot, i_dc_code_snapshot, i_amb_code_epoch, i_dc_code_epoch, i_calibrated_s1_value, i_programmable_15_code, i_programmable_15_valid, i_s1_calibration_applied, i_stage1_raw, i_stage2_raw}; // 12字段固定拼装，字段12含P2S §8.4.5新增的DC恢复原子载荷透传值

	// 入队仅在队列未满且上游保持有效时发生
	assign flag_push = i_result_valid && flag_queue_not_full; // 握手成立即视为本拍接受一笔新结果
	// 出队发生在队首条目正在发送且已到达最后一比特的那一拍
	assign flag_pop = (state_current == ST_SEND) && (cnt_tx_bit == 8'd160); // 第161拍（下标160）为条目最后一比特
	// 从IDLE进入SEND当且仅当当前已存在排队条目
	assign flag_load = (state_current == ST_IDLE) && (cnt_queue_depth != 2'd0); // 队列非空才发起新的串行发送
	// 队列未满的判据是排队数不等于2
	assign flag_queue_not_full = (cnt_queue_depth != 2'd2); // 深度2队列的唯一满员条件

	// 出队后的等效条目数，用于判定新入队条目应落入哪个槽位
	assign cnt_after_pop = flag_pop ? (cnt_queue_depth - 2'd1) : cnt_queue_depth; // 出队与入队可能同拍发生，先扣减出队再判定入队目标
	// 队首在真实二条目出队时接住原队尾，否则在队首因出队或原本为空而空出时直接接住新条目
	assign front_next = (flag_pop && (cnt_after_pop != 2'd0)) ? reg_queue_tail : ((flag_push && (cnt_after_pop == 2'd0)) ? payload_next : reg_queue_front); // 覆盖二条目出队前移、队首直接补位、无变化三种情形
	// 队尾只在新条目需要排到最后（出队后仍剩一个有效条目）时更新
	assign tail_next = (flag_push && (cnt_after_pop == 2'd1)) ? payload_next : reg_queue_tail; // 队首已占用时新条目落入队尾槽位，其余情形保持不变

	//-------------输出信号连线-------------//
	// 队首条目按当前比特下标做可变位选，非破坏性读出，不需要额外移位寄存器
	assign o_p2s_data = reg_queue_front[9'd160 - {1'b0, cnt_tx_bit}]; // 下标160为MSB，随cnt_tx_bit递增依次输出到LSB
	// 帧指示只在真实发送期间为高，IDLE态天然提供背靠背包间的低电平间隙
	assign o_p2s_frame = (state_current == ST_SEND) ? 1'b1 : 1'b0; // ST_SEND覆盖全部161拍，退出后至少一拍落低
	// 队列未满即可对上游承诺ready
	assign o_result_ready = flag_queue_not_full; // 直接暴露队列占用资格，供AMI结果fork的valid/ready握手

	//-----------状态机区域-----------//
	// 当前态寄存器只在时钟沿更新为上一拍算好的次态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE; // 复位回到排空等待态
		end else begin
			state_current <= state_next; // 每拍无条件锁存组合次态
		end
	end

	// 次态组合逻辑先默认维持当前态，再按状态覆盖真实跳转条件
	always@(*)begin
		state_next = state_current;   // 默认维持当前态，避免遗漏分支产生锁存
		case(state_current)
			ST_IDLE:begin
				if(flag_load)begin
					state_next = ST_SEND; // 队列非空，进入串行发送
				end
			end
			ST_SEND:begin
				if(flag_pop)begin
					state_next = ST_IDLE; // 已发完最后一比特，让出至少一拍间隙
				end
			end
			default:begin
				state_next = ST_IDLE; // 非法态兜底回到安全等待态
			end
		endcase
	end

	//-----------状态任务处理区域-----------//
	// 已发送比特下标只在真实发送期间递增，是唯一直接依据state_current取值分支的时序逻辑
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_tx_bit <= 8'd0;             // 复位清零比特下标
		end else if(flag_load)begin
			cnt_tx_bit <= 8'd0;             // 新条目从第0比特（MSB）开始输出
		end else if(state_current == ST_SEND)begin
			cnt_tx_bit <= cnt_tx_bit + 8'd1; // 每拍推进到下一比特下标
		end else begin
			cnt_tx_bit <= cnt_tx_bit;       // IDLE态无条目在发，保持不变
		end
	end

	//-----------主要任务处理区域-----------//
	// 队首槽位按front_next覆盖出队前移、队首补位与保持三种情形
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_queue_front <= {161{1'b0}}; // 上电复位归零，等待第一笔真实结果入队占用
		end else begin
			reg_queue_front <= front_next;  // 按组合逻辑统一覆盖
		end
	end

	// 队尾槽位只在新条目需要排队等待时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_queue_tail <= {161{1'b0}};  // 深度2队列第二槽位随同归零，尚无第二笔待发送条目
		end else begin
			reg_queue_tail <= tail_next;    // 接住组合逻辑算好的队尾下一拍取值
		end
	end

	// 排队条目数在出队与入队各自独立计入后合并更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_queue_depth <= 2'd0;        // 复位清空队列计数
		end else begin
			cnt_queue_depth <= cnt_after_pop + (flag_push ? 2'd1 : 2'd0); // 先扣出队再加入队，覆盖同拍并发情形
		end
	end

endmodule
