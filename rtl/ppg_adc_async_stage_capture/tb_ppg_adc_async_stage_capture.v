`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/24
// Design Name:        PPG ADC Asynchronous Stage Capture Testbench
// Module Name:        tb_ppg_adc_async_stage_capture
// Description:        TestBench/Vivado/2022.2/ppg_adc_async_stage_capture
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        PPG_ADC_IDAC_INTEGRATION_SPEC.md,
//                     ppg_adc_async_stage_capture.v
//
// Dependencies:       ppg_adc_async_stage_capture
//
// Version:            V1.0
// Revision Date:      2026/08/06
// History:
//    Time               Version       Revised by            Contents
// 2026/07/24            V1.0          Erie                  Create file.
// 2026/08/06            V1.0          Erie                  Add strict bilingual deliverable header.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年07月24日
// 设计名称:           PPG ADC异步双级捕获测试平台
// 模块名称:           tb_ppg_adc_async_stage_capture
// 模块说明:           TestBench/Vivado/2022.2/ppg_adc_async_stage_capture
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           PPG_ADC_IDAC_INTEGRATION_SPEC.md、ppg_adc_async_stage_capture.v
//
// 依赖文件:           ppg_adc_async_stage_capture
//
// 当前版本:           V1.0
// 修订日期:           2026年08月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年07月24日        V1.0          Erie                  创建文件
// 2026年08月06日        V1.0          Erie                  补齐严格交付双语文件头

// 显式ADC事务边界捕获器定向自检：覆盖9/15-bit选择、异步DONE、反压、同拍替换和复位
module tb_ppg_adc_async_stage_capture();

	//-------------配置参数区域-------------//
	// 测试参数匹配两级物理ADC端口和真实2 MHz数字处理时钟
	localparam integer C_RAW_WIDTH = 10;    // 每一级物理ADC输出码测试位宽
	localparam integer C_CLK_PERIOD = 500;  // 数字目的域时钟周期，单位为ns

	//--------------寄存器信号--------------//
	// 测试平台独立驱动事务边界、精度、两级异步接口和下游反压
	reg i_clk;                              // 周期翻转的数字处理域时钟
	reg i_rstn;                             // 捕获模块低有效异步复位
	reg i_adc_transaction_start;            // ADC_RST完成后的单周期事务开始脉冲
	reg i_precision_mode_committed;         // ADC_RST前已经提交的本次事务精度
	reg [C_RAW_WIDTH - 1:0]i_dout_stage1_low; // 模拟第一级保持到ADC_RST的物理码
	reg i_clk_stage1_dout_low_async;        // 模拟第一级完成后保持为高的CLK_DOUT
	reg [C_RAW_WIDTH - 1:0]i_dout_stage2_low; // 模拟第二级保持到ADC_RST的物理码
	reg i_clk_stage2_dout_low_async;        // 模拟第二级完成后保持为高的CLK_DOUT
	reg i_capture_ready;                    // 控制下游是否接收当前缓存事务
	reg flag_adc_rst_model_active;          // 波形中显示模拟ADC_RST清除阶段
	reg [3:0]reg_test_case_id;              // 标记当前定向测试阶段
	reg [2:0]reg_test_subcase;              // 标记异步DONE相位扫描子用例
	reg [C_RAW_WIDTH - 1:0]reg_expected_stage1_raw; // 保存当前相位测试的期望S1码
	integer cnt_error;                      // 累积所有自检失败数量
	integer cnt_phase_index;                // 遍历DONE相对i_clk的异步相位
	integer cnt_phase_delay;                // 当前异步DONE相对参考沿的延迟

	//---------------其他信号---------------//
	// DUT输出用于核对两级载荷、模式属性和ready/valid保持语义
	wire [C_RAW_WIDTH - 1:0]o_capture_stage1_raw; // 数字域缓存的第一级物理码
	wire [C_RAW_WIDTH - 1:0]o_capture_stage2_raw; // 数字域缓存的第二级物理码
	wire o_capture_precision_mode;          // 当前缓存事务的精度模式快照
	wire o_capture_valid;                   // 当前输出事务有效状态

	//-----------主要任务处理区域-----------//
	// 产生固定占空比目的域时钟，异步ADC事件刻意覆盖多个相位
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk; // 每半周期翻转数字处理时钟
	end

	// 依次执行启动门控、9-bit、15-bit、反压替换、异步相位和复位检查
	initial begin
		i_clk = 1'b0;                       // 从确定低电平开始生成系统时钟
		i_rstn = 1'b0;                      // 初始阶段保持数字捕获器复位
		i_adc_transaction_start = 1'b0;     // 复位期间禁止启动ADC事务
		i_precision_mode_committed = 1'b0;  // 首笔有效事务选择9-bit模式
		i_dout_stage1_low = {C_RAW_WIDTH{1'b0}}; // 模拟ADC_RST清除第一级输出
		i_clk_stage1_dout_low_async = 1'b0; // 复位阶段第一级DONE为空闲低
		i_dout_stage2_low = {C_RAW_WIDTH{1'b0}}; // 模拟ADC_RST清除第二级输出
		i_clk_stage2_dout_low_async = 1'b0; // 复位阶段第二级DONE为空闲低
		i_capture_ready = 1'b0;             // 首笔结果用于检查反压保持
		flag_adc_rst_model_active = 1'b1;   // 上电阶段显示模拟ADC处于复位
		reg_test_case_id = 4'd0;            // 阶段零验证显式事务开始门控
		reg_test_subcase = 3'd0;            // 基础阶段不使用相位子编号
		reg_expected_stage1_raw = {C_RAW_WIDTH{1'b0}}; // 初始化期望码避免未知值
		cnt_error = 0;                      // 清空测试失败计数器
		cnt_phase_index = 0;                // 初始化异步相位循环索引
		cnt_phase_delay = 0;                // 初始化异步事件延迟参数

		#(C_CLK_PERIOD * 2 + 1) i_rstn = 1'b1; // 在非活动沿释放数字域复位
		repeat(2) @(posedge i_clk);         // 等待数字复位释放后的稳定周期
		#37 i_dout_stage1_low = 10'h3FF;    // 无事务开始时准备一笔伪S1历史码
		i_clk_stage1_dout_low_async = 1'b1; // 无FRAME_START条件下拉高异步DONE
		repeat(4) @(posedge i_clk);         // 等待伪DONE完整通过两级同步链
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录缺少事务开始脉冲时发生的错误捕获
			$display("FAIL capture occurred without adc_transaction_start"); // 报告启动门控失效
		end

		// ADC_RST先清除旧DONE和RAW，事务开始脉冲随后建立9-bit捕获上下文
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b1;   // 模拟第一笔有效事务的ADC_RST阶段
		i_clk_stage1_dout_low_async = 1'b0; // ADC_RST清除伪S1完成电平
		i_clk_stage2_dout_low_async = 1'b0; // 关闭的第二级保持DONE为低
		i_dout_stage1_low = 10'h000;        // ADC_RST清除第一级历史码
		i_dout_stage2_low = 10'h000;        // ADC_RST清除第二级历史码
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b0;   // ADC_RST结束并保证两级DONE已经为低
		i_adc_transaction_start = 1'b1;     // 在转换开始前产生一拍事务边界
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 单周期事务脉冲结束
		#1;
		if((ppg_adc_async_stage_capture_Inst_dut.reg_capture_mode !== 1'b0) || (ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录9-bit模式未在事务边界正确锁存
			$display("FAIL 9-bit transaction commit mode=%b pending=%b", ppg_adc_async_stage_capture_Inst_dut.reg_capture_mode, ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending); // 报告粗精度上下文错误
		end

		#73 i_dout_stage2_low = 10'h3C3;    // 9-bit模式放置应被忽略的S2载荷
		i_clk_stage2_dout_low_async = 1'b1; // 非选中S2 DONE异步拉高
		repeat(4) @(posedge i_clk);         // 等待S2 DONE同步但不应产生捕获
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录9-bit事务被第二级完成错误触发
			$display("FAIL stage2 triggered 9-bit capture"); // 报告非选中DONE选择错误
		end
		#41 i_dout_stage1_low = 10'h155;    // 建立第一笔有效S1物理结果
		#3 i_clk_stage1_dout_low_async = 1'b1; // RAW稳定后异步拉高S1 DONE
		wait(o_capture_valid === 1'b1);     // 等待同步链后完成9-bit结果锁存
		#1;
		if((o_capture_stage1_raw !== 10'h155) || (o_capture_stage2_raw !== 10'h000) || (o_capture_precision_mode !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录9-bit载荷或模式快照错误
			$display("FAIL 9-bit capture mode=%b s1=%h s2=%h", o_capture_precision_mode, o_capture_stage1_raw, o_capture_stage2_raw); // 报告粗精度结果差异
		end
		i_dout_stage1_low = 10'h2AA;        // 改变异步总线验证缓存已经与模拟端隔离
		repeat(3) @(posedge i_clk);         // 在下游反压期间观察载荷保持
		#1;
		if((o_capture_valid !== 1'b1) || (o_capture_stage1_raw !== 10'h155))begin
			cnt_error = cnt_error + 1;      // 记录缓存被持续DONE或异步总线变化覆盖
			$display("FAIL 9-bit backpressure hold valid=%b s1=%h", o_capture_valid, o_capture_stage1_raw); // 报告缓存稳定性错误
		end
		@(negedge i_clk);
		i_capture_ready = 1'b1;             // 允许下游接收第一笔9-bit结果
		@(posedge i_clk);
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录消费后valid没有正确释放
			$display("FAIL 9-bit result did not retire"); // 报告粗精度所有权释放错误
		end
		i_capture_ready = 1'b0;             // 恢复受控反压以测试下一笔事务
		repeat(3) @(posedge i_clk);         // 持续高DONE不得重复捕获同一结果
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录单个DONE高电平被重复接纳
			$display("FAIL repeated capture after pending cleared"); // 报告一次性触发保护错误
		end

		// 下一笔模式在ADC_RST前提交，ADC_RST完成后事务脉冲锁存15-bit上下文
		reg_test_case_id = 4'd1;            // 阶段一验证15-bit最终完成边界
		@(negedge i_clk);
		i_precision_mode_committed = 1'b1;  // 在ADC_RST前提交下一笔15-bit模式
		flag_adc_rst_model_active = 1'b1;   // 开始下一笔模拟ADC_RST
		i_clk_stage1_dout_low_async = 1'b0; // 清除上一笔S1持续高电平
		i_clk_stage2_dout_low_async = 1'b0; // 清除非选中S2测试高电平
		i_dout_stage1_low = 10'h000;        // 清除上一笔第一级物理码
		i_dout_stage2_low = 10'h000;        // 清除上一笔第二级物理码
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b0;   // ADC_RST完成后允许15-bit转换
		i_adc_transaction_start = 1'b1;     // 锁存已提交的高精度模式
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束事务开始脉冲
		#1;
		if((ppg_adc_async_stage_capture_Inst_dut.reg_capture_mode !== 1'b1) || (ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录15-bit上下文没有在事务边界建立
			$display("FAIL 15-bit transaction commit mode=%b pending=%b", ppg_adc_async_stage_capture_Inst_dut.reg_capture_mode, ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending); // 报告精细模式锁存错误
		end
		#59 i_dout_stage1_low = 10'h2D1;    // 第一级转换结束时建立S1物理码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 高精度事务先产生S1 DONE
		repeat(4) @(posedge i_clk);         // 验证S1完成不会提前输出15-bit结果
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录15-bit事务被S1过早触发
			$display("FAIL stage1 triggered 15-bit capture"); // 报告高精度完成边界错误
		end
		#47 i_dout_stage2_low = 10'h16E;    // 第二级末位完成时建立S2物理码
		#3 i_clk_stage2_dout_low_async = 1'b1; // 异步拉高最终15-bit事务DONE
		wait(o_capture_valid === 1'b1);     // 等待S2同步后同时锁存两级结果
		#1;
		if((o_capture_stage1_raw !== 10'h2D1) || (o_capture_stage2_raw !== 10'h16E) || (o_capture_precision_mode !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录两级载荷或模式没有原子对齐
			$display("FAIL 15-bit capture mode=%b s1=%h s2=%h", o_capture_precision_mode, o_capture_stage1_raw, o_capture_stage2_raw); // 报告精细结果差异
		end

		// 保留旧15-bit输出，同时启动下一笔9-bit事务并验证同拍消费替换
		reg_test_case_id = 4'd2;            // 阶段二验证单元素弹性缓存
		@(negedge i_clk);
		i_precision_mode_committed = 1'b0;  // 在下一次ADC_RST前提交9-bit模式
		flag_adc_rst_model_active = 1'b1;   // 清除15-bit模拟输出准备下一事务
		i_clk_stage1_dout_low_async = 1'b0; // ADC_RST清除S1 DONE
		i_clk_stage2_dout_low_async = 1'b0; // ADC_RST清除S2 DONE
		i_dout_stage1_low = 10'h000;        // ADC_RST清除S1 RAW
		i_dout_stage2_low = 10'h000;        // ADC_RST清除S2 RAW
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b0;   // 结束模拟ADC_RST
		i_adc_transaction_start = 1'b1;     // 建立下一笔9-bit捕获上下文
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束单周期事务开始脉冲
		#1;
		if((o_capture_valid !== 1'b1) || (o_capture_stage1_raw !== 10'h2D1) || (o_capture_stage2_raw !== 10'h16E) || (o_capture_precision_mode !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 记录新事务开始破坏尚未消费的旧结果
			$display("FAIL frame start overwrote buffered 15-bit result"); // 报告输出所有权隔离错误
		end
		#67 i_dout_stage1_low = 10'h3A5;    // 准备缓存满时到达的新9-bit物理码
		#3 i_clk_stage1_dout_low_async = 1'b1; // 拉高新事务S1 DONE并保持RAW
		wait(ppg_adc_async_stage_capture_Inst_dut.flag_selected_done_sync === 1'b1); // 等待新DONE完成两级同步
		@(posedge i_clk);
		#1;
		if((o_capture_valid !== 1'b1) || (o_capture_stage1_raw !== 10'h2D1))begin
			cnt_error = cnt_error + 1;      // 记录下游反压期间新结果覆盖旧缓存
			$display("FAIL full-buffer hold valid=%b s1=%h", o_capture_valid, o_capture_stage1_raw); // 报告缓存满保持错误
		end
		@(negedge i_clk);
		i_capture_ready = 1'b1;             // 允许旧结果消费并同拍接纳等待结果
		@(posedge i_clk);
		#1;
		if((o_capture_valid !== 1'b1) || (o_capture_stage1_raw !== 10'h3A5) || (o_capture_stage2_raw !== 10'h000) || (o_capture_precision_mode !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录同拍替换未保持连续valid或载荷错误
			$display("FAIL same-cycle replace valid=%b mode=%b s1=%h s2=%h", o_capture_valid, o_capture_precision_mode, o_capture_stage1_raw, o_capture_stage2_raw); // 报告弹性缓存替换差异
		end
		@(posedge i_clk);
		#1;
		if(o_capture_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录替换后的新事务未在下一拍消费
			$display("FAIL replacement result did not retire"); // 报告连续握手结束错误
		end
		i_capture_ready = 1'b0;             // 相位扫描继续使用受控反压

		// 四种DONE相位验证显式事务边界与两级同步器组合行为
		reg_test_case_id = 4'd3;            // 阶段三执行异步相位扫描
		for(cnt_phase_index = 0; cnt_phase_index < 4; cnt_phase_index = cnt_phase_index + 1)begin
			reg_test_subcase = cnt_phase_index[2:0]; // 将当前相位编号送入波形标识总线
			case(cnt_phase_index)
				0:begin
					cnt_phase_delay = 1;    // DONE在参考上升沿后1 ns拉高
					reg_expected_stage1_raw = 10'h081; // 子用例零采用低区间测试码
				end
				1:begin
					cnt_phase_delay = 125;  // DONE在四分之一周期处拉高
					reg_expected_stage1_raw = 10'h182; // 子用例一采用中低区间测试码
				end
				2:begin
					cnt_phase_delay = 250;  // DONE在半周期处拉高
					reg_expected_stage1_raw = 10'h283; // 子用例二采用中高区间测试码
				end
				default:begin
					cnt_phase_delay = 499;  // DONE在下一上升沿前1 ns拉高
					reg_expected_stage1_raw = 10'h384; // 子用例三采用高区间测试码
				end
			endcase
			@(negedge i_clk);
			flag_adc_rst_model_active = 1'b1; // 每个子用例先执行模拟ADC_RST
			i_clk_stage1_dout_low_async = 1'b0; // 清除当前S1 DONE
			i_clk_stage2_dout_low_async = 1'b0; // 保持非选中S2 DONE为低
			i_dout_stage1_low = 10'h000;    // 清除当前S1 RAW
			i_dout_stage2_low = 10'h000;    // 清除当前S2 RAW
			@(negedge i_clk);
			flag_adc_rst_model_active = 1'b0; // 结束当前子用例ADC_RST
			i_adc_transaction_start = 1'b1; // 开放一次新的9-bit捕获事务
			@(negedge i_clk);
			i_adc_transaction_start = 1'b0; // 结束事务开始脉冲
			@(posedge i_clk);
			i_dout_stage1_low = reg_expected_stage1_raw; // 在异步DONE之前建立稳定物理码
			#(cnt_phase_delay) i_clk_stage1_dout_low_async = 1'b1; // 按指定相位拉高异步DONE
			wait(o_capture_valid === 1'b1); // 等待当前相位结果被唯一捕获
			#1;
			if((o_capture_stage1_raw !== reg_expected_stage1_raw) || (o_capture_stage2_raw !== 10'h000) || (o_capture_precision_mode !== 1'b0))begin
				cnt_error = cnt_error + 1;  // 记录相位造成的丢失、错码或模式错误
				$display("FAIL phase index=%0d mode=%b s1=%h expected=%h", cnt_phase_index, o_capture_precision_mode, o_capture_stage1_raw, reg_expected_stage1_raw); // 报告相位扫描差异
			end
			@(negedge i_clk);
			i_capture_ready = 1'b1;         // 允许当前相位结果被下游消费
			@(posedge i_clk);
			#1;
			if(o_capture_valid !== 1'b0)begin
				cnt_error = cnt_error + 1;  // 记录相位结果未在ready后释放
				$display("FAIL phase result did not retire index=%0d", cnt_phase_index); // 报告子用例握手错误
			end
			i_capture_ready = 1'b0;         // 下一个相位恢复受控反压
		end
		reg_test_subcase = 3'd0;            // 相位扫描完成后清除子编号

		// 最后一笔有效结果期间异步拉低数字复位，检查全部输出和控制状态
		reg_test_case_id = 4'd4;            // 阶段四验证有效缓存期间数字复位
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b1;   // 为复位测试准备一笔全新ADC事务
		i_clk_stage1_dout_low_async = 1'b0; // 清除上一相位S1 DONE
		i_dout_stage1_low = 10'h000;        // 清除上一相位S1 RAW
		@(negedge i_clk);
		flag_adc_rst_model_active = 1'b0;   // 结束模拟ADC_RST
		i_adc_transaction_start = 1'b1;     // 打开复位测试事务
		@(negedge i_clk);
		i_adc_transaction_start = 1'b0;     // 结束事务开始脉冲
		#53 i_dout_stage1_low = 10'h0E7;    // 准备数字复位前的有效结果
		#3 i_clk_stage1_dout_low_async = 1'b1; // 拉高当前事务S1 DONE
		wait(o_capture_valid === 1'b1);     // 等待结果进入输出缓存
		#37 i_rstn = 1'b0;                  // 在非时钟沿施加数字异步复位
		#1;
		if((o_capture_valid !== 1'b0) || (o_capture_stage1_raw !== 10'h000) || (o_capture_stage2_raw !== 10'h000) || (o_capture_precision_mode !== 1'b0) || (ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录异步数字复位未清除完整事务状态
			$display("FAIL valid-active reset mode=%b valid=%b s1=%h s2=%h pending=%b", o_capture_precision_mode, o_capture_valid, o_capture_stage1_raw, o_capture_stage2_raw, ppg_adc_async_stage_capture_Inst_dut.flag_capture_pending); // 报告复位清除差异
		end

		if(cnt_error == 0)begin
			$display("PASS ppg_adc_async_stage_capture explicit-frame checks"); // 全部显式事务边界检查通过
		end else begin
			$display("FAIL ppg_adc_async_stage_capture errors=%0d", cnt_error); // 汇总未通过的定向检查数量
		end
		$finish;                            // 结束已完成的自检仿真
	end

	// 独立超时保护避免CDC或valid错误使测试永久阻塞
	initial begin
		#200000;
		$display("FAIL timeout ppg_adc_async_stage_capture"); // 报告测试未在限定时间内闭环
		$finish;                            // 超时后终止仿真进程
	end

	//------------模块实例化区域------------//
	// 实例化显式事务边界双级ADC结果捕获器
	ppg_adc_async_stage_capture
	#(
		.C_RAW_WIDTH(C_RAW_WIDTH)           // 保持测试数据宽度与两级ADC一致
	)ppg_adc_async_stage_capture_Inst_dut(
		.i_clk(i_clk),                      // 提供结果捕获目的域时钟
		.i_rstn(i_rstn),                    // 驱动捕获器低有效异步复位
		.i_adc_transaction_start(i_adc_transaction_start), // 提供ADC_RST完成后的事务边界
		.i_precision_mode_committed(i_precision_mode_committed), // 提供ADC_RST前锁定的精度模式
		.i_dout_stage1_low(i_dout_stage1_low), // 连接模拟第一级物理码总线
		.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async), // 连接第一级异步CLK_DOUT
		.i_dout_stage2_low(i_dout_stage2_low), // 连接模拟第二级物理码总线
		.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async), // 连接第二级异步CLK_DOUT
		.i_capture_ready(i_capture_ready),  // 施加可控下游接收条件
		.o_capture_stage1_raw(o_capture_stage1_raw), // 观测第一级缓存结果
		.o_capture_stage2_raw(o_capture_stage2_raw), // 观测第二级缓存结果
		.o_capture_precision_mode(o_capture_precision_mode), // 检查事务精度模式快照
		.o_capture_valid(o_capture_valid)   // 检查缓存结果有效状态
	);

endmodule
