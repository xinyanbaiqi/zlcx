`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/01
// Design Name:        PPG ADC Result Router Testbench
// Module Name:        tb_ppg_adc_result_router
// Description:        TestBench/Vivado/2022.2/ppg_adc_result_router
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md,
//                     ppg_adc_result_router.v
//
// Dependencies:       ppg_adc_result_router
//
// Version:            V1.0
// Revision Date:      2026/08/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/01            V1.0          Erie                  Create file.
// 2026/08/06            V1.0          Erie                  Check calibrated payload and version tags.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月01日
// 设计名称:           PPG ADC结果路由器测试平台
// 模块名称:           tb_ppg_adc_result_router
// 模块说明:           TestBench/Vivado/2022.2/ppg_adc_result_router
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md、
//                     ppg_adc_result_router.v
//
// 依赖文件:           ppg_adc_result_router
//
// 当前版本:           V1.0
// 修订日期:           2026年08月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月01日        V1.0          Erie                  创建文件
// 2026年08月06日        V1.0          Erie                  增加校准载荷、饱和状态和版本标签自检

// 定向验证完整Stage1校准事务的互斥路由、原子透传、反压隔离和错误类别处理
module tb_ppg_adc_result_router();

	//-------------配置参数区域-------------//
	// 仿真时钟和载荷宽度与PPG数字处理域默认配置保持一致
	localparam integer C_CLK_PERIOD = 32'd500; // 2 MHz观察时钟对应500 ns周期
	localparam integer C_FRAME_ID_WIDTH = 32'd16; // 测试帧标识采用16-bit宽度
	localparam integer C_SAMPLE_INDEX_WIDTH = 32'd16; // 样本编号覆盖16-bit事务顺序
	localparam integer C_IDAC_CODE_WIDTH = 32'd8; // AMB与DC码快照均使用8 bit
	localparam integer C_CODE_EPOCH_WIDTH = 32'd4; // 两组调码版本标签使用4 bit
	localparam integer C_CONFIG_EPOCH_WIDTH = 32'd8; // 完整ACTIVE配置版本采用8 bit
	localparam integer C_COEF_EPOCH_WIDTH = 32'd8; // Stage1系数组版本采用8 bit

	//---------------计数信号---------------//
	// 错误计数只在真实比较失败时增加，最终决定PASS或FAIL
	integer cnt_error;                      // 累计全部定向场景的接口错误数量

	//--------------寄存器信号--------------//
	// 测试平台按事务阶段驱动完整上游载荷和三个下游ready
	reg i_clk;                              // 为波形中的握手事件提供2 MHz观察边沿
	reg i_rstn;                             // 低有效复位直接关闭组合路由输出
	reg i_result_valid;                     // 模拟Stage1校准器保持型结果有效电平
	reg signed [11:0]i_calibrated_s1_value; // 输入正式Stage1校准残差
	reg i_calibration_applied;              // 输入本笔校准系数资格标签
	reg i_saturation_low;                   // 输入校准负向饱和诊断状态
	reg i_saturation_high;                  // 输入校准正向饱和诊断状态
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // 输入完整ACTIVE配置版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // 输入Stage1系数组版本
	reg [8:0]i_detect_code;                 // 输入第一级9-bit检测残差
	reg [9:0]i_stage1_raw;                  // 输入完整S1物理决策位用于透传检查
	reg signed [10:0]i_stage1_code_ext;     // 输入未钳位D1_EXT测试值
	reg [9:0]i_stage2_raw;                  // 输入高精度事务第二级物理码
	reg i_precision_mode;                   // 输入当前结果实际9/15-bit模式
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 输入R/IR共享PPG周期标识
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 输入当前ADC结果顺序编号
	reg i_color_ir;                         // 输入红光零或红外一的颜色标签
	reg [1:0]i_frame_type;                  // 驱动AMB、DCS、NORMAL及非法编码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 输入本次事务使用的AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 输入当前颜色对应的DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 输入AMB码提交版本标签
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 输入R或IR DC码提交版本
	reg i_amb_cal_ready;                    // 控制AMB分支立即接收或施加反压
	reg i_dc_cal_ready;                     // 控制共享DC分支的消费能力
	reg i_normal_ready;                     // 控制正常PPG链的载荷接收时刻
	reg [3:0]reg_test_case_id;              // 在Vivado波形中标识当前验证阶段

	//---------------标志信号---------------//
	// 单一传输标志把组合ready/valid解释为系统时钟沿上的事务消费事件
	wire flag_result_transfer;              // 上游结果在当前观察沿被选中分支接收

	//---------------输出信号---------------//
	// 观察上游反压、三路互斥valid、非法类别和完整共享载荷
	wire o_result_ready;                    // 当前目的分支反馈给S1重构器的ready
	wire o_amb_cal_valid;                   // AMB_CAL事务专用有效电平
	wire o_dc_cal_valid;                    // DCS_CAL事务专用有效电平
	wire o_normal_valid;                    // NORMAL事务专用有效电平
	wire o_frame_type_error;                // 输入11类别时出现的协议错误指示
	wire signed [11:0]o_calibrated_s1_value; // 路由后保持符号的Stage1校准残差
	wire o_calibration_applied;             // 输出与事务绑定的校准资格标签
	wire o_saturation_low;                  // 输出校准器产生的负向饱和状态
	wire o_saturation_high;                 // 输出校准器产生的正向饱和状态
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch; // 输出本笔完整配置版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch; // 输出本笔Stage1系数组版本
	wire [8:0]o_detect_code;                // 路由后保持不变的9-bit检测码
	wire [9:0]o_stage1_raw;                 // 路由后保持事务归属的S1物理决策位
	wire signed [10:0]o_stage1_code_ext;    // 路由后保留符号的D1_EXT结果
	wire [9:0]o_stage2_raw;                 // 路由后与事务绑定的S2物理码
	wire o_precision_mode;                  // 输出事务所属的精度模式
	wire [C_FRAME_ID_WIDTH - 1:0]o_frame_id; // 输出共享PPG周期编号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index; // 输出ADC事务顺序号
	wire o_color_ir;                        // 输出红光或红外标签
	wire [1:0]o_frame_type;                 // 输出原始帧类别编码
	wire [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot; // 输出AMB实际码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot; // 输出当前颜色DC实际码
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch; // 输出AMB调码版本号
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch; // 输出当前颜色DC版本号

	//-------------其他信号连线-------------//
	// 波形中的传输事件只在输入valid和返回ready同时为高时成立
	assign flag_result_transfer = i_result_valid && o_result_ready; // 标识当前系统沿将消费一笔输入事务

	//-----------主要任务处理区域-----------//
	// 固定周期时钟只用于组织同步事务和形成易读的ready/valid波形
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk; // 每250 ns翻转观察时钟电平
	end

	// 依次覆盖复位、三分支路由、反压保持、连续事务和非法类别安全丢弃
	initial begin
		i_clk = 1'b0;                       // 从低电平启动2 MHz观察时钟
		i_rstn = 1'b0;                      // 初始复位禁止任何输入事务被接收
		i_result_valid = 1'b0;              // 复位期间上游没有有效校准结果
		i_calibrated_s1_value = 12'sd0;     // 清除初始Stage1校准残差
		i_calibration_applied = 1'b0;       // 初始事务不声明正式校准资格
		i_saturation_low = 1'b0;            // 初始负向饱和状态清零
		i_saturation_high = 1'b0;           // 初始正向饱和状态清零
		i_config_epoch = 8'h00;             // 初始完整配置版本为零
		i_coef_epoch = 8'h00;               // 初始Stage1系数组版本为零
		i_detect_code = 9'd0;               // 清除初始9-bit检测载荷
		i_stage1_raw = 10'd0;               // 清除初始S1物理决策载荷
		i_stage1_code_ext = 11'sd0;         // 清除初始扩展码测试输入
		i_stage2_raw = 10'd0;               // 清除初始第二级物理码
		i_precision_mode = 1'b0;            // 初始事务采用9-bit精度标签
		i_frame_id = 16'd0;                 // 复位阶段帧号设为零
		i_sample_index = 16'd0;             // 复位阶段样本编号设为零
		i_color_ir = 1'b0;                  // 默认颜色标签选择红光
		i_frame_type = 2'b00;               // 空闲载荷字段使用AMB编码
		i_amb_code_snapshot = 8'd0;         // 初始环境光抵消码清零
		i_dc_code_snapshot = 8'd0;          // 初始共享DC IDAC码清零
		i_amb_code_epoch = 4'd0;            // 初始AMB提交版本为零
		i_dc_code_epoch = 4'd0;             // 初始颜色DC版本为零
		i_amb_cal_ready = 1'b0;             // 复位期间关闭AMB接收能力
		i_dc_cal_ready = 1'b0;              // 复位期间关闭DC控制分支
		i_normal_ready = 1'b0;              // 复位期间关闭正常PPG数据链
		reg_test_case_id = 4'd0;            // 阶段零对应全局复位检查
		cnt_error = 0;                      // 开始测试前清空失败累计值

		// RTR-01：复位期间全部握手、分支valid和错误指示保持关闭
		#125;
		if((o_result_ready !== 1'b0) || (o_amb_cal_valid !== 1'b0) || (o_dc_cal_valid !== 1'b0) || (o_normal_valid !== 1'b0) || (o_frame_type_error !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录复位期间存在握手或分支活动
			$display("FAIL reset outputs ready=%b amb=%b dc=%b normal=%b error=%b", o_result_ready, o_amb_cal_valid, o_dc_cal_valid, o_normal_valid, o_frame_type_error); // 报告复位输出异常
		end

		// RTR-02：释放复位且无输入事务时提前开放上游ready
		@(negedge i_clk);
		i_rstn = 1'b1;                      // 下降沿释放复位避免检查竞争
		@(posedge i_clk);
		#1;
		if(o_result_ready !== 1'b1)begin
			cnt_error = cnt_error + 1;      // 记录空闲路由器没有提前开放ready
			$display("FAIL idle router did not advertise ready"); // 指出无valid时ready语义错误
		end

		// RTR-03：AMB_CAL只激活环境光分支并逐位透传完整校准载荷
		reg_test_case_id = 4'd1;            // 阶段一展示AMB事务立即传输
		@(negedge i_clk);
		i_result_valid = 1'b1;              // 提交一笔完整AMB校准载荷
		i_calibrated_s1_value = -12'sd37;   // 使用负校准残差核对符号透传
		i_calibration_applied = 1'b1;       // 声明本笔使用合法片外拟合系数
		i_saturation_low = 1'b0;            // 当前负值仍位于12-bit范围内
		i_saturation_high = 1'b0;           // 当前结果没有正向饱和
		i_config_epoch = 8'h12;             // 绑定可识别的整套配置版本
		i_coef_epoch = 8'h34;               // 绑定独立Stage1系数组版本
		i_detect_code = 9'd271;             // 使用非边界残差便于波形识别
		i_stage1_raw = 10'h155;             // 提供可识别的S1物理决策组合
		i_stage1_code_ext = 11'sd271;       // 令扩展码与检测码在正常区一致
		i_stage2_raw = 10'h000;             // AMB粗校准不需要第二级结果
		i_precision_mode = 1'b0;            // AMB搜索使用S1 9-bit检测路径
		i_frame_id = 16'h0101;              // 标记首个环境光校准周期
		i_sample_index = 16'h0001;          // 设置本次结果的全局序号一
		i_color_ir = 1'b0;                  // AMB阶段颜色字段不参与控制
		i_frame_type = 2'b00;               // 选择AMB_CAL路由编码
		i_amb_code_snapshot = 8'h24;        // 绑定实际环境光抵消码24
		i_dc_code_snapshot = 8'h00;         // AMB校准合同要求DC码为零
		i_amb_code_epoch = 4'h2;            // 指明AMB码处于版本二
		i_dc_code_epoch = 4'h0;             // DC未启用时保持初始版本
		i_amb_cal_ready = 1'b1;             // 环境光控制器允许立即接收
		i_dc_cal_ready = 1'b0;              // 未选DC分支保持反压以验证隔离
		i_normal_ready = 1'b0;              // 未选正常链也保持不可接收
		@(posedge i_clk);
		#1;
		if((o_amb_cal_valid !== 1'b1) || (o_dc_cal_valid !== 1'b0) || (o_normal_valid !== 1'b0) || (o_result_ready !== 1'b1) || (flag_result_transfer !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录AMB类别未互斥送往正确目的分支
			$display("FAIL AMB route valid/ready selection"); // 报告环境光路由选择错误
		end
		if(($signed(o_calibrated_s1_value) !== -12'sd37) || (o_calibration_applied !== 1'b1) || (o_saturation_low !== 1'b0) || (o_saturation_high !== 1'b0) || (o_config_epoch !== 8'h12) || (o_coef_epoch !== 8'h34) || (o_detect_code !== 9'd271) || (o_stage1_raw !== 10'h155) || (o_stage1_code_ext !== 11'sd271) || (o_stage2_raw !== 10'h000) || (o_precision_mode !== 1'b0) || (o_frame_id !== 16'h0101) || (o_sample_index !== 16'h0001) || (o_color_ir !== 1'b0) || (o_frame_type !== 2'b00) || (o_amb_code_snapshot !== 8'h24) || (o_dc_code_snapshot !== 8'h00) || (o_amb_code_epoch !== 4'h2) || (o_dc_code_epoch !== 4'h0))begin
			cnt_error = cnt_error + 1;      // 记录共享载荷字段在AMB路由中发生改变
			$display("FAIL AMB payload forwarding"); // 报告环境光事务元数据透传错误
		end

		// RTR-04：红光DCS_CAL在共享DC控制器反压期间保持完整校准事务
		reg_test_case_id = 4'd2;            // 阶段二展示红光DC校准反压
		@(negedge i_clk);
		i_calibrated_s1_value = 12'sd2047;  // 注入最大未饱和正端校准值
		i_calibration_applied = 1'b1;       // 红光DC事务使用正式校准系数
		i_saturation_low = 1'b0;            // 最大范围内值不产生负饱和
		i_saturation_high = 1'b0;           // +2047仍然不应标记正饱和
		i_config_epoch = 8'h56;             // 改变完整配置标签验证事务更新
		i_coef_epoch = 8'h78;               // 改变系数组标签验证同步透传
		i_detect_code = 9'd410;             // 模拟红光残差高于目标窗口
		i_stage1_code_ext = 11'sd410;       // 保留对应未钳位第一级结果
		i_stage2_raw = 10'h000;             // DC搜索只消费第一级检测码
		i_precision_mode = 1'b0;            // DCS_CAL采用粗精度路径
		i_frame_id = 16'h0202;              // 设置红光DC校准帧号
		i_sample_index = 16'h0002;          // 设置第二笔ADC结果编号
		i_color_ir = 1'b0;                  // 选择共享控制器的红光状态库
		i_frame_type = 2'b01;               // 选择DCS_CAL路由编码
		i_amb_code_snapshot = 8'h24;        // DCS搜索期间保持AMB稳定码
		i_dc_code_snapshot = 8'h51;         // 记录本次红光实际使用DC码51
		i_amb_code_epoch = 4'h2;            // AMB版本必须延续前序稳定值
		i_dc_code_epoch = 4'h5;             // 红光DC码处于提交版本五
		i_amb_cal_ready = 1'b1;             // 未选AMB分支ready不影响当前事务
		i_dc_cal_ready = 1'b0;              // 共享DC控制器主动施加两拍反压
		i_normal_ready = 1'b1;              // 未选NORMAL分支保持ready验证隔离
		repeat(2)begin
			@(posedge i_clk);
			#1;
			if((o_dc_cal_valid !== 1'b1) || (o_amb_cal_valid !== 1'b0) || (o_normal_valid !== 1'b0) || (o_result_ready !== 1'b0) || ($signed(o_calibrated_s1_value) !== 12'sd2047) || (o_calibration_applied !== 1'b1) || (o_config_epoch !== 8'h56) || (o_coef_epoch !== 8'h78) || (o_detect_code !== 9'd410) || (o_color_ir !== 1'b0) || (o_dc_code_snapshot !== 8'h51))begin
				cnt_error = cnt_error + 1;  // 记录DC反压期间valid或载荷没有保持
				$display("FAIL red DCS backpressure hold"); // 报告红光DC校准稳定性错误
			end
		end
		@(negedge i_clk);
		i_dc_cal_ready = 1'b1;              // 开放共享DC控制器完成红光传输
		@(posedge i_clk);
		#1;
		if((o_dc_cal_valid !== 1'b1) || (o_result_ready !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录反压解除后事务仍无法消费
			$display("FAIL red DCS did not transfer after ready"); // 报告共享DC ready恢复路径错误
		end

		// RTR-05和RTR-08：红外DCS复用DC分支并保持signed负端边界
		reg_test_case_id = 4'd3;            // 阶段三展示红外共享DC路由
		@(negedge i_clk);
		i_calibrated_s1_value = 12'sh800;   // 注入signed 12-bit最小合法边界
		i_calibration_applied = 1'b1;       // 红外DC事务继续使用正式系数
		i_saturation_low = 1'b0;            // -2048恰在范围内不应报饱和
		i_saturation_high = 1'b0;           // 负端边界不产生正向诊断
		i_config_epoch = 8'h9a;             // 为红外事务设置独立配置图样
		i_coef_epoch = 8'hbc;               // 为红外事务设置系数版本图样
		i_detect_code = 9'd92;              // 模拟红外残差低于控制目标
		i_stage1_code_ext = 11'sd92;        // 传递红外扩展残差测试值
		i_frame_id = 16'h0202;              // R/IR校准可归属同一PPG周期
		i_sample_index = 16'h0003;          // 红外结果紧随红光结果排序
		i_color_ir = 1'b1;                  // 选择共享DC控制器的红外状态库
		i_dc_code_snapshot = 8'h87;         // 记录红外实际施加DC码87
		i_dc_code_epoch = 4'h9;             // 红外DC状态使用独立版本九
		i_dc_cal_ready = 1'b1;              // 允许红外校准事务立即消费
		@(posedge i_clk);
		#1;
		if((o_dc_cal_valid !== 1'b1) || (o_calibrated_s1_value !== 12'sh800) || (o_saturation_low !== 1'b0) || (o_config_epoch !== 8'h9a) || (o_coef_epoch !== 8'hbc) || (o_color_ir !== 1'b1) || (o_dc_code_snapshot !== 8'h87) || (o_dc_code_epoch !== 4'h9) || (o_result_ready !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录红外状态标签或码快照路由错误
			$display("FAIL infrared DCS shared-controller route"); // 报告R/IR复用DC接口异常
		end

		// RTR-06和RTR-09：NORMAL粗精度事务保留校准资格与独立版本语义
		reg_test_case_id = 4'd4;            // 阶段四展示正常粗精度测量
		@(negedge i_clk);
		i_calibrated_s1_value = 12'sd188;   // 输入与固定码同量级的校准残差
		i_calibration_applied = 1'b0;       // 构造CHARACTERIZATION资格透传场景
		i_saturation_low = 1'b0;            // 范围内正值没有负向饱和
		i_saturation_high = 1'b0;           // 范围内正值没有正向饱和
		i_config_epoch = 8'hde;             // 配置版本保持非零诊断图样
		i_coef_epoch = 8'ha5;               // 非零epoch不得强迫资格变为一
		i_detect_code = 9'd188;             // 提供正常红光S1检测结果
		i_stage1_code_ext = 11'sd188;       // 提供DC恢复前的扩展残差
		i_stage2_raw = 10'h000;             // 9-bit事务没有有效S2载荷
		i_precision_mode = 1'b0;            // 指明当前为粗精度正常测量
		i_frame_id = 16'h0303;              // 设置正常PPG周期三
		i_sample_index = 16'h0004;          // 设置第四笔ADC结果编号
		i_color_ir = 1'b0;                  // 正常测量首先发送红光结果
		i_frame_type = 2'b10;               // 选择NORMAL路由编码
		i_amb_code_snapshot = 8'h24;        // 保存正常积分使用的AMB稳定码
		i_dc_code_snapshot = 8'h55;         // 保存红光DC恢复所需码快照
		i_amb_code_epoch = 4'h2;            // 保持环境光码版本可追踪
		i_dc_code_epoch = 4'h6;             // 正常红光码对应版本六
		i_amb_cal_ready = 1'b0;             // 非选AMB分支反压不得阻塞NORMAL
		i_dc_cal_ready = 1'b0;              // 非选DC分支反压也应被完全隔离
		i_normal_ready = 1'b1;              // 正常数据链允许立即接收结果
		@(posedge i_clk);
		#1;
		if((o_normal_valid !== 1'b1) || (o_amb_cal_valid !== 1'b0) || (o_dc_cal_valid !== 1'b0) || ($signed(o_calibrated_s1_value) !== 12'sd188) || (o_calibration_applied !== 1'b0) || (o_config_epoch !== 8'hde) || (o_coef_epoch !== 8'ha5) || (o_precision_mode !== 1'b0) || (o_result_ready !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录粗精度NORMAL事务分支或模式错误
			$display("FAIL NORMAL 9-bit route"); // 报告正常9-bit测量选择异常
		end

		// RTR-07和RTR-10：NORMAL高精度事务在反压时保持S1校准值、S2和饱和状态
		reg_test_case_id = 4'd5;            // 阶段五展示高精度正常事务反压
		@(negedge i_clk);
		i_calibrated_s1_value = 12'sd2047;  // 正向越界后的饱和值固定为+2047
		i_calibration_applied = 1'b1;       // 合法系数资格与零epoch相互独立
		i_saturation_low = 1'b0;            // 当前事务没有负向溢出
		i_saturation_high = 1'b1;           // 标记校准器发生正向饱和
		i_config_epoch = 8'hff;             // 使用最大完整配置版本图样
		i_coef_epoch = 8'h00;               // 回绕到零仍保持calibration_applied为一
		i_detect_code = 9'd233;             // 高精度事务仍携带S1检测码
		i_stage1_code_ext = 11'sd233;       // 精细重构使用同事务D1_EXT
		i_stage2_raw = 10'h2a5;             // 提供可识别的第二级物理结果
		i_precision_mode = 1'b1;            // 指明S1和S2均已完成的15-bit事务
		i_frame_id = 16'h0303;              // 红外与红光共享正常PPG帧号
		i_sample_index = 16'h0005;          // 设置第五笔ADC结果编号
		i_color_ir = 1'b1;                  // 当前高精度结果属于红外通道
		i_dc_code_snapshot = 8'h89;         // 绑定红外DC_CODE_IR实际码
		i_dc_code_epoch = 4'ha;             // 绑定红外DC码版本十
		i_normal_ready = 1'b0;              // 正常PPG数据链施加一拍反压
		@(posedge i_clk);
		#1;
		if((o_normal_valid !== 1'b1) || (o_result_ready !== 1'b0) || ($signed(o_calibrated_s1_value) !== 12'sd2047) || (o_calibration_applied !== 1'b1) || (o_saturation_low !== 1'b0) || (o_saturation_high !== 1'b1) || (o_config_epoch !== 8'hff) || (o_coef_epoch !== 8'h00) || (o_precision_mode !== 1'b1) || (o_stage2_raw !== 10'h2a5) || (o_color_ir !== 1'b1) || (o_frame_id !== 16'h0303))begin
			cnt_error = cnt_error + 1;      // 记录15-bit载荷在反压期间丢失或错配
			$display("FAIL NORMAL 15-bit backpressure hold"); // 报告精细事务保持错误
		end
		@(negedge i_clk);
		i_normal_ready = 1'b1;              // 解除正常链反压允许高精度结果消费
		@(posedge i_clk);
		#1;
		if((o_normal_valid !== 1'b1) || (o_result_ready !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录正常链开放后未完成15-bit握手
			$display("FAIL NORMAL 15-bit did not transfer"); // 报告高精度事务ready选择错误
		end

		// RTR-11：三笔连续事务逐拍改变类别和校准载荷而不插入空拍
		reg_test_case_id = 4'd6;            // 阶段六展示AMB到DCS再到NORMAL连续流
		@(negedge i_clk);
		i_amb_cal_ready = 1'b1;             // 开放连续序列中的AMB目的端
		i_dc_cal_ready = 1'b1;              // 开放连续序列中的共享DC目的端
		i_normal_ready = 1'b1;              // 开放连续序列中的正常PPG目的端
		i_frame_type = 2'b00;               // 连续序列第一拍选择AMB_CAL
		i_sample_index = 16'h0006;          // 第一笔连续事务使用编号六
		i_calibrated_s1_value = -12'sd12;   // 第一笔使用可识别负残差
		i_calibration_applied = 1'b0;       // 第一笔保留未校准表征资格
		i_saturation_low = 1'b0;            // 第一笔没有负向饱和
		i_saturation_high = 1'b0;           // 第一笔没有正向饱和
		i_config_epoch = 8'h01;             // 第一笔绑定配置版本一
		i_coef_epoch = 8'ha5;               // 第一笔非零系数版本不改变资格位
		@(posedge i_clk);
		#1;
		if((o_amb_cal_valid !== 1'b1) || ($signed(o_calibrated_s1_value) !== -12'sd12) || (o_calibration_applied !== 1'b0) || (o_config_epoch !== 8'h01) || (o_coef_epoch !== 8'ha5) || (flag_result_transfer !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录连续序列第一拍没有完成AMB传输
			$display("FAIL continuous AMB transaction"); // 报告无空拍序列起点异常
		end
		@(negedge i_clk);
		i_frame_type = 2'b01;               // 连续序列第二拍切换DCS_CAL
		i_sample_index = 16'h0007;          // 第二笔连续事务使用编号七
		i_color_ir = 1'b0;                  // 中间事务更新红光DC状态
		i_calibrated_s1_value = 12'sd12;    // 第二笔切换为正向校准残差
		i_calibration_applied = 1'b1;       // 第二笔声明正式校准资格
		i_config_epoch = 8'h02;             // 第二笔推进完整配置图样
		i_coef_epoch = 8'h00;               // 零系数版本不应清除资格位
		@(posedge i_clk);
		#1;
		if((o_dc_cal_valid !== 1'b1) || (o_amb_cal_valid !== 1'b0) || ($signed(o_calibrated_s1_value) !== 12'sd12) || (o_calibration_applied !== 1'b1) || (o_config_epoch !== 8'h02) || (o_coef_epoch !== 8'h00) || (flag_result_transfer !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录连续类别切换出现重复或空拍
			$display("FAIL continuous DCS transaction"); // 报告连续序列中间拍异常
		end
		@(negedge i_clk);
		i_frame_type = 2'b10;               // 连续序列第三拍切换NORMAL
		i_sample_index = 16'h0008;          // 第三笔连续事务使用编号八
		i_precision_mode = 1'b0;            // 最后一笔采用正常9-bit模式
		i_calibrated_s1_value = 12'sh800;   // 第三笔使用负向饱和后的输出边界
		i_saturation_low = 1'b1;            // 第三笔携带负向饱和诊断
		i_saturation_high = 1'b0;           // 第三笔保持正向饱和关闭
		i_config_epoch = 8'h03;             // 第三笔绑定配置版本三
		i_coef_epoch = 8'hff;               // 第三笔使用最大系数版本图样
		@(posedge i_clk);
		#1;
		if((o_normal_valid !== 1'b1) || (o_dc_cal_valid !== 1'b0) || (o_calibrated_s1_value !== 12'sh800) || (o_saturation_low !== 1'b1) || (o_saturation_high !== 1'b0) || (o_config_epoch !== 8'h03) || (o_coef_epoch !== 8'hff) || (flag_result_transfer !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录连续序列末拍未路由到正常链
			$display("FAIL continuous NORMAL transaction"); // 报告三类逐拍传输终点异常
		end

		// RTR-12：保留编码11不进入功能分支并通过错误指示直接消费
		reg_test_case_id = 4'd7;            // 阶段七展示非法类别诊断策略
		@(negedge i_clk);
		i_frame_type = 2'b11;               // 注入尚未定义的保留帧类型
		i_amb_cal_ready = 1'b0;             // 所有正常分支均施加反压验证错误旁路
		i_dc_cal_ready = 1'b0;              // 关闭共享DC目的端接收能力
		i_normal_ready = 1'b0;              // 关闭正常测量目的端接收能力
		@(posedge i_clk);
		#1;
		if((o_frame_type_error !== 1'b1) || (o_amb_cal_valid !== 1'b0) || (o_dc_cal_valid !== 1'b0) || (o_normal_valid !== 1'b0) || (o_result_ready !== 1'b1) || (flag_result_transfer !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录非法事务未被隔离或造成永久阻塞
			$display("FAIL reserved frame-type handling"); // 报告错误出口协议不符合预期
		end

		// RTR-13：有效NORMAL事务等待下游时施加复位并立即关闭控制输出
		reg_test_case_id = 4'd8;            // 阶段八验证反压期间异步复位门控
		@(negedge i_clk);
		i_frame_type = 2'b10;               // 恢复合法正常测量类别
		i_normal_ready = 1'b0;              // 令事务在复位到来前保持等待
		@(posedge i_clk);
		#1;
		if((o_normal_valid !== 1'b1) || (o_result_ready !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录复位前没有形成预期等待状态
			$display("FAIL reset-interrupt setup"); // 报告复位场景准备条件错误
		end
		#37;
		i_rstn = 1'b0;                      // 在非时钟边沿模拟全局数字复位到来
		#1;
		if((o_result_ready !== 1'b0) || (o_amb_cal_valid !== 1'b0) || (o_dc_cal_valid !== 1'b0) || (o_normal_valid !== 1'b0) || (o_frame_type_error !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录复位未立即关闭组合握手控制
			$display("FAIL asynchronous reset gating"); // 报告路由器复位门控错误
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;              // 复位期间撤销测试平台输入有效电平
		i_rstn = 1'b1;                      // 重新释放复位检查空闲恢复
		@(posedge i_clk);
		#1;
		if(o_result_ready !== 1'b1)begin
			cnt_error = cnt_error + 1;      // 记录复位结束后路由器未恢复空闲ready
			$display("FAIL router did not recover after reset"); // 报告复位恢复路径异常
		end

		reg_test_case_id = 4'd9;            // 阶段九表示全部定向用例已经结束
		if(cnt_error == 0)begin
			$display("PASS ppg_adc_result_router RTR-01..RTR-13"); // 仅在全部合同用例真实比较通过后报告成功
		end else begin
			$display("FAIL ppg_adc_result_router errors=%0d", cnt_error); // 汇总全部失败数供日志门禁识别
		end
		#500;
		$finish;                            // 保留一拍完成波形后结束正常仿真
	end

	// 独立看门狗防止时钟等待或激励流程错误造成仿真永久挂起
	initial begin
		#30000;
		$display("FAIL ppg_adc_result_router watchdog timeout"); // 超时直接说明测试流程没有正常结束
		$finish;                            // 强制关闭挂起的xsim会话
	end

	// 实例化待验证的三分支PPG ADC结果路由器
	ppg_adc_result_router
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 对齐测试帧号字段宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 对齐样本顺序编号位宽
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 对齐两组IDAC快照位宽
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 对齐调码版本字段宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 对齐完整配置版本位宽
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 对齐Stage1系数组版本位宽
	)u_ppg_adc_result_router(
		.i_rstn(i_rstn),                    // 连接测试平台低有效复位
		.i_result_valid(i_result_valid),    // 驱动上游保持型事务valid
		.i_calibrated_s1_value(i_calibrated_s1_value), // 驱动signed 12-bit校准残差
		.i_calibration_applied(i_calibration_applied), // 驱动本笔系数合法资格
		.i_saturation_low(i_saturation_low), // 驱动负向饱和诊断状态
		.i_saturation_high(i_saturation_high), // 驱动正向饱和诊断状态
		.i_config_epoch(i_config_epoch),    // 驱动完整ACTIVE配置版本
		.i_coef_epoch(i_coef_epoch),        // 驱动Stage1系数组版本
		.i_detect_code(i_detect_code),      // 传入9-bit ADC检测残差
		.i_stage1_raw(i_stage1_raw),        // 传入逐物理位校准所需S1原始码
		.i_stage1_code_ext(i_stage1_code_ext), // 传入未钳位第一级扩展码
		.i_stage2_raw(i_stage2_raw),        // 传入高精度第二级物理码
		.i_precision_mode(i_precision_mode), // 传入事务实际精度标签
		.i_frame_id(i_frame_id),            // 传入R/IR共享PPG帧号
		.i_sample_index(i_sample_index),    // 传入全局ADC结果序号
		.i_color_ir(i_color_ir),            // 传入颜色状态库选择标签
		.i_frame_type(i_frame_type),        // 传入三类帧路由编码
		.i_amb_code_snapshot(i_amb_code_snapshot), // 传入AMB实际施加码快照
		.i_dc_code_snapshot(i_dc_code_snapshot), // 传入当前颜色DC码快照
		.i_amb_code_epoch(i_amb_code_epoch), // 传入AMB码安全提交版本
		.i_dc_code_epoch(i_dc_code_epoch),  // 传入当前颜色DC码版本
		.i_amb_cal_ready(i_amb_cal_ready),  // 驱动环境光控制分支ready
		.i_dc_cal_ready(i_dc_cal_ready),    // 驱动共享DC控制分支ready
		.i_normal_ready(i_normal_ready),    // 驱动正常PPG处理链ready
		.o_result_ready(o_result_ready),    // 观察返回上游的选择后ready
		.o_amb_cal_valid(o_amb_cal_valid),  // 观察AMB校准专用valid
		.o_dc_cal_valid(o_dc_cal_valid),    // 观察DCS校准专用valid
		.o_normal_valid(o_normal_valid),    // 观察正常测量专用valid
		.o_frame_type_error(o_frame_type_error), // 观察保留类别错误指示
		.o_calibrated_s1_value(o_calibrated_s1_value), // 核对正式Stage1校准值透传
		.o_calibration_applied(o_calibration_applied), // 核对校准资格未被重算
		.o_saturation_low(o_saturation_low), // 核对负向饱和状态传播
		.o_saturation_high(o_saturation_high), // 核对正向饱和状态传播
		.o_config_epoch(o_config_epoch),    // 核对完整配置版本绑定
		.o_coef_epoch(o_coef_epoch),        // 核对Stage1系数组版本绑定
		.o_detect_code(o_detect_code),      // 核对共享9-bit载荷透传
		.o_stage1_raw(o_stage1_raw),        // 核对S1物理位没有被路由器改变
		.o_stage1_code_ext(o_stage1_code_ext), // 核对有符号D1_EXT透传
		.o_stage2_raw(o_stage2_raw),        // 核对同事务S2码透传
		.o_precision_mode(o_precision_mode), // 核对输出精度元数据
		.o_frame_id(o_frame_id),            // 核对PPG周期身份字段
		.o_sample_index(o_sample_index),    // 核对ADC结果排序标签
		.o_color_ir(o_color_ir),            // 核对红光或红外标志
		.o_frame_type(o_frame_type),        // 核对原始帧类别保留
		.o_amb_code_snapshot(o_amb_code_snapshot), // 核对AMB码快照透传
		.o_dc_code_snapshot(o_dc_code_snapshot), // 核对当前颜色DC码透传
		.o_amb_code_epoch(o_amb_code_epoch), // 核对AMB版本标签传播
		.o_dc_code_epoch(o_dc_code_epoch)   // 核对颜色DC版本标签传播
	);

endmodule
