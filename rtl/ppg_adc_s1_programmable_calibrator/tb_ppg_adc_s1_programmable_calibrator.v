`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/06
// Design Name:        PPG ADC Stage1 Programmable Calibrator Testbench
// Module Name:        tb_ppg_adc_s1_programmable_calibrator
// Description:        TestBench/Vivado/2022.2/ppg_adc_s1_programmable_calibrator
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// Dependencies:       ppg_adc_s1_programmable_calibrator
//
// Version:            V1.0
// Revision Date:      2026/08/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/06            V1.0          Erie                  Create self-checking testbench.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月06日
// 设计名称:           PPG ADC Stage1可编程校准器自检平台
// 模块名称:           tb_ppg_adc_s1_programmable_calibrator
// 模块说明:           TestBench/Vivado/2022.2/ppg_adc_s1_programmable_calibrator
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// 依赖文件:           ppg_adc_s1_programmable_calibrator
//
// 当前版本:           V1.0
// 修订日期:           2026年08月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月06日        V1.0          Erie                  创建CAL-01至CAL-17自检平台

module tb_ppg_adc_s1_programmable_calibrator();

	//-------------配置参数区域-------------//
	// 固定V1默认位宽用于覆盖完整生产接口和原子payload保持
	localparam integer C_FRAME_ID_WIDTH = 16; // 测试R/IR共享帧号的默认宽度
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 测试颜色内样本序号的默认宽度
	localparam integer C_IDAC_CODE_WIDTH = 8; // 测试AMB和颜色DC码快照宽度
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 测试IDAC码版本标签宽度
	localparam integer C_CONFIG_EPOCH_WIDTH = 8; // 测试完整ACTIVE配置版本宽度
	localparam integer C_COEF_EPOCH_WIDTH = 8; // 测试Stage1系数组版本宽度
	localparam integer C_OBSERVED_PAYLOAD_WIDTH = 131; // 汇总全部DUT输出字段的比较宽度

	//--------------计数器信号--------------//
	// 循环索引和错误计数确保穷举完成后才允许报告PASS
	integer cnt_raw_code;                   // 遍历全部1024个S1物理码
	integer cnt_bit_index;                  // 遍历十个one-hot物理位
	integer cnt_hold_cycle;                 // 统计反压和无效输入保持周期
	integer cnt_expected_value;             // 保存独立黄金模型的当前整数结果
	integer cnt_error;                      // 累计全部CAL用例失败数量

	//--------------寄存器信号--------------//
	// 全局和ACTIVE配置激励保持到DUT在时钟沿接收
	reg i_clk;                              // 产生100 MHz语义仿真时钟以缩短回归时间
	reg i_rstn;                             // 驱动低有效异步复位
	reg i_active_valid;                     // 控制DUT是否允许接纳新输入事务
	reg i_stage1_calibration_valid;         // 指明当前权重是否属于合法片外校准
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // 驱动完整配置版本标签
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // 驱动Stage1系数版本标签
	reg signed [25:0]i_stage1_weight_q16_0; // 驱动S1_RAW[0]的Q16绝对权重
	reg signed [25:0]i_stage1_weight_q16_1; // 驱动S1_RAW[1]的Q16绝对权重
	reg signed [25:0]i_stage1_weight_q16_2; // 驱动S1_RAW[2]的Q16绝对权重
	reg signed [25:0]i_stage1_weight_q16_3; // 驱动S1_RAW[3]冗余支路权重
	reg signed [25:0]i_stage1_weight_q16_4; // 驱动S1_RAW[4]主8.0支路权重
	reg signed [25:0]i_stage1_weight_q16_5; // 驱动S1_RAW[5]的Q16权重
	reg signed [25:0]i_stage1_weight_q16_6; // 驱动S1_RAW[6]的Q16权重
	reg signed [25:0]i_stage1_weight_q16_7; // 驱动S1_RAW[7]的Q16权重
	reg signed [25:0]i_stage1_weight_q16_8; // 驱动S1_RAW[8]的Q16权重
	reg signed [25:0]i_stage1_weight_q16_9; // 驱动S1_RAW[9]的Q16权重
	reg signed [31:0]i_stage1_offset_q16; // 驱动逐物理位乘加使用的Q16偏置

	// 上游事务激励覆盖数值字段和每个路由元数据字段
	reg i_result_valid;                     // 驱动S1固定重构器侧保持型valid
	reg [9:0]i_stage1_raw;                  // 驱动十个物理判决位
	reg [8:0]i_detect_code;                 // 驱动固定黄金9-bit观察码
	reg signed [10:0]i_stage1_code_ext;     // 驱动未钳位D1_EXT诊断值
	reg [9:0]i_stage2_raw;                  // 驱动后续精细链物理码
	reg i_precision_mode;                   // 驱动事务精度快照
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 驱动共享PPG周期编号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 驱动颜色内样本编号
	reg i_color_ir;                         // 驱动红光或红外身份
	reg [1:0]i_frame_type;                  // 驱动AMB、DCS或NORMAL类型
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 驱动本次AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 驱动本次颜色DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 驱动AMB码提交版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 驱动颜色DC码提交版本
	reg i_calibrated_ready;                 // 驱动router侧下游接收许可
	reg [C_OBSERVED_PAYLOAD_WIDTH - 1:0]reg_payload_hold; // 保存反压开始时的完整输出快照

	//---------------其他信号---------------//
	// DUT输出观察线与冻结端口逐一对应
	wire o_result_ready;                    // 观察上游输入接收许可
	wire o_calibrated_valid;                // 观察输出保持型valid
	wire signed [11:0]o_calibrated_s1_value; // 观察signed 12-bit校准值
	wire o_calibration_applied;             // 观察片外校准资格快照
	wire o_saturation_low;                  // 观察负向端点保护
	wire o_saturation_high;                 // 观察正向端点保护
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch; // 观察事务绑定配置版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch; // 观察事务绑定系数版本
	wire [9:0]o_stage1_raw;                 // 观察原子透传S1物理码
	wire [8:0]o_detect_code;                // 观察原子透传固定检测码
	wire signed [10:0]o_stage1_code_ext;    // 观察原子透传D1_EXT
	wire [9:0]o_stage2_raw;                 // 观察原子透传S2物理码
	wire o_precision_mode;                  // 观察输出精度模式
	wire [C_FRAME_ID_WIDTH - 1:0]o_frame_id; // 观察输出共享帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index; // 观察输出样本编号
	wire o_color_ir;                        // 观察输出颜色属性
	wire [1:0]o_frame_type;                 // 观察输出事务类别
	wire [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot; // 观察输出AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot; // 观察输出颜色DC码快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch; // 观察输出AMB码版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch; // 观察输出颜色DC码版本
	wire [C_OBSERVED_PAYLOAD_WIDTH - 1:0]dec_observed_payload; // 汇总全部保持型输出供逐拍稳定比较

	//-------------其他信号连线-------------//
	// 输出汇总顺序与DUT内部冻结payload一致，便于反压期间一次比较全部字段
	assign dec_observed_payload = {
		o_calibrated_s1_value,
		o_calibration_applied,
		o_saturation_low,
		o_saturation_high,
		o_config_epoch,
		o_coef_epoch,
		o_stage1_raw,
		o_detect_code,
		o_stage1_code_ext,
		o_stage2_raw,
		o_precision_mode,
		o_frame_id,
		o_sample_index,
		o_color_ir,
		o_frame_type,
		o_amb_code_snapshot,
		o_dc_code_snapshot,
		o_amb_code_epoch,
		o_dc_code_epoch
	};                                      // 捕获输出载荷任一位的非预期变化

	//-------------主要任务处理区域-------------//
	// 自由运行时钟只用于testbench，不进入任何设计RTL
	always begin
		#5;
		i_clk = ~i_clk;                      // 每5 ns翻转一次形成10 ns周期
	end

	// 依次执行复位、穷举算术、舍入饱和、配置门控和事务保持检查
	initial begin
		i_clk = 1'b0;                        // 仿真从确定低电平时钟开始
		i_rstn = 1'b0;                       // CAL-01首先保持数字复位
		i_active_valid = 1'b0;               // 复位期间ACTIVE快照不具备资格
		i_stage1_calibration_valid = 1'b0;   // 初始不声明片外校准有效
		i_config_epoch = 8'h00;              // 初始完整配置版本为零
		i_coef_epoch = 8'h00;                // 初始系数组版本为零
		i_stage1_weight_q16_0 = 26'sd65536; // 装入标称vd0权重
		i_stage1_weight_q16_1 = 26'sd131072; // 装入标称vd1权重
		i_stage1_weight_q16_2 = 26'sd262144; // 装入标称vd2权重
		i_stage1_weight_q16_3 = 26'sd524288; // 装入标称冗余8.0权重
		i_stage1_weight_q16_4 = 26'sd524288; // 装入标称主8.0权重
		i_stage1_weight_q16_5 = 26'sd1048576; // 装入标称16.0权重
		i_stage1_weight_q16_6 = 26'sd2097152; // 装入标称32.0权重
		i_stage1_weight_q16_7 = 26'sd4194304; // 装入标称64.0权重
		i_stage1_weight_q16_8 = 26'sd8388608; // 装入标称128.0权重
		i_stage1_weight_q16_9 = 26'sd16777216; // 装入标称256.0权重
		i_stage1_offset_q16 = -32'sd262144;  // 装入标称负4.0偏置
		i_result_valid = 1'b0;               // 复位期间不发送S1事务
		i_stage1_raw = 10'b0000000000;       // 清除物理位激励
		i_detect_code = 9'd0;                // 清除固定检测码激励
		i_stage1_code_ext = 11'sd0;          // 清除D1_EXT激励
		i_stage2_raw = 10'b0000000000;       // 清除S2物理码激励
		i_precision_mode = 1'b0;             // 默认粗精度事务
		i_frame_id = 16'h0000;               // 初始帧号清零
		i_sample_index = 16'h0000;           // 初始样本编号清零
		i_color_ir = 1'b0;                   // 初始选择红光身份
		i_frame_type = 2'b00;                // 初始选择AMB_CAL类别
		i_amb_code_snapshot = 8'h00;         // 初始AMB码快照清零
		i_dc_code_snapshot = 8'h00;          // 初始DC码快照清零
		i_amb_code_epoch = 4'h0;             // 初始AMB码版本清零
		i_dc_code_epoch = 4'h0;              // 初始DC码版本清零
		i_calibrated_ready = 1'b0;           // 复位期间下游不接收载荷
		reg_payload_hold = {C_OBSERVED_PAYLOAD_WIDTH{1'b0}}; // 清除反压比较快照
		cnt_expected_value = 0;              // 清除黄金整数结果
		cnt_error = 0;                       // 从无失败记录开始回归

		#2;
		if(o_calibrated_valid || o_result_ready ||
			(dec_observed_payload !== {C_OBSERVED_PAYLOAD_WIDTH{1'b0}}))begin
			$display("FAIL CAL-01 reset outputs"); // 报告复位值或ready门控异常
			cnt_error = cnt_error + 1;         // 累计CAL-01失败
		end
		@(negedge i_clk);
		i_rstn = 1'b1;                       // 在下降沿释放复位避免竞争
		i_active_valid = 1'b1;               // 允许后续事务使用标称ACTIVE配置
		i_calibrated_ready = 1'b1;           // 下游持续接收穷举结果

		// CAL-02：标称权重穷举全部1024个物理码并独立复现固定D1_EXT
		i_result_valid = 1'b1;               // 连续保持valid实现无气泡输入
		for(cnt_raw_code = 0; cnt_raw_code < 1024; cnt_raw_code = cnt_raw_code + 1)begin
			@(negedge i_clk);
			i_stage1_raw = cnt_raw_code[9:0]; // 驱动当前十位物理码
			cnt_expected_value = ((((cnt_raw_code >> 4) & 63) * 8) +
				(cnt_raw_code & 7) + (((cnt_raw_code >> 3) & 1) ? 4 : -4)); // 独立整数黄金公式
			i_stage1_code_ext = cnt_expected_value; // 透传字段使用同一笔黄金扩展值
			i_detect_code = (cnt_expected_value < 0) ? 9'd0 :
				(cnt_expected_value > 511) ? 9'd511 : cnt_expected_value[8:0]; // 构造固定钳位观察码
			i_stage2_raw = (~cnt_raw_code) & 10'h3ff; // 让S2透传字段随穷举码反相变化
			i_precision_mode = cnt_raw_code[0]; // 交替覆盖粗精度和细精度属性
			i_frame_id = 16'h4000 + cnt_raw_code; // 为每个物理码生成唯一帧号
			i_sample_index = cnt_raw_code;     // 使用物理码索引作为样本号
			i_color_ir = cnt_raw_code[1];      // 交替覆盖红光和红外身份
			i_frame_type = cnt_raw_code[3:2]; // 变化事务类型以检查透明保持
			i_amb_code_snapshot = cnt_raw_code[7:0]; // 变化AMB码快照
			i_dc_code_snapshot = ~cnt_raw_code[7:0]; // 变化颜色DC码快照
			i_amb_code_epoch = cnt_raw_code[3:0]; // 变化AMB提交版本
			i_dc_code_epoch = cnt_raw_code[7:4]; // 变化颜色DC提交版本
			@(posedge i_clk);
			#1;
			if(!o_calibrated_valid ||
				($signed(o_calibrated_s1_value) !== cnt_expected_value) ||
				o_saturation_low || o_saturation_high || o_calibration_applied ||
				(o_stage1_raw !== cnt_raw_code[9:0]) ||
				(o_stage1_code_ext !== cnt_expected_value) ||
				(o_frame_id !== (16'h4000 + cnt_raw_code)) ||
				(o_sample_index !== cnt_raw_code[15:0]))begin
				$display("FAIL CAL-02 raw=%0d expected=%0d actual=%0d", cnt_raw_code, cnt_expected_value, $signed(o_calibrated_s1_value)); // 报告首次级别逐码偏差
				cnt_error = cnt_error + 1;     // 累计标称穷举错误
			end
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 停止穷举输入并允许最后结果消费
		@(posedge i_clk);
		#1;
		if(o_calibrated_valid)begin
			$display("FAIL CAL-02 valid drain"); // 报告无替换输入时valid未清零
			cnt_error = cnt_error + 1;         // 累计穷举排空失败
		end

		// CAL-03：使用十个唯一整数权重确认RAW索引不会错位
		i_stage1_weight_q16_0 = 26'sd65536; // one-hot位0期望整数1
		i_stage1_weight_q16_1 = 26'sd131072; // one-hot位1期望整数2
		i_stage1_weight_q16_2 = 26'sd196608; // one-hot位2期望整数3
		i_stage1_weight_q16_3 = 26'sd262144; // one-hot冗余位期望整数4
		i_stage1_weight_q16_4 = 26'sd327680; // one-hot主8.0位期望整数5
		i_stage1_weight_q16_5 = 26'sd393216; // one-hot位5期望整数6
		i_stage1_weight_q16_6 = 26'sd458752; // one-hot位6期望整数7
		i_stage1_weight_q16_7 = 26'sd524288; // one-hot位7期望整数8
		i_stage1_weight_q16_8 = 26'sd589824; // one-hot位8期望整数9
		i_stage1_weight_q16_9 = 26'sd655360; // one-hot位9期望整数10
		i_stage1_offset_q16 = 32'sd0;        // 清除偏置隔离one-hot权重贡献
		i_stage1_calibration_valid = 1'b1;   // 标记当前唯一权重组为校准配置
		i_result_valid = 1'b1;               // 连续发送十个one-hot事务
		for(cnt_bit_index = 0; cnt_bit_index < 10; cnt_bit_index = cnt_bit_index + 1)begin
			@(negedge i_clk);
			i_stage1_raw = 10'b0000000001 << cnt_bit_index; // 仅置当前物理判决位
			cnt_expected_value = cnt_bit_index + 1; // 唯一权重直接标识RAW索引
			@(posedge i_clk);
			#1;
			if(($signed(o_calibrated_s1_value) !== cnt_expected_value) ||
				!o_calibration_applied || o_saturation_low || o_saturation_high)begin
				$display("FAIL CAL-03 bit=%0d actual=%0d", cnt_bit_index, $signed(o_calibrated_s1_value)); // 报告物理位权重映射异常
				cnt_error = cnt_error + 1;     // 累计one-hot映射失败
			end
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 结束one-hot输入流
		@(posedge i_clk);

		// CAL-04：混合负权重和负offset检查完整signed扩展
		@(negedge i_clk);
		i_stage1_weight_q16_0 = -26'sd81920; // 位0贡献-1.25
		i_stage1_weight_q16_1 = 26'sd163840; // 位1贡献+2.5
		i_stage1_weight_q16_2 = -26'sd32768; // 位2贡献-0.5
		i_stage1_weight_q16_3 = 26'sd0;      // 清除其余物理位贡献
		i_stage1_weight_q16_4 = 26'sd0;      // 清除主8.0位测试贡献
		i_stage1_weight_q16_5 = 26'sd0;      // 清除位5测试贡献
		i_stage1_weight_q16_6 = 26'sd0;      // 清除位6测试贡献
		i_stage1_weight_q16_7 = 26'sd0;      // 清除位7测试贡献
		i_stage1_weight_q16_8 = 26'sd0;      // 清除位8测试贡献
		i_stage1_weight_q16_9 = 26'sd0;      // 清除位9测试贡献
		i_stage1_offset_q16 = -32'sd49152;   // 叠加-0.75后两项结果恰为+0.5
		i_stage1_raw = 10'b0000000011;       // 选择-1.25和+2.5两个权重
		i_result_valid = 1'b1;               // 发送signed混合事务
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== 1)begin
			$display("FAIL CAL-04 signed accumulation actual=%0d", $signed(o_calibrated_s1_value)); // 报告负权重或offset扩展错误
			cnt_error = cnt_error + 1;         // 累计signed乘加失败
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 结束signed混合事务
		@(posedge i_clk);

		// CAL-05：权重清零后直接用offset构造六个正负半LSB边界
		i_stage1_weight_q16_0 = 26'sd0;      // 清零位0权重隔离舍入器
		i_stage1_weight_q16_1 = 26'sd0;      // 清零位1权重隔离舍入器
		i_stage1_weight_q16_2 = 26'sd0;      // 清零位2权重隔离舍入器
		i_stage1_raw = 10'b0000000000;       // 全零RAW使累加器只包含offset
		i_result_valid = 1'b1;               // 连续发送六个舍入边界
		@(negedge i_clk);
		i_stage1_offset_q16 = 32'sd32767;    // 构造略小于正0.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== 0)begin
			$display("FAIL CAL-05 positive below half"); // 报告正半LSB以下误进位
			cnt_error = cnt_error + 1;         // 累计正向舍入失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = 32'sd32768;    // 构造精确正0.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== 1)begin
			$display("FAIL CAL-05 positive half tie"); // 报告正半LSB未远离零
			cnt_error = cnt_error + 1;         // 累计正tie失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = 32'sd98304;    // 构造精确正1.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== 2)begin
			$display("FAIL CAL-05 positive one-half"); // 报告正1.5舍入结果错误
			cnt_error = cnt_error + 1;         // 累计正幅度舍入失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = -32'sd32767;   // 构造略大于负0.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== 0)begin
			$display("FAIL CAL-05 negative below half"); // 报告负半LSB以内产生偏置
			cnt_error = cnt_error + 1;         // 累计负向零附近失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = -32'sd32768;   // 构造精确负0.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== -1)begin
			$display("FAIL CAL-05 negative half tie"); // 报告负半LSB未远离零
			cnt_error = cnt_error + 1;         // 累计负tie失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = -32'sd98304;   // 构造精确负1.5
		@(posedge i_clk);
		#1;
		if($signed(o_calibrated_s1_value) !== -2)begin
			$display("FAIL CAL-05 negative one-half"); // 报告负1.5舍入结果错误
			cnt_error = cnt_error + 1;         // 累计负幅度舍入失败
		end

		// CAL-06和CAL-07：检查signed 12-bit边界及上下越界显式饱和
		@(negedge i_clk);
		i_stage1_offset_q16 = -32'sd134217728; // 精确构造-2048
		@(posedge i_clk);
		#1;
		if(($signed(o_calibrated_s1_value) !== -2048) || o_saturation_low || o_saturation_high)begin
			$display("FAIL CAL-06 negative endpoint"); // 报告合法负端点被误饱和
			cnt_error = cnt_error + 1;         // 累计负边界失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = 32'sd134152192; // 精确构造+2047
		@(posedge i_clk);
		#1;
		if(($signed(o_calibrated_s1_value) !== 2047) || o_saturation_low || o_saturation_high)begin
			$display("FAIL CAL-06 positive endpoint"); // 报告合法正端点被误饱和
			cnt_error = cnt_error + 1;         // 累计正边界失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = -32'sd134283264; // 构造-2049触发低饱和
		@(posedge i_clk);
		#1;
		if(($signed(o_calibrated_s1_value) !== -2048) || !o_saturation_low || o_saturation_high)begin
			$display("FAIL CAL-07 low saturation"); // 报告负向端点保护错误
			cnt_error = cnt_error + 1;         // 累计低饱和失败
		end
		@(negedge i_clk);
		i_stage1_offset_q16 = 32'sd134217728; // 构造+2048触发高饱和
		@(posedge i_clk);
		#1;
		if(($signed(o_calibrated_s1_value) !== 2047) || o_saturation_low || !o_saturation_high)begin
			$display("FAIL CAL-07 high saturation"); // 报告正向端点保护错误
			cnt_error = cnt_error + 1;         // 累计高饱和失败
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 结束舍入和饱和输入流
		@(posedge i_clk);

		// CAL-08：ACTIVE无效时阻止新事务且不产生伪输出
		@(negedge i_clk);
		i_active_valid = 1'b0;               // 撤销当前配置运行资格
		i_result_valid = 1'b1;               // 上游故意保持一个待发送事务
		i_stage1_offset_q16 = 32'sd65536;    // 准备可识别的整数1结果
		for(cnt_hold_cycle = 0; cnt_hold_cycle < 3; cnt_hold_cycle = cnt_hold_cycle + 1)begin
			@(posedge i_clk);
			#1;
			if(o_result_ready || o_calibrated_valid)begin
				$display("FAIL CAL-08 active gating cycle=%0d", cnt_hold_cycle); // 报告无ACTIVE资格仍接收事务
				cnt_error = cnt_error + 1;     // 累计ACTIVE门控失败
			end
		end

		// CAL-09：标称CHARACTERIZATION路径产生有效结果但不冒充已校准
		@(negedge i_clk);
		i_active_valid = 1'b1;               // 恢复合法ACTIVE快照
		i_stage1_calibration_valid = 1'b0;   // 声明标称表征而非片外校准
		i_stage1_offset_q16 = -32'sd262144;  // 恢复标称负4.0偏置
		i_stage1_weight_q16_0 = 26'sd65536; // 恢复标称最低位权重
		i_stage1_weight_q16_1 = 26'sd131072; // 恢复标称第二位权重
		i_stage1_weight_q16_2 = 26'sd262144; // 恢复标称第三位权重
		i_stage1_weight_q16_3 = 26'sd524288; // 恢复标称冗余位权重
		i_stage1_weight_q16_4 = 26'sd524288; // 恢复标称主8.0位权重
		i_stage1_weight_q16_5 = 26'sd1048576; // 恢复标称16.0权重
		i_stage1_weight_q16_6 = 26'sd2097152; // 恢复标称32.0权重
		i_stage1_weight_q16_7 = 26'sd4194304; // 恢复标称64.0权重
		i_stage1_weight_q16_8 = 26'sd8388608; // 恢复标称128.0权重
		i_stage1_weight_q16_9 = 26'sd16777216; // 恢复标称256.0权重
		i_stage1_raw = 10'b0000011000;       // 同时选择冗余与主8.0支路
		i_result_valid = 1'b1;               // 发送标称表征事务
		@(posedge i_clk);
		#1;
		if(!o_calibrated_valid || o_calibration_applied ||
			($signed(o_calibrated_s1_value) !== 12))begin
			$display("FAIL CAL-09 characterization qualification"); // 报告标称结果或资格标记错误
			cnt_error = cnt_error + 1;         // 累计CHARACTERIZATION失败
		end

		// CAL-10：合法片外系数必须与config/coef epoch原子绑定
		@(negedge i_clk);
		i_stage1_calibration_valid = 1'b1;   // 声明当前系数通过片外拟合资格
		i_config_epoch = 8'h5a;              // 设置可识别完整配置版本
		i_coef_epoch = 8'ha5;                // 设置独立系数组版本
		i_stage1_raw = 10'b0000000001;       // 选择最低物理位得到-3
		@(posedge i_clk);
		#1;
		if(!o_calibration_applied || (o_config_epoch !== 8'h5a) ||
			(o_coef_epoch !== 8'ha5) || ($signed(o_calibrated_s1_value) !== -3))begin
			$display("FAIL CAL-10 calibrated epochs"); // 报告校准资格或版本错拍
			cnt_error = cnt_error + 1;         // 累计版本绑定失败
		end

		// CAL-11和CAL-14：输出反压期间改变输入及ACTIVE总线不得污染已缓存payload
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 暂停上游新事务
		i_calibrated_ready = 1'b0;           // 保持当前CAL-10输出等待消费
		reg_payload_hold = dec_observed_payload; // 记录反压开始时全部131位输出
		i_stage1_raw = 10'b1111111111;       // 改变无效上游物理码总线
		i_stage1_offset_q16 = 32'sd1234567;  // 改变ACTIVE偏置输入用于污染注入
		i_config_epoch = 8'hc3;              // 改变实时配置版本输入
		i_coef_epoch = 8'h3c;                // 改变实时系数版本输入
		i_stage1_calibration_valid = 1'b0;   // 改变实时校准资格输入
		for(cnt_hold_cycle = 0; cnt_hold_cycle < 4; cnt_hold_cycle = cnt_hold_cycle + 1)begin
			@(posedge i_clk);
			#1;
			if(!o_calibrated_valid || (dec_observed_payload !== reg_payload_hold) || o_result_ready)begin
				$display("FAIL CAL-11/CAL-14 hold cycle=%0d", cnt_hold_cycle); // 报告反压期间任一payload位变化
				cnt_error = cnt_error + 1;     // 累计缓存保持失败
			end
		end

		// CAL-12：旧事务消费和新输入接收同拍发生时直接替换且不清valid
		@(negedge i_clk);
		i_calibrated_ready = 1'b1;           // 允许当前旧输出在下一沿消费
		i_result_valid = 1'b1;               // 同拍提供一笔替换输入
		i_stage1_calibration_valid = 1'b1;   // 新事务恢复合法校准资格
		i_stage1_offset_q16 = 32'sd458752;   // 权重仍为标称且RAW全零时输出整数7
		i_stage1_raw = 10'b0000000000;       // 隔离offset作为替换结果
		i_config_epoch = 8'h66;              // 替换事务使用新配置版本
		i_coef_epoch = 8'h77;                // 替换事务使用新系数版本
		i_frame_id = 16'hcafe;               // 替换事务使用可识别帧号
		@(posedge i_clk);
		#1;
		if(!o_calibrated_valid || ($signed(o_calibrated_s1_value) !== 7) ||
			(o_config_epoch !== 8'h66) || (o_coef_epoch !== 8'h77) ||
			(o_frame_id !== 16'hcafe))begin
			$display("FAIL CAL-12 same-cycle replacement"); // 报告连续事务之间出现空拍或字段混合
			cnt_error = cnt_error + 1;         // 累计同拍替换失败
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 停止替换输入以消费当前结果
		@(posedge i_clk);
		#1;
		if(o_calibrated_valid)begin
			$display("FAIL CAL-12 replacement drain"); // 报告替换结果消费后valid未清零
			cnt_error = cnt_error + 1;         // 累计替换排空失败
		end

		// CAL-13：valid为0时任意改变输入不得建立内部事务
		for(cnt_hold_cycle = 0; cnt_hold_cycle < 3; cnt_hold_cycle = cnt_hold_cycle + 1)begin
			@(negedge i_clk);
			i_stage1_raw = i_stage1_raw + 10'd137; // 改变物理码而不提供valid
			i_frame_id = i_frame_id + 16'h0101; // 改变帧号而不提供valid
			i_stage1_offset_q16 = i_stage1_offset_q16 - 32'sd11111; // 改变算术输入而不握手
			@(posedge i_clk);
			#1;
			if(o_calibrated_valid)begin
				$display("FAIL CAL-13 invalid input change"); // 报告无valid输入产生伪事务
				cnt_error = cnt_error + 1;     // 累计无效输入隔离失败
			end
		end

		// CAL-15：复位异步打断反压中的有效事务且旧载荷不复活
		@(negedge i_clk);
		i_calibrated_ready = 1'b0;           // 准备把新结果保持在输出缓存
		i_result_valid = 1'b1;               // 发送将被复位打断的事务
		i_active_valid = 1'b1;               // 保持输入接收资格
		i_stage1_offset_q16 = 32'sd131072;   // 构造可识别整数2结果
		i_stage1_raw = 10'b0000000000;       // 仅使用offset形成结果
		@(posedge i_clk);
		#1;
		if(!o_calibrated_valid)begin
			$display("FAIL CAL-15 preload"); // 报告复位打断前未建立待消费事务
			cnt_error = cnt_error + 1;         // 累计复位预置失败
		end
		#2;
		i_rstn = 1'b0;                       // 在非时钟边沿异步断言复位
		#1;
		if(o_calibrated_valid || o_result_ready ||
			(dec_observed_payload !== {C_OBSERVED_PAYLOAD_WIDTH{1'b0}}))begin
			$display("FAIL CAL-15 asynchronous reset clear"); // 报告异步复位未立即清除旧事务
			cnt_error = cnt_error + 1;         // 累计异步复位失败
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 复位释放前撤销旧输入valid
		i_calibrated_ready = 1'b1;           // 恢复下游接收许可
		i_rstn = 1'b1;                       // 同步语义下降沿释放复位
		@(posedge i_clk);
		#1;
		if(o_calibrated_valid)begin
			$display("FAIL CAL-15 stale transaction revival"); // 报告复位后旧事务重新出现
			cnt_error = cnt_error + 1;         // 累计旧事务复活失败
		end

		// CAL-16：使用互异图样一次检查全部透传字段的原子对齐
		@(negedge i_clk);
		i_result_valid = 1'b1;               // 发送完整元数据检查事务
		i_active_valid = 1'b1;               // 保持合法ACTIVE资格
		i_stage1_calibration_valid = 1'b1;   // 标记本笔使用合法校准系数
		i_stage1_offset_q16 = -32'sd65536;   // 构造全零RAW时整数-1
		i_stage1_raw = 10'h2a5;              // 驱动非对称S1物理码图样
		i_detect_code = 9'h12d;              // 驱动非对称固定检测码图样
		i_stage1_code_ext = -11'sd321;       // 驱动负D1_EXT透传图样
		i_stage2_raw = 10'h15a;              // 驱动互补S2物理码图样
		i_precision_mode = 1'b1;             // 声明当前为高精度事务
		i_frame_id = 16'h1357;               // 驱动共享帧号图样
		i_sample_index = 16'h2468;           // 驱动样本编号图样
		i_color_ir = 1'b1;                   // 声明红外事务
		i_frame_type = 2'b10;                // 声明NORMAL事务
		i_amb_code_snapshot = 8'ha6;         // 驱动AMB码图样
		i_dc_code_snapshot = 8'h59;          // 驱动颜色DC码图样
		i_amb_code_epoch = 4'hc;             // 驱动AMB版本图样
		i_dc_code_epoch = 4'h3;              // 驱动DC版本图样
		i_config_epoch = 8'h96;              // 驱动完整配置版本图样
		i_coef_epoch = 8'h69;                // 驱动系数版本图样
		@(posedge i_clk);
		#1;
		if(!o_calibrated_valid || (o_stage1_raw !== 10'h2a5) ||
			(o_detect_code !== 9'h12d) || (o_stage1_code_ext !== -11'sd321) ||
			(o_stage2_raw !== 10'h15a) || !o_precision_mode ||
			(o_frame_id !== 16'h1357) || (o_sample_index !== 16'h2468) ||
			!o_color_ir || (o_frame_type !== 2'b10) ||
			(o_amb_code_snapshot !== 8'ha6) || (o_dc_code_snapshot !== 8'h59) ||
			(o_amb_code_epoch !== 4'hc) || (o_dc_code_epoch !== 4'h3) ||
			(o_config_epoch !== 8'h96) || (o_coef_epoch !== 8'h69))begin
			$display("FAIL CAL-16 metadata alignment"); // 报告任一透传字段丢失或错拍
			cnt_error = cnt_error + 1;         // 累计原子元数据失败
		end

		// CAL-17：epoch模256回绕不能改变独立校准资格语义
		@(negedge i_clk);
		i_config_epoch = 8'hff;              // 首笔事务使用最大配置版本
		i_coef_epoch = 8'hff;                // 首笔事务使用最大系数版本
		i_stage1_calibration_valid = 1'b1;   // 回绕前保持校准资格有效
		i_stage1_raw = 10'b0000000000;       // 结果数值不影响版本检查
		@(posedge i_clk);
		#1;
		if(!o_calibration_applied || (o_config_epoch !== 8'hff) || (o_coef_epoch !== 8'hff))begin
			$display("FAIL CAL-17 epoch pre-wrap"); // 报告最大epoch事务标签错误
			cnt_error = cnt_error + 1;         // 累计回绕前失败
		end
		@(negedge i_clk);
		i_config_epoch = 8'h00;              // 模拟下一次完整配置版本回绕
		i_coef_epoch = 8'h00;                // 模拟下一次系数组版本回绕
		@(posedge i_clk);
		#1;
		if(!o_calibration_applied || (o_config_epoch !== 8'h00) || (o_coef_epoch !== 8'h00))begin
			$display("FAIL CAL-17 epoch wrap"); // 报告epoch为零时错误撤销校准资格
			cnt_error = cnt_error + 1;         // 累计模256回绕失败
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;               // 停止最后输入并排空输出
		@(posedge i_clk);
		#1;

		if(cnt_error == 0)begin
			$display("PASS ppg_adc_s1_programmable_calibrator CAL-01..CAL-17"); // 仅在全部合同检查成功时报告PASS
		end else begin
			$display("FAIL ppg_adc_s1_programmable_calibrator errors=%0d", cnt_error); // 汇总全部失败数量
		end
		$finish;                             // 完成完整自检后结束仿真
	end

	// 独立超时保护避免ready/valid等待异常造成回归无限运行
	initial begin
		#200000;
		$display("FAIL ppg_adc_s1_programmable_calibrator timeout"); // 报告主测试流程未在预算时间内完成
		$finish;                             // 超时后强制结束仿真
	end

	//-------------模块例化区域-------------//
	// Stage1可编程校准器DUT连接全部冻结端口
	ppg_adc_s1_programmable_calibrator
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 使用V1默认帧号宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 使用V1默认样本序号宽度
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 使用V1默认IDAC码宽度
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 使用V1默认IDAC版本宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 使用V1默认配置版本宽度
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 使用V1默认系数版本宽度
	)ppg_adc_s1_programmable_calibrator_Inst_dut(
		.i_clk(i_clk),                       // 连接自由运行仿真时钟
		.i_rstn(i_rstn),                     // 连接低有效异步复位
		.i_active_valid(i_active_valid),     // 连接ACTIVE运行资格
		.i_stage1_calibration_valid(i_stage1_calibration_valid), // 连接校准系数资格
		.i_config_epoch(i_config_epoch),     // 连接完整配置版本
		.i_coef_epoch(i_coef_epoch),         // 连接Stage1系数版本
		.i_stage1_weight_q16_0(i_stage1_weight_q16_0), // 连接vd0绝对权重
		.i_stage1_weight_q16_1(i_stage1_weight_q16_1), // 连接vd1绝对权重
		.i_stage1_weight_q16_2(i_stage1_weight_q16_2), // 连接vd2绝对权重
		.i_stage1_weight_q16_3(i_stage1_weight_q16_3), // 连接冗余支路权重
		.i_stage1_weight_q16_4(i_stage1_weight_q16_4), // 连接主8.0支路权重
		.i_stage1_weight_q16_5(i_stage1_weight_q16_5), // 连接16.0级权重
		.i_stage1_weight_q16_6(i_stage1_weight_q16_6), // 连接32.0级权重
		.i_stage1_weight_q16_7(i_stage1_weight_q16_7), // 连接64.0级权重
		.i_stage1_weight_q16_8(i_stage1_weight_q16_8), // 连接128.0级权重
		.i_stage1_weight_q16_9(i_stage1_weight_q16_9), // 连接256.0级权重
		.i_stage1_offset_q16(i_stage1_offset_q16), // 连接Stage1整体偏置
		.i_result_valid(i_result_valid),     // 连接上游保持型valid
		.i_stage1_raw(i_stage1_raw),         // 连接十个物理判决位
		.i_detect_code(i_detect_code),       // 连接固定黄金检测码
		.i_stage1_code_ext(i_stage1_code_ext), // 连接未钳位D1_EXT
		.i_stage2_raw(i_stage2_raw),         // 连接后续精细链物理码
		.i_precision_mode(i_precision_mode), // 连接事务精度快照
		.i_frame_id(i_frame_id),             // 连接共享PPG帧号
		.i_sample_index(i_sample_index),     // 连接颜色内样本序号
		.i_color_ir(i_color_ir),             // 连接红光或红外身份
		.i_frame_type(i_frame_type),         // 连接AMB、DCS或NORMAL类别
		.i_amb_code_snapshot(i_amb_code_snapshot), // 连接本次AMB码快照
		.i_dc_code_snapshot(i_dc_code_snapshot), // 连接本次颜色DC码快照
		.i_amb_code_epoch(i_amb_code_epoch), // 连接AMB码版本
		.i_dc_code_epoch(i_dc_code_epoch),   // 连接颜色DC码版本
		.o_result_ready(o_result_ready),     // 观察上游事务接收许可
		.i_calibrated_ready(i_calibrated_ready), // 连接router侧接收许可
		.o_calibrated_valid(o_calibrated_valid), // 观察校准输出valid
		.o_calibrated_s1_value(o_calibrated_s1_value), // 观察signed 12-bit校准值
		.o_calibration_applied(o_calibration_applied), // 观察片外校准资格
		.o_saturation_low(o_saturation_low), // 观察负向端点保护
		.o_saturation_high(o_saturation_high), // 观察正向端点保护
		.o_config_epoch(o_config_epoch),     // 观察事务绑定配置版本
		.o_coef_epoch(o_coef_epoch),         // 观察事务绑定系数版本
		.o_stage1_raw(o_stage1_raw),         // 观察透传S1物理码
		.o_detect_code(o_detect_code),       // 观察透传固定检测码
		.o_stage1_code_ext(o_stage1_code_ext), // 观察透传D1_EXT
		.o_stage2_raw(o_stage2_raw),         // 观察透传S2物理码
		.o_precision_mode(o_precision_mode), // 观察输出精度模式
		.o_frame_id(o_frame_id),             // 观察输出共享帧号
		.o_sample_index(o_sample_index),     // 观察输出样本序号
		.o_color_ir(o_color_ir),             // 观察输出颜色属性
		.o_frame_type(o_frame_type),         // 观察输出事务类别
		.o_amb_code_snapshot(o_amb_code_snapshot), // 观察输出AMB码快照
		.o_dc_code_snapshot(o_dc_code_snapshot), // 观察输出颜色DC码快照
		.o_amb_code_epoch(o_amb_code_epoch), // 观察输出AMB码版本
		.o_dc_code_epoch(o_dc_code_epoch)    // 观察输出颜色DC码版本
	);

endmodule
