`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/25
// Design Name:        PPG S1 Redundancy Corrector
// Module Name:        ppg_adc_s1_redundancy_corrector
// Description:        Description/ppg_adc_s1_redundancy_corrector_Design.pdf
// Simulations:        TestBench/Vivado/2021.1/ppg_adc_s1_redundancy_corrector
//
// Referrences:        sar_stage1_vout_test Verilog-A monitor,
//                     PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// Dependencies:       ppg_adc_async_stage_capture
//
// Version:            V1.0
// Revision Date:      2026/07/30
// History:
//    Time               Version       Revised by            Contents
// 2026/07/25            V1.0          Erie                  Create file.
// 2026/07/30            V1.0          Erie                  Align context with the explicit ADC transaction.
// 2026/07/30            V1.0          Erie                  Clarify the shared R/IR frame and global precision snapshot contract.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年07月25日
// 设计名称:           PPG第一级冗余重构器
// 模块名称:           ppg_adc_s1_redundancy_corrector
// 模块说明:           Description/ppg_adc_s1_redundancy_corrector_Design.pdf
// 仿真工程:           TestBench/Vivado/2021.1/ppg_adc_s1_redundancy_corrector
//
// 参考资料:           sar_stage1_vout_test Verilog-A监视器、PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// 依赖文件:           ppg_adc_async_stage_capture
//
// 当前版本:           V1.0
// 修订日期:           2026年07月30日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年07月25日        V1.0          Erie                  创建文件
// 2026年07月30日        V1.0          Erie                  按显式ADC事务边界对齐上下文
// 2026年07月30日        V1.0          Erie                  明确R/IR共享帧号和全局精度快照合同
// 2026年08月05日        V1.0          Erie                  保留完整S1物理决策位供片外拟合与后续校准

// 保存顶层已提交的R/IR事务属性并重构S1码，不在本模块产生精度模式切换请求
module ppg_adc_s1_redundancy_corrector
#(
	parameter integer C_FRAME_ID_WIDTH = 16,                            // R/IR共享PPG周期标识的字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 16,                        // 各颜色结果排序所需的样本序号位宽
	parameter integer C_IDAC_CODE_WIDTH = 8,                            // 实际施加AMB/DC码值的快照位宽
	parameter integer C_CODE_EPOCH_WIDTH = 4                            // 安全提交代号用于识别调码前后样本
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，释放由系统顶层同步

	//----------ADC事务上下文输入接口----------//
	input i_adc_transaction_start,             // 与捕获模块共用的单周期ADC事务开始脉冲
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,  // 同一PPG周期的红光与红外事务使用相同标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前颜色结果在输出数据流中的顺序编号
	input i_color_ir,                          // 低为红光、高为红外，只标记颜色而不决定精度
	input [1:0]i_frame_type,                   // 当前事务属于AMB_CAL、DCS_CAL或NORMAL
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // ADC积分期间实际施加的AMB抵消码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 结合颜色解释的本帧DC抵消码快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // AMB码安全提交后递增的版本标识
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前R或IR DC码对应的版本标识

	//----------ADC捕获结果输入接口----------//
	input [9:0]i_capture_stage1_raw,         // 位序固定为vd8至vd3、vdred、vd2至vd0
	input [9:0]i_capture_stage2_raw,         // 与S1同一ADC事务的第二级物理码
	input i_capture_precision_mode,          // 捕获模块锁存的全局已提交9/15-bit模式快照
	input i_capture_valid,                   // 捕获载荷保持有效直到本模块拉高ready

	//----------重构结果接收接口----------//
	input i_detect_ready,                 // 下游允许在当前上升沿接收完整重构事务

	//----------ADC事务控制输出接口----------//
	output o_transaction_ready,              // 高电平允许顶层启动并锁存下一笔ADC事务

	//----------ADC捕获握手输出接口----------//
	output o_capture_ready,                  // 高电平允许捕获模块交付当前RAW载荷

	//----------重构结果输出接口----------//
	output [8:0]o_detect_code,            // 饱和到0至511的S1稳定检测码
	output [9:0]o_stage1_raw,             // 与重构结果同事务的完整S1物理决策位
	output signed [10:0]o_stage1_code_ext, // Verilog-A公式得到的未饱和D1_EXT，范围-4至515
	output [9:0]o_stage2_raw,             // 为后续15-bit链保存的同事务S2物理码
	output o_precision_mode,              // 与结果对齐的全局PPG周期精度模式快照
	output o_detect_valid,                // 全部重构结果及元数据有效并保持至ready

	//----------重构事务元数据输出接口----------//
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id,  // 用于配对同一PPG周期R/IR结果的共享标识
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 随结果返回的样本顺序编号
	output o_color_ir,                          // 指明当前载荷属于红光还是红外光
	output [1:0]o_frame_type,                   // 将校准或正常采样类别送往结果路由器
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 追踪当前ADC结果所使用的AMB码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 追踪本次颜色通道所使用的DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 输出与AMB快照匹配的提交代号
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch // 标识红光或红外直流抵消码的提交版本
);

	//-------------配置参数区域-------------//
	// 元数据采用固定字段位置打包，减少多组上下文寄存器的控制分叉
	localparam integer C_DETECT_CODE_WIDTH = 32'd9; // 黄金比较、范围观察和标称表征使用的固定9-bit码
	localparam [C_DETECT_CODE_WIDTH - 1:0] DETECT_CODE_MAX = 9'h1ff; // 饱和检测码的正向端点511
	localparam integer C_DC_EPOCH_LSB = 32'd0; // 打包上下文中DC代号的起始位置
	localparam integer C_AMB_EPOCH_LSB = C_DC_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB代号位于DC代号之后
	localparam integer C_DC_CODE_LSB = C_AMB_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // DC码快照紧邻两组epoch
	localparam integer C_AMB_CODE_LSB = C_DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB码快照位于DC码之上
	localparam integer C_FRAME_TYPE_LSB = C_AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // 帧类别占据码值字段之后两位
	localparam integer C_COLOR_LSB = C_FRAME_TYPE_LSB + 32'd2; // 颜色标识跟随帧类别字段
	localparam integer C_SAMPLE_INDEX_LSB = C_COLOR_LSB + 32'd1; // 样本编号放在颜色标识之上
	localparam integer C_FRAME_ID_LSB = C_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 帧号占据打包上下文最高段
	localparam integer C_METADATA_WIDTH = C_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 上下文保持寄存器的完整位宽

	//--------------寄存器信号--------------//
	// 单笔上下文缓冲器在ADC转换开始前固定颜色、帧类别和IDAC快照
	reg [C_METADATA_WIDTH - 1:0]reg_context; // 等待与捕获RAW配对的事务上下文

	//---------------标志信号---------------//
	// 两组ready/valid事件分别管理事务上下文、捕获RAW和下游重构结果
	reg flag_context_valid;                 // 指示上下文缓冲器包含尚未配对的事务
	wire flag_context_ready;                // 当前拍允许锁存新ADC事务上下文
	wire flag_context_transfer;             // 顶层在允许条件下真正启动一笔事务
	wire flag_output_buffer_available;      // 输出为空或旧结果将在本拍被消费
	wire flag_capture_transfer;             // 捕获RAW与旧上下文在本拍完成配对
	wire flag_detect_transfer;              // 下游接收当前完整重构事务的事件

	//---------------译码信号---------------//
	// 黄金模型先形成无冗余偏置的基本码，再加入vdred的正负4 LSB贡献
	wire [9:0]dec_base_code;                // vd8至vd3和vd2至vd0形成的0至511基准码
	wire signed [10:0]dec_stage1_code_ext;  // 加入冗余项后的D1_EXT扩展结果
	reg [C_DETECT_CODE_WIDTH - 1:0]dec_detect_code; // 对扩展结果执行边界钳位后的9-bit码

	//---------------其他信号---------------//
	// 实时上下文只在事务握手沿进入保持寄存器，ADC完成时不再读取顶层配置
	wire [C_METADATA_WIDTH - 1:0]metadata_input; // 当前待启动ADC事务的数字上下文集合

	//---------------输出信号---------------//
	// 单元素弹性输出缓存把数据、模式和元数据作为不可拆分的载荷保持
	reg [C_DETECT_CODE_WIDTH - 1:0]detect_code_o; // 反压期间保持稳定的固定黄金饱和码
	reg [9:0]stage1_raw_o;                  // 供逐物理位校准和测试导出的S1原始决策位
	reg signed [10:0]stage1_code_ext_o;     // 供量程诊断和15-bit链使用的D1_EXT
	reg [9:0]stage2_raw_o;                  // 与S1重构结果保持一致事务归属的S2码
	reg precision_mode_o;                   // 保存顶层全局模式在当前颜色事务中的快照
	reg [C_METADATA_WIDTH - 1:0]metadata_o; // 与重构结果同拍保存的完整数字上下文
	reg detect_valid_o;                     // 声明输出缓存拥有一笔未消费重构事务

	//-------------其他信号连线-------------//
	// 下游消费允许在同一拍接纳新捕获载荷，不为连续ADC结果引入空拍
	assign flag_detect_transfer = detect_valid_o && i_detect_ready; // 定义输出ready/valid的唯一消费事件
	assign flag_output_buffer_available = (detect_valid_o == 1'b0) || i_detect_ready; // 判断重构输出缓存是否可写
	assign flag_capture_transfer = i_rstn && i_capture_valid && flag_context_valid && flag_output_buffer_available; // 只接收拥有对应上下文的RAW
	assign flag_context_ready = (flag_context_valid == 1'b0) || flag_capture_transfer; // 允许空闲锁存或同拍替换上下文
	assign flag_context_transfer = i_rstn && i_adc_transaction_start && flag_context_ready; // 接纳由顶层正式启动的新事务

	// 高六个常规位提供8 LSB步进，低三位补充1 LSB分辨率，vdred单独校正
	assign dec_base_code = {1'b0, i_capture_stage1_raw[9:4], 3'b000} +
		{7'b0000000, i_capture_stage1_raw[2:0]}; // 重建不含冗余偏置的基础S1码
	assign dec_stage1_code_ext = $signed({1'b0, dec_base_code}) +
		(i_capture_stage1_raw[3] ? 11'sd4 : -11'sd4); // 精确实现bred乘8后减4的黄金公式

	// 帧号位于最高段，epoch位于最低段，打包顺序与字段位置常量严格对应
	assign metadata_input = {
		i_frame_id,
		i_sample_index,
		i_color_ir,
		i_frame_type,
		i_amb_code_snapshot,
		i_dc_code_snapshot,
		i_amb_code_epoch,
		i_dc_code_epoch
	};                                      // 组合出下一笔ADC事务的待锁存上下文

	//-------------输出信号连线-------------//
	// 握手控制输出直接反映内部单元素上下文和结果缓存的可用状态
	assign o_transaction_ready = i_rstn && flag_context_ready; // 告知帧控制器当前允许发起ADC事务
	assign o_capture_ready = i_rstn && flag_context_valid && flag_output_buffer_available; // 仅在上下文已准备好时接收捕获结果
	assign o_detect_code = detect_code_o;   // 输出已稳定保存的9-bit检测值
	assign o_stage1_raw = stage1_raw_o;     // 输出与检测码同拍锁存的S1物理位
	assign o_stage1_code_ext = stage1_code_ext_o; // 输出未饱和的第一级冗余重构码
	assign o_stage2_raw = stage2_raw_o;     // 将同事务第二级物理码传向精细链路
	assign o_precision_mode = precision_mode_o; // 传递本PPG周期已提交的全局精度快照
	assign o_detect_valid = detect_valid_o; // 声明全部输出字段构成一笔有效载荷
	assign o_dc_code_epoch = metadata_o[C_DC_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解析最低段DC提交代号
	assign o_amb_code_epoch = metadata_o[C_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解析AMB码版本字段
	assign o_dc_code_snapshot = metadata_o[C_DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 还原当前颜色使用的DC码
	assign o_amb_code_snapshot = metadata_o[C_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 还原环境光抵消码快照
	assign o_frame_type = metadata_o[C_FRAME_TYPE_LSB +: 2]; // 解包AMB/DCS/NORMAL类别
	assign o_color_ir = metadata_o[C_COLOR_LSB]; // 解包红光或红外通道标识
	assign o_sample_index = metadata_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 解包ADC样本编号
	assign o_frame_id = metadata_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 解包帧调度器事务编号

	//-----------输出信号处理区域-----------//
	// 输入握手沿保存饱和检测码，反压期间不重新观察捕获总线
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			detect_code_o <= {C_DETECT_CODE_WIDTH{1'b0}}; // 数字复位清除不可用检测值
		end else if(flag_capture_transfer == 1'b1)begin
			detect_code_o <= dec_detect_code; // 锁存本笔S1的稳定9-bit等效码
		end else begin
			detect_code_o <= detect_code_o; // 无新载荷时维持输出缓存内容
		end
	end

	// 完整S1物理决策位与固定重构结果在同一输入握手沿进入缓存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage1_raw_o <= 10'b0000000000; // 复位清除不可用的S1物理决策历史
		end else if(flag_capture_transfer == 1'b1)begin
			stage1_raw_o <= i_capture_stage1_raw; // 保存后续逐物理位校准所需的原子RAW
		end else begin
			stage1_raw_o <= stage1_raw_o;   // 反压期间保持RAW与其余字段严格一致
		end
	end

	// 未饱和D1_EXT与检测码在同一输入握手沿进入结果缓存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage1_code_ext_o <= 11'sd0;    // 复位时扩展码回到确定零值
		end else if(flag_capture_transfer == 1'b1)begin
			stage1_code_ext_o <= dec_stage1_code_ext; // 完整保存-4至515冗余重构结果
		end else begin
			stage1_code_ext_o <= stage1_code_ext_o; // 结果未消费时禁止扩展码变化
		end
	end

	// 透传S2使后续精细链与已经重构的S1继续共享同一事务
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage2_raw_o <= 10'b0000000000; // 复位移除历史第二级物理码
		end else if(flag_capture_transfer == 1'b1)begin
			stage2_raw_o <= i_capture_stage2_raw; // 保存捕获器已经对齐的S2载荷
		end else begin
			stage2_raw_o <= stage2_raw_o;   // 下游阻塞期间保持精细链输入
		end
	end

	// 捕获模块提供的全局模式快照决定当前颜色事务是否携带有效S2
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			precision_mode_o <= 1'b0;       // 复位默认采用9-bit载荷解释
		end else if(flag_capture_transfer == 1'b1)begin
			precision_mode_o <= i_capture_precision_mode; // 原子保存R/IR共同使用的已提交精度
		end else begin
			precision_mode_o <= precision_mode_o; // 防止顶层下次模式变化污染旧结果
		end
	end

	// 捕获RAW只能读取此前已经冻结的上下文，不在ADC完成时采样实时控制总线
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			metadata_o <= {C_METADATA_WIDTH{1'b0}}; // 复位清空输出事务身份信息
		end else if(flag_capture_transfer == 1'b1)begin
			metadata_o <= reg_context;      // 把待配对上下文绑定到当前RAW
		end else begin
			metadata_o <= metadata_o;       // 反压期间维持所有元数据字段
		end
	end

	// 新捕获结果优先于同拍旧结果消费，允许连续事务无气泡替换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			detect_valid_o <= 1'b0;         // 复位后不得报告虚假重构结果
		end else if(flag_capture_transfer == 1'b1)begin
			detect_valid_o <= 1'b1;         // 数据、模式和元数据已经同步写入
		end else if(flag_detect_transfer == 1'b1)begin
			detect_valid_o <= 1'b0;         // 下游消费且无替换输入时释放缓存
		end else begin
			detect_valid_o <= detect_valid_o; // 空闲或阻塞期间保持事务所有权
		end
	end

	//-----------主要任务处理区域-----------//
	// 把Verilog-A允许的-4至515扩展区间钳位到控制链可使用的0至511范围
	always@(*)begin
		if(dec_stage1_code_ext < 11'sd0)begin
			dec_detect_code = {C_DETECT_CODE_WIDTH{1'b0}}; // 负扩展码统一压到9-bit零端点
		end else if(dec_stage1_code_ext > 11'sd511)begin
			dec_detect_code = DETECT_CODE_MAX; // 正过量程码统一限制为511
		end else begin
			dec_detect_code = dec_stage1_code_ext[C_DETECT_CODE_WIDTH - 1:0]; // 正常区间保持黄金模型整数结果
		end
	end

	// 事务握手沿锁存上下文，保证R/IR和IDAC码在ADC完成前切换也不会错配
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_context <= {C_METADATA_WIDTH{1'b0}}; // 复位移除未启动事务的历史上下文
		end else if(flag_context_transfer == 1'b1)begin
			reg_context <= metadata_input;  // 在ADC转换开始边界保存全部数字属性
		end else begin
			reg_context <= reg_context;     // 等待RAW期间禁止上下文漂移
		end
	end

	// 上下文被RAW消费后释放；若同拍启动下一事务则直接装入新上下文
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_context_valid <= 1'b0;     // 复位期间没有等待配对的ADC事务
		end else if(flag_context_transfer == 1'b1)begin
			flag_context_valid <= 1'b1;     // 新上下文已经获得单元素缓冲器所有权
		end else if(flag_capture_transfer == 1'b1)begin
			flag_context_valid <= 1'b0;     // 当前上下文已与捕获RAW成功绑定
		end else begin
			flag_context_valid <= flag_context_valid; // 未发生握手时保持等待状态
		end
	end

endmodule
