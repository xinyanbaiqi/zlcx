`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/07/23
// Design Name:        PPG IDAC Safe Switch Wave Demo
// Module Name:        tb_ppg_idac_code_controller_wave
// Description:        Visible timing demo for binary startup search and safe IDAC updates
// Simulations:        TestBench/Vivado/2022.2/ppg_idac_code_controller_wave
//
// Referrences:        ppg_idac_code_controller.v
//
// Dependencies:       ppg_idac_code_controller.v
//
// Version:            V1.0
// Revision Date:      2026/07/24
// History:
//    Time               Version       Revised by            Contents
// 2026/07/23            V1.0          Erie                  Create wave demo.
// 2026/07/24            V1.0          Erie                  Show complete startup search.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:          Erie
// 开发人员:          Erie
//
// 创建日期:          2026年07月23日
// 设计名称:          PPG IDAC安全切换波形演示
// 模块名称:          tb_ppg_idac_code_controller_wave
// 模块说明:          展示完整二分搜索、ADC证据形成与IDAC安全边界更新
// 仿真工程:          TestBench/Vivado/2022.2/ppg_idac_code_controller_wave
//
// 参考资料:          ppg_idac_code_controller.v
//
// 依赖文件:          ppg_idac_code_controller.v
//
// 当前版本:          V1.0
// 修订日期:          2026年07月24日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年07月23日        V1.0          Erie                  创建波形演示
// 2026年07月24日        V1.0          Erie                  展开完整上电快速搜索

// 使用可见等待间隔展示公共IDAC码只在ADC转换结束后的安全边界更新
module tb_ppg_idac_code_controller_wave;

	//-------------配置参数区域-------------//
	// 演示窗口采用9-bit检测结果和8-bit差分IDAC公共码
	localparam integer C_ADC_WIDTH = 9;                                  // 第一级等效检测码宽度
	localparam integer C_CODE_WIDTH = 8;                                 // 差分IDAC对公共幅度码宽度
	localparam [C_ADC_WIDTH - 1:0] ADC_HIGH = 9'd400;                    // 高于上阈值的越界样本
	localparam [C_ADC_WIDTH - 1:0] ADC_CENTER = 9'd256;                  // 位于死区窗口中心的样本
	localparam [C_ADC_WIDTH - 1:0] ADC_LOW = 9'd100;                     // 低于下阈值的越界样本

	//--------------寄存器信号--------------//
	// 时钟、运行控制和ADC结果由测试平台显式驱动
	reg i_clk;                                                           // 100 MHz仿真观察时钟
	reg i_rstn;                                                          // 低有效异步复位激励
	reg i_enable;                                                        // IDAC控制器运行许可
	reg i_analog_ready;                                                  // 模拟偏置和参考建立完成
	reg i_frame_safe_boundary;                                          // 转换结束后的公共码安全更新边界
	reg i_sample_valid;                                                  // 第一级ADC等效结果有效脉冲
	reg [C_ADC_WIDTH - 1:0]i_detect_code;                               // 当前转换完成后的9-bit检测码
	reg i_cfg_shadow_write;                                              // 本演示不使用的shadow写脉冲
	reg [2:0]i_cfg_shadow_addr;                                          // 本演示保持为零的配置索引
	reg [C_ADC_WIDTH - 1:0]i_cfg_shadow_wdata;                           // 本演示保持为零的配置数据
	reg i_cfg_commit;                                                     // 本演示不产生配置提交请求

	//---------------输出信号---------------//
	// 观察公共码、更新事件和搜索跟踪状态
	wire [C_CODE_WIDTH - 1:0]o_idac_code;                               // 同时控制PMOS/NMOS阵列的公共幅度码
	wire o_code_update;                                                   // 公共码实际改变的单周期脉冲
	wire o_track_adjust;                                                  // 慢速跟踪1 LSB更新脉冲
	wire o_search_done;                                                   // 初始搜索结果已经确认
	wire o_search_exhausted;                                              // 搜索无法进入阈值窗口
	wire o_tracking_active;                                               // 正常慢速跟踪阶段指示
	wire o_code_at_min;                                                   // 公共码达到零值边界
	wire o_code_at_max;                                                   // 公共码达到最大值边界
	wire o_commit_pending;                                                // shadow提交等待状态
	wire o_commit_ack;                                                    // 合法配置提交应答
	wire o_commit_error;                                                  // 非法配置提交拒绝脉冲
	wire o_threshold_error;                                               // 配置错误锁定状态

	//-----------主要任务处理区域-----------//
	// 产生稳定时钟供波形窗口观察每个采样和安全边界事件
	always #5 i_clk = ~i_clk;                                             // 10 ns周期仿真时钟

	// 先展开八位二分搜索，再演示慢速跟踪候选等待安全边界
	initial begin
		i_clk = 1'b0;                                                      // 初始化仿真时钟
		i_rstn = 1'b0;                                                     // 启动阶段保持异步复位
		i_enable = 1'b0;                                                   // 复位时禁止自动搜索
		i_analog_ready = 1'b0;                                             // 复位时模拟参考尚未建立
		i_frame_safe_boundary = 1'b0;                                     // 默认禁止公共码更新
		i_sample_valid = 1'b0;                                             // 默认没有已完成转换结果
		i_detect_code = ADC_CENTER;                                       // 默认检测码位于死区中心
		i_cfg_shadow_write = 1'b0;                                        // 不执行shadow字段写入
		i_cfg_shadow_addr = 3'd0;                                         // 配置索引保持确定值
		i_cfg_shadow_wdata = 9'd0;                                        // 配置数据保持确定值
		i_cfg_commit = 1'b0;                                               // 不发起运行期commit

		repeat(4) @(posedge i_clk);                                        // 保持足够异步复位时间
		@(negedge i_clk);                                                  // 在非采样边沿释放运行条件
		i_rstn = 1'b1;                                                     // 释放低有效异步复位
		i_enable = 1'b1;                                                   // 允许控制器开始搜索
		i_analog_ready = 1'b1;                                             // 表示模拟偏置和参考已稳定

		repeat(4) @(posedge i_clk);                                        // 留出可见的上电准备区间
		@(negedge i_clk);                                                  // 在时钟下降沿准备搜索安全边界
		i_frame_safe_boundary = 1'b1;                                     // 允许施加初始MSB试探码128
		@(negedge i_clk);                                                  // 覆盖一个完整上升沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭初始码更新许可

		if(o_idac_code != 8'h80)begin
			$display("FAIL: initial MSB code=%0h", o_idac_code);              // 检查首个安全边界施加0x80
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x80首个试探码的保持区间
		@(negedge i_clk);                                                  // 准备0x80对应的高侧ADC结果
		i_detect_code = ADC_HIGH;                                         // 高侧越界要求保留MSB并预置下一位
		i_sample_valid = 1'b1;                                             // 采纳0x80试探结果并形成0xC0候选
		@(negedge i_clk);                                                  // 覆盖搜索采样对应的上升沿
		i_sample_valid = 1'b0;                                             // 结束0x80试探结果有效期
		repeat(4) @(posedge i_clk);                                        // 保留0xC0仅为pending的观察间隔
		@(negedge i_clk);                                                  // 准备提交第二个搜索候选
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x80切换到0xC0
		@(negedge i_clk);                                                  // 覆盖0xC0实际生效的上升沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭本次搜索码更新窗口
		if(o_idac_code != 8'hc0)begin
			$display("FAIL: search step expected C0 code=%0h", o_idac_code); // 检查第二个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0xC0码已经稳定施加
		@(negedge i_clk);                                                  // 准备0xC0对应的低侧ADC结果
		i_detect_code = ADC_LOW;                                          // 低侧越界清除当前试探位并预置下一位
		i_sample_valid = 1'b1;                                             // 采纳0xC0结果并形成0xA0候选
		@(negedge i_clk);                                                  // 覆盖当前搜索结果采纳边沿
		i_sample_valid = 1'b0;                                             // 结束0xC0试探结果有效期
		repeat(4) @(posedge i_clk);                                        // 展示0xA0候选尚未进入模拟阵列
		@(negedge i_clk);                                                  // 准备0xA0安全提交边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0xC0切换到0xA0
		@(negedge i_clk);                                                  // 覆盖0xA0生效的系统上升沿
		i_frame_safe_boundary = 1'b0;                                     // 结束第三个候选提交窗口
		if(o_idac_code != 8'ha0)begin
			$display("FAIL: search step expected A0 code=%0h", o_idac_code); // 检查第三个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0xA0在ADC转换期间保持不变
		@(negedge i_clk);                                                  // 准备0xA0对应的低侧判断
		i_detect_code = ADC_LOW;                                          // 再次低侧越界形成更小的搜索候选
		i_sample_valid = 1'b1;                                             // 采纳0xA0结果并形成0x90候选
		@(negedge i_clk);                                                  // 覆盖本次ADC结果采样边沿
		i_sample_valid = 1'b0;                                             // 撤销0xA0结果有效指示
		repeat(4) @(posedge i_clk);                                        // 展示0x90只保存在pending寄存器
		@(negedge i_clk);                                                  // 准备0x90安全提交边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0xA0切换到0x90
		@(negedge i_clk);                                                  // 覆盖0x90实际更新边沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭0x90提交许可
		if(o_idac_code != 8'h90)begin
			$display("FAIL: search step expected 90 code=%0h", o_idac_code); // 检查第四个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x90实际输出的稳定区间
		@(negedge i_clk);                                                  // 准备0x90对应的高侧ADC结果
		i_detect_code = ADC_HIGH;                                         // 高侧越界保留当前位并预置0x08
		i_sample_valid = 1'b1;                                             // 采纳0x90结果并形成0x98候选
		@(negedge i_clk);                                                  // 覆盖0x90搜索结果采纳边沿
		i_sample_valid = 1'b0;                                             // 结束当前ADC结果有效期
		repeat(4) @(posedge i_clk);                                        // 保留0x98候选与实际0x90的对照
		@(negedge i_clk);                                                  // 准备0x98安全提交边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x90切换到0x98
		@(negedge i_clk);                                                  // 覆盖0x98实际生效边沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭0x98提交窗口
		if(o_idac_code != 8'h98)begin
			$display("FAIL: search step expected 98 code=%0h", o_idac_code); // 检查第五个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x98在下一次采样前保持
		@(negedge i_clk);                                                  // 准备0x98对应的低侧ADC结果
		i_detect_code = ADC_LOW;                                          // 低侧越界清除0x08并预置0x04
		i_sample_valid = 1'b1;                                             // 采纳0x98结果并形成0x94候选
		@(negedge i_clk);                                                  // 覆盖0x98结果采纳边沿
		i_sample_valid = 1'b0;                                             // 撤销当前搜索样本有效信号
		repeat(4) @(posedge i_clk);                                        // 展示0x94候选等待安全边界
		@(negedge i_clk);                                                  // 准备0x94候选提交
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x98切换到0x94
		@(negedge i_clk);                                                  // 覆盖0x94更新上升沿
		i_frame_safe_boundary = 1'b0;                                     // 结束0x94安全更新窗口
		if(o_idac_code != 8'h94)begin
			$display("FAIL: search step expected 94 code=%0h", o_idac_code); // 检查第六个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x94在模拟转换阶段稳定
		@(negedge i_clk);                                                  // 准备0x94对应的高侧ADC结果
		i_detect_code = ADC_HIGH;                                         // 高侧越界保留0x04并预置0x02
		i_sample_valid = 1'b1;                                             // 采纳0x94结果并形成0x96候选
		@(negedge i_clk);                                                  // 覆盖0x94搜索结果采纳边沿
		i_sample_valid = 1'b0;                                             // 结束0x94结果有效期
		repeat(4) @(posedge i_clk);                                        // 展示0x96仅作为待施加候选
		@(negedge i_clk);                                                  // 准备0x96安全提交边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x94切换到0x96
		@(negedge i_clk);                                                  // 覆盖0x96实际生效边沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭0x96提交许可
		if(o_idac_code != 8'h96)begin
			$display("FAIL: search step expected 96 code=%0h", o_idac_code); // 检查第七个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x96公共码稳定输出
		@(negedge i_clk);                                                  // 准备0x96对应的低侧ADC结果
		i_detect_code = ADC_LOW;                                          // 低侧越界清除0x02并预置最终LSB
		i_sample_valid = 1'b1;                                             // 采纳0x96结果并形成0x95候选
		@(negedge i_clk);                                                  // 覆盖0x96结果采纳边沿
		i_sample_valid = 1'b0;                                             // 结束0x96结果有效期
		repeat(4) @(posedge i_clk);                                        // 展示0x95候选与0x96实际码隔离
		@(negedge i_clk);                                                  // 准备0x95安全提交边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x96切换到0x95
		@(negedge i_clk);                                                  // 覆盖0x95实际生效边沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭最终LSB候选提交窗口
		if(o_idac_code != 8'h95)begin
			$display("FAIL: search step expected 95 code=%0h", o_idac_code); // 检查第八个二分试探码
		end

		repeat(4) @(posedge i_clk);                                        // 展示0x95最终LSB试探保持稳定
		@(negedge i_clk);                                                  // 准备最终LSB方向判断样本
		i_detect_code = ADC_HIGH;                                         // 高侧结果确认最终LSB应保持为1
		i_sample_valid = 1'b1;                                             // 形成仍为0x95的最终验证候选
		@(negedge i_clk);                                                  // 覆盖最终LSB判断采样边沿
		i_sample_valid = 1'b0;                                             // 结束最终LSB判断结果有效期
		repeat(4) @(posedge i_clk);                                        // 展示最终候选仍等待状态推进边界
		@(negedge i_clk);                                                  // 准备进入最终码验证状态
		i_frame_safe_boundary = 1'b1;                                     // 即使码值不变也只在安全边界推进搜索
		@(negedge i_clk);                                                  // 覆盖进入ST_SEARCH_VERIFY的上升沿
		i_frame_safe_boundary = 1'b0;                                     // 关闭最终搜索状态推进边界
		if(o_search_done != 1'b0)begin
			$display("FAIL: search done before final ADC observation");      // 检查最终码尚未被ADC确认
		end

		repeat(4) @(posedge i_clk);                                        // 展示最终码验证前仍未宣布搜索完成
		@(negedge i_clk);                                                  // 准备窗口中心的最终确认结果
		i_detect_code = ADC_CENTER;                                       // 模拟0x95已经把ADC带入目标窗口
		i_sample_valid = 1'b1;                                             // 表示最终候选对应的转换已经完成
		@(negedge i_clk);                                                  // 让控制器确认最终实际码
		i_sample_valid = 1'b0;                                             // 结束最终确认结果有效期
		if((o_idac_code != 8'h95) || (o_search_done != 1'b1))begin
			$display("FAIL: final search code=%0h done=%0b", o_idac_code,
				o_search_done);                                                // 检查0x95经过ADC确认后结束搜索
		end

		repeat(8) @(posedge i_clk);                                        // 分隔完整快速搜索与长期跟踪阶段
		@(negedge i_clk);                                                  // 准备第一个高侧越界结果
		i_detect_code = ADC_HIGH;                                         // ADC结果高于死区上阈值
		i_sample_valid = 1'b1;                                             // 第一帧转换完成并形成高侧证据
		@(negedge i_clk);                                                  // 完成第一个证据采纳
		i_sample_valid = 1'b0;                                             // 转换完成脉冲结束
		repeat(5) @(posedge i_clk);                                        // 拉开连续有效样本的显示间隔
		@(negedge i_clk);                                                  // 准备第二个高侧越界结果
		i_sample_valid = 1'b1;                                             // 第二帧转换完成并延续同向证据
		@(negedge i_clk);                                                  // 完成第二个证据采纳
		i_sample_valid = 1'b0;                                             // 结束第二个有效结果脉冲
		repeat(5) @(posedge i_clk);                                        // 保留公共码未变化的观察窗口
		@(negedge i_clk);                                                  // 准备第三个高侧越界结果
		i_sample_valid = 1'b1;                                             // 第三帧结果满足N_CONFIRM等于3
		@(negedge i_clk);                                                  // 内部只锁存公共码129候选
		i_sample_valid = 1'b0;                                             // ADC转换结果有效期已经结束

		repeat(16) @(posedge i_clk);                                       // 故意推迟安全边界以观察输出码仍为0x95
		if(o_idac_code != 8'h95)begin
			$display("FAIL: IDAC code changed before post-conversion safe boundary"); // 检查候选码没有提前输出
		end
		@(negedge i_clk);                                                  // 在ADC有效脉冲结束后准备安全边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x95切换到0x96
		@(negedge i_clk);                                                  // 公共码只在此边界对应上升沿改变
		i_frame_safe_boundary = 1'b0;                                     // 立即关闭后续更新许可
		if(o_idac_code != 8'h96)begin
			$display("FAIL: IDAC code did not update at safe boundary");    // 检查高侧确认后的1 LSB上调
		end

		repeat(12) @(posedge i_clk);                                       // 展示新码在下一组转换前保持稳定
		@(negedge i_clk);                                                  // 准备第一个低侧越界结果
		i_detect_code = ADC_LOW;                                          // ADC结果低于死区下阈值
		i_sample_valid = 1'b1;                                             // 第一帧低侧转换结果有效
		@(negedge i_clk);                                                  // 完成第一个低侧证据采纳
		i_sample_valid = 1'b0;                                             // 结束本次有效结果脉冲
		repeat(5) @(posedge i_clk);                                        // 拉开低侧样本显示间隔
		@(negedge i_clk);                                                  // 准备第二个低侧越界结果
		i_sample_valid = 1'b1;                                             // 第二帧继续形成低侧证据
		@(negedge i_clk);                                                  // 完成第二个低侧证据采纳
		i_sample_valid = 1'b0;                                             // 关闭第二个ADC有效脉冲
		repeat(5) @(posedge i_clk);                                        // 展示公共码0x96继续保持
		@(negedge i_clk);                                                  // 准备第三个低侧越界结果
		i_sample_valid = 1'b1;                                             // 第三帧结果满足低侧确认数
		@(negedge i_clk);                                                  // 内部只锁存公共码0x95候选
		i_sample_valid = 1'b0;                                             // 低侧转换结果有效期结束

		repeat(16) @(posedge i_clk);                                       // 再次展示候选已经形成但输出尚未切换
		if(o_idac_code != 8'h96)begin
			$display("FAIL: return code changed before second safe boundary"); // 检查下调候选仍被安全边界隔离
		end
		@(negedge i_clk);                                                  // 准备第二个转换后安全边界
		i_frame_safe_boundary = 1'b1;                                     // 允许公共码从0x96恢复到0x95
		@(negedge i_clk);                                                  // 在安全边界对应上升沿提交下调
		i_frame_safe_boundary = 1'b0;                                     // 结束公共码更新窗口
		if(o_idac_code != 8'h95)begin
			$display("FAIL: return code did not update at safe boundary"); // 检查低侧确认后的1 LSB下调
		end

		repeat(20) @(posedge i_clk);                                       // 保留最终稳定波形供GUI观察
		$display("PASS: startup search 80-C0-A0-90-98-94-96-95 and safe tracking updates"); // 报告完整波形演示完成
		$stop;                                                             // 暂停GUI仿真并保留全部波形
	end

	//------------模块实例化区域------------//
	// 使用三个确认样本和零建立屏蔽突出公共码安全切换时序
	ppg_idac_code_controller
	#(
		.C_ADC_WIDTH(C_ADC_WIDTH),                                        // 匹配演示使用的9-bit检测结果
		.C_CODE_WIDTH(C_CODE_WIDTH),                                      // 匹配演示使用的8-bit公共IDAC码
		.C_DEFAULT_AMB_THRESHOLD_LOW(9'd240),                             // 设置演示死区下阈值
		.C_DEFAULT_AMB_THRESHOLD_HIGH(9'd272),                            // 设置演示死区上阈值
		.C_DEFAULT_DCS_THRESHOLD_LOW(9'd240),                             // 保持未选DCS窗口配置合法
		.C_DEFAULT_DCS_THRESHOLD_HIGH(9'd272),                            // 保持未选DCS窗口严格递增
		.C_DEFAULT_N_CONFIRM(8'd3),                                       // 三个连续同侧样本形成调整候选
		.C_DEFAULT_IDAC_POLARITY(1'b1),                                  // 高侧越界映射为公共码增加
		.C_DEFAULT_TRACK_ENABLE(1'b1),                                   // 搜索完成后允许长期跟踪
		.C_SETTLE_SAMPLE_COUNT(8'd0)                                      // 关闭额外屏蔽以简化显示
	)ppg_idac_code_controller_Inst_dut
	(
		.i_clk(i_clk),                                                     // 连接演示时钟
		.i_rstn(i_rstn),                                                   // 连接低有效异步复位
		.i_enable(i_enable),                                               // 连接运行许可
		.i_analog_ready(i_analog_ready),                                   // 连接模拟建立完成状态
		.i_frame_safe_boundary(i_frame_safe_boundary),                     // 连接转换后安全更新边界
		.i_sample_valid(i_sample_valid),                                   // 连接ADC转换结果有效脉冲
		.i_detect_code(i_detect_code),                                     // 连接第一级9-bit等效检测码
		.i_cfg_shadow_write(i_cfg_shadow_write),                           // 固定关闭shadow写接口
		.i_cfg_shadow_addr(i_cfg_shadow_addr),                             // 连接静态配置字段索引
		.i_cfg_shadow_wdata(i_cfg_shadow_wdata),                           // 连接静态配置写数据
		.i_cfg_commit(i_cfg_commit),                                       // 固定关闭commit请求
		.o_idac_code(o_idac_code),                                         // 观察差分IDAC对公共幅度码
		.o_code_update(o_code_update),                                     // 观察安全边界实际更新事件
		.o_track_adjust(o_track_adjust),                                   // 观察慢速跟踪1 LSB脉冲
		.o_search_done(o_search_done),                                     // 观察初始码确认状态
		.o_search_exhausted(o_search_exhausted),                           // 观察搜索量程状态
		.o_tracking_active(o_tracking_active),                             // 观察长期跟踪活动状态
		.o_code_at_min(o_code_at_min),                                     // 观察公共码下边界状态
		.o_code_at_max(o_code_at_max),                                     // 观察公共码上边界状态
		.o_commit_pending(o_commit_pending),                               // 观察配置提交等待状态
		.o_commit_ack(o_commit_ack),                                       // 观察配置提交成功脉冲
		.o_commit_error(o_commit_error),                                   // 观察非法配置拒绝脉冲
		.o_threshold_error(o_threshold_error)                              // 观察配置错误锁定状态
	);

endmodule
