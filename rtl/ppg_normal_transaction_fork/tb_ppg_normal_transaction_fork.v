`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/07
// Design Name:        PPG NORMAL Transaction Fork Testbench
// Module Name:        tb_ppg_normal_transaction_fork
// Description:        Description/tb_ppg_normal_transaction_fork_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_normal_transaction_fork
//
// Referrences:        PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_normal_transaction_fork.v
//
// Version:            V1.1
// Revision Date:      2026/09/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V1.0          Erie                  Create file.
// 2026/09/06            V1.1          Erie                  Cross-referenced this pre-existing FFK-01~09 suite against matrix item P13 ("AMI fork | Separate qualification storage and release are fixed") -- FFK-02 already proves independent per-branch storage and FFK-03/04 already prove the exact symmetric single-branch backpressure/independent-release behavior P13 asks for (FFK-06 repeats it under sustained 5-cycle backpressure), but this file was never cross-referenced from the 18 ppg_control_top-level TBs or the alias mapping table -- same "hidden evidence in a pre-existing module-level unit TB" pattern already found once for ppg_system_fault_abort_supervisor. Re-ran fresh under iverilog (50/50 PASS, 0 FAIL, clean $finish) and tagged the four directly-relevant PASS messages (FFK-02/03/04/06) with "(P13)" so future grep-based reconciliation finds them. No RTL or test logic changed.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月07日
// 设计名称:           PPG NORMAL事务双分支分发器自检平台
// 模块名称:           tb_ppg_normal_transaction_fork
// 模块说明:           Description/tb_ppg_normal_transaction_fork_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_normal_transaction_fork
//
// 参考资料:           PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_normal_transaction_fork.v
//
// 当前版本:           V1.1
// 修订日期:           2026年09月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V1.0          Erie                  创建文件
// 2026年09月06日        V1.1          Erie                  把这份已存在的FFK-01~09自检套件与矩阵P13项（"AMI fork | Separate qualification storage and release are fixed"）做交叉核对：FFK-02已经证明两分支独立存储，FFK-03/04已经证明P13要求的对称单分支反压/独立释放行为（FFK-06在5拍持续反压下重复验证），但本文件此前从未被18份ppg_control_top级TB或别名映射表交叉引用过——与ppg_system_fault_abort_supervisor那次"隐藏在已存在module-level unit TB里的证据"同一种模式。用iverilog重新真实跑了一遍（50/50 PASS，0 FAIL，正常$finish），并给FFK-02/03/04/06四条直接相关的PASS消息追加了"(P13)"字样，方便后续grep核对脚本找到。RTL和测试逻辑本身未改动。

// 覆盖FFK-01至FFK-09，检查双分支单次消费、独立反压、同拍替换和复位清理行为
module tb_ppg_normal_transaction_fork;

	//-------------配置参数区域-------------//
	// 测试平台使用冻结合同默认字段宽度，并以500 ns周期模拟2 MHz数字时钟
	localparam integer C_FRAME_ID_WIDTH = 32'd16;                         // 自检帧号采用合同规定的16-bit宽度
	localparam integer C_SAMPLE_INDEX_WIDTH = 32'd16;                     // 自检样本编号采用合同规定的16-bit宽度
	localparam integer C_IDAC_CODE_WIDTH = 32'd8;                         // 自检IDAC码快照采用8-bit宽度
	localparam integer C_CODE_EPOCH_WIDTH = 32'd4;                        // 自检码版本采用模16标签
	localparam integer C_CONFIG_EPOCH_WIDTH = 32'd8;                      // 自检ACTIVE版本采用8-bit标签
	localparam integer C_COEF_EPOCH_WIDTH = 32'd8;                        // 自检Stage1系数版本采用8-bit标签
	localparam integer C_PAYLOAD_WIDTH = 32'd131;                         // measurement完整NORMAL载荷的默认总位宽
	localparam integer C_TRACK_PAYLOAD_WIDTH = 32'd91;                    // tracking裁剪载荷的默认总位宽
	localparam integer C_CLOCK_HALF_PERIOD = 32'd250;                     // 2 MHz时钟的半周期纳秒数

	//--------------寄存器信号--------------//
	// 全局时钟复位与上游NORMAL载荷由测试过程显式驱动
	reg i_clk;                            // 自检平台生成的2 MHz时钟
	reg i_rstn;                           // 驱动DUT低有效异步复位
	reg i_normal_valid;                   // 驱动router侧保持型输入valid
	reg signed [11:0]i_calibrated_s1_value; // 驱动Stage1校准后的有符号残差
	reg i_calibration_applied;            // 驱动正式校准资格属性
	reg i_saturation_low;                 // 驱动Stage1负向饱和诊断
	reg i_saturation_high;                // 驱动Stage1正向饱和诊断
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // 驱动完整配置版本标签
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // 驱动Stage1系数组版本标签
	reg [8:0]i_detect_code;               // 驱动固定9-bit黄金检测码
	reg [9:0]i_stage1_raw;                // 驱动十个Stage1物理判决位
	reg signed [10:0]i_stage1_code_ext;   // 驱动未钳位D1_EXT测试值
	reg [9:0]i_stage2_raw;                // 驱动十个Stage2物理判决位
	reg i_precision_mode;                 // 驱动当前事务9/15-bit精度身份
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 驱动R/IR共享帧编号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 驱动全局ADC事务序号
	reg i_color_ir;                       // 驱动红光或红外颜色身份
	reg [1:0]i_frame_type;                // 驱动冻结的NORMAL编码2'b10
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 驱动AMB实际码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 驱动当前颜色DC实际码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 驱动AMB committed版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 驱动当前颜色DC committed版本
	reg i_measurement_ready;              // 控制测量分支独立反压
	reg i_track_ready;                    // 控制IDAC跟踪分支独立反压

	// 三笔互异事务用于发现丢失、复制和跨事务字段混合
	reg [C_PAYLOAD_WIDTH - 1:0]packet_a; // 保存粗精度红光基准事务
	reg [C_PAYLOAD_WIDTH - 1:0]packet_b; // 保存精细精度红外替换事务
	reg [C_PAYLOAD_WIDTH - 1:0]packet_c; // 保存MANUAL/HOLD消费语义事务
	reg [C_TRACK_PAYLOAD_WIDTH - 1:0]track_packet_a; // 保存A事务的IDAC裁剪期望值
	reg [C_TRACK_PAYLOAD_WIDTH - 1:0]track_packet_b; // 保存B事务的跟踪字段期望值
	reg [C_TRACK_PAYLOAD_WIDTH - 1:0]track_packet_c; // 保存C事务的慢速观察期望值
	reg [C_PAYLOAD_WIDTH - 1:0]held_measurement_payload; // 记录测量分支反压前的稳定载荷
	reg [C_TRACK_PAYLOAD_WIDTH - 1:0]held_track_payload; // 记录tracking分支反压前的稳定载荷

	//---------------计数信号---------------//
	// 两个计数器分别统计真实valid/ready握手次数，检测重复消费
	integer cnt_measurement_transfer;      // 测量分支累计消费次数
	integer cnt_track_transfer;            // IDAC跟踪分支累计消费次数
	integer cnt_error;                     // 所有自检断言累计失败数
	integer cnt_hold_cycle;                // 五拍反压稳定性检查循环索引

	//---------------其他信号---------------//
	// DUT输出逐项接出，随后重新拼装为便于逐位比较的两种事务向量
	wire o_normal_ready;                   // DUT返回router的输入接纳许可
	wire o_measurement_valid;              // DUT测量分支保持型valid
	wire signed [11:0]o_measurement_calibrated_s1_value; // 测量分支Stage1校准残差
	wire o_measurement_calibration_applied; // 测量分支校准资格
	wire o_measurement_saturation_low;     // 测量分支负向饱和属性
	wire o_measurement_saturation_high;    // 测量分支正向饱和属性
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_measurement_config_epoch; // 测量分支ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_measurement_coef_epoch; // 测量分支Stage1版本
	wire [8:0]o_measurement_detect_code;   // 测量分支固定检测码
	wire [9:0]o_measurement_stage1_raw;    // 测量分支Stage1物理位
	wire signed [10:0]o_measurement_stage1_code_ext; // 测量分支未钳位D1_EXT
	wire [9:0]o_measurement_stage2_raw;    // 测量分支Stage2物理位
	wire o_measurement_precision_mode;     // 测量分支精度快照
	wire [C_FRAME_ID_WIDTH - 1:0]o_measurement_frame_id; // 测量分支共享帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_measurement_sample_index; // 测量分支样本序号
	wire o_measurement_color_ir;           // 测量分支颜色身份
	wire [1:0]o_measurement_frame_type;    // 测量分支NORMAL编码
	wire [C_IDAC_CODE_WIDTH - 1:0]o_measurement_amb_code_snapshot; // 测量分支AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]o_measurement_dc_code_snapshot; // 测量分支DC快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_measurement_amb_code_epoch; // 测量分支AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_measurement_dc_code_epoch; // 测量分支DC版本
	wire o_track_valid;                    // DUT跟踪分支保持型valid
	wire signed [11:0]o_track_calibrated_s1_value; // 跟踪分支IDAC主比较值
	wire o_track_calibration_applied;      // 跟踪分支校准资格
	wire o_track_saturation_low;           // 跟踪分支低侧越界属性
	wire o_track_saturation_high;          // 跟踪分支高侧越界属性
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_track_config_epoch; // 跟踪分支ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_track_coef_epoch; // 跟踪分支Stage1版本
	wire o_track_precision_mode;           // 跟踪分支精度身份
	wire [C_FRAME_ID_WIDTH - 1:0]o_track_frame_id; // 跟踪分支共享帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_track_sample_index; // 跟踪分支事务序号
	wire o_track_color_ir;                 // 跟踪分支颜色选择
	wire [1:0]o_track_frame_type;          // 跟踪分支NORMAL类别
	wire [C_IDAC_CODE_WIDTH - 1:0]o_track_amb_code_snapshot; // 跟踪分支AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]o_track_dc_code_snapshot; // 跟踪分支DC快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_track_amb_code_epoch; // 跟踪分支AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_track_dc_code_epoch; // 跟踪分支DC版本
	wire [C_PAYLOAD_WIDTH - 1:0]measurement_payload; // 重组全部measurement输出字段
	wire [C_TRACK_PAYLOAD_WIDTH - 1:0]track_payload; // 重组IDAC实际可见的裁剪字段

	//-------------其他信号连线-------------//
	// measurement向量顺序严格复用DUT输入打包顺序，便于一次比较全部字段
	assign measurement_payload = {
		o_measurement_calibrated_s1_value,
		o_measurement_calibration_applied,
		o_measurement_saturation_low,
		o_measurement_saturation_high,
		o_measurement_config_epoch,
		o_measurement_coef_epoch,
		o_measurement_detect_code,
		o_measurement_stage1_raw,
		o_measurement_stage1_code_ext,
		o_measurement_stage2_raw,
		o_measurement_precision_mode,
		o_measurement_frame_id,
		o_measurement_sample_index,
		o_measurement_color_ir,
		o_measurement_frame_type,
		o_measurement_amb_code_snapshot,
		o_measurement_dc_code_snapshot,
		o_measurement_amb_code_epoch,
		o_measurement_dc_code_epoch
	};                                      // 形成131-bit完整测量副本观察总线

	// tracking向量排除detect_code、Stage1原始码、D1_EXT和全部Stage2数据
	assign track_payload = {
		o_track_calibrated_s1_value,
		o_track_calibration_applied,
		o_track_saturation_low,
		o_track_saturation_high,
		o_track_config_epoch,
		o_track_coef_epoch,
		o_track_precision_mode,
		o_track_frame_id,
		o_track_sample_index,
		o_track_color_ir,
		o_track_frame_type,
		o_track_amb_code_snapshot,
		o_track_dc_code_snapshot,
		o_track_amb_code_epoch,
		o_track_dc_code_epoch
	};                                      // 形成91-bit IDAC跟踪资格和身份总线

	//------------主要任务处理区域-----------//
	// 生成连续2 MHz方波，为全部握手和寄存更新提供统一上升沿
	always begin
		#C_CLOCK_HALF_PERIOD i_clk = ~i_clk; // 每250 ns翻转一次得到500 ns周期
	end

	// 统计measurement真实握手，valid保持多个周期时不得重复计入未ready拍
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_measurement_transfer = 0;       // 每次复位重新开始测量消费计数
		end else if(o_measurement_valid && i_measurement_ready)begin
			cnt_measurement_transfer = cnt_measurement_transfer + 1; // 只在valid与ready同时为高时累计
		end else begin
			cnt_measurement_transfer = cnt_measurement_transfer; // 非握手周期保持历史次数
		end
	end

	// 统计tracking真实握手，证明MANUAL/HOLD忽略语义也不会形成重复事务
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_track_transfer = 0;             // 每次复位清空IDAC分支消费历史
		end else if(o_track_valid && i_track_ready)begin
			cnt_track_transfer = cnt_track_transfer + 1; // 记录IDAC入口真正接收的样本数
		end else begin
			cnt_track_transfer = cnt_track_transfer; // 反压或空闲时禁止虚增
		end
	end

	// 将一个131-bit黄金事务展开到DUT全部输入字段，保持与RTL拼接顺序一致
	task drive_packet;
		input [C_PAYLOAD_WIDTH - 1:0]packet_value; // 调用者提供的完整NORMAL事务
		begin
			{
				i_calibrated_s1_value,
				i_calibration_applied,
				i_saturation_low,
				i_saturation_high,
				i_config_epoch,
				i_coef_epoch,
				i_detect_code,
				i_stage1_raw,
				i_stage1_code_ext,
				i_stage2_raw,
				i_precision_mode,
				i_frame_id,
				i_sample_index,
				i_color_ir,
				i_frame_type,
				i_amb_code_snapshot,
				i_dc_code_snapshot,
				i_amb_code_epoch,
				i_dc_code_epoch
			} = packet_value;                  // 同拍更新完整上游载荷
		end
	endtask

	// 施加异步复位并在释放后等待一个时钟，隔离每个定向测试场景
	task apply_reset;
		begin
			@(negedge i_clk);                   // 在非采样边沿改变复位以避免竞争
			i_rstn = 1'b0;                     // 清除DUT缓存和两个pending位
			i_normal_valid = 1'b0;             // 复位期间禁止输入事务
			i_measurement_ready = 1'b0;         // 复位场景默认关闭测量消费
			i_track_ready = 1'b0;               // 复位场景默认关闭跟踪消费
			repeat(2)@(posedge i_clk);          // 保持复位跨越两个有效时钟沿
			@(negedge i_clk);                   // 在下降沿释放低有效复位
			i_rstn = 1'b1;                     // 恢复正常事务处理
			@(posedge i_clk);                   // 等待组合ready稳定到运行状态
			#1;                                // 避开非阻塞更新观察区竞争
		end
	endtask

	// 等待fork可接纳后送入一笔事务，并在唯一握手沿后撤销输入valid
	task accept_packet;
		input [C_PAYLOAD_WIDTH - 1:0]packet_value; // 本次需要送入缓存的黄金事务
		begin
			@(negedge i_clk);                   // 在采样沿之前建立valid和载荷
			drive_packet(packet_value);         // 驱动所有NORMAL输入字段
			i_normal_valid = 1'b1;             // 声明上游持有待接纳事务
			while(o_normal_ready !== 1'b1)begin
				@(negedge i_clk);               // 保持输入直到fork真正可写
			end
			@(posedge i_clk);                   // 当前沿完成输入valid/ready握手
			#1;                                // 等待DUT寄存输出更新完成
			@(negedge i_clk);                   // 下一下降沿撤销上游valid
			i_normal_valid = 1'b0;             // 防止同一事务再次被接纳
		end
	endtask

	// 对一个布尔条件执行可检索的PASS/FAIL报告，并累计全局错误数
	task check_condition;
		input condition_value;                // 当前检查点的真假结果
		input [8 * 96 - 1:0]case_message;      // 仿真日志中的场景说明文本
		begin
			if(condition_value)begin
				$display("PASS: %0s", case_message); // 条件成立时报告对应合同点通过
			end else begin
				cnt_error = cnt_error + 1;       // 条件失败时累计一次可见错误
				$display("FAIL: %0s", case_message); // 输出失败场景便于定位波形
			end
		end
	endtask

	// 主测试序列按FFK编号依次验证复位、独立消费、反压稳定和无气泡替换
	initial begin
		i_clk = 1'b0;                         // 时钟初始为低电平
		i_rstn = 1'b0;                        // 上电首先保持数字复位
		i_normal_valid = 1'b0;                // 初始不存在router事务
		i_measurement_ready = 1'b0;           // 初始测量链不接收数据
		i_track_ready = 1'b0;                 // 初始IDAC入口不接收数据
		cnt_error = 0;                         // 清空跨场景累计错误数
		drive_packet({C_PAYLOAD_WIDTH{1'b0}}); // 初始化全部DUT数据输入

		packet_a = {
			-12'sd321, 1'b1, 1'b0, 1'b0, 8'h11, 8'h21,
			9'h155, 10'h2aa, -11'sd7, 10'h155, 1'b0,
			16'h1001, 16'h2001, 1'b0, 2'b10, 8'h31, 8'h41, 4'h5, 4'h6
		};                                      // A事务覆盖负残差、9-bit和红光身份
		track_packet_a = {
			-12'sd321, 1'b1, 1'b0, 1'b0, 8'h11, 8'h21, 1'b0,
			16'h1001, 16'h2001, 1'b0, 2'b10, 8'h31, 8'h41, 4'h5, 4'h6
		};                                      // A事务裁剪后保留全部IDAC所需字段
		packet_b = {
			12'sd777, 1'b1, 1'b0, 1'b1, 8'h12, 8'h22,
			9'h0a3, 10'h155, 11'sd510, 10'h2d3, 1'b1,
			16'h1002, 16'h2002, 1'b1, 2'b10, 8'h32, 8'h42, 4'h7, 4'h8
		};                                      // B事务覆盖正残差、15-bit和红外身份
		track_packet_b = {
			12'sd777, 1'b1, 1'b0, 1'b1, 8'h12, 8'h22, 1'b1,
			16'h1002, 16'h2002, 1'b1, 2'b10, 8'h32, 8'h42, 4'h7, 4'h8
		};                                      // B事务跟踪期望保留正向饱和属性
		packet_c = {
			-12'sd1024, 1'b0, 1'b1, 1'b0, 8'h13, 8'h23,
			9'h1f0, 10'h3c3, -11'sd256, 10'h3aa, 1'b1,
			16'h1003, 16'h2003, 1'b0, 2'b10, 8'h33, 8'h43, 4'h9, 4'ha
		};                                      // C事务模拟控制器消费后忽略的不合格样本
		track_packet_c = {
			-12'sd1024, 1'b0, 1'b1, 1'b0, 8'h13, 8'h23, 1'b1,
			16'h1003, 16'h2003, 1'b0, 2'b10, 8'h33, 8'h43, 4'h9, 4'ha
		};                                      // C事务仍应完整到达tracking入口一次

		apply_reset;                           // 建立FFK-01初始复位场景
		check_condition((o_measurement_valid == 1'b0) &&
			(o_track_valid == 1'b0), "FFK-01 reset clears both output valids");
		check_condition(o_normal_ready == 1'b1, "FFK-01 empty fork accepts input after reset release");

		accept_packet(packet_a);               // FFK-02装入第一笔完整事务
		check_condition((o_measurement_valid == 1'b1) &&
			(o_track_valid == 1'b1), "FFK-02 one input creates one pending copy per branch (P13 independent storage)");
		check_condition(measurement_payload == packet_a, "FFK-02 measurement receives the complete atomic payload");
		check_condition(track_payload == track_packet_a, "FFK-02 tracking receives only the frozen IDAC fields");
		check_condition(cnt_measurement_transfer == 0 && cnt_track_transfer == 0,
			"FFK-02 no branch consumes while both ready inputs are low");

		@(negedge i_clk);                     // 准备FFK-03让measurement先消费
		i_measurement_ready = 1'b1;           // 仅开放测量分支一个周期
		@(posedge i_clk);                     // measurement完成第一次握手
		#1;                                    // 等待pending状态更新
		@(negedge i_clk);                     // 关闭测量ready防止后续新事务误消费
		i_measurement_ready = 1'b0;           // tracking继续保持反压
		check_condition((o_measurement_valid == 1'b0) &&
			(o_track_valid == 1'b1), "FFK-03 measurement consumes once while tracking remains pending (P13)");
		check_condition(track_payload == track_packet_a, "FFK-03 tracking payload survives earlier measurement consumption");
		check_condition(cnt_measurement_transfer == 1 && cnt_track_transfer == 0,
			"FFK-03 consumed measurement copy is not repeated");
		@(negedge i_clk);                     // 结束A事务剩余tracking所有权
		i_track_ready = 1'b1;                 // 允许IDAC入口接收A事务
		@(posedge i_clk);                     // tracking完成唯一握手
		#1;                                    // 等待缓存释放组合状态
		@(negedge i_clk);                     // 恢复默认反压输入
		i_track_ready = 1'b0;                 // 关闭tracking ready
		check_condition((o_measurement_valid == 1'b0) &&
			(o_track_valid == 1'b0), "FFK-03 final tracking handshake releases the transaction");

		apply_reset;                           // 隔离FFK-04相反消费顺序
		accept_packet(packet_b);               // 装入高精度红外事务
		@(negedge i_clk);                     // 准备tracking先消费
		i_track_ready = 1'b1;                 // 只开放IDAC跟踪分支
		@(posedge i_clk);                     // tracking完成B事务握手
		#1;                                    // 等待独立pending位清除
		@(negedge i_clk);                     // 关闭跟踪入口
		i_track_ready = 1'b0;                 // measurement仍处于反压
		check_condition((o_measurement_valid == 1'b1) &&
			(o_track_valid == 1'b0), "FFK-04 tracking consumes once while measurement remains pending (P13)");
		check_condition(measurement_payload == packet_b, "FFK-04 complete measurement payload remains stable after tracking");
		check_condition(cnt_measurement_transfer == 0 && cnt_track_transfer == 1,
			"FFK-04 consumed tracking copy is not presented twice");
		@(negedge i_clk);                     // 结束B事务剩余measurement所有权
		i_measurement_ready = 1'b1;           // 允许测量链接收B事务
		@(posedge i_clk);                     // measurement完成唯一握手
		#1;                                    // 等待测量valid清除
		@(negedge i_clk);                     // 恢复默认ready状态
		i_measurement_ready = 1'b0;           // 关闭测量分支ready

		apply_reset;                           // 建立FFK-05同拍双消费与替换场景
		accept_packet(packet_a);               // 先让A事务同时等待两个分支
		@(negedge i_clk);                     // 在旧事务消费沿前建立B输入
		drive_packet(packet_b);               // 用完全不同的元数据准备替换载荷
		i_normal_valid = 1'b1;               // 请求同沿装入B事务
		i_measurement_ready = 1'b1;           // 当前沿消费A测量副本
		i_track_ready = 1'b1;                 // 当前沿消费A跟踪副本
		#1;                                    // 等待组合ready反映旧事务将释放
		check_condition(o_normal_ready == 1'b1, "FFK-05 both old consumers ready permit same-cycle replacement");
		@(posedge i_clk);                     // 同沿消费A并原子写入B
		#1;                                    // 观察替换后的新输出
		check_condition((o_measurement_valid == 1'b1) &&
			(o_track_valid == 1'b1), "FFK-05 replacement keeps both branch valids asserted");
		check_condition(measurement_payload == packet_b, "FFK-05 measurement output switches atomically to packet B");
		check_condition(track_payload == track_packet_b, "FFK-05 tracking output switches atomically to packet B");
		check_condition(cnt_measurement_transfer == 1 && cnt_track_transfer == 1,
			"FFK-05 packet A is consumed exactly once on both branches");
		@(negedge i_clk);                     // 撤销输入但保持两个消费者ready
		i_normal_valid = 1'b0;               // 禁止B事务重复装入
		@(posedge i_clk);                     // 两个分支同时消费B事务
		#1;                                    // 等待两个valid清除
		@(negedge i_clk);                     // 关闭两个ready结束场景
		i_measurement_ready = 1'b0;           // 恢复测量分支反压
		i_track_ready = 1'b0;                 // 恢复跟踪分支反压
		check_condition((o_measurement_valid == 1'b0) &&
			(o_track_valid == 1'b0), "FFK-05 packet B releases without an extra duplicate");
		check_condition(cnt_measurement_transfer == 2 && cnt_track_transfer == 2,
			"FFK-07 two consecutive packets preserve exact branch counts");

		apply_reset;                           // 建立FFK-06 measurement五拍反压场景
		accept_packet(packet_b);               // 装入需要稳定保持的B事务
		held_measurement_payload = measurement_payload; // 记录反压开始时完整测量载荷
		@(negedge i_clk);                     // 先让tracking独立消费
		i_track_ready = 1'b1;                 // IDAC入口立即接收，不等待测量链
		@(posedge i_clk);                     // tracking消费B事务
		#1;                                    // 等待tracking valid撤销
		@(negedge i_clk);                     // 关闭tracking ready
		i_track_ready = 1'b0;                 // 后续只观察measurement保持
		for(cnt_hold_cycle = 0; cnt_hold_cycle < 5; cnt_hold_cycle = cnt_hold_cycle + 1)begin
			@(posedge i_clk);                   // 连续五个采样沿保持measurement反压
			#1;                                // 观察寄存载荷稳定值
			check_condition(o_measurement_valid == 1'b1,
				"FFK-06 measurement valid remains high during five-cycle backpressure (P13)");
			check_condition(measurement_payload == held_measurement_payload,
				"FFK-06 every measurement payload bit remains stable while stalled");
		end
		@(negedge i_clk);                     // 五拍后允许measurement完成消费
		i_measurement_ready = 1'b1;           // 释放测量分支反压
		@(posedge i_clk);                     // 完成B事务measurement握手
		#1;                                    // 等待valid清零
		@(negedge i_clk);                     // 恢复ready默认值
		i_measurement_ready = 1'b0;           // 关闭测量ready

		apply_reset;                           // 建立FFK-06 tracking五拍反压互补场景
		accept_packet(packet_a);               // 装入需要稳定保持的A事务
		held_track_payload = track_payload;    // 记录反压开始时完整跟踪载荷
		@(negedge i_clk);                     // 让measurement先独立消费
		i_measurement_ready = 1'b1;           // overlap立即接收A事务
		@(posedge i_clk);                     // measurement消费A副本
		#1;                                    // 等待measurement valid撤销
		@(negedge i_clk);                     // 关闭测量ready
		i_measurement_ready = 1'b0;           // 后续只观察tracking保持
		for(cnt_hold_cycle = 0; cnt_hold_cycle < 5; cnt_hold_cycle = cnt_hold_cycle + 1)begin
			@(posedge i_clk);                   // 连续五拍维持IDAC反压
			#1;                                // 等待输出观察区稳定
			check_condition(o_track_valid == 1'b1,
				"FFK-06 tracking valid remains high during five-cycle backpressure (P13)");
			check_condition(track_payload == held_track_payload,
				"FFK-06 every tracking field remains stable while IDAC is stalled");
		end
		@(negedge i_clk);                     // 五拍后允许tracking消费
		i_track_ready = 1'b1;                 // 释放IDAC入口反压
		@(posedge i_clk);                     // 完成A事务tracking握手
		#1;                                    // 等待跟踪valid清零
		@(negedge i_clk);                     // 恢复默认ready值
		i_track_ready = 1'b0;                 // 关闭跟踪入口

		apply_reset;                           // 建立FFK-08控制器消费后忽略语义
		accept_packet(packet_c);               // 注入calibration_applied为0的事务
		@(negedge i_clk);                     // 模拟MANUAL/HOLD控制器始终消费tracking
		i_track_ready = 1'b1;                 // IDAC入口接收但后续内部忽略该样本
		@(posedge i_clk);                     // tracking完成C事务握手
		#1;                                    // 等待独立tracking pending清除
		@(negedge i_clk);                     // 关闭tracking ready
		i_track_ready = 1'b0;                 // measurement仍可独立等待
		check_condition((o_track_valid == 1'b0) &&
			(o_measurement_valid == 1'b1), "FFK-08 ignored tracking semantics do not discard measurement");
		check_condition(measurement_payload == packet_c, "FFK-08 measurement keeps the full transaction after IDAC ignore");
		check_condition(track_payload == track_packet_c,
			"FFK-08 tracking fields remain the accepted packet after controller consumption");
		@(negedge i_clk);                     // 允许测量链最终接收C事务
		i_measurement_ready = 1'b1;           // 释放measurement反压
		@(posedge i_clk);                     // 完成剩余测量副本握手
		#1;                                    // 等待缓存彻底排空
		@(negedge i_clk);                     // 关闭测量ready
		i_measurement_ready = 1'b0;           // 返回默认反压状态
		check_condition(cnt_measurement_transfer == 1 && cnt_track_transfer == 1,
			"FFK-08 both branches consume once even when IDAC mode ignores content");

		apply_reset;                           // 建立FFK-09复位打断场景
		accept_packet(packet_b);               // 让两个分支都持有一笔未消费事务
		check_condition((o_measurement_valid == 1'b1) &&
			(o_track_valid == 1'b1), "FFK-09 precondition holds one pending transaction");
		@(negedge i_clk);                     // 在无握手时异步拉低复位
		i_rstn = 1'b0;                        // 统一复位明确丢弃尚未消费的两个副本
		#1;                                    // 观察异步复位立即生效
		check_condition((o_measurement_valid == 1'b0) &&
			(o_track_valid == 1'b0), "FFK-09 reset interruption clears both pending valids");
		check_condition(o_normal_ready == 1'b0, "FFK-09 reset blocks new upstream acceptance");
		repeat(2)@(posedge i_clk);             // 确认复位期间不会产生伪传输
		check_condition(cnt_measurement_transfer == 0 && cnt_track_transfer == 0,
			"FFK-09 reset interruption creates no spurious branch transfer");
		@(negedge i_clk);                     // 释放最终复位
		i_rstn = 1'b1;                        // 恢复空fork运行状态
		@(posedge i_clk);                     // 等待ready重新开放
		#1;                                    // 避开组合传播观察竞争
		check_condition(o_normal_ready == 1'b1, "FFK-09 fork returns empty after reset release");

		if(cnt_error == 0)begin
			$display("PASS: ppg_normal_transaction_fork completed FFK-01 through FFK-09"); // 仅全部比较通过时报告总成功
		end else begin
			$display("FAIL: ppg_normal_transaction_fork found %0d errors", cnt_error); // 汇总所有失败检查数量
		end
		$finish;                               // 结束自检仿真并关闭xsim
	end

	// 独立看门狗防止ready/valid等待错误造成仿真无限挂起
	initial begin
		#500000;                               // 允许主测试运行最多500 us
		$display("FAIL: ppg_normal_transaction_fork simulation timeout"); // 超时视为握手或测试流程故障
		$finish;                               // 强制结束无法正常收敛的仿真
	end

	//------------模块实例化区域-------------//
	// 实例化待测NORMAL双输出fork并逐字段连接冻结合同接口
	ppg_normal_transaction_fork
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),                     // 使用16-bit共享帧号
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),             // 使用16-bit全局样本号
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),                   // 使用8-bit IDAC码快照
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),                 // 使用4-bit committed版本
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH),             // 使用8-bit ACTIVE版本
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH)                  // 使用8-bit Stage1系数版本
	)ppg_normal_transaction_fork_Inst_dut(
		.i_clk(i_clk),                                           // 连接2 MHz自检时钟
		.i_rstn(i_rstn),                                         // 连接低有效异步复位
		.i_normal_valid(i_normal_valid),                         // 连接router侧输入valid
		.i_calibrated_s1_value(i_calibrated_s1_value),           // 连接Stage1校准残差
		.i_calibration_applied(i_calibration_applied),           // 连接正式校准资格
		.i_saturation_low(i_saturation_low),                     // 连接负向饱和属性
		.i_saturation_high(i_saturation_high),                   // 连接正向饱和属性
		.i_config_epoch(i_config_epoch),                         // 连接ACTIVE版本标签
		.i_coef_epoch(i_coef_epoch),                             // 连接Stage1系数版本
		.i_detect_code(i_detect_code),                           // 连接固定黄金检测码
		.i_stage1_raw(i_stage1_raw),                             // 连接Stage1物理判决位
		.i_stage1_code_ext(i_stage1_code_ext),                   // 连接未钳位D1_EXT
		.i_stage2_raw(i_stage2_raw),                             // 连接Stage2物理判决位
		.i_precision_mode(i_precision_mode),                     // 连接事务精度身份
		.i_frame_id(i_frame_id),                                 // 连接R/IR共享帧号
		.i_sample_index(i_sample_index),                         // 连接全局ADC顺序号
		.i_color_ir(i_color_ir),                                 // 连接红光或红外身份
		.i_frame_type(i_frame_type),                             // 连接NORMAL类别编码
		.i_amb_code_snapshot(i_amb_code_snapshot),               // 连接AMB实际码快照
		.i_dc_code_snapshot(i_dc_code_snapshot),                 // 连接当前颜色DC快照
		.i_amb_code_epoch(i_amb_code_epoch),                     // 连接AMB committed版本
		.i_dc_code_epoch(i_dc_code_epoch),                       // 连接当前颜色DC版本
		.o_normal_ready(o_normal_ready),                         // 观察上游接纳许可
		.i_measurement_ready(i_measurement_ready),               // 驱动测量分支ready
		.o_measurement_valid(o_measurement_valid),               // 观察测量分支valid
		.o_measurement_calibrated_s1_value(o_measurement_calibrated_s1_value), // 观察完整Stage1残差
		.o_measurement_calibration_applied(o_measurement_calibration_applied), // 观察测量校准资格
		.o_measurement_saturation_low(o_measurement_saturation_low), // 观察测量负向饱和
		.o_measurement_saturation_high(o_measurement_saturation_high), // 观察测量正向饱和
		.o_measurement_config_epoch(o_measurement_config_epoch), // 观察测量ACTIVE版本
		.o_measurement_coef_epoch(o_measurement_coef_epoch),     // 观察测量Stage1版本
		.o_measurement_detect_code(o_measurement_detect_code),   // 观察测量黄金码
		.o_measurement_stage1_raw(o_measurement_stage1_raw),     // 观察测量Stage1物理码
		.o_measurement_stage1_code_ext(o_measurement_stage1_code_ext), // 观察测量D1_EXT
		.o_measurement_stage2_raw(o_measurement_stage2_raw),     // 观察测量Stage2物理码
		.o_measurement_precision_mode(o_measurement_precision_mode), // 观察测量精度快照
		.o_measurement_frame_id(o_measurement_frame_id),         // 观察测量共享帧号
		.o_measurement_sample_index(o_measurement_sample_index), // 观察测量样本序号
		.o_measurement_color_ir(o_measurement_color_ir),         // 观察测量颜色身份
		.o_measurement_frame_type(o_measurement_frame_type),     // 观察测量NORMAL编码
		.o_measurement_amb_code_snapshot(o_measurement_amb_code_snapshot), // 观察测量AMB快照
		.o_measurement_dc_code_snapshot(o_measurement_dc_code_snapshot), // 观察测量DC快照
		.o_measurement_amb_code_epoch(o_measurement_amb_code_epoch), // 观察测量AMB版本
		.o_measurement_dc_code_epoch(o_measurement_dc_code_epoch), // 观察测量DC版本
		.i_track_ready(i_track_ready),                           // 驱动IDAC跟踪ready
		.o_track_valid(o_track_valid),                           // 观察跟踪分支valid
		.o_track_calibrated_s1_value(o_track_calibrated_s1_value), // 观察IDAC主比较值
		.o_track_calibration_applied(o_track_calibration_applied), // 观察跟踪校准资格
		.o_track_saturation_low(o_track_saturation_low),         // 观察跟踪低侧越界属性
		.o_track_saturation_high(o_track_saturation_high),       // 观察跟踪高侧越界属性
		.o_track_config_epoch(o_track_config_epoch),             // 观察跟踪ACTIVE版本
		.o_track_coef_epoch(o_track_coef_epoch),                 // 观察跟踪Stage1版本
		.o_track_precision_mode(o_track_precision_mode),         // 观察跟踪精度身份
		.o_track_frame_id(o_track_frame_id),                     // 观察跟踪共享帧号
		.o_track_sample_index(o_track_sample_index),             // 观察跟踪事务序号
		.o_track_color_ir(o_track_color_ir),                     // 观察跟踪颜色选择
		.o_track_frame_type(o_track_frame_type),                 // 观察跟踪NORMAL编码
		.o_track_amb_code_snapshot(o_track_amb_code_snapshot),   // 观察跟踪AMB快照
		.o_track_dc_code_snapshot(o_track_dc_code_snapshot),     // 观察跟踪DC快照
		.o_track_amb_code_epoch(o_track_amb_code_epoch),         // 观察跟踪AMB版本
		.o_track_dc_code_epoch(o_track_dc_code_epoch)            // 观察跟踪DC版本
	);

endmodule
