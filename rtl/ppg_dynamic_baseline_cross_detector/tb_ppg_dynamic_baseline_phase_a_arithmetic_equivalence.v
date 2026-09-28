`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/10
// Design Name:        PPG Dynamic Baseline Phase-A Arithmetic Equivalence
// Module Name:        tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence
// Description:        Bit-exact comparison of original wide and reduced arithmetic
// Simulations:        TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// Referrences:        PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md
//
// Dependencies:       None
//
// Version:            V1.0
// Revision Date:      2026/08/10
// History:
//    Time               Version       Revised by            Contents
// 2026/08/10            V1.0          Erie                  Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月10日
// 设计名称:           PPG动态基线阶段A算术逐位等价验证
// 模块名称:           tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence
// 模块说明:           对比优化前宽位公式与阶段A精确收缩公式
// 仿真工程:           TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// 参考资料:           PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md
//
// 依赖文件:           无
//
// 当前版本:           V1.0
// 修订日期:           2026年08月10日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月10日        V1.0          Erie                  创建文件

// 对冻结周期更新公式执行边界向量和确定性随机逐位等价比较
module tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence;

	//-------------配置参数区域-------------//
	// 随机向量数量在保持快速仿真的同时覆盖大量舍入和饱和组合
	localparam integer C_RANDOM_VECTOR_COUNT = 32'd20000;                 // 确定性随机差分向量总数
	localparam [79:0]Q15_ROUND_HALF_80 = 80'd16384;                       // 优化前80-bit路径舍入常数
	localparam [49:0]Q15_ROUND_HALF_50 = 50'd16384;                       // 收缩后50-bit平滑舍入常数
	localparam [47:0]Q15_ROUND_HALF_48 = 48'd16384;                       // 收缩后48-bit调整舍入常数

	//--------------寄存器信号--------------//
	// 随机生成器使用固定种子保证每次优化回归输入完全相同
	integer reg_seed;                                                      // Verilog确定性随机种子
	integer cnt_vector;                                                    // 已执行差分向量计数
	reg [31:0]reg_random_word;                                             // 当前随机字段原始字
	reg [24:0]reg_amplitude;                                               // 正峰谷幅度测试值
	reg [15:0]reg_period_frames;                                           // 非零短跨度周期帧数
	reg signed [31:0]reg_slope_current_q16;                               // 当前signed Q16活动斜率
	reg [15:0]reg_alpha_q15;                                               // 幅度比例测试字段
	reg [15:0]reg_beta_q15;                                                // 平滑比例测试字段
	reg [15:0]reg_adjust_ratio_q15;                                        // 时刻调整比例测试字段
	reg reg_cross_valid;                                                   // 当前周期是否具有已知相交
	reg [15:0]reg_lead_frames;                                             // 相交距离下一波峰的帧数

	//-----------主要任务处理区域-----------//
	// 单向量任务同时计算原64/80-bit公式和阶段A冻结宽度公式
	task check_vector;
		input [24:0]amplitude;
		input [15:0]period_frames;
		input signed [31:0]slope_current_q16;
		input [15:0]alpha_q15;
		input [15:0]beta_q15;
		input [15:0]adjust_ratio_q15;
		input cross_valid;
		input [15:0]lead_frames;
		reg [63:0]ref_base_numerator;
		reg [63:0]ref_base_rounded_numerator;
		reg [63:0]ref_base_magnitude;
		reg signed [63:0]ref_slope_base_wide;
		reg signed [31:0]ref_slope_base_q16;
		reg signed [63:0]ref_smooth_difference;
		reg signed [79:0]ref_smooth_product;
		reg [79:0]ref_smooth_product_abs;
		reg [79:0]ref_smooth_rounded_abs;
		reg signed [63:0]ref_smooth_delta;
		reg [63:0]ref_base_abs;
		reg [79:0]ref_adjust_product;
		reg [79:0]ref_adjust_rounded;
		reg signed [63:0]ref_adjust_step;
		reg signed [63:0]ref_timing_term;
		reg signed [63:0]ref_slope_candidate;
		reg ref_clamp_min;
		reg ref_clamp_max;
		reg signed [31:0]ref_slope_next_q16;
		reg [41:0]narrow_base_numerator;
		reg [41:0]narrow_base_rounded_numerator;
		reg [41:0]narrow_base_magnitude;
		reg signed [42:0]narrow_slope_base_wide;
		reg signed [31:0]narrow_slope_base_q16;
		reg signed [32:0]narrow_smooth_difference;
		reg signed [49:0]narrow_smooth_product;
		reg [49:0]narrow_smooth_product_abs;
		reg [49:0]narrow_smooth_rounded_abs;
		reg signed [33:0]narrow_smooth_delta;
		reg [31:0]narrow_base_abs;
		reg [47:0]narrow_adjust_product;
		reg [47:0]narrow_adjust_rounded;
		reg signed [32:0]narrow_adjust_step;
		reg signed [32:0]narrow_timing_term;
		reg signed [34:0]narrow_slope_candidate;
		reg narrow_clamp_min;
		reg narrow_clamp_max;
		reg signed [31:0]narrow_slope_next_q16;
	begin
		ref_base_numerator = $unsigned({39'd0, amplitude}) * $unsigned({48'd0, alpha_q15}) * 64'd2; // 按优化前64-bit域计算基础分子
		ref_base_rounded_numerator = ref_base_numerator + ({48'd0, period_frames} >> 1); // 按原公式加入半分母
		ref_base_magnitude = ref_base_rounded_numerator / period_frames;     // 保留原64-bit无符号除法商
		ref_slope_base_wide = -$signed(ref_base_magnitude);                  // 原路径基础斜率固定取负
		ref_slope_base_q16 = (ref_slope_base_wide < -64'sd2147483647) ? -32'sd2147483647 : ref_slope_base_wide[31:0]; // 原路径执行32-bit防御饱和
		ref_smooth_difference = $signed({{32{ref_slope_base_q16[31]}}, ref_slope_base_q16}) - $signed({{32{slope_current_q16[31]}}, slope_current_q16}); // 原宽域保存完整斜率差
		ref_smooth_product = $signed({{16{ref_smooth_difference[63]}}, ref_smooth_difference}) * $signed({64'd0, beta_q15}); // 原80-bit域完成beta乘法
		ref_smooth_product_abs = ref_smooth_product[79] ? (~ref_smooth_product + 80'd1) : $unsigned(ref_smooth_product); // 原路径提取乘积绝对值
		ref_smooth_rounded_abs = (ref_smooth_product_abs + Q15_ROUND_HALF_80) >> 15; // 原路径执行对称最近舍入
		ref_smooth_delta = ref_smooth_product[79] ? -$signed(ref_smooth_rounded_abs[63:0]) : $signed(ref_smooth_rounded_abs[63:0]); // 原路径恢复平滑步长符号
		ref_base_abs = ref_slope_base_q16[31] ? $unsigned(-$signed(ref_slope_base_q16)) : $unsigned(ref_slope_base_q16); // 原路径取得基础斜率正幅值
		ref_adjust_product = $unsigned({16'd0, ref_base_abs}) * $unsigned({64'd0, adjust_ratio_q15}); // 原80-bit域完成时刻修正乘法
		ref_adjust_rounded = (ref_adjust_product + Q15_ROUND_HALF_80) >> 15; // 原路径执行调整步长最近舍入
		ref_adjust_step = (ref_adjust_rounded == 0) ? 64'sd1 : $signed(ref_adjust_rounded[63:0]); // 原路径保证调整量至少一个LSB
		ref_timing_term = (cross_valid == 1'b0) ? -ref_adjust_step : ((lead_frames < 16'd17) ? -ref_adjust_step : ((lead_frames > 16'd19) ? ref_adjust_step : 64'sd0)); // 原路径选择相交时刻修正方向
		ref_slope_candidate = $signed({{32{slope_current_q16[31]}}, slope_current_q16}) + ref_smooth_delta + ref_timing_term; // 原64-bit域合成斜率候选
		ref_clamp_min = (ref_slope_candidate < -64'sd2147483647);            // 原路径检测最负边界
		ref_clamp_max = (ref_slope_candidate > -64'sd1);                     // 原路径检测近零边界
		ref_slope_next_q16 = ref_clamp_min ? -32'sd2147483647 : (ref_clamp_max ? -32'sd1 : ref_slope_candidate[31:0]); // 原路径生成夹紧结果

		narrow_base_numerator = {({16'd0, amplitude} * {25'd0, alpha_q15}), 1'b0}; // 阶段A形成42-bit基础分子
		narrow_base_rounded_numerator = narrow_base_numerator + ({26'd0, period_frames} >> 1); // 阶段A在42-bit域加入半分母
		narrow_base_magnitude = narrow_base_rounded_numerator / period_frames; // 阶段A保留完整42-bit商
		narrow_slope_base_wide = -$signed({1'b0, narrow_base_magnitude});    // 阶段A在43-bit域安全取负
		narrow_slope_base_q16 = (narrow_slope_base_wide < -43'sd2147483647) ? -32'sd2147483647 : narrow_slope_base_wide[31:0]; // 阶段A执行相同防御饱和
		narrow_smooth_difference = $signed({narrow_slope_base_q16[31], narrow_slope_base_q16}) - $signed({slope_current_q16[31], slope_current_q16}); // 阶段A保存33-bit完整差值
		narrow_smooth_product = $signed({{17{narrow_smooth_difference[32]}}, narrow_smooth_difference}) * $signed({34'd0, beta_q15}); // 阶段A在50-bit域完成平滑乘法
		narrow_smooth_product_abs = narrow_smooth_product[49] ? (~narrow_smooth_product + 50'd1) : $unsigned(narrow_smooth_product); // 阶段A提取50-bit绝对值
		narrow_smooth_rounded_abs = (narrow_smooth_product_abs + Q15_ROUND_HALF_50) >> 15; // 阶段A执行相同对称舍入
		narrow_smooth_delta = narrow_smooth_product[49] ? -$signed({1'b0, narrow_smooth_rounded_abs[32:0]}) : $signed({1'b0, narrow_smooth_rounded_abs[32:0]}); // 阶段A在34-bit域恢复符号
		narrow_base_abs = narrow_slope_base_q16[31] ? $unsigned(-$signed(narrow_slope_base_q16)) : $unsigned(narrow_slope_base_q16); // 阶段A取得32-bit基础幅值
		narrow_adjust_product = $unsigned({16'd0, narrow_base_abs}) * $unsigned({32'd0, adjust_ratio_q15}); // 阶段A在48-bit域完成调整乘法
		narrow_adjust_rounded = (narrow_adjust_product + Q15_ROUND_HALF_48) >> 15; // 阶段A执行相同最近舍入
		narrow_adjust_step = (narrow_adjust_rounded == 0) ? 33'sd1 : $signed({1'b0, narrow_adjust_rounded[31:0]}); // 阶段A保证调整步长非零
		narrow_timing_term = (cross_valid == 1'b0) ? -narrow_adjust_step : ((lead_frames < 16'd17) ? -narrow_adjust_step : ((lead_frames > 16'd19) ? narrow_adjust_step : 33'sd0)); // 阶段A选择相同修正方向
		narrow_slope_candidate = $signed({{3{slope_current_q16[31]}}, slope_current_q16}) + $signed({narrow_smooth_delta[33], narrow_smooth_delta}) + $signed({{2{narrow_timing_term[32]}}, narrow_timing_term}); // 阶段A在35-bit域合成候选
		narrow_clamp_min = (narrow_slope_candidate < -35'sd2147483647);      // 阶段A检测最负边界
		narrow_clamp_max = (narrow_slope_candidate > -35'sd1);               // 阶段A检测近零边界
		narrow_slope_next_q16 = narrow_clamp_min ? -32'sd2147483647 : (narrow_clamp_max ? -32'sd1 : narrow_slope_candidate[31:0]); // 阶段A生成夹紧结果

		if((ref_base_numerator != {22'd0, narrow_base_numerator}) || (ref_base_rounded_numerator != {22'd0, narrow_base_rounded_numerator}) || (ref_base_magnitude != {22'd0, narrow_base_magnitude}) || (ref_slope_base_wide != {{21{narrow_slope_base_wide[42]}}, narrow_slope_base_wide}) || (ref_slope_base_q16 != narrow_slope_base_q16) || (ref_smooth_difference != {{31{narrow_smooth_difference[32]}}, narrow_smooth_difference}) || (ref_smooth_product != {{30{narrow_smooth_product[49]}}, narrow_smooth_product}) || (ref_smooth_product_abs != {30'd0, narrow_smooth_product_abs}) || (ref_smooth_rounded_abs != {30'd0, narrow_smooth_rounded_abs}) || (ref_smooth_delta != {{30{narrow_smooth_delta[33]}}, narrow_smooth_delta}) || (ref_base_abs != {32'd0, narrow_base_abs}) || (ref_adjust_product != {32'd0, narrow_adjust_product}) || (ref_adjust_rounded != {32'd0, narrow_adjust_rounded}) || (ref_adjust_step != {{31{narrow_adjust_step[32]}}, narrow_adjust_step}) || (ref_timing_term != {{31{narrow_timing_term[32]}}, narrow_timing_term}) || (ref_slope_candidate != {{29{narrow_slope_candidate[34]}}, narrow_slope_candidate}) || (ref_clamp_min != narrow_clamp_min) || (ref_clamp_max != narrow_clamp_max) || (ref_slope_next_q16 != narrow_slope_next_q16))begin
			$display("FAIL PHASE_A_ARITH vector=%0d A=%h T=%h S=%h alpha=%h beta=%h adjust=%h cross=%b lead=%h", cnt_vector, amplitude, period_frames, slope_current_q16, alpha_q15, beta_q15, adjust_ratio_q15, cross_valid, lead_frames); // 报告首个不等价输入向量
			$fatal(1);                                                        // 任一位差异立即阻断阶段A交付
		end
	end
	endtask

	//---------------初始化区域---------------//
	// 定向边界之后执行固定种子随机差分以覆盖舍入和饱和组合
	initial begin
		reg_seed = 32'sh13579bdf;                                           // 固定随机种子保证结果可复现
		cnt_vector = 0;                                                     // 从首个定向向量开始编号
		check_vector(25'h0ffffff, 16'd1, -32'sd1, 16'hffff, 16'hffff, 16'hffff, 1'b0, 16'd0); // 覆盖最大幅度、T等于1和低端饱和
		cnt_vector = cnt_vector + 1;                                       // 完成OPT-01与OPT-02联合边界
		check_vector(25'h0ffffff, 16'h7fff, -32'sd2147483647, 16'hffff, 16'hffff, 16'hffff, 1'b1, 16'd19); // 覆盖最大合法短周期和平滑正差
		cnt_vector = cnt_vector + 1;                                       // 完成OPT-03与OPT-05边界
		check_vector(25'd1, 16'h7fff, -32'sd1, 16'd1, 16'hffff, 16'hffff, 1'b1, 16'd20); // 覆盖平滑负差和近零方向修正
		cnt_vector = cnt_vector + 1;                                       // 完成OPT-06与OPT-09边界
		check_vector(25'h0800000, 16'd3, -32'sd2147483647, 16'h4000, 16'h8000, 16'hffff, 1'b1, 16'd16); // 覆盖除法半LSB附近和最负修正
		cnt_vector = cnt_vector + 1;                                       // 完成OPT-07与OPT-08边界
		check_vector(25'd1, 16'd4, -32'sd65536, 16'd1, 16'h2000, 16'h0800, 1'b1, 16'd17); // 分子余数严格等于半分母以覆盖半LSB舍入
		cnt_vector = cnt_vector + 1;                                       // 完成OPT-04精确舍入边界

		for(cnt_vector = cnt_vector; cnt_vector < (C_RANDOM_VECTOR_COUNT + 5); cnt_vector = cnt_vector + 1)begin
			reg_random_word = $random(reg_seed);                              // 生成正幅度原始随机字
			reg_amplitude = {1'b0, reg_random_word[23:0]};                    // 限制到signed 25-bit合法正范围
			if(reg_amplitude == 0)begin
				reg_amplitude = 25'd1;                                         // 避免随机向量退化为非法零幅度
			end
			reg_random_word = $random(reg_seed);                              // 生成短周期帧数随机字
			reg_period_frames = {1'b0, reg_random_word[14:0]};                // 保证帧差小于半回绕
			if(reg_period_frames == 0)begin
				reg_period_frames = 16'd1;                                     // 除数始终保持非零
			end
			reg_random_word = $random(reg_seed);                              // 生成活动负斜率随机字
			reg_slope_current_q16 = -$signed({1'b0, reg_random_word[30:0]});  // 覆盖负斜率32-bit合法范围
			if(reg_slope_current_q16 == 0)begin
				reg_slope_current_q16 = -32'sd1;                               // 固定配置不允许零斜率
			end
			reg_random_word = $random(reg_seed);                              // 生成alpha随机比例
			reg_alpha_q15 = reg_random_word[15:0];                            // 覆盖全部16-bit比例编码
			if(reg_alpha_q15 == 0)begin
				reg_alpha_q15 = 16'd1;                                         // ACTIVE合法配置要求alpha非零
			end
			reg_random_word = $random(reg_seed);                              // 生成beta随机比例
			reg_beta_q15 = reg_random_word[15:0];                             // 覆盖平滑舍入的不同低位组合
			if(reg_beta_q15 == 0)begin
				reg_beta_q15 = 16'd1;                                          // ACTIVE合法配置要求beta非零
			end
			reg_random_word = $random(reg_seed);                              // 生成时刻修正随机比例
			reg_adjust_ratio_q15 = reg_random_word[15:0];                     // 覆盖48-bit调整乘积范围
			if(reg_adjust_ratio_q15 == 0)begin
				reg_adjust_ratio_q15 = 16'd1;                                  // ACTIVE合法配置要求修正比例非零
			end
			reg_random_word = $random(reg_seed);                              // 生成相交资格和lead随机字
			reg_cross_valid = reg_random_word[0];                             // 随机覆盖有相交和无相交周期
			reg_lead_frames = reg_random_word[31:16];                         // 随机覆盖过晚、合格和过早区间
			check_vector(reg_amplitude, reg_period_frames, reg_slope_current_q16, reg_alpha_q15, reg_beta_q15, reg_adjust_ratio_q15, reg_cross_valid, reg_lead_frames); // 执行优化前后逐位比较
		end

		$display("PHASE_A_ARITH_EQV PASS vectors=%0d", C_RANDOM_VECTOR_COUNT + 5); // 所有定向和随机向量逐位一致
		$finish;                                                            // 正常结束阶段A算术验证
	end

endmodule
