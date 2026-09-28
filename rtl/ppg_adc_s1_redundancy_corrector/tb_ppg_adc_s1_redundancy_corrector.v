`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/25
// Design Name:        PPG S1 Redundancy Corrector Testbench
// Module Name:        tb_ppg_adc_s1_redundancy_corrector
// Description:        TestBench/Vivado/2021.1/ppg_adc_s1_redundancy_corrector
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        sar_stage1_vout_test Verilog-A monitor,
//                     PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// Dependencies:       ppg_adc_async_stage_capture,
//                     ppg_adc_s1_redundancy_corrector
//
// Version:            V1.0
// Revision Date:      2026/08/05
// History:
//    Time               Version       Revised by            Contents
// 2026/07/25            V1.0          Erie                  Create file.
// 2026/07/30            V1.0          Erie                  Add capture-to-corrector integration verification.
// 2026/07/30            V1.0          Erie                  Verify paired R/IR precision commits at PPG boundaries.
// 2026/08/05            V1.0          Erie                  Close complete payload checks under backpressure and replacement.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年07月25日
// 设计名称:           PPG第一级冗余重构器测试平台
// 模块名称:           tb_ppg_adc_s1_redundancy_corrector
// 模块说明:           TestBench/Vivado/2021.1/ppg_adc_s1_redundancy_corrector
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           sar_stage1_vout_test Verilog-A监视器、PPG_ADC_IDAC_INTEGRATION_SPEC.md
//
// 依赖文件:           ppg_adc_async_stage_capture、ppg_adc_s1_redundancy_corrector
//
// 当前版本:           V1.0
// 修订日期:           2026年08月05日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年07月25日        V1.0          Erie                  创建文件
// 2026年07月30日        V1.0          Erie                  增加捕获到重构器的联合验证
// 2026年07月30日        V1.0          Erie                  验证PPG边界提交的R/IR成对精度模式
// 2026年08月05日        V1.0          Erie                  补齐反压保持与同拍替换的完整载荷检查

// 联合验证异步捕获、事务上下文锁存、S1黄金重构、反压保持和全部1024个物理码
module tb_ppg_adc_s1_redundancy_corrector();

	//-------------配置参数区域-------------//
	// 测试参数与PPG数字域、ADC物理总线及默认元数据宽度保持一致
	localparam integer C_CLK_PERIOD = 500;  // 2 MHz系统时钟对应500 ns周期
	localparam integer C_FRAME_ID_WIDTH = 16; // 联合测试采用16-bit帧标识
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 样本顺序字段使用16-bit宽度
	localparam integer C_IDAC_CODE_WIDTH = 8; // 两组IDAC码均按8-bit测试
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 码值提交代号采用4-bit回绕计数

	//---------------计数信号---------------//
	// 自检计数器记录错误总数并遍历完整S1物理输入空间
	integer cnt_error;                      // 所有接口和数值比较的累计失败数
	integer cnt_raw_index;                  // 从0到1023枚举十根物理决策线

	//--------------寄存器信号--------------//
	// 测试平台驱动共享事务边界、模拟ADC接口和数字上下文
	reg i_clk;                              // 捕获与重构模块共用的2 MHz时钟
	reg i_rstn;                             // 两个DUT共用的低有效数字复位
	reg i_adc_transaction_start;            // 同时启动上下文锁存和ADC捕获事务
	reg i_precision_mode_committed;         // ADC_RST前确定的9/15-bit转换模式
	reg [9:0]i_dout_stage1_low;             // 模拟S1物理决策位保持总线
	reg i_clk_stage1_dout_low_async;        // S1最后一位完成后的异步保持电平
	reg [9:0]i_dout_stage2_low;             // 模拟S2物理决策位保持总线
	reg i_clk_stage2_dout_low_async;        // S2转换结束后的异步完成电平
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 事务开始时提供的帧标识
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 当前颜色通道的样本编号
	reg i_color_ir;                         // 低电平模拟红光，高电平模拟红外光
	reg [1:0]i_frame_type;                  // 定向覆盖AMB_CAL、DCS_CAL和NORMAL
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 转换积分期间使用的AMB码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 本次R或IR通道使用的DC码
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 与AMB码值对应的提交代号
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 与当前DC码对应的提交代号
	reg i_detect_ready;                     // 控制重构结果下游是否产生反压
	reg [3:0]reg_test_case_id;              // 波形中标识当前定向测试阶段
	reg flag_precision_mode_pending_model;  // 模拟红光检测器产生但尚未提交的高精度请求

	//---------------其他信号---------------//
	// 组合期望值严格复现Verilog-A整数重构和饱和定义
	integer dec_expected_ext;               // 黄金模型计算的-4至515扩展码
	integer dec_expected_detect;            // 扩展码钳位到0至511后的期望值

	//---------------标志信号---------------//
	// 两级DUT之间的ready/valid连线决定唯一RAW传输事件
	wire flag_transaction_ready;            // 重构器允许帧控制器启动下一事务
	wire flag_capture_ready;                // 重构器允许捕获模块交付当前载荷
	wire flag_capture_valid;                // 捕获缓存中存在一笔稳定ADC结果
	wire flag_detect_valid;                 // 重构输出缓存包含完整有效事务

	//------------模块实例化信号------------//
	// 捕获模块输出同时为重构器提供S1、S2和实际精度快照
	wire [9:0]capture_stage1_raw;           // 已跨异步完成边界保存的S1物理码
	wire [9:0]capture_stage2_raw;           // 15-bit事务中与S1原子保存的S2码
	wire capture_precision_mode;            // 捕获事务使用的精度模式快照

	//---------------输出信号---------------//
	// 观察重构结果、S2透传和全部事务身份字段
	wire [8:0]detect_code_o;                // 饱和后的9-bit检测链输入码
	wire [9:0]stage1_raw_o;                 // 与固定重构结果对齐的S1物理决策位
	wire signed [10:0]stage1_code_ext_o;    // 未饱和的Verilog-A D1_EXT结果
	wire [9:0]stage2_raw_o;                 // 传递到后续精细重构链的S2物理码
	wire precision_mode_o;                  // 与输出事务绑定的9/15-bit模式
	wire [C_FRAME_ID_WIDTH - 1:0]frame_id_o; // 输出帧标识用于核对上下文锁存
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]sample_index_o; // 输出样本编号用于检查事务顺序
	wire color_ir_o;                        // 输出颜色必须保持事务开始时的值
	wire [1:0]frame_type_o;                 // 输出帧类别用于后续AMB/DCS路由
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_code_snapshot_o; // 输出ADC实际使用的AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dc_code_snapshot_o; // 输出本次颜色对应的DC码快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]amb_code_epoch_o; // 输出AMB码提交代号
	wire [C_CODE_EPOCH_WIDTH - 1:0]dc_code_epoch_o; // 输出DC码提交代号

	//-----------主要任务处理区域-----------//
	// 固定占空比时钟为异步DONE同步链和全部ready/valid寄存器提供参考边沿
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk; // 每250 ns翻转一次系统时钟
	end

	// 先验证真实接口时序，再遍历全码空间并在每笔事务后执行自检比较
	initial begin
		i_clk = 1'b0;                       // 从确定低电平启动数字时钟
		i_rstn = 1'b0;                      // 初始阶段复位捕获和重构模块
		i_adc_transaction_start = 1'b0;     // 复位期间不允许建立事务上下文
		i_precision_mode_committed = 1'b0;  // 首笔转换默认选择9-bit模式
		i_dout_stage1_low = 10'b0000000000; // 模拟ADC_RST清除S1物理输出
		i_clk_stage1_dout_low_async = 1'b0; // 模拟ADC_RST压低S1完成电平
		i_dout_stage2_low = 10'b0000000000; // 模拟ADC_RST清除S2物理输出
		i_clk_stage2_dout_low_async = 1'b0; // 模拟ADC_RST压低S2完成电平
		i_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 清除未启动事务的帧号激励
		i_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 清除初始样本顺序字段
		i_color_ir = 1'b0;                  // 初始上下文选择红光通道
		i_frame_type = 2'b00;               // 初始帧类别使用AMB_CAL编码
		i_amb_code_snapshot = {C_IDAC_CODE_WIDTH{1'b0}}; // 初始AMB抵消码设为零
		i_dc_code_snapshot = {C_IDAC_CODE_WIDTH{1'b0}}; // 初始DC抵消码设为零
		i_amb_code_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 初始AMB版本代号清零
		i_dc_code_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 初始DC版本代号清零
		i_detect_ready = 1'b0;              // 复位阶段阻止下游消费
		reg_test_case_id = 4'd0;            // 波形阶段零表示数字复位检查
		flag_precision_mode_pending_model = 1'b0; // 复位后不存在红光触发的高精度请求
		cnt_error = 0;                      // 自检开始前清空错误累计值
		dec_expected_ext = 0;               // 初始化黄金扩展码工作变量
		dec_expected_detect = 0;            // 初始化期望检测码工作变量

		#113;
		if((flag_detect_valid !== 1'b0) || (flag_capture_valid !== 1'b0) || (flag_transaction_ready !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录复位期间出现有效载荷或ready
			$display("FAIL reset interface valid=%b capture=%b transaction_ready=%b", flag_detect_valid, flag_capture_valid, flag_transaction_ready); // 报告复位接口状态
		end
		@(negedge i_clk);
		i_rstn = 1'b1;                      // 在下降沿释放数字复位避免测试竞争
		@(posedge i_clk);
		#1;
		if(flag_transaction_ready !== 1'b1)begin
			cnt_error = cnt_error + 1;      // 记录空闲重构器未开放首笔事务
			$display("FAIL transaction context was not ready after reset"); // 报告上下文缓冲器初始化错误
		end

		// 红光上下文在事务开始时锁存，随后实时总线切到红外也不得改变返回属性
		reg_test_case_id = 4'd1;            // 阶段一验证事务快照和9-bit重构
		@(negedge i_clk);
		i_frame_id = 16'h1111;              // 设置红光事务的帧号
		i_sample_index = 16'h0021;          // 设置红光样本序号
		i_color_ir = 1'b0;                  // 本次转换属于红光
		i_frame_type = 2'b10;               // 本次转换使用NORMAL类别
		i_amb_code_snapshot = 8'h35;        // 红光转换实际采用AMB码35
		i_dc_code_snapshot = 8'h72;         // 红光转换实际采用DC_R码72
		i_amb_code_epoch = 4'h3;            // 绑定AMB版本三
		i_dc_code_epoch = 4'h7;             // 绑定红光DC版本七
		i_precision_mode_committed = 1'b0;  // 首笔联合事务采用9-bit模式
		i_adc_transaction_start = 1'b1;     // 同拍启动捕获并保存红光上下文
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束单周期事务开始脉冲
		i_frame_id = 16'h2222;              // 模拟顶层提前准备下一笔红外帧号
		i_sample_index = 16'h0042;          // 改变实时样本编号检查快照隔离
		i_color_ir = 1'b1;                  // 实时颜色切换到红外
		i_frame_type = 2'b01;               // 实时帧类别切换到DCS_CAL
		i_amb_code_snapshot = 8'h99;        // 改变实时AMB码以暴露错误晚采样
		i_dc_code_snapshot = 8'ha6;         // 改变实时DC_IR码以检查原子对齐
		i_amb_code_epoch = 4'h9;            // 推进实时AMB版本字段
		i_dc_code_epoch = 4'ha;             // 推进实时DC版本字段
		#73 i_dout_stage1_low = 10'b0101011011; // 建立S1物理码并保持到下一ADC_RST
		#3 i_clk_stage1_dout_low_async = 1'b1; // 异步拉高S1完成电平
		wait(flag_detect_valid === 1'b1);   // 等待捕获与重构两级握手完成
		#1;
		dec_expected_ext = ((10'b0101011011 >> 4) * 8) +
			(10'b0101011011 & 7) + (((10'b0101011011 >> 3) & 1) ? 4 : -4); // 计算本次S1扩展黄金值
		if((stage1_code_ext_o !== dec_expected_ext[10:0]) || (detect_code_o !== dec_expected_ext[8:0]) || (frame_id_o !== 16'h1111) || (sample_index_o !== 16'h0021) || (color_ir_o !== 1'b0) || (frame_type_o !== 2'b10) || (amb_code_snapshot_o !== 8'h35) || (dc_code_snapshot_o !== 8'h72) || (amb_code_epoch_o !== 4'h3) || (dc_code_epoch_o !== 4'h7) || (precision_mode_o !== 1'b0) || (stage2_raw_o !== 10'b0000000000))begin
			cnt_error = cnt_error + 1;      // 记录红光RAW与红外实时上下文发生错配
			$display("FAIL context snapshot ext=%0d detect=%h frame=%h color=%b", $signed(stage1_code_ext_o), detect_code_o, frame_id_o, color_ir_o); // 报告快照隔离差异
		end
		@(negedge i_clk);
		i_detect_ready = 1'b1;              // 允许下游消费首笔红光重构结果
		@(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录首笔结果在ready后仍未释放
			$display("FAIL first reconstructed result did not retire"); // 报告输出握手释放错误
		end
		i_detect_ready = 1'b0;              // 恢复反压以准备15-bit定向检查

		// 高精度事务必须等待S2完成，并把两级RAW与红外上下文绑定为同一载荷
		reg_test_case_id = 4'd2;            // 阶段二验证15-bit捕获边界和S2透传
		@(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0; // 模拟ADC_RST清除上一笔S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 复位未工作的S2完成电平
		i_dout_stage1_low = 10'b0000000000; // ADC_RST清除上一笔S1物理码
		i_dout_stage2_low = 10'b0000000000; // ADC_RST清除上一笔S2物理码
		i_frame_id = 16'h3001;              // 为红外精细采样分配新帧号
		i_sample_index = 16'h0043;          // 设置红外精细样本编号
		i_color_ir = 1'b1;                  // 精细事务属于红外通道
		i_frame_type = 2'b10;               // 精细转换发生在NORMAL帧
		i_amb_code_snapshot = 8'h36;        // 保存本次实际AMB抵消码
		i_dc_code_snapshot = 8'ha7;         // 保存本次红外DC抵消码
		i_amb_code_epoch = 4'h4;            // 记录AMB码版本四
		i_dc_code_epoch = 4'hb;             // 记录红外DC码版本十一
		i_precision_mode_committed = 1'b1;  // 顶层在ADC_RST前提交15-bit模式
		i_adc_transaction_start = 1'b1;     // 建立捕获和上下文的同一事务
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束精细事务启动脉冲
		#61 i_dout_stage1_low = 10'b1010010110; // 建立高精度事务的S1物理结果
		#3 i_clk_stage1_dout_low_async = 1'b1; // S1先完成但不得提前交付15-bit事务
		repeat(4) @(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录高精度事务错误使用S1 DONE触发
			$display("FAIL 15-bit transaction completed before stage2 DONE"); // 报告精度完成边界错误
		end
		#47 i_dout_stage2_low = 10'b0011011101; // 建立与当前S1对应的S2物理结果
		#3 i_clk_stage2_dout_low_async = 1'b1; // S2完成后允许捕获两级结果
		wait(flag_detect_valid === 1'b1);   // 等待完整高精度载荷进入重构缓存
		#1;
		dec_expected_ext = ((10'b1010010110 >> 4) * 8) +
			(10'b1010010110 & 7) + (((10'b1010010110 >> 3) & 1) ? 4 : -4); // 重构本次高精度S1值
		if((stage1_code_ext_o !== dec_expected_ext[10:0]) || (stage2_raw_o !== 10'b0011011101) || (precision_mode_o !== 1'b1) || (frame_id_o !== 16'h3001) || (color_ir_o !== 1'b1) || (dc_code_snapshot_o !== 8'ha7))begin
			cnt_error = cnt_error + 1;      // 记录S1、S2、模式或红外上下文未原子对齐
			$display("FAIL 15-bit alignment ext=%0d s2=%h mode=%b frame=%h", $signed(stage1_code_ext_o), stage2_raw_o, precision_mode_o, frame_id_o); // 报告精细载荷差异
		end

		// 输出阻塞时允许准备一笔新事务，但第三笔事务必须由transaction_ready阻止
		reg_test_case_id = 4'd3;            // 阶段三验证两级弹性缓存和上下文背压
		@(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0; // 模拟下一笔ADC_RST清除S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 模拟下一笔ADC_RST清除S2 DONE
		i_dout_stage1_low = 10'b0000000000; // 清除高精度S1物理总线
		i_dout_stage2_low = 10'b0000000000; // 清除高精度S2物理总线
		i_frame_id = 16'h4002;              // 准备输出反压期间的下一帧标识
		i_sample_index = 16'h0044;          // 设置等待事务的样本编号
		i_color_ir = 1'b0;                  // 下一笔事务返回红光通道
		i_frame_type = 2'b01;               // 等待事务属于DCS_CAL阶段
		i_amb_code_snapshot = 8'h40;        // 等待事务采用新的AMB码
		i_dc_code_snapshot = 8'h81;         // 等待事务采用红光DC码81
		i_amb_code_epoch = 4'h5;            // 等待事务绑定AMB版本五
		i_dc_code_epoch = 4'h8;             // 等待事务绑定DC版本八
		i_precision_mode_committed = 1'b0;  // 下一笔转换使用9-bit模式
		i_adc_transaction_start = 1'b1;     // 在旧重构结果被阻塞时启动下一ADC事务
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束等待事务的启动脉冲
		#79 i_dout_stage1_low = 10'b0111101001; // 建立等待事务的S1物理码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 让捕获模块保存但暂不交付新结果
		wait(flag_capture_valid === 1'b1);  // 等待第二笔RAW占用捕获输出缓存
		repeat(2) @(posedge i_clk);
		#1;
		dec_expected_ext = ((10'b1010010110 >> 4) * 8) +
			(10'b1010010110 & 7) + (((10'b1010010110 >> 3) & 1) ? 4 : -4); // 重新建立被阻塞旧事务的完整黄金值
		if((flag_detect_valid !== 1'b1) || (stage1_raw_o !== 10'b1010010110) || (stage1_code_ext_o !== dec_expected_ext[10:0]) || (detect_code_o !== dec_expected_ext[8:0]) || (stage2_raw_o !== 10'b0011011101) || (precision_mode_o !== 1'b1) || (frame_id_o !== 16'h3001) || (sample_index_o !== 16'h0043) || (color_ir_o !== 1'b1) || (frame_type_o !== 2'b10) || (amb_code_snapshot_o !== 8'h36) || (dc_code_snapshot_o !== 8'ha7) || (amb_code_epoch_o !== 4'h4) || (dc_code_epoch_o !== 4'hb) || (flag_capture_ready !== 1'b0) || (flag_transaction_ready !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录反压时旧完整载荷被覆盖或错误开放第三事务
			$display("FAIL backpressure hold raw1=%h ext=%0d detect=%0d raw2=%h mode=%b frame=%h sample=%h color=%b type=%b amb=%h dc=%h amb_epoch=%h dc_epoch=%h capture_ready=%b transaction_ready=%b", stage1_raw_o, $signed(stage1_code_ext_o), detect_code_o, stage2_raw_o, precision_mode_o, frame_id_o, sample_index_o, color_ir_o, frame_type_o, amb_code_snapshot_o, dc_code_snapshot_o, amb_code_epoch_o, dc_code_epoch_o, flag_capture_ready, flag_transaction_ready); // 报告被阻塞旧事务的逐字段差异
		end
		@(negedge i_clk);
		i_detect_ready = 1'b1;              // 同拍消费旧精细结果并接收等待的红光RAW
		@(posedge i_clk);
		#1;
		dec_expected_ext = ((10'b0111101001 >> 4) * 8) +
			(10'b0111101001 & 7) + (((10'b0111101001 >> 3) & 1) ? 4 : -4); // 计算替换事务期望S1值
		if((flag_detect_valid !== 1'b1) || (stage1_raw_o !== 10'b0111101001) || (stage1_code_ext_o !== dec_expected_ext[10:0]) || (detect_code_o !== dec_expected_ext[8:0]) || (stage2_raw_o !== 10'b0000000000) || (precision_mode_o !== 1'b0) || (frame_id_o !== 16'h4002) || (sample_index_o !== 16'h0044) || (color_ir_o !== 1'b0) || (frame_type_o !== 2'b01) || (amb_code_snapshot_o !== 8'h40) || (dc_code_snapshot_o !== 8'h81) || (amb_code_epoch_o !== 4'h5) || (dc_code_epoch_o !== 4'h8))begin
			cnt_error = cnt_error + 1;      // 记录同拍消费替换后的任一载荷字段不一致
			$display("FAIL same-cycle replacement valid=%b raw1=%h ext=%0d detect=%0d raw2=%h mode=%b frame=%h sample=%h color=%b type=%b amb=%h dc=%h amb_epoch=%h dc_epoch=%h", flag_detect_valid, stage1_raw_o, $signed(stage1_code_ext_o), detect_code_o, stage2_raw_o, precision_mode_o, frame_id_o, sample_index_o, color_ir_o, frame_type_o, amb_code_snapshot_o, dc_code_snapshot_o, amb_code_epoch_o, dc_code_epoch_o); // 报告替换后新事务的逐字段差异
		end
		@(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录替换结果在连续ready下未被消费
			$display("FAIL replacement result did not retire"); // 报告连续握手结束错误
		end
		i_detect_ready = 1'b1;              // 全码遍历期间保持下游持续可接收

		// 红光确认相交后只形成pending，同周期红外仍使用9-bit，下一完整R/IR周期共同使用15-bit
		reg_test_case_id = 4'd6;            // 阶段六验证全局精度在R/IR成对安全边界提交
		@(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0; // 模拟9-bit红光事务前的ADC_RST清除S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 粗精度PPG周期保持第二级完成电平为低
		i_dout_stage1_low = 10'b0000000000; // 清除上一笔事务留下的S1物理总线
		i_dout_stage2_low = 10'b0000000000; // 9-bit红光事务不携带第二级物理码
		i_frame_id = 16'h6100;              // 为本次R/IR粗精度对分配共享PPG周期号
		i_sample_index = 16'h0200;          // 为成对红光与红外结果分配同一采样序号
		i_color_ir = 1'b0;                  // 先启动作为模式判断参考的红光事务
		i_frame_type = 2'b10;               // 成对模式检查发生在NORMAL采样阶段
		i_amb_code_snapshot = 8'h42;        // 粗精度PPG周期采用AMB码42
		i_dc_code_snapshot = 8'h62;         // 红光事务携带独立的DC_R码62
		i_amb_code_epoch = 4'h6;            // 绑定当前AMB安全提交版本
		i_dc_code_epoch = 4'h2;             // 绑定当前红光DC安全提交版本
		i_precision_mode_committed = 1'b0;  // 周期6100开始时全局模式仍为9-bit
		i_adc_transaction_start = 1'b1;     // 锁存红光颜色、周期号和粗精度模式
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束红光事务开始脉冲
		#53 i_dout_stage1_low = 10'b0011001101; // 建立红光第一级物理决策码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 红光S1完成后触发9-bit捕获
		wait(flag_detect_valid === 1'b1);   // 等待红光粗精度结果进入重构输出
		#1;
		dec_expected_ext = ((10'b0011001101 >> 4) * 8) +
			(10'b0011001101 & 7) + (((10'b0011001101 >> 3) & 1) ? 4 : -4); // 计算红光粗精度黄金重构结果
		if((stage1_code_ext_o !== dec_expected_ext[10:0]) || (precision_mode_o !== 1'b0) || (frame_id_o !== 16'h6100) || (sample_index_o !== 16'h0200) || (color_ir_o !== 1'b0) || (dc_code_snapshot_o !== 8'h62))begin
			cnt_error = cnt_error + 1;      // 记录共享周期中红光粗精度载荷发生错配
			$display("FAIL paired red coarse mode=%b frame=%h color=%b", precision_mode_o, frame_id_o, color_ir_o); // 报告红光成对合同差异
		end
		flag_precision_mode_pending_model = 1'b1; // 模拟红光向上相交确认后提出15-bit请求
		@(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录持续ready下红光结果未按时释放
			$display("FAIL paired red coarse result did not retire"); // 报告红光结果握手停滞
		end

		@(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0; // 红外事务ADC_RST清除红光S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 当前PPG周期仍未启用第二级ADC
		i_dout_stage1_low = 10'b0000000000; // 清除红光物理码后准备红外结果
		i_dout_stage2_low = 10'b0000000000; // 粗精度红外事务保持S2载荷无效
		i_frame_id = 16'h6100;              // 红外事务沿用红光的共享PPG周期号
		i_sample_index = 16'h0200;          // 红外结果与同周期红光使用相同样本序号
		i_color_ir = 1'b1;                  // 第二笔事务切换为红外通道
		i_dc_code_snapshot = 8'hb2;         // 红外事务携带独立的DC_IR码B2
		i_dc_code_epoch = 4'hc;             // 绑定当前红外DC安全提交版本
		i_precision_mode_committed = 1'b0;  // pending存在时同周期红外仍保持9-bit
		i_adc_transaction_start = 1'b1;     // 锁存红外颜色和尚未切换的全局模式
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束红外粗精度事务开始脉冲
		#53 i_dout_stage1_low = 10'b0100110110; // 建立红外第一级物理决策码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 红外S1完成后按9-bit边界捕获
		wait(flag_detect_valid === 1'b1);   // 等待红外粗精度结果与上下文配对
		#1;
		dec_expected_ext = ((10'b0100110110 >> 4) * 8) +
			(10'b0100110110 & 7) + (((10'b0100110110 >> 3) & 1) ? 4 : -4); // 计算红外粗精度黄金重构结果
		if((stage1_code_ext_o !== dec_expected_ext[10:0]) || (precision_mode_o !== 1'b0) || (frame_id_o !== 16'h6100) || (sample_index_o !== 16'h0200) || (color_ir_o !== 1'b1) || (dc_code_snapshot_o !== 8'hb2) || (flag_precision_mode_pending_model !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录pending错误提前改变同周期红外精度
			$display("FAIL paired IR coarse mode=%b frame=%h pending=%b", precision_mode_o, frame_id_o, flag_precision_mode_pending_model); // 报告红外安全边界差异
		end
		@(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录红外粗精度结果未被持续ready消费
			$display("FAIL paired IR coarse result did not retire"); // 报告同周期红外握手停滞
		end

		@(negedge i_clk);
		i_precision_mode_committed = flag_precision_mode_pending_model; // R/IR均完成后在下一PPG周期提交15-bit
		flag_precision_mode_pending_model = 1'b0; // 已提交请求不再保留为在途状态
		i_clk_stage1_dout_low_async = 1'b0; // 新高精度周期开始前ADC_RST清除S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 新高精度周期开始前ADC_RST清除S2 DONE
		i_dout_stage1_low = 10'b0000000000; // 清除上一周期红外S1物理码
		i_dout_stage2_low = 10'b0000000000; // 清除上一周期无效S2总线
		i_frame_id = 16'h6101;              // 为下一完整高精度R/IR对分配新周期号
		i_sample_index = 16'h0201;          // 高精度红光和红外共享下一样本序号
		i_color_ir = 1'b0;                  // 新周期仍从红光参考事务开始
		i_dc_code_snapshot = 8'h63;         // 高精度红光事务使用DC_R码63
		i_dc_code_epoch = 4'h3;             // 更新红光DC码版本字段
		i_adc_transaction_start = 1'b1;     // 锁存红光和已安全提交的15-bit模式
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束高精度红光事务开始脉冲
		#53 i_dout_stage1_low = 10'b1011001010; // 建立高精度红光S1物理码
		#3 i_clk_stage1_dout_low_async = 1'b1; // S1先完成但15-bit事务继续等待S2
		repeat(3) @(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录高精度红光错误地由S1提前触发
			$display("FAIL paired red fine completed before S2"); // 报告红光高精度完成边界错误
		end
		#47 i_dout_stage2_low = 10'b0010110101; // 建立同一红光事务的S2物理码
		#3 i_clk_stage2_dout_low_async = 1'b1; // S2完成后允许原子捕获两级数据
		wait(flag_detect_valid === 1'b1);   // 等待高精度红光结果进入输出缓存
		#1;
		if((precision_mode_o !== 1'b1) || (frame_id_o !== 16'h6101) || (sample_index_o !== 16'h0201) || (color_ir_o !== 1'b0) || (stage2_raw_o !== 10'b0010110101) || (dc_code_snapshot_o !== 8'h63))begin
			cnt_error = cnt_error + 1;      // 记录新周期红光未使用已提交15-bit模式
			$display("FAIL paired red fine mode=%b frame=%h s2=%h", precision_mode_o, frame_id_o, stage2_raw_o); // 报告红光高精度载荷差异
		end
		@(posedge i_clk);
		#1;

		@(negedge i_clk);
		i_clk_stage1_dout_low_async = 1'b0; // 高精度红外事务前清除红光S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // 高精度红外事务前清除红光S2 DONE
		i_dout_stage1_low = 10'b0000000000; // 清除高精度红光S1物理结果
		i_dout_stage2_low = 10'b0000000000; // 清除高精度红光S2物理结果
		i_frame_id = 16'h6101;              // 红外沿用本周期红光的PPG周期标识
		i_sample_index = 16'h0201;          // 红外沿用本周期红光的样本序号
		i_color_ir = 1'b1;                  // 第二笔高精度事务属于红外通道
		i_dc_code_snapshot = 8'hb3;         // 高精度红外事务使用DC_IR码B3
		i_dc_code_epoch = 4'hd;             // 更新红外DC码版本字段
		i_precision_mode_committed = 1'b1;  // 同一PPG周期红外继续使用全局15-bit模式
		i_adc_transaction_start = 1'b1;     // 锁存红外和与红光相同的高精度模式
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束高精度红外事务开始脉冲
		#53 i_dout_stage1_low = 10'b1100010111; // 建立高精度红外S1物理码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 红外S1完成但仍等待S2结束
		repeat(3) @(posedge i_clk);
		#47 i_dout_stage2_low = 10'b0101100011; // 建立同一红外事务的S2物理码
		#3 i_clk_stage2_dout_low_async = 1'b1; // 红外S2完成后触发双级捕获
		wait(flag_detect_valid === 1'b1);   // 等待高精度红外结果完成重构对齐
		#1;
		if((precision_mode_o !== 1'b1) || (frame_id_o !== 16'h6101) || (sample_index_o !== 16'h0201) || (color_ir_o !== 1'b1) || (stage2_raw_o !== 10'b0101100011) || (dc_code_snapshot_o !== 8'hb3))begin
			cnt_error = cnt_error + 1;      // 记录同周期红外未继承红光使用的全局模式
			$display("FAIL paired IR fine mode=%b frame=%h s2=%h", precision_mode_o, frame_id_o, stage2_raw_o); // 报告红外高精度载荷差异
		end
		@(posedge i_clk);
		#1;
		if(flag_detect_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录高精度R/IR配对结束后输出未释放
			$display("FAIL paired fine result did not retire"); // 报告高精度成对握手停滞
		end

		// 每个物理位组合都通过真实捕获接口进入重构器，并与黄金整数公式逐笔比较
		reg_test_case_id = 4'd4;            // 阶段四执行全部1024个S1物理输入组合
		for(cnt_raw_index = 0; cnt_raw_index < 1024; cnt_raw_index = cnt_raw_index + 1)begin
			@(negedge i_clk);
			i_clk_stage1_dout_low_async = 1'b0; // 每次ADC_RST先清除上笔S1 DONE
			i_clk_stage2_dout_low_async = 1'b0; // 9-bit遍历始终保持S2 DONE为低
			i_dout_stage1_low = 10'b0000000000; // ADC_RST阶段清除S1物理总线
			i_dout_stage2_low = 10'b0000000000; // 9-bit事务明确清除无效S2载荷
			i_frame_id = cnt_raw_index[15:0]; // 使用物理码索引作为可追踪帧号
			i_sample_index = cnt_raw_index[15:0] ^ 16'h5a5a; // 为样本编号生成独立可核对图样
			i_color_ir = cnt_raw_index[0];  // 交替验证红光与红外上下文
			i_frame_type = cnt_raw_index[2:1]; // 遍历全部两位帧类别编码
			i_amb_code_snapshot = cnt_raw_index[7:0]; // AMB码快照覆盖完整8-bit空间
			i_dc_code_snapshot = cnt_raw_index[7:0] ^ 8'ha5; // DC码使用与AMB不同的测试图样
			i_amb_code_epoch = cnt_raw_index[3:0]; // AMB版本随低四位循环
			i_dc_code_epoch = cnt_raw_index[3:0] ^ 4'ha; // DC版本保持独立可预测关系
			i_precision_mode_committed = 1'b0; // 全码遍历固定采用S1完成边界
			if(flag_transaction_ready !== 1'b1)begin
				cnt_error = cnt_error + 1;  // 记录上一事务没有正确释放上下文槽
				$display("FAIL transaction not ready before raw index=%0d", cnt_raw_index); // 报告遍历握手停滞点
			end
			i_adc_transaction_start = 1'b1; // 同时锁存本笔模式和数字上下文
			@(negedge i_clk);
			i_adc_transaction_start = 1'b0; // 事务开始脉冲严格保持一个周期
			#53 i_dout_stage1_low = cnt_raw_index[9:0]; // 在DONE前建立当前物理位组合
			#3 i_clk_stage1_dout_low_async = 1'b1; // 产生异步S1转换完成电平
			wait(flag_detect_valid === 1'b1); // 等待当前物理码完成跨模块交付
			#1;
			dec_expected_ext = ((cnt_raw_index >> 4) * 8) +
				(cnt_raw_index & 7) + (((cnt_raw_index >> 3) & 1) ? 4 : -4); // 复现Verilog-A decode_stage1_bits
			if(dec_expected_ext < 0)begin
				dec_expected_detect = 0;    // 负冗余扩展区饱和为零
			end else if(dec_expected_ext > 511)begin
				dec_expected_detect = 511;  // 正冗余扩展区饱和为511
			end else begin
				dec_expected_detect = dec_expected_ext; // 正常区间保持完整9-bit整数
			end
			if((stage1_raw_o !== cnt_raw_index[9:0]) || (stage1_code_ext_o !== dec_expected_ext[10:0]) || (detect_code_o !== dec_expected_detect[8:0]) || (stage2_raw_o !== 10'b0000000000) || (precision_mode_o !== 1'b0) || (frame_id_o !== cnt_raw_index[15:0]) || (sample_index_o !== (cnt_raw_index[15:0] ^ 16'h5a5a)) || (color_ir_o !== cnt_raw_index[0]) || (frame_type_o !== cnt_raw_index[2:1]) || (amb_code_snapshot_o !== cnt_raw_index[7:0]) || (dc_code_snapshot_o !== (cnt_raw_index[7:0] ^ 8'ha5)) || (amb_code_epoch_o !== cnt_raw_index[3:0]) || (dc_code_epoch_o !== (cnt_raw_index[3:0] ^ 4'ha)))begin
				cnt_error = cnt_error + 1;  // 记录黄金公式、饱和或元数据对齐差异
				$display("FAIL raw=%h ext=%0d/%0d detect=%0d/%0d frame=%h", cnt_raw_index[9:0], $signed(stage1_code_ext_o), dec_expected_ext, detect_code_o, dec_expected_detect, frame_id_o); // 报告当前物理码错误
			end
			@(posedge i_clk);
			#1;
			if(flag_detect_valid !== 1'b0)begin
				cnt_error = cnt_error + 1;  // 记录持续ready下同一物理码被重复输出
				$display("FAIL raw index=%0d produced repeated valid", cnt_raw_index); // 报告单笔事务消费错误
			end
		end

		// 数字复位在有效结果期间必须同时清除捕获、上下文和重构输出所有权
		reg_test_case_id = 4'd5;            // 阶段五验证流水中断复位行为
		@(negedge i_clk);
		i_detect_ready = 1'b0;              // 保持最后一笔测试结果用于复位打断
		i_clk_stage1_dout_low_async = 1'b0; // 清除全码遍历最后一个DONE
		i_frame_id = 16'h5e5e;              // 设置复位打断事务的帧号
		i_sample_index = 16'h0101;          // 设置复位打断事务的样本编号
		i_adc_transaction_start = 1'b1;     // 建立复位前最后一笔有效上下文
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束最后一笔事务启动脉冲
		#41 i_dout_stage1_low = 10'h155;    // 建立复位打断前的S1载荷
		#3 i_clk_stage1_dout_low_async = 1'b1; // 触发最后一笔9-bit捕获
		wait(flag_detect_valid === 1'b1);   // 确保重构输出确实处于有效保持状态
		#37 i_rstn = 1'b0;                  // 在非时钟沿异步施加全局数字复位
		#1;
		if((flag_detect_valid !== 1'b0) || (flag_capture_valid !== 1'b0) || (detect_code_o !== 9'b000000000) || (stage1_raw_o !== 10'b0000000000) || (stage1_code_ext_o !== 11'sd0) || (stage2_raw_o !== 10'b0000000000) || (precision_mode_o !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录异步复位未清除完整数据流水
			$display("FAIL active-result reset valid=%b capture=%b detect=%h ext=%0d", flag_detect_valid, flag_capture_valid, detect_code_o, $signed(stage1_code_ext_o)); // 报告复位清除差异
		end

		if(cnt_error == 0)begin
			$display("PASS ppg_adc_s1_redundancy_corrector integrated exhaustive checks"); // 全部真实接口和1024码自检通过
		end else begin
			$display("FAIL ppg_adc_s1_redundancy_corrector errors=%0d", cnt_error); // 汇总所有未通过检查数量
		end
		$finish;                            // 结束完整联合验证
	end

	// 独立看门狗防止ready/valid或异步DONE错误造成仿真永久等待
	initial begin
		#10000000;
		$display("FAIL timeout tb_ppg_adc_s1_redundancy_corrector"); // 报告测试未在10 ms内闭环
		$finish;                            // 超时后强制结束仿真进程
	end

	//------------模块实例化区域------------//
	// 真实异步捕获器把双级ADC保持接口转换为目的域ready/valid载荷
	ppg_adc_async_stage_capture
	#(
		.C_RAW_WIDTH(10)                    // 两级物理ADC输出固定为10-bit
	)ppg_adc_async_stage_capture_Inst_dut(
		.i_clk(i_clk),                      // 提供2 MHz目的域采样时钟
		.i_rstn(i_rstn),                    // 连接联合测试的低有效复位
		.i_adc_transaction_start(i_adc_transaction_start), // 与上下文重构器共用事务边界
		.i_precision_mode_committed(i_precision_mode_committed), // 提交本次9/15-bit转换模式
		.i_dout_stage1_low(i_dout_stage1_low), // 连接模拟S1物理决策总线
		.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async), // 连接异步S1转换完成电平
		.i_dout_stage2_low(i_dout_stage2_low), // 连接模拟S2物理决策总线
		.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async), // 连接异步S2转换完成电平
		.i_capture_ready(flag_capture_ready), // 接收重构器返回的RAW消费许可
		.o_capture_stage1_raw(capture_stage1_raw), // 输出目的域稳定S1载荷
		.o_capture_stage2_raw(capture_stage2_raw), // 输出目的域稳定S2载荷
		.o_capture_precision_mode(capture_precision_mode), // 输出与RAW原子对齐的精度快照
		.o_capture_valid(flag_capture_valid) // 声明当前捕获缓存拥有有效事务
	);

	// S1重构器保存事务上下文并在唯一RAW握手沿生成D1_EXT和9-bit检测码
	ppg_adc_s1_redundancy_corrector
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 匹配测试帧标识字段宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 匹配样本序号配置
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 匹配AMB/DC码值位宽
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH) // 匹配两组提交代号宽度
	)ppg_adc_s1_redundancy_corrector_Inst_dut(
		.i_clk(i_clk),                      // 连接与捕获模块一致的数字时钟
		.i_rstn(i_rstn),                    // 使用同一数字复位清空完整流水
		.i_adc_transaction_start(i_adc_transaction_start), // 在ADC转换前保存数字上下文
		.i_frame_id(i_frame_id),            // 提供当前待启动事务的帧号
		.i_sample_index(i_sample_index),    // 提供当前颜色样本编号
		.i_color_ir(i_color_ir),            // 指明本次转换属于R或IR
		.i_frame_type(i_frame_type),        // 传入AMB/DCS/NORMAL事务类别
		.i_amb_code_snapshot(i_amb_code_snapshot), // 传入模拟端实际使用的AMB码
		.i_dc_code_snapshot(i_dc_code_snapshot), // 传入本次R或IR实际DC码
		.i_amb_code_epoch(i_amb_code_epoch), // 传入AMB码安全提交代号
		.i_dc_code_epoch(i_dc_code_epoch),  // 传入DC码安全提交代号
		.i_capture_stage1_raw(capture_stage1_raw), // 接收捕获器稳定S1物理码
		.i_capture_stage2_raw(capture_stage2_raw), // 接收同一事务的S2物理码
		.i_capture_precision_mode(capture_precision_mode), // 接收捕获器实际精度快照
		.i_capture_valid(flag_capture_valid), // 接收保持型捕获载荷有效位
		.i_detect_ready(i_detect_ready),    // 施加后续检测链反压条件
		.o_transaction_ready(flag_transaction_ready), // 观察新ADC事务准入状态
		.o_capture_ready(flag_capture_ready), // 驱动捕获模块的结果消费许可
		.o_detect_code(detect_code_o),      // 观察饱和9-bit检测结果
		.o_stage1_raw(stage1_raw_o),        // 核对完整S1物理位与固定结果对齐
		.o_stage1_code_ext(stage1_code_ext_o), // 观察完整未饱和D1_EXT
		.o_stage2_raw(stage2_raw_o),        // 观察与S1对齐的S2透传码
		.o_precision_mode(precision_mode_o), // 观察结果事务的实际精度
		.o_detect_valid(flag_detect_valid), // 观察完整重构载荷有效状态
		.o_frame_id(frame_id_o),            // 核对帧号是否在事务开始时冻结
		.o_sample_index(sample_index_o),    // 核对样本编号是否与RAW配对
		.o_color_ir(color_ir_o),            // 核对红光与红外上下文隔离
		.o_frame_type(frame_type_o),        // 核对AMB/DCS/NORMAL路由字段
		.o_amb_code_snapshot(amb_code_snapshot_o), // 核对实际AMB码快照传递
		.o_dc_code_snapshot(dc_code_snapshot_o), // 核对当前颜色DC码快照传递
		.o_amb_code_epoch(amb_code_epoch_o), // 核对AMB版本标记对齐
		.o_dc_code_epoch(dc_code_epoch_o)   // 核对DC版本标记对齐
	);

endmodule
