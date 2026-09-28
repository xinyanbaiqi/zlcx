`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/08
// Design Name:        PPG Coarse Detection FIR Testbench
// Module Name:        tb_ppg_coarse_detection_fir
// Description:        Description/tb_ppg_coarse_detection_fir_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_coarse_detection_fir
//
// Referrences:        PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_coarse_detection_fir.v
//
// Version:            V2.2
// Revision Date:      2026/09/17
// History:
//    Time               Version       Revised by            Contents
// 2026/08/08            V1.0          Erie                  Create file.
// 2026/08/12            V2.0          Erie                  Verify 21-tap cyclic MAC FIR.
// 2026/09/16            V2.1          Erie                  Adapt to RTL V2.1-V2.3: connect the PWI-broadcast i_detection_discard group, i_run_generation, i_sample_valid, the default-off test-injection ports and o_local_empty; FIR-25 STOP/abort and the scoreboard clear now use generation-scoped discard broadcasts, plus a stale-generation negative case; scoreboard only models history for i_sample_valid=1; add FIR-31/32/33 i_sample_valid checks; final verdict also requires an exact PASS count.
// 2026/09/17            V2.2          Erie                  Work-line-D remediation of 4 confirmed test gaps (no RTL change): FIR-01 now resets a genuinely in-flight MAC (not a virgin state) and checks payload/diagnostic freeze plus exact zero counts via hierarchical reference; FIR-12 actually drives i_recheck_busy while histories are non-empty instead of idling; FIR-19 adds a real, assertable protocol-violation report counter per contract:95 instead of a silent check only; FIR-21 replaces the TB-self-comparison payload check and the near-tautological single-consumption check with hierarchical dut.cnt_ir_sample counting. Raise the pass gate to 103.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月08日
// 设计名称:           PPG粗检测FIR自检平台
// 模块名称:           tb_ppg_coarse_detection_fir
// 模块说明:           Description/tb_ppg_coarse_detection_fir_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_coarse_detection_fir
//
// 参考资料:           PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_coarse_detection_fir.v
//
// 当前版本:           V2.2
// 修订日期:           2026年09月17日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月08日        V1.0          Erie                  创建文件
// 2026年08月12日        V2.0          Erie                  覆盖21抽头周期MAC合同
// 2026年09月16日        V2.1          Erie                  适配RTL V2.1-V2.3：连接PWI广播的i_detection_discard组、i_run_generation、i_sample_valid、默认关闭的验证注入口和o_local_empty；FIR-25的STOP/abort与记分板清队列改用代际discard广播并新增陈旧代际反例；记分板只对i_sample_valid=1建模历史；新增FIR-31/32/33的i_sample_valid断言；最终判定同时核对PASS条数
// 2026年09月17日        V2.2          Erie                  工作线D独立复核确认的4处缺测试证据修复（不改RTL）：FIR-01改为在真实在途MAC（非处女态）时复位，并用层次化引用核对载荷/诊断冻结值与精确零计数；FIR-12真实驱动i_recheck_busy且历史非空，不再是空转；FIR-19按合同:95新增可断言的协议违规上报计数器，不再只是静默检查；FIR-21用层次化`dut.cnt_ir_sample`计数取代TB自比恒真式和近乎恒真的析取式。总PASS门限提高到103

// 使用独立64-bit黄金模型逐笔验证FIR-01至FIR-33的数学、时序、双颜色历史、样本资格和生命周期行为
module tb_ppg_coarse_detection_fir
(
);

	//-------------配置参数区域-------------//
	// 测试平台采用合同默认字段宽度和2 MHz处理时钟
	localparam integer C_FRAME_ID_WIDTH = 32'd16; // 中心帧号黄金字段宽度
	localparam integer C_SAMPLE_INDEX_WIDTH = 32'd16; // 中心事务号黄金字段宽度
	localparam integer C_IDAC_CODE_WIDTH = 32'd8; // IDAC码快照黄金字段宽度
	localparam integer C_CODE_EPOCH_WIDTH = 32'd4; // IDAC版本黄金字段宽度
	localparam integer C_CONFIG_EPOCH_WIDTH = 32'd8; // ACTIVE版本黄金字段宽度
	localparam integer C_COEF_EPOCH_WIDTH = 32'd8; // Stage1版本黄金字段宽度
	localparam integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8; // DC恢复版本黄金字段宽度
	localparam integer C_CLOCK_HALF_PERIOD = 32'd250; // 2 MHz时钟半周期为250 ns
	localparam integer C_META_WIDTH = 32'd84; // 中心身份打包总宽度
	localparam integer C_OUTPUT_WIDTH = 32'd113; // 完整输出事务打包总宽度
	localparam integer C_QUEUE_DEPTH = 32'd1024; // 随机回归黄金队列深度
	localparam integer C_PROCESS_MAX_CYCLES = 32'd16; // 周期MAC最大允许延迟
	localparam integer C_RUN_GENERATION_WIDTH = 32'd8; // DUT RUN代际字段宽度
	localparam integer C_SAMPLE_WIDTH = 32'd111; // DUT单点历史打包宽度：24值+3资格诊断+24三版本+1精度+32身份+1颜色+2类型+16码+8码版本
	localparam integer C_HISTORY_WIDTH = C_SAMPLE_WIDTH * 32'd21; // DUT每色21点历史总宽度
	localparam [1:0]DISCARD_REASON_STOP = 2'b00; // AMI私有discard组STOP排空编码
	localparam [1:0]DISCARD_REASON_ABORT = 2'b01; // AMI私有discard组abort撤销编码
	localparam [7:0]RUN_GENERATION_CURRENT = 8'h3C; // 本TB固定的当前RUN代际
	localparam [7:0]RUN_GENERATION_STALE = 8'h3B; // 与当前代际不同的陈旧代际
	localparam integer C_EXPECTED_PASS_COUNT = 32'd103; // V2.0归档94行PASS，加FIR-25陈旧代际1行与FIR-31/32/33各1行；2026-09-17工作线D复核修复FIR-01(+4)/FIR-19(+1)再加5行

	//--------------寄存器信号--------------//
	// 生命周期、输入事务与下游反压由定向测试过程驱动
	reg i_clk;                              // 2 MHz自检工作时钟
	reg i_rstn;                             // DUT低有效异步复位
	reg i_run_enable;                       // NORMAL运行接收许可
	reg i_start_ack_event;                  // 新RUN确认事件
	reg i_detection_discard_event;          // PWI代际清空广播单拍
	reg [1:0]i_detection_discard_reason;    // 清空原因STOP/abort/系统故障编码
	reg i_detection_discard_identity_valid; // 清空触发身份可信标志，本TB使用scope-only清空
	reg i_detection_discard_sample_valid;   // 清空触发事务样本资格快照
	reg [C_FRAME_ID_WIDTH - 1:0]i_detection_discard_frame_id; // 清空触发事务帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_detection_discard_sample_index; // 清空触发事务序号
	reg i_detection_discard_color_ir;       // 清空触发事务颜色
	reg [1:0]i_detection_discard_frame_type; // 清空触发事务类型
	reg i_detection_discard_precision;      // 清空触发事务精度
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_detection_discard_config_epoch; // 清空触发事务ACTIVE版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_detection_discard_coef_epoch; // 清空触发事务Stage1版本
	reg [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_detection_discard_dc_recovery_epoch; // 清空触发事务DC恢复版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_amb_code_epoch; // 清空触发事务AMB码版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_dc_code_epoch; // 清空触发事务DC码版本
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_detection_discard_run_generation; // 清空目标RUN代际
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation; // 当前RUN代际快照激励
	reg i_sample_valid;                     // 独立样本资格激励
	reg i_test_inject_enable;               // 验证注入总使能，本TB保持关闭
	reg i_test_calibration_loss_inject_valid; // calibration-loss注入请求，本TB保持无效
	reg i_recheck_accept_event;             // AMB重检安全接管事件
	reg i_recheck_busy;                     // AMB重检活动状态
	reg i_result_valid;                     // 上游保持型事务valid
	reg signed [23:0]i_coarse_ppg_value;    // signed 24-bit粗PPG输入
	reg i_coarse_valid;                     // 粗结果数值有效资格
	reg i_coarse_recovery_calibrated;       // 正式DC恢复资格
	reg i_stage1_saturation_low;            // Stage1负向饱和注入
	reg i_stage1_saturation_high;           // Stage1正向饱和注入
	reg i_coarse_saturation_low;            // DC恢复负向饱和注入
	reg i_coarse_saturation_high;           // DC恢复正向饱和注入
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // ACTIVE配置版本刺激
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // Stage1系数组版本刺激
	reg [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch; // DC恢复版本刺激
	reg i_precision_mode;                   // 当前9/15-bit身份刺激
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 当前采样帧号刺激
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 当前全局事务号刺激
	reg i_color_ir;                         // 当前红光或红外颜色刺激
	reg [1:0]i_frame_type;                  // NORMAL或非法帧类别刺激
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 当前AMB码快照刺激
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 当前颜色DC码快照刺激
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 当前AMB码版本刺激
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 当前颜色DC码版本刺激
	reg i_result_ready;                     // 下游输出消费许可
	reg [C_OUTPUT_WIDTH - 1:0]reg_held_payload; // 反压期完整载荷参考
	reg [C_META_WIDTH - 1:0]reg_expected_center_meta; // 定向中心身份参考
	reg flag_test_done;                     // 主测试结束标志
	reg flag_case_ok;                       // 多阶段用例的局部比较累积结果
	reg [C_HISTORY_WIDTH - 1:0]reg_red_history_snapshot; // invalid事务前红光完整历史参考
	reg [C_HISTORY_WIDTH - 1:0]reg_ir_history_snapshot; // invalid事务前红外完整历史参考
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_legal_tenth_index; // invalid间隙前第10笔合法样本事务号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_legal_eleventh_index; // invalid间隙后第11笔合法样本事务号

	//---------------计数信号---------------//
	// 模型、队列、周期和测试循环使用独立计数器
	integer cnt_error;                      // 全部真实比较失败总数
	integer cnt_stimulus;                   // 输入身份生成序号
	integer cnt_clock_cycle;                // 2 MHz时钟周期计数
	integer cnt_last_input_cycle;           // 最近一次输入握手周期
	integer cnt_model_red;                  // 红光真实历史样本数
	integer cnt_model_ir;                   // 红外真实历史样本数
	integer cnt_queue_head;                 // 黄金输出队列读指针
	integer cnt_queue_tail;                 // 黄金输出队列写指针
	integer cnt_queue_used;                 // 黄金输出待比较数量
	integer cnt_model_index;                // 黄金历史循环索引
	integer cnt_test_index;                 // 定向测试循环索引
	integer cnt_wait_cycle;                 // 有界等待循环索引
	integer cnt_random_seed;                // 可复现随机刺激种子
	integer cnt_pass;                       // 全部真实比较通过总数
	integer cnt_input_transfer;             // 上游真实握手累计次数
	integer cnt_output_transfer;            // 下游真实握手累计次数
	integer cnt_error_snapshot;             // 定向用例开始前的失败总数快照
	integer cnt_input_snapshot;             // 定向用例开始前的上游握手快照
	integer cnt_output_snapshot;            // 定向用例开始前的下游握手快照
	integer cnt_red_snapshot;               // 单笔发送前的红光真实深度快照
	integer cnt_ir_snapshot;                // FIR-21新增：反压前的红外真实深度快照，替代TB自比
	integer cnt_protocol_violation_report;  // FIR-19新增：自检TB真实上报的上游集成协议错误次数

	//---------------其他信号---------------//
	// DUT输出逐字段连接并重新打包进行原子比较
	wire o_result_ready;                    // DUT输入ready
	wire o_result_valid;                    // DUT输出valid
	wire signed [23:0]o_filtered_ppg_value; // DUT滤波后粗PPG值
	wire o_detection_qualified;             // DUT窗口正式检测资格
	wire o_window_saturation_low;           // DUT窗口负向饱和诊断
	wire o_window_saturation_high;          // DUT窗口正向饱和诊断
	wire o_fir_saturation_low;              // DUT滤波器负端饱和诊断
	wire o_fir_saturation_high;             // DUT滤波器正端饱和诊断
	wire o_history_full_r;                  // DUT红光历史满标志
	wire o_history_full_ir;                 // DUT红外历史满标志
	wire o_fir_idle;                        // DUT安全排空标志
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch; // DUT中心ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch; // DUT中心Stage1版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_dc_recovery_coef_epoch; // DUT中心恢复版本
	wire o_precision_mode;                  // DUT中心精度身份
	wire [C_FRAME_ID_WIDTH - 1:0]o_frame_id; // DUT中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index; // DUT中心事务号
	wire o_color_ir;                        // DUT输出颜色
	wire [1:0]o_frame_type;                 // DUT中心帧类别
	wire [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot; // DUT中心AMB码
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot; // DUT中心DC码
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch; // DUT中心AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch; // DUT中心DC版本
	wire [C_OUTPUT_WIDTH - 1:0]dec_observed_payload; // DUT完整输出观察载荷
	wire o_local_empty;                     // DUT本地排空状态
	wire o_test_calibration_loss_inject_ready; // DUT验证注入ready，参数关闭时恒0

	// 黄金模型使用32-bit样本和64-bit乘加，避免复用DUT中间位宽
	reg signed [31:0]model_red_data [0:20]; // 红光21点黄金历史
	reg signed [31:0]model_ir_data [0:20];  // 红外21点黄金历史
	reg model_red_qualified [0:20];        // 红光逐点资格历史
	reg model_ir_qualified [0:20];         // 红外逐点资格历史
	reg model_red_saturation_low [0:20];   // 红光逐点负向诊断历史
	reg model_ir_saturation_low [0:20];    // 红外逐点负向诊断历史
	reg model_red_saturation_high [0:20];  // 红光逐点正向诊断历史
	reg model_ir_saturation_high [0:20];   // 红外逐点正向诊断历史
	reg [C_META_WIDTH - 1:0]model_red_meta [0:20]; // 红光逐点身份历史
	reg [C_META_WIDTH - 1:0]model_ir_meta [0:20]; // 红外逐点身份历史
	reg [C_OUTPUT_WIDTH - 1:0]model_expected_queue [0:C_QUEUE_DEPTH - 1]; // 完整黄金输出队列
	reg signed [63:0]model_accumulator_work; // 64-bit Q15乘加工作量
	reg signed [63:0]model_rounded_work;    // 64-bit舍入后黄金值
	reg signed [23:0]model_filtered_work;   // 24-bit饱和后黄金值
	reg model_fir_saturation_low_work;      // 黄金FIR负端诊断
	reg model_fir_saturation_high_work;     // 黄金FIR正端诊断
	reg model_sample_qualified_work;        // 当前输入单点资格
	reg model_sample_saturation_low_work;   // 当前输入单点负向诊断
	reg model_sample_saturation_high_work;  // 当前输入单点正向诊断
	reg model_window_qualified_work;        // 当前窗口正式资格
	reg model_window_saturation_low_work;   // 当前窗口负向诊断
	reg model_window_saturation_high_work;  // 当前窗口正向诊断
	reg flag_model_output_generated_work;   // 当前输入是否真实形成21点黄金输出
	reg [C_META_WIDTH - 1:0]model_input_meta_work; // 当前输入身份打包量
	reg [C_META_WIDTH - 1:0]model_center_meta_work; // 当前窗口中心身份
	reg signed [23:0]model_impulse_expected [0:20]; // 单位冲激冻结系数响应
	real model_frequency_real;              // 频率响应实部工作量
	real model_frequency_imag;              // 频率响应虚部工作量
	real model_frequency_magnitude;         // 频率响应归一化幅值
	real model_frequency_angle;             // 频率响应相位角工作量

	//-------------其他信号连线-------------//
	// 输出打包顺序与V2合同完全一致
	assign dec_observed_payload = {
		o_dc_code_epoch,
		o_amb_code_epoch,
		o_dc_code_snapshot,
		o_amb_code_snapshot,
		o_frame_type,
		o_color_ir,
		o_sample_index,
		o_frame_id,
		o_precision_mode,
		o_dc_recovery_coef_epoch,
		o_coef_epoch,
		o_config_epoch,
		o_fir_saturation_high,
		o_fir_saturation_low,
		o_window_saturation_high,
		o_window_saturation_low,
		o_detection_qualified,
		o_filtered_ppg_value
	};                                      // 形成113-bit原子观察载荷

	//------------主要任务处理区域------------//
	// 连续翻转形成2 MHz统一采样时钟
	always begin
		#C_CLOCK_HALF_PERIOD i_clk = ~i_clk;  // 每250 ns翻转时钟电平
	end

	// 周期计数器为MAC延迟和有界反压检查提供参考
	always@(posedge i_clk)begin
		cnt_clock_cycle = cnt_clock_cycle + 1; // 每个上升沿累计一个处理周期
	end

	// 上游握手计数独立于记分板，用于核对invalid事务只消费一次
	always@(posedge i_clk)begin
		if(i_result_valid == 1'b1 && o_result_ready == 1'b1)begin
			cnt_input_transfer = cnt_input_transfer + 1; // 采样沿前的valid与ready同时为1即一次真实接纳
		end
	end

	// 下游握手计数独立于记分板，用于核对合法历史不足时无输出事件
	always@(posedge i_clk)begin
		if(o_result_valid == 1'b1 && i_result_ready == 1'b1)begin
			cnt_output_transfer = cnt_output_transfer + 1; // 采样沿前的输出valid与下游ready同时为1即一次真实消费
		end
	end

	// 黄金模型在真实输入握手时建立期望，在真实输出握手时逐位比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_model_red = 0;                  // 清除红光真实样本数
			cnt_model_ir = 0;                   // 清除红外真实样本数
			cnt_queue_head = 0;                 // 黄金队列读指针归零
			cnt_queue_tail = 0;                 // 黄金队列写指针归零
			cnt_queue_used = 0;                 // 复位期间无待比较输出
			for(cnt_model_index = 0; cnt_model_index < 21; cnt_model_index = cnt_model_index + 1)begin
				model_red_data[cnt_model_index] = 32'sd0; // 清除红光数值历史
				model_ir_data[cnt_model_index] = 32'sd0; // 清除红外数值历史
				model_red_qualified[cnt_model_index] = 1'b0; // 清除红光资格历史
				model_ir_qualified[cnt_model_index] = 1'b0; // 清除红外资格历史
				model_red_saturation_low[cnt_model_index] = 1'b0; // 清除红光低侧历史
				model_ir_saturation_low[cnt_model_index] = 1'b0; // 清除红外低侧历史
				model_red_saturation_high[cnt_model_index] = 1'b0; // 清除红光高侧历史
				model_ir_saturation_high[cnt_model_index] = 1'b0; // 清除红外高侧历史
				model_red_meta[cnt_model_index] = {C_META_WIDTH{1'b0}}; // 清除红光身份历史
				model_ir_meta[cnt_model_index] = {C_META_WIDTH{1'b0}}; // 清除红外身份历史
			end
		end else begin
			if(i_start_ack_event == 1'b1 || (i_detection_discard_event == 1'b1 && i_detection_discard_run_generation == i_run_generation) || (i_recheck_accept_event == 1'b1 && o_fir_idle == 1'b1))begin
				cnt_model_red = 0;                // 生命周期清理撤销红光历史
				cnt_model_ir = 0;                 // 生命周期清理撤销红外历史
				cnt_queue_head = 0;               // 撤销全部旧期望输出
				cnt_queue_tail = 0;               // 下一笔期望从队首写入
				cnt_queue_used = 0;               // 清理后无待比较输出
				for(cnt_model_index = 0; cnt_model_index < 21; cnt_model_index = cnt_model_index + 1)begin
					model_red_data[cnt_model_index] = 32'sd0; // 擦除红光数值历史
					model_ir_data[cnt_model_index] = 32'sd0; // 擦除红外数值历史
					model_red_qualified[cnt_model_index] = 1'b0; // 擦除红光资格历史
					model_ir_qualified[cnt_model_index] = 1'b0; // 擦除红外资格历史
					model_red_saturation_low[cnt_model_index] = 1'b0; // 擦除红光负向历史
					model_ir_saturation_low[cnt_model_index] = 1'b0; // 擦除红外负向历史
					model_red_saturation_high[cnt_model_index] = 1'b0; // 擦除红光正向历史
					model_ir_saturation_high[cnt_model_index] = 1'b0; // 擦除红外正向历史
					model_red_meta[cnt_model_index] = {C_META_WIDTH{1'b0}}; // 擦除红光身份历史
					model_ir_meta[cnt_model_index] = {C_META_WIDTH{1'b0}}; // 擦除红外身份历史
				end
			end else begin
				if(o_result_valid == 1'b1 && i_result_ready == 1'b1)begin
					if(cnt_queue_used == 0)begin
						cnt_error = cnt_error + 1;  // 空队列输出属于伪事务
						$display("[FAIL] unexpected output time=%0t", $time); // 报告无对应黄金结果
					end else if(dec_observed_payload !== model_expected_queue[cnt_queue_head])begin
						cnt_error = cnt_error + 1;  // 任一字段不一致均记录失败
						$display("[FAIL] payload mismatch time=%0t got=%h expected=%h", $time, dec_observed_payload, model_expected_queue[cnt_queue_head]); // 报告完整载荷差异
					end
					if(cnt_queue_used > 0)begin
						cnt_queue_head = (cnt_queue_head + 1) % C_QUEUE_DEPTH; // 消费黄金队首
						cnt_queue_used = cnt_queue_used - 1; // 待比较数量减少一笔
					end
				end

				if(i_result_valid == 1'b1 && o_result_ready == 1'b1 && i_sample_valid == 1'b1 && i_coarse_valid == 1'b1 && i_frame_type == 2'b10)begin
					cnt_last_input_cycle = cnt_clock_cycle; // 记录本笔真实输入握手周期
					flag_model_output_generated_work = 1'b0; // 预热输入默认不形成黄金输出
					model_sample_qualified_work = i_coarse_recovery_calibrated && (i_stage1_saturation_low == 1'b0) && (i_stage1_saturation_high == 1'b0) && (i_coarse_saturation_low == 1'b0) && (i_coarse_saturation_high == 1'b0); // 独立计算单点资格
					model_sample_saturation_low_work = i_stage1_saturation_low || i_coarse_saturation_low; // 合并负向输入诊断
					model_sample_saturation_high_work = i_stage1_saturation_high || i_coarse_saturation_high; // 合并正向输入诊断
					model_input_meta_work = {
						i_dc_code_epoch,
						i_amb_code_epoch,
						i_dc_code_snapshot,
						i_amb_code_snapshot,
						i_frame_type,
						i_color_ir,
						i_sample_index,
						i_frame_id,
						i_precision_mode,
						i_dc_recovery_coef_epoch,
						i_coef_epoch,
						i_config_epoch
					};                              // 打包当前输入身份

					if(i_color_ir == 1'b0)begin
						if(cnt_model_red >= 20)begin
							flag_model_output_generated_work = 1'b1; // 红光旧历史已包含20笔真实样本
							model_accumulator_work = ($signed(i_coarse_ppg_value) * 64'sd164) + (model_red_data[0] * 64'sd231) + (model_red_data[1] * 64'sd409) + (model_red_data[2] * 64'sd704) + (model_red_data[3] * 64'sd1100) + (model_red_data[4] * 64'sd1566) + (model_red_data[5] * 64'sd2056) + (model_red_data[6] * 64'sd2515) + (model_red_data[7] * 64'sd2891) + (model_red_data[8] * 64'sd3136) + (model_red_data[9] * 64'sd3224) + (model_red_data[10] * 64'sd3136) + (model_red_data[11] * 64'sd2891) + (model_red_data[12] * 64'sd2515) + (model_red_data[13] * 64'sd2056) + (model_red_data[14] * 64'sd1566) + (model_red_data[15] * 64'sd1100) + (model_red_data[16] * 64'sd704) + (model_red_data[17] * 64'sd409) + (model_red_data[18] * 64'sd231) + (model_red_data[19] * 64'sd164); // 红光独立21抽头乘加
							model_center_meta_work = model_red_meta[9]; // 红光中心严格取旧tap9
							model_window_qualified_work = model_sample_qualified_work; // 从当前样本开始归约资格
							model_window_saturation_low_work = model_sample_saturation_low_work; // 从当前样本开始归约低侧诊断
							model_window_saturation_high_work = model_sample_saturation_high_work; // 从当前样本开始归约高侧诊断
							for(cnt_model_index = 0; cnt_model_index < 20; cnt_model_index = cnt_model_index + 1)begin
								model_window_qualified_work = model_window_qualified_work && model_red_qualified[cnt_model_index]; // 合并旧20点资格
								model_window_saturation_low_work = model_window_saturation_low_work || model_red_saturation_low[cnt_model_index]; // 合并旧20点负向诊断
								model_window_saturation_high_work = model_window_saturation_high_work || model_red_saturation_high[cnt_model_index]; // 合并旧20点正向诊断
							end
						end

						if(cnt_model_red == 0)begin
							for(cnt_model_index = 0; cnt_model_index < 21; cnt_model_index = cnt_model_index + 1)begin
								model_red_data[cnt_model_index] = $signed(i_coarse_ppg_value); // 首笔红光值预填物理tap
								model_red_qualified[cnt_model_index] = model_sample_qualified_work; // 首笔红光资格预填
								model_red_saturation_low[cnt_model_index] = model_sample_saturation_low_work; // 首笔红光负向属性预填
								model_red_saturation_high[cnt_model_index] = model_sample_saturation_high_work; // 首笔红光正向属性预填
								model_red_meta[cnt_model_index] = model_input_meta_work; // 首笔红光身份预填
							end
						end else begin
							for(cnt_model_index = 20; cnt_model_index > 0; cnt_model_index = cnt_model_index - 1)begin
								model_red_data[cnt_model_index] = model_red_data[cnt_model_index - 1]; // 红光数值向旧方向移动
								model_red_qualified[cnt_model_index] = model_red_qualified[cnt_model_index - 1]; // 红光资格同步移动
								model_red_saturation_low[cnt_model_index] = model_red_saturation_low[cnt_model_index - 1]; // 红光负向属性同步移动
								model_red_saturation_high[cnt_model_index] = model_red_saturation_high[cnt_model_index - 1]; // 红光正向属性同步移动
								model_red_meta[cnt_model_index] = model_red_meta[cnt_model_index - 1]; // 红光身份同步移动
							end
							model_red_data[0] = $signed(i_coarse_ppg_value); // 当前红光值进入tap0
							model_red_qualified[0] = model_sample_qualified_work; // 当前红光资格进入tap0
							model_red_saturation_low[0] = model_sample_saturation_low_work; // 当前红光负向属性进入tap0
							model_red_saturation_high[0] = model_sample_saturation_high_work; // 当前红光正向属性进入tap0
							model_red_meta[0] = model_input_meta_work; // 当前红光身份进入tap0
						end
						if(cnt_model_red < 21)begin
							cnt_model_red = cnt_model_red + 1; // 红光真实样本数饱和到21
						end
					end else begin
						if(cnt_model_ir >= 20)begin
							flag_model_output_generated_work = 1'b1; // 红外旧历史已包含20笔真实样本
							model_accumulator_work = ($signed(i_coarse_ppg_value) * 64'sd164) + (model_ir_data[0] * 64'sd231) + (model_ir_data[1] * 64'sd409) + (model_ir_data[2] * 64'sd704) + (model_ir_data[3] * 64'sd1100) + (model_ir_data[4] * 64'sd1566) + (model_ir_data[5] * 64'sd2056) + (model_ir_data[6] * 64'sd2515) + (model_ir_data[7] * 64'sd2891) + (model_ir_data[8] * 64'sd3136) + (model_ir_data[9] * 64'sd3224) + (model_ir_data[10] * 64'sd3136) + (model_ir_data[11] * 64'sd2891) + (model_ir_data[12] * 64'sd2515) + (model_ir_data[13] * 64'sd2056) + (model_ir_data[14] * 64'sd1566) + (model_ir_data[15] * 64'sd1100) + (model_ir_data[16] * 64'sd704) + (model_ir_data[17] * 64'sd409) + (model_ir_data[18] * 64'sd231) + (model_ir_data[19] * 64'sd164); // 红外独立21抽头乘加
							model_center_meta_work = model_ir_meta[9]; // 红外中心严格取旧tap9
							model_window_qualified_work = model_sample_qualified_work; // 从当前红外样本开始归约资格
							model_window_saturation_low_work = model_sample_saturation_low_work; // 从当前红外样本开始归约低侧诊断
							model_window_saturation_high_work = model_sample_saturation_high_work; // 从当前红外样本开始归约高侧诊断
							for(cnt_model_index = 0; cnt_model_index < 20; cnt_model_index = cnt_model_index + 1)begin
								model_window_qualified_work = model_window_qualified_work && model_ir_qualified[cnt_model_index]; // 合并旧20点资格
								model_window_saturation_low_work = model_window_saturation_low_work || model_ir_saturation_low[cnt_model_index]; // 合并旧20点负向诊断
								model_window_saturation_high_work = model_window_saturation_high_work || model_ir_saturation_high[cnt_model_index]; // 合并旧20点正向诊断
							end
						end

						if(cnt_model_ir == 0)begin
							for(cnt_model_index = 0; cnt_model_index < 21; cnt_model_index = cnt_model_index + 1)begin
								model_ir_data[cnt_model_index] = $signed(i_coarse_ppg_value); // 首笔红外值预填物理tap
								model_ir_qualified[cnt_model_index] = model_sample_qualified_work; // 首笔红外资格预填
								model_ir_saturation_low[cnt_model_index] = model_sample_saturation_low_work; // 首笔红外负向属性预填
								model_ir_saturation_high[cnt_model_index] = model_sample_saturation_high_work; // 首笔红外正向属性预填
								model_ir_meta[cnt_model_index] = model_input_meta_work; // 首笔红外身份预填
							end
						end else begin
							for(cnt_model_index = 20; cnt_model_index > 0; cnt_model_index = cnt_model_index - 1)begin
								model_ir_data[cnt_model_index] = model_ir_data[cnt_model_index - 1]; // 红外数值向旧方向移动
								model_ir_qualified[cnt_model_index] = model_ir_qualified[cnt_model_index - 1]; // 红外资格同步移动
								model_ir_saturation_low[cnt_model_index] = model_ir_saturation_low[cnt_model_index - 1]; // 红外负向属性同步移动
								model_ir_saturation_high[cnt_model_index] = model_ir_saturation_high[cnt_model_index - 1]; // 红外正向属性同步移动
								model_ir_meta[cnt_model_index] = model_ir_meta[cnt_model_index - 1]; // 红外身份同步移动
							end
							model_ir_data[0] = $signed(i_coarse_ppg_value); // 当前红外值进入tap0
							model_ir_qualified[0] = model_sample_qualified_work; // 当前红外资格进入tap0
							model_ir_saturation_low[0] = model_sample_saturation_low_work; // 当前红外负向属性进入tap0
							model_ir_saturation_high[0] = model_sample_saturation_high_work; // 当前红外正向属性进入tap0
							model_ir_meta[0] = model_input_meta_work; // 当前红外身份进入tap0
						end
						if(cnt_model_ir < 21)begin
							cnt_model_ir = cnt_model_ir + 1; // 红外真实样本数饱和到21
						end
					end

					if(flag_model_output_generated_work == 1'b1)begin
						if(model_accumulator_work >= 0)begin
							model_rounded_work = (model_accumulator_work + 64'sd16384) >>> 15; // 正值按半LSB远离零舍入
						end else begin
							model_rounded_work = -(((-model_accumulator_work) + 64'sd16384) >>> 15); // 负值按幅值对称舍入
						end
						model_fir_saturation_low_work = model_rounded_work < -64'sd8388608; // 黄金负端饱和判断
						model_fir_saturation_high_work = model_rounded_work > 64'sd8388607; // 黄金正端饱和判断
						if(model_fir_saturation_low_work == 1'b1)begin
							model_filtered_work = 24'sh800000; // 黄金值钳位负端点
						end else if(model_fir_saturation_high_work == 1'b1)begin
							model_filtered_work = 24'sh7fffff; // 黄金值钳位正端点
						end else begin
							model_filtered_work = model_rounded_work[23:0]; // 合法范围保留低24位
						end
						model_expected_queue[cnt_queue_tail] = {model_center_meta_work, model_fir_saturation_high_work, model_fir_saturation_low_work, model_window_saturation_high_work, model_window_saturation_low_work, model_window_qualified_work, model_filtered_work}; // 原子写入黄金输出
						cnt_queue_tail = (cnt_queue_tail + 1) % C_QUEUE_DEPTH; // 推进黄金队列写指针
						cnt_queue_used = cnt_queue_used + 1; // 新增一笔待比较结果
					end
				end
			end
		end
	end

	// 将一笔数值及互异身份字段放到输入总线
	task load_sample_fields;
		input signed [23:0]sample_value;      // 当前粗PPG测试值
		input sample_color_ir;                // 当前颜色身份
		input sample_precision_mode;          // 当前精度身份
		input sample_calibrated;              // 当前正式恢复资格
		input sample_saturation_low;          // 当前负向诊断注入
		input sample_saturation_high;         // 当前正向诊断注入
		input [1:0]sample_frame_type;         // 当前事务帧类别
		input [3:0]sample_dc_epoch;           // 当前颜色DC版本
		begin
			cnt_stimulus = cnt_stimulus + 1;  // 为本笔事务生成互异身份
			i_coarse_ppg_value = sample_value; // 驱动signed 24-bit输入
			i_coarse_valid = 1'b1;            // 默认提供可计算粗数值
			i_coarse_recovery_calibrated = sample_calibrated; // 驱动正式恢复资格
			i_stage1_saturation_low = sample_saturation_low; // 使用Stage1注入负向诊断
			i_stage1_saturation_high = 1'b0;  // 默认Stage1正向无饱和
			i_coarse_saturation_low = 1'b0;   // 默认恢复结果负向无饱和
			i_coarse_saturation_high = sample_saturation_high; // 使用恢复级注入正向诊断
			i_config_epoch = cnt_stimulus[7:0]; // ACTIVE版本跟随刺激序号
			i_coef_epoch = cnt_stimulus[7:0] + 8'h40; // Stage1版本采用不同图样
			i_dc_recovery_coef_epoch = cnt_stimulus[7:0] + 8'h80; // 恢复版本采用第三种图样
			i_precision_mode = sample_precision_mode; // 绑定本笔精度身份
			i_frame_id = cnt_stimulus[15:0]; // 帧号保存输入顺序
			i_sample_index = cnt_stimulus[15:0] + 16'h1000; // 样本号与帧号保持可区分
			i_color_ir = sample_color_ir;    // 选择独立颜色历史
			i_frame_type = sample_frame_type; // 驱动NORMAL或非法类别
			i_amb_code_snapshot = 8'h20 + cnt_stimulus[2:0]; // 生成变化AMB码快照
			i_dc_code_snapshot = 8'h40 + sample_dc_epoch; // DC码随版本变化
			i_amb_code_epoch = cnt_stimulus[3:0]; // AMB版本按模16变化
			i_dc_code_epoch = sample_dc_epoch; // 驱动调用者指定DC版本
		end
	endtask

	// 按保持型ready/valid协议发送唯一一笔事务
	task send_sample;
		input signed [23:0]sample_value;      // 待发送粗PPG值
		input sample_color_ir;                // 待发送颜色身份
		input sample_precision_mode;          // 待发送精度身份
		input sample_calibrated;              // 待发送正式资格
		input sample_saturation_low;          // 待发送负向诊断
		input sample_saturation_high;         // 待发送正向诊断
		input [1:0]sample_frame_type;         // 待发送帧类别
		input [3:0]sample_dc_epoch;           // 待发送DC版本
		begin
			@(negedge i_clk);                 // 非采样沿准备完整载荷
			load_sample_fields(sample_value, sample_color_ir, sample_precision_mode, sample_calibrated, sample_saturation_low, sample_saturation_high, sample_frame_type, sample_dc_epoch); // 原子加载输入字段
			i_result_valid = 1'b1;            // valid保持到唯一握手
			while(o_result_ready !== 1'b1)begin
				@(negedge i_clk);               // 反压期间禁止覆盖载荷
			end
			@(posedge i_clk);                 // 当前上升沿完成输入握手
			#1;                               // 避开DUT非阻塞更新区
			@(negedge i_clk);                 // 下一非采样沿撤销valid
			i_result_valid = 1'b0;            // 防止同一事务重复消费
		end
	endtask

	// 等待当前计算结果首次建立valid并返回等待周期数
	task wait_result_valid;
		output integer wait_cycles;           // 从任务进入到valid可见的周期数
		begin
			wait_cycles = 0;                   // 初始化等待周期
			while(o_result_valid !== 1'b1 && wait_cycles < 40)begin
				@(negedge i_clk);               // 在稳定半周期观察valid
				wait_cycles = wait_cycles + 1;  // 累计实际等待时间
			end
		end
	endtask

	// 消费当前输出并等待DUT返回无valid状态
	task drain_output;
		begin
			i_result_ready = 1'b1;             // 允许消费任何保持输出
			if(o_result_valid == 1'b1)begin
				@(posedge i_clk);               // 当前沿完成输出握手
				#1;                             // 等待valid清除生效
				@(negedge i_clk);               // 在稳定半周期继续测试
			end
		end
	endtask

	// 等待MAC和输出缓冲均排空
	task wait_fir_idle;
		begin
			cnt_wait_cycle = 0;                // 初始化排空等待计数
			while(o_fir_idle !== 1'b1 && cnt_wait_cycle < 80)begin
				@(negedge i_clk);               // 观察DUT安全排空状态
				cnt_wait_cycle = cnt_wait_cycle + 1; // 防止异常永久等待
			end
		end
	endtask

	// 统一执行真实布尔比较并累计失败
	task check_condition;
		input condition;                      // 实际比较结果
		input [8 * 96 - 1:0]case_name;        // 可检索用例名称
		begin
			if(condition !== 1'b1)begin
				cnt_error = cnt_error + 1;      // 失败路径累计错误
				$display("[FAIL] %0s time=%0t", case_name, $time); // 报告失败用例
			end else begin
				cnt_pass = cnt_pass + 1;        // 通过路径累计真实PASS条数
				$display("[PASS] %0s", case_name); // 仅真实条件成立时报告通过
			end
		end
	endtask

	// 复位DUT并恢复默认NORMAL运行接口
	task apply_reset;
		begin
			@(negedge i_clk);                 // 在下降沿进入异步复位
			i_rstn = 1'b0;                    // 清除DUT全部状态
			i_result_valid = 1'b0;            // 复位期间无上游事务
			i_result_ready = 1'b1;            // 默认下游持续接收
			i_run_enable = 1'b0;              // 复位期间关闭RUN
			i_start_ack_event = 1'b0;         // 清除START事件
			i_detection_discard_event = 1'b0; // 清除代际discard事件
			i_sample_valid = 1'b1;            // 默认样本资格有效
			i_recheck_accept_event = 1'b0;    // 清除重检accept
			i_recheck_busy = 1'b0;            // 清除重检busy
			repeat(3)@(posedge i_clk);         // 保持足够复位时钟边沿
			#1;                               // 等待异步复位传播
			@(negedge i_clk);                 // 在非采样沿释放复位
			i_rstn = 1'b1;                    // 恢复正常时序运行
			i_run_enable = 1'b1;              // 允许NORMAL事务
			repeat(2)@(posedge i_clk);         // 等待接口进入确定状态
			#1;                               // 观察复位后输出
		end
	endtask

	// 产生一个时钟宽度的生命周期控制事件
	task pulse_control_event;
		input [1:0]event_select;              // 00为START、01为STOP discard、10为abort discard、11为recheck
		begin
			@(negedge i_clk);                 // 非采样沿建立事件
			case(event_select)
				2'b00:begin
					i_start_ack_event = 1'b1;   // 触发新RUN清理
				end
				2'b01:begin
					i_detection_discard_event = 1'b1; // 触发当前代际STOP discard清理
					i_detection_discard_reason = DISCARD_REASON_STOP; // STOP排空原因
					i_detection_discard_run_generation = RUN_GENERATION_CURRENT; // 命中当前代际
				end
				2'b10:begin
					i_detection_discard_event = 1'b1; // 触发当前代际abort discard撤销
					i_detection_discard_reason = DISCARD_REASON_ABORT; // abort撤销原因
					i_detection_discard_run_generation = RUN_GENERATION_CURRENT; // 命中当前代际
				end
				default:begin
					i_recheck_accept_event = 1'b1; // 请求AMB重检接管
				end
			endcase
			@(posedge i_clk);                 // 当前沿提交控制事件
			#1;                               // 等待DUT清理状态
			@(negedge i_clk);                 // 下一非采样沿撤销事件
			i_start_ack_event = 1'b0;         // 恢复START低电平
			i_detection_discard_event = 1'b0; // 恢复discard低电平
			i_detection_discard_reason = DISCARD_REASON_STOP; // 恢复默认原因编码
			i_detection_discard_run_generation = 8'd0; // 恢复默认目标代际
			i_recheck_accept_event = 1'b0;    // 恢复recheck低电平
		end
	endtask

	// 向单一颜色发送指定数量的常量NORMAL样本
	task send_constant_samples;
		input integer sample_count;           // 需要发送的真实样本数量
		input signed [23:0]sample_value;      // 每笔常量粗PPG值
		input sample_color_ir;                // 目标颜色历史
		input sample_precision_mode;          // 目标精度身份
		begin
			for(cnt_test_index = 0; cnt_test_index < sample_count; cnt_test_index = cnt_test_index + 1)begin
				send_sample(sample_value, sample_color_ir, sample_precision_mode, 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 发送合法常量事务
			end
		end
	endtask

	// 由冻结Q15系数直接计算指定频率的归一化幅值
	task check_frequency_response;
		input integer frequency_hz;           // 需要检查的物理频率
		input real magnitude_min;              // 合同允许的最小线性幅值
		input real magnitude_max;              // 合同允许的最大线性幅值
		input [8 * 96 - 1:0]case_name;        // 频率检查名称
		begin
			model_frequency_real = 0.0;         // 初始化频响实部
			model_frequency_imag = 0.0;         // 初始化频响虚部
			for(cnt_model_index = 0; cnt_model_index < 21; cnt_model_index = cnt_model_index + 1)begin
				model_frequency_angle = 6.283185307179586 * frequency_hz * cnt_model_index / 400.0; // 计算离散角频率相位
				model_frequency_real = model_frequency_real + model_impulse_expected[cnt_model_index] * $cos(model_frequency_angle); // 累加频响实部
				model_frequency_imag = model_frequency_imag - model_impulse_expected[cnt_model_index] * $sin(model_frequency_angle); // 累加频响虚部
			end
			model_frequency_magnitude = $sqrt((model_frequency_real * model_frequency_real) + (model_frequency_imag * model_frequency_imag)) / 32768.0; // 得到归一化线性幅值
			check_condition((model_frequency_magnitude >= magnitude_min) && (model_frequency_magnitude <= magnitude_max), case_name); // 比较冻结频响门限
		end
	endtask

	//-------------初始化与测试区域-------------//
	// 主测试逐项覆盖V2合同FIR-01至FIR-33
	initial begin
		i_clk = 1'b0;                        // 初始化2 MHz时钟低电平
		i_rstn = 1'b0;                       // 启动时保持复位
		i_run_enable = 1'b0;                 // 启动时关闭RUN
		i_start_ack_event = 1'b0;            // 初始化START事件
		i_detection_discard_event = 1'b0;    // 初始化代际discard事件
		i_detection_discard_reason = DISCARD_REASON_STOP; // 初始化discard原因
		i_detection_discard_identity_valid = 1'b0; // scope-only清空不携带触发身份
		i_detection_discard_sample_valid = 1'b0; // 身份无效时样本资格为0
		i_detection_discard_frame_id = 16'd0; // 身份无效时帧号为0
		i_detection_discard_sample_index = 16'd0; // 身份无效时事务号为0
		i_detection_discard_color_ir = 1'b0; // 身份无效时颜色为0
		i_detection_discard_frame_type = 2'b00; // 身份无效时类别为0
		i_detection_discard_precision = 1'b0; // 身份无效时精度为0
		i_detection_discard_config_epoch = 8'd0; // 身份无效时ACTIVE版本为0
		i_detection_discard_coef_epoch = 8'd0; // 身份无效时Stage1版本为0
		i_detection_discard_dc_recovery_epoch = 8'd0; // 身份无效时DC恢复版本为0
		i_detection_discard_amb_code_epoch = 4'd0; // 身份无效时AMB码版本为0
		i_detection_discard_dc_code_epoch = 4'd0; // 身份无效时DC码版本为0
		i_detection_discard_run_generation = 8'd0; // 初始化清空目标代际
		i_run_generation = RUN_GENERATION_CURRENT; // 固定当前RUN代际
		i_sample_valid = 1'b1;               // 初始化样本资格有效
		i_test_inject_enable = 1'b0;         // 验证注入保持关闭
		i_test_calibration_loss_inject_valid = 1'b0; // 不发出注入请求
		cnt_pass = 0;                        // 清除通过统计
		cnt_protocol_violation_report = 0;   // 清除协议违规上报统计
		cnt_input_transfer = 0;              // 清除上游握手统计
		cnt_output_transfer = 0;             // 清除下游握手统计
		i_recheck_accept_event = 1'b0;       // 初始化重检accept
		i_recheck_busy = 1'b0;               // 初始化重检busy
		i_result_valid = 1'b0;               // 初始化上游valid
		i_coarse_ppg_value = 24'sd0;         // 初始化粗PPG值
		i_coarse_valid = 1'b0;               // 初始化粗值资格
		i_coarse_recovery_calibrated = 1'b0; // 初始化恢复资格
		i_stage1_saturation_low = 1'b0;      // 初始化Stage1负向诊断
		i_stage1_saturation_high = 1'b0;     // 初始化Stage1正向诊断
		i_coarse_saturation_low = 1'b0;      // 初始化恢复负向诊断
		i_coarse_saturation_high = 1'b0;     // 初始化恢复正向诊断
		i_config_epoch = 8'd0;               // 初始化ACTIVE版本
		i_coef_epoch = 8'd0;                 // 初始化Stage1版本
		i_dc_recovery_coef_epoch = 8'd0;     // 初始化恢复版本
		i_precision_mode = 1'b0;             // 初始化9-bit身份
		i_frame_id = 16'd0;                  // 初始化帧号
		i_sample_index = 16'd0;              // 初始化事务号
		i_color_ir = 1'b0;                   // 初始化红光颜色
		i_frame_type = 2'b10;                // 初始化NORMAL类别
		i_amb_code_snapshot = 8'd0;          // 初始化AMB码
		i_dc_code_snapshot = 8'd0;           // 初始化DC码
		i_amb_code_epoch = 4'd0;             // 初始化AMB版本
		i_dc_code_epoch = 4'd0;              // 初始化DC版本
		i_result_ready = 1'b1;               // 默认下游持续接收
		cnt_error = 0;                       // 清除错误统计
		cnt_stimulus = 0;                    // 清除刺激身份序号
		cnt_clock_cycle = 0;                 // 清除处理周期计数
		cnt_last_input_cycle = 0;            // 清除最近输入周期
		cnt_random_seed = 32'h13579bdf;      // 固定随机回归种子
		flag_test_done = 1'b0;               // 保持watchdog活动

		model_impulse_expected[0] = 24'sd164; // 冻结第0抽头系数
		model_impulse_expected[1] = 24'sd231; // 冻结第1抽头系数
		model_impulse_expected[2] = 24'sd409; // 冻结第2抽头系数
		model_impulse_expected[3] = 24'sd704; // 冻结第3抽头系数
		model_impulse_expected[4] = 24'sd1100; // 冻结第4抽头系数
		model_impulse_expected[5] = 24'sd1566; // 冻结第5抽头系数
		model_impulse_expected[6] = 24'sd2056; // 冻结第6抽头系数
		model_impulse_expected[7] = 24'sd2515; // 冻结第7抽头系数
		model_impulse_expected[8] = 24'sd2891; // 冻结第8抽头系数
		model_impulse_expected[9] = 24'sd3136; // 冻结第9抽头系数
		model_impulse_expected[10] = 24'sd3224; // 冻结中心抽头系数
		model_impulse_expected[11] = 24'sd3136; // 冻结第11抽头系数
		model_impulse_expected[12] = 24'sd2891; // 冻结第12抽头系数
		model_impulse_expected[13] = 24'sd2515; // 冻结第13抽头系数
		model_impulse_expected[14] = 24'sd2056; // 冻结第14抽头系数
		model_impulse_expected[15] = 24'sd1566; // 冻结第15抽头系数
		model_impulse_expected[16] = 24'sd1100; // 冻结第16抽头系数
		model_impulse_expected[17] = 24'sd704; // 冻结第17抽头系数
		model_impulse_expected[18] = 24'sd409; // 冻结第18抽头系数
		model_impulse_expected[19] = 24'sd231; // 冻结第19抽头系数
		model_impulse_expected[20] = 24'sd164; // 冻结第20抽头系数

		apply_reset;                          // 建立FIR-01复位基线
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0 && o_history_full_ir == 1'b0 && o_fir_idle == 1'b1, "FIR-01 asynchronous reset"); // 检查复位后确定状态
		check_condition((o_filtered_ppg_value == 24'sd0) && (o_detection_qualified == 1'b0) && (o_window_saturation_low == 1'b0) && (o_window_saturation_high == 1'b0) && (o_fir_saturation_low == 1'b0) && (o_fir_saturation_high == 1'b0) && (o_config_epoch == 0) && (o_coef_epoch == 0) && (o_dc_recovery_coef_epoch == 0) && (o_frame_id == 0) && (o_sample_index == 0) && (o_color_ir == 1'b0), "FIR-01 payload and diagnostics freeze to reset value"); // 载荷与诊断端口逐项核对冻结复位值
		check_condition((dut.cnt_red_sample == 5'd0) && (dut.cnt_ir_sample == 5'd0), "FIR-01 sample counts exactly zero after reset"); // 层次化引用精确核对计数为0而不只是小于21

		send_constant_samples(20, 24'sd8400, 1'b0, 1'b0); // 建立FIR-01撤销MAC测试窗口
		send_sample(24'sd8400, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动真实在途MAC
		repeat(4)@(posedge i_clk);             // 进入中间乘加阶段
		check_condition(dut.state_current == 2'b01, "FIR-01 MAC genuinely in flight before reset"); // 确认复位前MAC真的在途，不是处女态
		apply_reset;                          // 在真实在途MAC期间撤销，而不是处女态复位
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0 && o_history_full_ir == 1'b0 && o_fir_idle == 1'b1 && (dut.cnt_red_sample == 5'd0) && (dut.cnt_ir_sample == 5'd0) && (dut.state_current == 2'b00), "FIR-01 reset cancels genuinely in-flight MAC"); // 真正撤销在途MAC，不只是"无物可撤"的复位

		send_constant_samples(20, 24'sd12345, 1'b0, 1'b0); // 红光前20笔仅预热
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0, "FIR-02 first twenty samples"); // 不得提前产生输出
		send_sample(24'sd12345, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd4); // 第21笔启动首次MAC
		wait_result_valid(cnt_wait_cycle);     // 等待首次输出可见
		check_condition(o_result_valid == 1'b1 && o_history_full_r == 1'b1 && (cnt_clock_cycle - cnt_last_input_cycle) <= C_PROCESS_MAX_CYCLES, "FIR-03 twenty-first sample and latency"); // 检查满窗和16周期上限
		check_condition(o_filtered_ppg_value == 24'sd12345, "FIR-04 unity DC gain"); // 常量窗口输出严格等于输入
		drain_output;                          // 消费常量输出

		apply_reset;                          // 隔离单位冲激响应
		send_constant_samples(20, 24'sd0, 1'b0, 1'b0); // 建立全零20点旧历史
		for(cnt_test_index = 0; cnt_test_index < 21; cnt_test_index = cnt_test_index + 1)begin
			if(cnt_test_index == 0)begin
				send_sample(24'sd32768, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 第一个输出注入Q15单位冲激
			end else begin
				send_sample(24'sd0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 后续零样本移动冲激
			end
			wait_result_valid(cnt_wait_cycle);   // 等待当前冲激抽头输出
			check_condition(o_filtered_ppg_value == model_impulse_expected[cnt_test_index], "FIR-05 impulse coefficient response"); // 比较冻结Q15系数
			drain_output;                        // 消费当前抽头响应
		end

		apply_reset;                          // 构造正半LSB精确累加值
		send_constant_samples(19, 24'sd0, 1'b0, 1'b0); // 保持其余19个位置为零
		send_sample(24'sd12, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 形成231乘12项
		send_sample(24'sd83, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 形成164乘83并使总和为16384
		wait_result_valid(cnt_wait_cycle);     // 等待正半LSB输出
		check_condition(o_filtered_ppg_value == 24'sd1, "FIR-06 positive half LSB away from zero"); // 正tie必须舍入为正1
		drain_output;                          // 消费正舍入结果
		apply_reset;                          // 构造负半LSB精确累加值
		send_constant_samples(19, 24'sd0, 1'b0, 1'b0); // 保持其余19个位置为零
		send_sample(-24'sd12, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 形成负231乘12项
		send_sample(-24'sd83, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 使总和严格为负16384
		wait_result_valid(cnt_wait_cycle);     // 等待负半LSB输出
		check_condition(o_filtered_ppg_value == -24'sd1, "FIR-06 negative half LSB away from zero"); // 负tie必须舍入为负1
		drain_output;                          // 消费负舍入结果

		apply_reset;                          // 检查signed 24-bit正端点
		send_constant_samples(21, 24'sh7fffff, 1'b0, 1'b0); // 全窗口驱动最大正数
		wait_result_valid(cnt_wait_cycle);     // 等待正端点结果
		check_condition(o_filtered_ppg_value == 24'sh7fffff && o_fir_saturation_high == 1'b0, "FIR-07 positive signed endpoint"); // 直流单位增益不得回绕
		drain_output;                          // 消费正端点结果
		apply_reset;                          // 检查signed 24-bit负端点
		send_constant_samples(21, 24'sh800000, 1'b0, 1'b0); // 全窗口驱动最负数
		wait_result_valid(cnt_wait_cycle);     // 等待负端点结果
		check_condition(o_filtered_ppg_value == 24'sh800000 && o_fir_saturation_low == 1'b0, "FIR-07 negative signed endpoint"); // 最负数不得绝对值回绕
		drain_output;                          // 消费负端点结果

		apply_reset;                          // 建立两色交错历史场景
		for(cnt_test_index = 0; cnt_test_index < 21; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd1000 + cnt_test_index, 1'b0, cnt_test_index[0], 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 发送红光斜坡和交错精度
			if(cnt_test_index == 20)begin
				wait_result_valid(cnt_wait_cycle); // 等待红光首次输出
				drain_output;                    // 消费红光首次输出
			end
			send_sample(-24'sd2000 - cnt_test_index, 1'b1, ~cnt_test_index[0], 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 发送红外负斜坡
			if(cnt_test_index == 20)begin
				wait_result_valid(cnt_wait_cycle); // 等待红外首次输出
			end
		end
		check_condition(o_history_full_r == 1'b1 && o_history_full_ir == 1'b1 && o_color_ir == 1'b1, "FIR-08 independent dual-color histories"); // 检查双历史与红外身份
		reg_expected_center_meta = model_ir_meta[10]; // 此时移位后tap10保存刚才输出的中心输入
		check_condition(o_frame_id == reg_expected_center_meta[40:25] && o_sample_index == reg_expected_center_meta[56:41], "FIR-09 center metadata x[n-10]"); // 检查中心帧号和事务号
		check_condition(o_precision_mode == 1'b1, "FIR-10 precision metadata follows center"); // 第11笔红外精度由交错图样确定为1
		drain_output;                          // 消费红外首次输出

		send_constant_samples(3, 24'sd3000, 1'b0, 1'b0); // 模拟15到9普通切换后的连续样本
		wait_result_valid(cnt_wait_cycle);     // 等待连续历史输出
		check_condition(o_history_full_r == 1'b1, "FIR-11 precision return keeps history"); // 普通切换不得重新预热
		drain_output;                          // 排空连续历史结果
		i_recheck_busy = 1'b1;                 // 真实驱动"接管等待"投影（合同:483），此时历史仍非空
		repeat(8)@(posedge i_clk);             // 观察busy期间历史是否被意外改变
		check_condition(o_history_full_r == 1'b1 && o_history_full_ir == 1'b1, "FIR-12 pending alone keeps histories"); // pending无accept不得清理
		i_recheck_busy = 1'b0;                 // 撤销busy，避免影响后续FIR-13场景

		wait_fir_idle;                         // 确保安全接管条件成立
		pulse_control_event(2'b11);            // 接受周期重检
		check_condition(o_history_full_r == 1'b0 && o_history_full_ir == 1'b0 && o_result_valid == 1'b0, "FIR-13 recheck accept clears both histories"); // 两色历史同步失效
		i_recheck_busy = 1'b1;                // 进入三帧重检活动期
		repeat(6)begin
			@(posedge i_clk);                   // 观察重检活动期间接口
			#1;                                 // 等待组合ready稳定
			check_condition(o_result_ready == 1'b0 && o_result_valid == 1'b0, "FIR-14 recheck busy blocks FIR traffic"); // 不输入0且不产生输出
		end
		i_recheck_busy = 1'b0;                // 重检结束恢复NORMAL
		send_constant_samples(20, 24'sd4000, 1'b0, 1'b0); // 重建红光前20笔
		check_condition(o_history_full_r == 1'b0 && o_result_valid == 1'b0, "FIR-15 rewarm first twenty samples"); // 不得提前恢复资格
		send_sample(24'sd4000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 重检后第21笔
		wait_result_valid(cnt_wait_cycle);     // 等待重新预热输出
		check_condition(o_history_full_r == 1'b1 && o_filtered_ppg_value == 24'sd4000, "FIR-15 rewarm twenty-first sample"); // 第21笔恢复正式数学输出
		drain_output;                          // 消费重预热输出

		for(cnt_test_index = 0; cnt_test_index < 4; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd4100 + cnt_test_index, 1'b0, cnt_test_index[0], 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 模拟DC码版本逐笔变化
			wait_result_valid(cnt_wait_cycle);   // 等待每笔连续输出
			drain_output;                        // 消费每笔结果
		end
		check_condition(o_history_full_r == 1'b1, "FIR-16 slow DC tracking keeps history"); // 慢速调码不得清历史

		apply_reset;                          // 隔离未校准窗口资格测试
		send_constant_samples(20, 24'sd5000, 1'b0, 1'b0); // 前20笔保持正式资格
		send_sample(24'sd5000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b10, 4'd0); // 第21笔注入未校准样本
		wait_result_valid(cnt_wait_cycle);     // 等待无资格窗口输出
		check_condition(o_result_valid == 1'b1 && o_detection_qualified == 1'b0, "FIR-17 uncalibrated sample keeps value but clears qualification"); // 数值仍输出但资格为0
		drain_output;                          // 消费无资格结果
		apply_reset;                          // 隔离窗口饱和归约测试
		send_constant_samples(20, 24'sd6000, 1'b0, 1'b0); // 前20笔无饱和
		send_sample(24'sd6000, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 2'b10, 4'd0); // 第21笔注入负向饱和属性
		wait_result_valid(cnt_wait_cycle);     // 等待窗口诊断输出
		check_condition(o_window_saturation_low == 1'b1 && o_detection_qualified == 1'b0, "FIR-18 saturation OR and qualification"); // 饱和OR与资格必须一致
		drain_output;                          // 消费饱和诊断结果

		apply_reset;                          // 隔离非NORMAL过滤测试
		send_constant_samples(20, 24'sd7000, 1'b0, 1'b0); // 建立20笔合法NORMAL样本
		send_sample(24'sd9999, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 4'd0); // 注入不应移动历史的AMB_CAL事务
		if(i_frame_type != 2'b10)begin
			cnt_protocol_violation_report = cnt_protocol_violation_report + 1; // 依据真实驱动的i_frame_type上报一次上游集成协议错误
			$display("[PROTOCOL_ERROR] FIR-19 non-NORMAL frame_type=%0d observed on upstream interface at time=%0t (contract:95 upstream integration violation)", i_frame_type, $time); // 合同:95明文要求自检TB必须报告该错误
		end
		check_condition(o_history_full_r == 1'b0 && o_result_valid == 1'b0, "FIR-19 non-NORMAL input ignored"); // 非NORMAL不得贡献历史深度
		check_condition(cnt_protocol_violation_report == 1, "FIR-19 self-checking TB reports the integration protocol error"); // 合同:95"自检TB必须报告该错误"从打印升级为可断言对象
		send_sample(24'sd7000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 第21笔合法NORMAL样本
		wait_result_valid(cnt_wait_cycle);     // 等待过滤后的首次输出
		drain_output;                          // 消费协议过滤结果

		i_result_ready = 1'b0;                // 建立下游反压
		send_sample(24'sd7100, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动受阻输出计算
		wait_result_valid(cnt_wait_cycle);     // 等待输出valid建立
		reg_held_payload = dec_observed_payload; // 保存完整受阻载荷
		repeat(5)begin
			@(posedge i_clk);                   // 保持五拍下游反压
			#1;                                 // 等待输出寄存器稳定
			check_condition(o_result_valid == 1'b1 && dec_observed_payload === reg_held_payload, "FIR-20 held output payload stable"); // 全部字段逐拍保持
		end

		@(negedge i_clk);                     // 在MAC空闲但输出受阻时准备下一笔上游事务
		load_sample_fields(24'sd7200, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd1); // 准备红外载荷用于有界反压
		i_result_valid = 1'b1;                // 上游必须保持valid和载荷
		cnt_ir_snapshot = dut.cnt_ir_sample;   // 记录反压前DUT内部真实红外深度，取代TB拿自己变量跟自己比
		repeat(4)begin
			@(posedge i_clk);                   // 输出缓冲受阻期间输入ready必须为0
			#1;                                 // 观察接口稳定状态
			check_condition(o_result_ready == 1'b0 && (dut.cnt_ir_sample == cnt_ir_snapshot), "FIR-21 bounded input backpressure"); // busy期间DUT真的未提前消费这笔输入（层次化计数核对，非TB自比恒真式）
		end
		i_result_ready = 1'b1;                // 释放旧输出
		while(o_result_ready !== 1'b1)begin
			@(negedge i_clk);                   // 等待输出消费后的输入许可
		end
		@(posedge i_clk);                     // 只消费一次保持的红外事务
		#1;                                   // 等待握手状态更新
		@(negedge i_clk);                     // 撤销上游valid
		i_result_valid = 1'b0;                // 防止重复消费
		check_condition(dut.cnt_ir_sample == cnt_ir_snapshot + 1, "FIR-21 input resumes exactly once"); // 精确计数恰好消费一次，取代近乎恒真的析取式

		apply_reset;                          // 隔离MAC项序列检查
		send_constant_samples(20, 24'sd8000, 1'b0, 1'b0); // 建立完整旧历史
		send_sample(24'sd8000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动11次周期MAC
		for(cnt_test_index = 0; cnt_test_index < 11; cnt_test_index = cnt_test_index + 1)begin
			check_condition(dut.state_current == 2'b01 && dut.cnt_mac_index == cnt_test_index[3:0], "FIR-22 sequential MAC index"); // 检查0至10逐项推进
			@(posedge i_clk);                   // 推进当前乘加项
			#1;                                 // 等待项号寄存器更新
			@(negedge i_clk);                   // 在稳定半周期检查下一项
		end
		check_condition(dut.state_current == 2'b10, "FIR-22 commit follows eleven products"); // 十一项后进入提交阶段
		wait_result_valid(cnt_wait_cycle);     // 等待提交结果建立valid
		check_condition((cnt_clock_cycle - cnt_last_input_cycle) <= C_PROCESS_MAX_CYCLES, "FIR-23 maximum sixteen-cycle processing"); // 检查端到端处理上限
		check_condition(o_fir_idle == 1'b0, "FIR-24 pending output is not idle"); // 输出未消费时不得宣称idle
		drain_output;                          // 消费MAC序列结果
		wait_fir_idle;                         // 等待完全排空
		check_condition(o_fir_idle == 1'b1, "FIR-24 fully drained idle"); // MAC和输出均空时idle为1

		apply_reset;                          // START在MAC中撤销测试
		send_constant_samples(20, 24'sd8100, 1'b0, 1'b0); // 建立START测试窗口
		send_sample(24'sd8100, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动在途MAC
		repeat(3)@(posedge i_clk);             // 进入中间乘加阶段
		pulse_control_event(2'b00);            // 在MAC中触发START清理
		repeat(20)@(posedge i_clk);            // 等待可能的迟到输出窗口
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0, "FIR-25 START cancels in-flight MAC"); // START不得留下迟到输出
		apply_reset;                          // STOP在MAC中撤销测试
		send_constant_samples(20, 24'sd8200, 1'b0, 1'b0); // 建立STOP测试窗口
		send_sample(24'sd8200, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动STOP在途MAC
		repeat(5)@(posedge i_clk);             // 进入更后乘加阶段
		pulse_control_event(2'b01);            // 在MAC中触发STOP清理
		repeat(20)@(posedge i_clk);            // 等待迟到输出观察窗口
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0, "FIR-25 STOP discard cancels in-flight MAC"); // STOP discard不得提交部分和
		apply_reset;                          // abort在MAC中撤销测试
		send_constant_samples(20, 24'sd8300, 1'b0, 1'b0); // 建立abort测试窗口
		send_sample(24'sd8300, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动abort在途MAC
		repeat(7)@(posedge i_clk);             // 进入靠后乘加阶段
		pulse_control_event(2'b10);            // 在MAC中触发abort清理
		repeat(20)@(posedge i_clk);            // 等待迟到输出观察窗口
		check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0, "FIR-25 abort discard cancels in-flight MAC"); // abort discard不得生成迟到事务
		apply_reset;                          // 陈旧代际discard不得撤销当前代际MAC
		send_constant_samples(20, 24'sd8250, 1'b0, 1'b0); // 建立陈旧代际测试窗口
		send_sample(24'sd8250, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动当前代际在途MAC
		repeat(4)@(posedge i_clk);             // 进入中间乘加阶段
		@(negedge i_clk);                     // 非采样沿建立陈旧代际事件
		i_detection_discard_event = 1'b1;     // 广播discard事件
		i_detection_discard_reason = DISCARD_REASON_ABORT; // 原因编码不改变代际比较
		i_detection_discard_run_generation = RUN_GENERATION_STALE; // 目标代际与当前代际不符
		@(posedge i_clk);                     // DUT必须忽略陈旧代际
		#1;                                   // 等待可能的错误清理生效
		@(negedge i_clk);                     // 撤销陈旧事件
		i_detection_discard_event = 1'b0;     // 恢复事件低电平
		i_detection_discard_run_generation = 8'd0; // 恢复默认目标代际
		wait_result_valid(cnt_wait_cycle);     // 等待未被撤销的MAC提交
		check_condition(o_result_valid == 1'b1 && o_history_full_r == 1'b1 && o_filtered_ppg_value == 24'sd8250, "FIR-25 stale-generation discard keeps in-flight MAC"); // 陈旧代际不得清理当前事务和历史
		drain_output;                          // 消费当前代际结果

		apply_reset;                          // 建立重检排空保护测试
		send_constant_samples(21, 24'sd8400, 1'b0, 1'b0); // 建立一笔即将受阻的输出
		i_result_ready = 1'b0;                // 在结果出现前阻塞下游
		wait_result_valid(cnt_wait_cycle);     // 等待保持型输出
		reg_held_payload = dec_observed_payload; // 保存危险重检前的完整输出载荷
		@(negedge i_clk);                     // 非采样沿提出危险重检accept
		i_recheck_accept_event = 1'b1;        // 故意违反idle前置条件
		@(posedge i_clk);                     // DUT必须忽略危险接管
		#1;                                   // 观察输出仍被保持
		@(negedge i_clk);                     // 撤销危险事件
		i_recheck_accept_event = 1'b0;        // 恢复正常生命周期输入
		check_condition(o_result_valid == 1'b1 && dec_observed_payload === reg_held_payload, "FIR-26 unsafe recheck cannot revoke output"); // 受阻结果必须仍有效
		i_result_ready = 1'b1;                // 释放保持输出
		drain_output;                          // 完成输出握手
		wait_fir_idle;                         // 等待安全接管条件
		pulse_control_event(2'b11);            // 空闲后接受重检
		check_condition(o_history_full_r == 1'b0 && o_history_full_ir == 1'b0, "FIR-26 safe recheck takeover"); // 安全接管清除两色状态

		apply_reset;                          // 随机双颜色极值回归从空历史开始
		for(cnt_test_index = 0; cnt_test_index < 160; cnt_test_index = cnt_test_index + 1)begin
			send_sample($random(cnt_random_seed), cnt_test_index[0], cnt_test_index[1], 1'b1, cnt_test_index[4] && cnt_test_index[2], cnt_test_index[5] && cnt_test_index[3], 2'b10, cnt_test_index[3:0]); // 发送可复现随机signed值与诊断
			if(o_result_valid == 1'b1)begin
				drain_output;                    // 保持队列及时消费
			end
		end
		wait_fir_idle;                         // 排空最后一笔随机结果
		check_condition(cnt_queue_used == 0 && cnt_error == 0, "FIR-27 dual-color random wide-model regression"); // 独立64-bit模型逐笔一致

		check_frequency_response(5, 0.9440, 1.0001, "FIR-28 five-Hz response"); // 5 Hz衰减不得超过约0.5 dB
		check_frequency_response(10, 0.8200, 0.8400, "FIR-28 ten-Hz response"); // 10 Hz幅值约对应1.6 dB衰减
		check_frequency_response(20, 0.0000, 0.4740, "FIR-28 twenty-Hz attenuation"); // 20 Hz衰减至少约6.5 dB
		check_frequency_response(50, 0.0000, 0.0030, "FIR-28 fifty-Hz attenuation"); // 50 Hz保持约51.8 dB阻带衰减

		apply_reset;                          // 建立中心精度固定群延时测试
		send_constant_samples(21, 24'sd9000, 1'b0, 1'b0); // 预热全9-bit红光窗口
		wait_result_valid(cnt_wait_cycle);     // 等待9-bit中心输出
		drain_output;                          // 消费基准输出
		for(cnt_test_index = 0; cnt_test_index < 10; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd9000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 连续输入前10笔15-bit身份
			wait_result_valid(cnt_wait_cycle);   // 等待对应窗口输出
			check_condition(o_precision_mode == 1'b0, "FIR-29 precision change delayed by center history"); // 前10笔输出中心仍是旧9-bit样本
			drain_output;                        // 消费当前延迟输出
		end
		send_sample(24'sd9000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 第11笔15-bit身份使中心切换
		wait_result_valid(cnt_wait_cycle);     // 等待中心身份切换输出
		check_condition(o_precision_mode == 1'b1 && o_history_full_r == 1'b1, "FIR-29 center precision changes without clearing history"); // 精度只在10样本延迟后可见
		drain_output;                          // 消费中心精度输出

		apply_reset;                          // 建立计算超时故障注入测试
		send_constant_samples(20, 24'sd9100, 1'b0, 1'b0); // 建立完整旧窗口
		send_sample(24'sd9100, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 启动待故障注入MAC
		force dut.cnt_mac_index = 4'd0;       // 故意阻止MAC项号前进以触发保护
		repeat(18)@(posedge i_clk);            // 超过16周期保护边界
		release dut.cnt_mac_index;             // 释放层次化故障注入
		repeat(3)@(posedge i_clk);             // 等待DUT回到稳定空闲
		check_condition(o_result_valid == 1'b0 && dut.state_current == 2'b00 && o_history_full_r == 1'b1, "FIR-30 timeout cancels partial result without clearing history"); // 超时仅撤销计算并保留历史

		apply_reset;                          // 隔离独立invalid事务测试
		send_constant_samples(20, 24'sd500, 1'b0, 1'b0); // 红光建立20笔合法历史
		send_constant_samples(20, -24'sd600, 1'b1, 1'b0); // 红外建立20笔合法历史
		reg_red_history_snapshot = dut.reg_red_history; // 保存invalid前红光完整历史
		reg_ir_history_snapshot = dut.reg_ir_history; // 保存invalid前红外完整历史
		cnt_input_snapshot = cnt_input_transfer; // 保存invalid前上游握手次数
		cnt_output_snapshot = cnt_output_transfer; // 保存invalid前下游握手次数
		i_sample_valid = 1'b0;                // 下两笔事务独立样本资格无效
		send_sample(24'sd7777, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 若误入历史将成为红光第21笔并启动MAC
		send_sample(-24'sd7777, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 若误入历史将成为红外第21笔并启动MAC
		i_sample_valid = 1'b1;                // 恢复合法样本资格
		repeat(20)@(posedge i_clk);            // 覆盖任何可能的迟到MAC与输出
		#1;                                   // 观察寄存器稳定值
		check_condition((cnt_input_transfer - cnt_input_snapshot) == 2 && (cnt_output_transfer == cnt_output_snapshot) && (dut.reg_red_history === reg_red_history_snapshot) && (dut.reg_ir_history === reg_ir_history_snapshot) && dut.cnt_red_sample == 5'd20 && dut.cnt_ir_sample == 5'd20 && o_history_full_r == 1'b0 && o_history_full_ir == 1'b0 && dut.state_current == 2'b00 && o_result_valid == 1'b0 && o_fir_idle == 1'b1, "FIR-31 invalid transaction consumed once without history MAC or output"); // invalid事务只握手一次且全部检测状态保持

		apply_reset;                          // 隔离资格正交性测试
		flag_case_ok = 1'b1;                  // 累积每笔样本的历史推进比较
		cnt_error_snapshot = cnt_error;       // 保存记分板基线失败数
		for(cnt_test_index = 0; cnt_test_index < 21; cnt_test_index = cnt_test_index + 1)begin
			cnt_red_snapshot = dut.cnt_red_sample; // 保存本笔之前的红光真实深度
			case(cnt_test_index)
				0:begin
					send_sample(24'sd0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // RAW零值样本
				end
				1:begin
					send_sample(24'sh800000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd1); // RAW最低码样本
				end
				2:begin
					send_sample(24'sh7fffff, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd2); // RAW最高码样本
				end
				3:begin
					send_sample(24'sd300, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b10, 4'd3); // calibration无效样本
				end
				4:begin
					send_sample(24'sd400, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 2'b10, 4'd4); // 负向饱和样本
				end
				5:begin
					send_sample(24'sd500, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 2'b10, 4'd5); // 正向饱和样本
				end
				6:begin
					send_sample(24'sd600, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 2'b10, 4'd6); // 未校准且双向饱和组合
				end
				default:begin
					send_sample(24'sd1000 + cnt_test_index, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 普通合法样本补齐窗口
				end
			endcase
			flag_case_ok = flag_case_ok && (dut.cnt_red_sample == cnt_red_snapshot + 1) && (dut.reg_red_history[23:0] == i_coarse_ppg_value); // sample_valid=1事务无论资格组合都真实移入tap0
		end
		wait_result_valid(cnt_wait_cycle);     // 等待含非合格样本窗口的输出
		flag_case_ok = flag_case_ok && (o_result_valid == 1'b1) && (o_detection_qualified == 1'b0) && (o_window_saturation_low == 1'b1) && (o_window_saturation_high == 1'b1) && (o_history_full_r == 1'b1); // 资格和饱和只影响窗口诊断不影响历史推进
		drain_output;                          // 消费并由记分板逐位比较输出
		wait_fir_idle;                         // 等待完全排空
		check_condition(flag_case_ok && (cnt_error == cnt_error_snapshot), "FIR-32 qualification orthogonal to sample_valid"); // 未校准和饱和组合不得冒充invalid

		apply_reset;                          // 隔离invalid后恢复测试
		flag_case_ok = 1'b1;                  // 累积恢复阶段逐项比较
		cnt_error_snapshot = cnt_error;       // 保存记分板基线失败数
		cnt_output_snapshot = cnt_output_transfer; // 保存恢复前下游握手次数
		for(cnt_test_index = 0; cnt_test_index < 10; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd1000 + (cnt_test_index * 16), 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 合法斜坡前10笔
		end
		reg_legal_tenth_index = i_sample_index; // 记录第10笔合法样本事务号
		i_sample_valid = 1'b0;                // 插入3笔invalid同色事务
		for(cnt_test_index = 0; cnt_test_index < 3; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd0); // 若被插入历史将以0破坏斜坡
		end
		i_sample_valid = 1'b1;                // 恢复合法样本资格
		flag_case_ok = flag_case_ok && (dut.cnt_red_sample == 5'd10); // invalid事务不占历史位置
		for(cnt_test_index = 10; cnt_test_index < 20; cnt_test_index = cnt_test_index + 1)begin
			send_sample(24'sd1000 + (cnt_test_index * 16), 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, cnt_test_index[3:0]); // 合法斜坡第11至20笔
			if(cnt_test_index == 10)begin
				reg_legal_eleventh_index = i_sample_index; // 记录第11笔合法样本事务号
			end
		end
		flag_case_ok = flag_case_ok && (dut.cnt_red_sample == 5'd20) && (o_history_full_r == 1'b0) && (o_result_valid == 1'b0) && (cnt_output_transfer == cnt_output_snapshot); // 21笔合法历史前无输出事件
		send_sample(24'sd1320, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 4'd4); // 第21笔合法样本
		wait_result_valid(cnt_wait_cycle);     // 等待首个合法窗口输出
		flag_case_ok = flag_case_ok && (o_result_valid == 1'b1) && (o_detection_qualified == 1'b1) && (o_sample_index == reg_legal_eleventh_index) && ((reg_legal_eleventh_index - reg_legal_tenth_index) == 16'd4) && (o_filtered_ppg_value == 24'sd1160); // 对称单位增益FIR对线性斜坡输出中心值，插0会破坏该等式
		drain_output;                          // 消费并由记分板逐位比较输出
		wait_fir_idle;                         // 等待完全排空
		check_condition(flag_case_ok && (cnt_error == cnt_error_snapshot), "FIR-33 invalid gap keeps legal history continuity"); // invalid不插0不复制且身份保持原始间隙

		flag_test_done = 1'b1;                // 关闭watchdog并汇总结果
		if(cnt_error == 0 && cnt_pass == C_EXPECTED_PASS_COUNT)begin
			$display("PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=%0d", cnt_pass); // 全部真实比较通过且条数完整时报告PASS
		end else begin
			$display("PPG_COARSE_DETECTION_FIR_V2_TB_FAIL errors=%0d pass=%0d expected_pass=%0d", cnt_error, cnt_pass, C_EXPECTED_PASS_COUNT); // 报告累计失败数与PASS条数差异
		end
		$finish;                              // 结束自检仿真
	end

	// 独立watchdog防止握手或FSM异常导致仿真永久挂起
	initial begin
		#50000000;                            // 允许完整定向与随机回归执行
		if(flag_test_done == 1'b0)begin
			$display("PPG_COARSE_DETECTION_FIR_V2_TB_TIMEOUT"); // 报告测试未正常结束
			$finish;                            // 超时后强制终止仿真
		end
	end

	//------------模块例化区域------------//
	// 例化V2粗检测FIR并连接全部数值、诊断和中心元数据端口
	ppg_coarse_detection_fir
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 绑定16-bit中心帧号
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 绑定16-bit中心事务号
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 绑定8-bit IDAC码
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 绑定4-bit码版本
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 绑定8-bit ACTIVE版本
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 绑定8-bit Stage1版本
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // 绑定8-bit恢复版本
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH), // 绑定8-bit RUN代际
		.C_ENABLE_TEST_INJECTION(32'd0)       // 验证注入结构保持生产默认关闭
	)dut(
		.i_clk(i_clk),                       // 连接2 MHz时钟
		.i_rstn(i_rstn),                     // 连接低有效异步复位
		.i_run_enable(i_run_enable),         // 连接RUN资格
		.i_start_ack_event(i_start_ack_event), // 连接START事件
		.i_detection_discard_event(i_detection_discard_event), // 连接代际discard事件
		.i_detection_discard_reason(i_detection_discard_reason), // 连接discard原因
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 连接触发身份有效性
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 连接触发样本资格
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 连接触发帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 连接触发事务号
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 连接触发颜色
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 连接触发类别
		.i_detection_discard_precision(i_detection_discard_precision), // 连接触发精度
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 连接触发ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 连接触发Stage1版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 连接触发DC恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 连接触发AMB码版本
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 连接触发DC码版本
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 连接清空目标代际
		.i_run_generation(i_run_generation), // 连接当前RUN代际
		.o_local_empty(o_local_empty),       // 观察本地排空状态
		.i_recheck_accept_event(i_recheck_accept_event), // 连接重检accept
		.i_recheck_busy(i_recheck_busy),     // 连接重检busy
		.i_result_valid(i_result_valid),     // 连接上游valid
		.o_result_ready(o_result_ready),     // 观察上游ready
		.i_sample_valid(i_sample_valid),     // 连接独立样本资格
		.i_coarse_ppg_value(i_coarse_ppg_value), // 连接signed 24-bit粗值
		.i_coarse_valid(i_coarse_valid),     // 连接粗值资格
		.i_coarse_recovery_calibrated(i_coarse_recovery_calibrated), // 连接正式恢复资格
		.i_stage1_saturation_low(i_stage1_saturation_low), // 连接Stage1低侧诊断
		.i_stage1_saturation_high(i_stage1_saturation_high), // 连接Stage1高侧诊断
		.i_coarse_saturation_low(i_coarse_saturation_low), // 连接恢复低侧诊断
		.i_coarse_saturation_high(i_coarse_saturation_high), // 连接恢复高侧诊断
		.i_config_epoch(i_config_epoch),     // 连接ACTIVE版本
		.i_coef_epoch(i_coef_epoch),         // 连接Stage1版本
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch), // 连接恢复版本
		.i_precision_mode(i_precision_mode), // 连接精度身份
		.i_frame_id(i_frame_id),             // 连接帧号
		.i_sample_index(i_sample_index),     // 连接事务号
		.i_color_ir(i_color_ir),             // 连接颜色身份
		.i_frame_type(i_frame_type),         // 连接帧类别
		.i_amb_code_snapshot(i_amb_code_snapshot), // 连接AMB码快照
		.i_dc_code_snapshot(i_dc_code_snapshot), // 连接DC码快照
		.i_amb_code_epoch(i_amb_code_epoch), // 连接AMB版本
		.i_dc_code_epoch(i_dc_code_epoch),   // 连接DC版本
		.i_test_inject_enable(i_test_inject_enable), // 连接验证注入总使能
		.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid), // 连接注入请求
		.o_test_calibration_loss_inject_ready(o_test_calibration_loss_inject_ready), // 观察注入ready
		.i_result_ready(i_result_ready),     // 连接下游ready
		.o_result_valid(o_result_valid),     // 观察输出valid
		.o_filtered_ppg_value(o_filtered_ppg_value), // 观察滤波值
		.o_detection_qualified(o_detection_qualified), // 观察正式资格
		.o_window_saturation_low(o_window_saturation_low), // 观察窗口低侧诊断
		.o_window_saturation_high(o_window_saturation_high), // 观察窗口高侧诊断
		.o_fir_saturation_low(o_fir_saturation_low), // 观察FIR低端诊断
		.o_fir_saturation_high(o_fir_saturation_high), // 观察FIR高端诊断
		.o_history_full_r(o_history_full_r), // 观察红光满窗
		.o_history_full_ir(o_history_full_ir), // 观察红外满窗
		.o_fir_idle(o_fir_idle),             // 观察安全排空
		.o_config_epoch(o_config_epoch),     // 观察中心ACTIVE版本
		.o_coef_epoch(o_coef_epoch),         // 观察中心Stage1版本
		.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch), // 观察中心恢复版本
		.o_precision_mode(o_precision_mode), // 观察中心精度身份
		.o_frame_id(o_frame_id),             // 观察中心帧号
		.o_sample_index(o_sample_index),     // 观察中心事务号
		.o_color_ir(o_color_ir),             // 观察输出颜色
		.o_frame_type(o_frame_type),         // 观察中心帧类别
		.o_amb_code_snapshot(o_amb_code_snapshot), // 观察中心AMB码
		.o_dc_code_snapshot(o_dc_code_snapshot), // 观察中心DC码
		.o_amb_code_epoch(o_amb_code_epoch), // 观察中心AMB版本
		.o_dc_code_epoch(o_dc_code_epoch)    // 观察中心DC版本
	);

endmodule
