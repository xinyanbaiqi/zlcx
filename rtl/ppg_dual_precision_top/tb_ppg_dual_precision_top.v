`timescale 1ns / 1ps

// PPG 双精度顶层定向自检仿真，覆盖 CDC、帧安全切换和光学时序合同
module tb_ppg_dual_precision_top;

	localparam integer CLK_HALF_PERIOD_NS = 32'd250; // 2 MHz 系统时钟的半周期
	localparam integer SPI_HALF_PERIOD_NS = 32'd350; // 与系统时钟异步的 SPI 半周期

	reg i_clk;
	reg i_rstn;
	reg i_spi_sclk;
	reg i_spi_config_commit;
	reg i_spi_timing_enable;
	reg i_spi_precision_mode;
	reg i_spi_test_mode;
	reg [1:0]i_spi_optical_mode;
	reg i_spi_static_characterization_enable;
	reg [4:0]i_spi_test_mux_ctrl;
	reg [7:0]i_spi_static_sar9_amb_code;
	reg [7:0]i_spi_static_sar9_dc_code;
	reg [7:0]i_spi_static_sar15_amb_code;
	reg [7:0]i_spi_static_sar15_dc_code;
	reg [7:0]i_spi_leddac_r_code;
	reg [7:0]i_spi_leddac_ir_code;
	reg [7:0]i_spi_idac_sar9_amb_r_code;
	reg [7:0]i_spi_idac_sar9_amb_ir_code;
	reg [7:0]i_spi_idac_sar9_dc_r_code;
	reg [7:0]i_spi_idac_sar9_dc_ir_code;
	reg [7:0]i_spi_idac_sar15_amb_r_code;
	reg [7:0]i_spi_idac_sar15_amb_ir_code;
	reg [7:0]i_spi_idac_sar15_dc_r_code;
	reg [7:0]i_spi_idac_sar15_dc_ir_code;

	wire o_spi_config_busy;
	wire o_frame_start_400hz;
	wire o_active_precision_mode;
	wire o_config_applied;
	wire [7:0]o_leddac;
	wire o_leden1_low;
	wire o_leden2_low;
	wire o_en_test;
	wire o_clk_buf_low;
	wire o_clk_q2_low;
	wire o_clk_q3_low;
	wire o_en_15sar_low;
	wire o_en_sar9_amb_low;
	wire o_en_sar9_dc_low;
	wire o_en_sar15_amb_low;
	wire o_en_sar15_dc_low;
	wire [7:0]o_idac_sar9ambn_low;
	wire [7:0]o_idac_sar9dcn_low;
	wire [7:0]o_idac_sar15ambn_low;
	wire [7:0]o_idac_sar15dcn_low;
	wire [4:0]o_s_in;

	integer cnt_cycle;
	integer cnt_error;
	integer frame_cycle_first;
	integer frame_cycle_second;
	integer sar9_red_center_twice;
	integer sar9_ir_center_twice;
	integer sar15_red_center_twice;
	integer sar15_ir_center_twice;

	// 产生外部 2 MHz 数字主时钟
	always #(CLK_HALF_PERIOD_NS) i_clk = ~i_clk;

	// 产生与系统时钟无固定相位关系的 SPI_SCLK
	always #(SPI_HALF_PERIOD_NS) i_spi_sclk = ~i_spi_sclk;

	// 在系统复位释放后记录时钟周期序号
	always@(posedge i_clk)begin
		if(i_rstn == 1'b0)begin
			cnt_cycle = 0;
		end else begin
			cnt_cycle = cnt_cycle + 1;
		end
	end

	// 在 SPI 时钟域提交当前全部配置并等待请求应答完成
	task submit_config;
	begin
		@(negedge i_spi_sclk);
		i_spi_config_commit = 1'b1;
		@(negedge i_spi_sclk);
		i_spi_config_commit = 1'b0;
		wait(o_spi_config_busy == 1'b1);
		wait(o_spi_config_busy == 1'b0);
	end
	endtask

	// 等待最近一笔跨域配置在帧安全点原子生效
	task wait_config_applied;
	begin
		@(posedge o_config_applied);
		repeat(2) @(negedge i_clk);
	end
	endtask

	// 测量同一帧内红光与红外 Q3 窗口的中心和间隔
	task measure_q3_centers;
		output integer red_center_twice;
		output integer ir_center_twice;
		integer frame_base;
		integer red_rise;
		integer red_fall;
		integer ir_rise;
		integer ir_fall;
	begin
		@(posedge o_frame_start_400hz);
		frame_base = cnt_cycle;
		@(posedge o_clk_q3_low);
		red_rise = cnt_cycle - frame_base;
		@(negedge o_clk_q3_low);
		red_fall = cnt_cycle - frame_base;
		@(posedge o_clk_q3_low);
		ir_rise = cnt_cycle - frame_base;
		@(negedge o_clk_q3_low);
		ir_fall = cnt_cycle - frame_base;
		red_center_twice = red_rise + red_fall;
		ir_center_twice = ir_rise + ir_fall;
		if((ir_rise - red_rise) != 160)begin
			$display("FAIL: Q3 R/IR rising-edge offset is %0d instead of 160", ir_rise - red_rise);
			cnt_error = cnt_error + 1;
		end
		if((ir_fall - red_fall) != 160)begin
			$display("FAIL: Q3 R/IR falling-edge offset is %0d instead of 160", ir_fall - red_fall);
			cnt_error = cnt_error + 1;
		end
	end
	endtask

	// 在完整一帧中核对两个 LED 窗口是否符合光学模式
	task check_optical_windows;
		input expected_red;
		input expected_ir;
		integer index_cycle;
		integer seen_red;
		integer seen_ir;
	begin
		seen_red = 0;
		seen_ir = 0;
		@(posedge o_frame_start_400hz);
		for(index_cycle = 0; index_cycle < 5000; index_cycle = index_cycle + 1)begin
			@(negedge i_clk);
			if(o_leden1_low == 1'b1)begin
				seen_red = 1;
			end
			if(o_leden2_low == 1'b1)begin
				seen_ir = 1;
			end
		end
		if(seen_red != expected_red)begin
			$display("FAIL: red optical window observed=%0d expected=%0d", seen_red, expected_red);
			cnt_error = cnt_error + 1;
		end
		if(seen_ir != expected_ir)begin
			$display("FAIL: infrared optical window observed=%0d expected=%0d", seen_ir, expected_ir);
			cnt_error = cnt_error + 1;
		end
	end
	endtask

	// 顶层定向刺激与自检流程
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		i_spi_sclk = 1'b0;
		i_spi_config_commit = 1'b0;
		i_spi_timing_enable = 1'b0;
		i_spi_precision_mode = 1'b0;
		i_spi_test_mode = 1'b0;
		i_spi_optical_mode = 2'b00;
		i_spi_static_characterization_enable = 1'b0;
		i_spi_test_mux_ctrl = 5'b10101;
		i_spi_static_sar9_amb_code = 8'h91;
		i_spi_static_sar9_dc_code = 8'h92;
		i_spi_static_sar15_amb_code = 8'hA1;
		i_spi_static_sar15_dc_code = 8'hA2;
		i_spi_leddac_r_code = 8'h31;
		i_spi_leddac_ir_code = 8'h32;
		i_spi_idac_sar9_amb_r_code = 8'h41;
		i_spi_idac_sar9_amb_ir_code = 8'h42;
		i_spi_idac_sar9_dc_r_code = 8'h43;
		i_spi_idac_sar9_dc_ir_code = 8'h44;
		i_spi_idac_sar15_amb_r_code = 8'h51;
		i_spi_idac_sar15_amb_ir_code = 8'h52;
		i_spi_idac_sar15_dc_r_code = 8'h53;
		i_spi_idac_sar15_dc_ir_code = 8'h54;
		cnt_cycle = 0;
		cnt_error = 0;

		#2000;
		i_rstn = 1'b1;
		repeat(4) @(posedge i_spi_sclk);
		repeat(2) @(posedge i_clk);

		// 用双光 SAR9 配置启动第一个完整时序系统
		i_spi_timing_enable = 1'b1;
		i_spi_precision_mode = 1'b0;
		i_spi_optical_mode = 2'b00;
		submit_config;
		wait_config_applied;
		if((o_active_precision_mode !== 1'b0) || (o_en_15sar_low !== 1'b0))begin
			$display("FAIL: initial SAR9 precision selection is not low");
			cnt_error = cnt_error + 1;
		end
		if(o_s_in !== 5'b10101)begin
			$display("FAIL: test MUX snapshot is not atomically applied");
			cnt_error = cnt_error + 1;
		end

		// 检查连续两个帧起始脉冲间严格相差 5000 拍
		@(posedge o_frame_start_400hz);
		frame_cycle_first = cnt_cycle;
		@(posedge o_frame_start_400hz);
		frame_cycle_second = cnt_cycle;
		if((frame_cycle_second - frame_cycle_first) != 5000)begin
			$display("FAIL: frame period is %0d clocks instead of 5000", frame_cycle_second - frame_cycle_first);
			cnt_error = cnt_error + 1;
		end

		// 记录 SAR9 的红光和红外 Q3 中心作为跨精度比较基准
		measure_q3_centers(sar9_red_center_twice, sar9_ir_center_twice);
		if((sar9_red_center_twice != 68) || (sar9_ir_center_twice != 388))begin
			$display("FAIL: SAR9 Q3 centers are %0d/2 and %0d/2 clocks", sar9_red_center_twice, sar9_ir_center_twice);
			cnt_error = cnt_error + 1;
		end

		// 在帧活动区中提交 SAR15 请求，精度必须保持到预建立窗口前
		repeat(100) @(posedge i_clk);
		i_spi_precision_mode = 1'b1;
		submit_config;
		if(o_active_precision_mode !== 1'b0)begin
			$display("FAIL: precision changed before the safe frame-apply point");
			cnt_error = cnt_error + 1;
		end
		wait_config_applied;
		if((o_active_precision_mode !== 1'b1) || (o_en_15sar_low !== 1'b1))begin
			$display("FAIL: SAR15 precision did not become active at the safe point");
			cnt_error = cnt_error + 1;
		end

		// SAR15 Q3 窗口宽度不同，但两个光学中心必须与 SAR9 完全一致
		measure_q3_centers(sar15_red_center_twice, sar15_ir_center_twice);
		if((sar15_red_center_twice != sar9_red_center_twice) ||
			(sar15_ir_center_twice != sar9_ir_center_twice))begin
			$display("FAIL: SAR9/SAR15 Q3 centers do not match");
			cnt_error = cnt_error + 1;
		end

		// 红光单通道模式不得产生红外 LED 窗口
		i_spi_optical_mode = 2'b01;
		submit_config;
		wait_config_applied;
		check_optical_windows(1, 0);

		// 红外单通道模式必须关闭红光 LED 窗口
		i_spi_optical_mode = 2'b10;
		submit_config;
		wait_config_applied;
		check_optical_windows(0, 1);

		// 恢复双光以直接检查两个 LED 窗口都存在
		i_spi_optical_mode = 2'b00;
		submit_config;
		wait_config_applied;
		check_optical_windows(1, 1);

		// 静态表征开启时保持 SAR15 选择且 EN_TEST 仍为低
		i_spi_static_characterization_enable = 1'b1;
		i_spi_test_mode = 1'b0;
		submit_config;
		wait_config_applied;
		if((o_en_15sar_low !== 1'b1) || (o_en_test !== 1'b0) || (o_clk_buf_low !== 1'b1))begin
			$display("FAIL: static characterization changed precision or EN_TEST semantics");
			cnt_error = cnt_error + 1;
		end
		if((o_idac_sar9ambn_low !== 8'h91) || (o_idac_sar9dcn_low !== 8'h92) ||
			(o_idac_sar15ambn_low !== 8'hA1) || (o_idac_sar15dcn_low !== 8'hA2))begin
			$display("FAIL: static characterization IDAC snapshot mismatch");
			cnt_error = cnt_error + 1;
		end
		if((o_en_sar9_amb_low !== 1'b1) || (o_en_sar9_dc_low !== 1'b1) ||
			(o_en_sar15_amb_low !== 1'b1) || (o_en_sar15_dc_low !== 1'b1))begin
			$display("FAIL: static characterization did not enable all measured IDAC branches");
			cnt_error = cnt_error + 1;
		end

		// 只更新 EN_TEST，静态码和精度必须保持不变
		i_spi_test_mode = 1'b1;
		submit_config;
		wait_config_applied;
		if((o_en_test !== 1'b1) || (o_en_15sar_low !== 1'b1) ||
			(o_idac_sar15ambn_low !== 8'hA1))begin
			$display("FAIL: EN_TEST is not independent from static characterization");
			cnt_error = cnt_error + 1;
		end

		// 退出静态表征时不得自动清除 EN_TEST
		i_spi_static_characterization_enable = 1'b0;
		submit_config;
		wait_config_applied;
		if((o_en_test !== 1'b1) || (o_en_15sar_low !== 1'b1) || (o_clk_buf_low !== 1'b0))begin
			$display("FAIL: leaving static characterization altered independent controls");
			cnt_error = cnt_error + 1;
		end

		if(cnt_error == 0)begin
			$display("PASS: ppg_dual_precision_top CDC and frame-safe timing contract verified");
		end else begin
			$display("FAIL: ppg_dual_precision_top detected %0d errors", cnt_error);
		end
		$finish;
	end

	// 看门狗防止 CDC 或帧等待因设计错误而永久挂起仿真
	initial begin
		#50000000;
		$display("FAIL: simulation watchdog timeout");
		$finish;
	end

	// 实例化双精度顶层并只引出本次合同验证需要的观测点
	ppg_dual_precision_top dut(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_spi_sclk(i_spi_sclk),
		.i_spi_config_commit(i_spi_config_commit),
		.i_spi_timing_enable(i_spi_timing_enable),
		.i_spi_precision_mode(i_spi_precision_mode),
		.i_spi_test_mode(i_spi_test_mode),
		.i_spi_optical_mode(i_spi_optical_mode),
		.i_spi_static_characterization_enable(i_spi_static_characterization_enable),
		.i_spi_test_mux_ctrl(i_spi_test_mux_ctrl),
		.i_spi_static_sar9_amb_code(i_spi_static_sar9_amb_code),
		.i_spi_static_sar9_dc_code(i_spi_static_sar9_dc_code),
		.i_spi_static_sar15_amb_code(i_spi_static_sar15_amb_code),
		.i_spi_static_sar15_dc_code(i_spi_static_sar15_dc_code),
		.i_spi_leddac_r_code(i_spi_leddac_r_code),
		.i_spi_leddac_ir_code(i_spi_leddac_ir_code),
		.i_spi_idac_sar9_amb_r_code(i_spi_idac_sar9_amb_r_code),
		.i_spi_idac_sar9_amb_ir_code(i_spi_idac_sar9_amb_ir_code),
		.i_spi_idac_sar9_dc_r_code(i_spi_idac_sar9_dc_r_code),
		.i_spi_idac_sar9_dc_ir_code(i_spi_idac_sar9_dc_ir_code),
		.i_spi_idac_sar15_amb_r_code(i_spi_idac_sar15_amb_r_code),
		.i_spi_idac_sar15_amb_ir_code(i_spi_idac_sar15_amb_ir_code),
		.i_spi_idac_sar15_dc_r_code(i_spi_idac_sar15_dc_r_code),
		.i_spi_idac_sar15_dc_ir_code(i_spi_idac_sar15_dc_ir_code),
		.o_spi_config_busy(o_spi_config_busy),
		.o_frame_start_400hz(o_frame_start_400hz),
		.o_active_precision_mode(o_active_precision_mode),
		.o_config_applied(o_config_applied),
		.o_en_tia_low(),
		.o_leddac(o_leddac),
		.o_leden1_low(o_leden1_low),
		.o_leden2_low(o_leden2_low),
		.o_en_test(o_en_test),
		.o_clk_buf_low(o_clk_buf_low),
		.o_clk_2m(),
		.o_clk_iref_idac_low(),
		.o_clk_9q1_low(),
		.o_clk_15q1_low(),
		.o_clk_aferst_low(),
		.o_clk_iref_idac_sar9_low(),
		.o_clk_iref_idac_sar15_low(),
		.o_clk_q2_low(o_clk_q2_low),
		.o_clk_q3_low(o_clk_q3_low),
		.o_clk_tiaen_low(),
		.o_en_15sar_low(o_en_15sar_low),
		.o_en_sar9_amb_low(o_en_sar9_amb_low),
		.o_en_sar9_dc_low(o_en_sar9_dc_low),
		.o_en_sar9_iref(),
		.o_en_sar15_amb_low(o_en_sar15_amb_low),
		.o_en_sar15_dc_low(o_en_sar15_dc_low),
		.o_en_sar15_iref(),
		.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
		.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
		.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
		.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
		.o_s_in(o_s_in)
	);

endmodule
