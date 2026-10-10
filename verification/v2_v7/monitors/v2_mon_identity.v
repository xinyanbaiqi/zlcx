`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Owner Identity Scoreboard
// Module Name:     v2_mon_identity
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 2
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md V1.11 sections 5.3 and 8.3,
//                  contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md section 7.1a (scheme A owner lifecycle)
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Read-only owner identity scoreboard. The scheduler commit event opens one owner (frame, sample index, colour, frame type, precision); one cycle later the SSW owner registers and the AMI in-flight registers must hold the same identity and all three in-flight flags must be 1; outside the commit/close transition cycles the three flags must agree with the scoreboard. Exactly one AMI completion or void carrying the owner's sample index closes it. A successful NORMAL completion enters a 2-entry pending list (at most the RED and IR owners of one frame can be waiting for their results); every formal result must match and consume one pending entry, every identity-valid discard must match a pending entry or one of the last 2 closed owners, and a pending entry left unresolved for C_RESOLVE_MAX cycles is a failure. Violations while i_excl_window is high (the F-3 contract-premise window) are counted separately and not as failures. Failure codes on o_fail_code: 1 double commit, 2 record mismatch at commit+1, 3 in-flight flags disagree, 4 close without owner, 5 close index mismatch, 6 result without owner, 7 discard without owner, 8 unresolved completion, 9 owner open at START, 10 pending list overflow (reported, never silently dropped). Synthesizable checker core.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻owner身份记分板
// 模块名称:        v2_mon_identity
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第2项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md V1.11第5.3、8.3节，
//                  PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md第7.1a节（方案甲owner生命周期）
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。只读owner身份记分板。调度器提交事件打开一个owner（帧号、序号、颜色、帧类型、精度）；下一拍SSW owner寄存器与AMI在途寄存器必须是同一身份，三方在途标志都为1；提交与关闭的过渡拍之外，三方标志必须与记分板开闭一致。恰好一次带该序号的AMI完成或作废关闭它。成功的NORMAL完成进入2项待决表（同一帧最多RED、IR两笔在等结果）；每个正式结果必须匹配并消费一项，每个身份有效的discard必须匹配一项待决或最近2个已关闭owner之一，待决项超过C_RESOLVE_MAX拍未了结判失败。i_excl_window为高（F-3合同前提窗口）期间的违例单独计数，不算失败。o_fail_code失败码：1重复提交，2提交后一拍记录不一致，3在途标志不一致，4无owner的关闭，5关闭序号不符，6无owner的结果，7无owner的discard，8完成未了结，9 START时owner仍打开，10待决表溢出（报告，绝不静默丢弃）。可综合检查核心。

// owner身份记分板：三方记录一致、每owner一次关闭、结果与discard都能对上owner
module v2_mon_identity
#(
	parameter integer C_RESOLVE_MAX = 10000 // 成功NORMAL完成到结果或discard的最长拍数
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	//-------------生命周期输入-------------//
	input i_start_ack,                      // 调度器收到的START确认
	//-------------调度器提交输入-------------//
	input i_commit,                           // 调度器owner提交单拍
	input [15:0] i_commit_frame,              // 提交载荷帧号
	input [15:0] i_commit_idx,                // 提交载荷序号
	input i_commit_color,                     // 提交载荷颜色
	input [1:0] i_commit_type,                // 提交载荷帧类型
	input i_commit_prec,                      // 提交载荷精度
	input i_sched_inflight,                   // 调度器状态向量中的B_INFLIGHT
	//-------------SSW记录输入-------------//
	input i_ssw_inflight,                  // SSW物理owner在途寄存
	input [15:0] i_ssw_frame,              // SSW锁存的owner帧号
	input [15:0] i_ssw_idx,                // SSW锁存的owner序号
	input i_ssw_color,                     // SSW锁存的owner颜色
	input [1:0] i_ssw_type,                // SSW锁存的owner帧类型
	input i_ssw_prec,                      // SSW锁存的owner精度
	//-------------AMI记录输入-------------//
	input i_ami_inflight,                  // AMI唯一ADC事务所有权寄存
	input [15:0] i_ami_frame,              // AMI锁存的物理事务帧号
	input [15:0] i_ami_idx,                // AMI锁存的物理事务序号
	input i_ami_color,                     // AMI锁存的物理事务颜色
	input [1:0] i_ami_type,                // AMI锁存的物理事务类型
	input i_ami_prec,                      // AMI锁存的物理事务精度
	//-------------关闭与输出输入-------------//
	input i_done,                             // AMI完成事件
	input i_done_success,                     // 完成成功资格
	input i_lost,                             // AMI作废事件
	input [15:0] i_close_idx,                 // 完成或作废携带的序号
	input i_result,                           // 正式结果握手
	input [15:0] i_res_frame,                 // 结果帧号
	input [15:0] i_res_idx,                   // 结果序号
	input i_res_color,                        // 结果颜色
	input [1:0] i_res_type,                   // 结果帧类型
	input i_disc,                             // 身份有效的测量结果discard事件
	input [15:0] i_disc_frame,                // discard帧号
	input [15:0] i_disc_idx,                  // discard序号
	input i_disc_color,                       // discard颜色
	input [1:0] i_disc_type,                  // discard帧类型
	input i_excl_window,                      // F-3合同前提窗口，期间违例不计失败
	//-------------统计输出-------------//
	output [31:0] o_commit_count,       // owner提交次数
	output [31:0] o_close_count,        // owner关闭次数
	output [31:0] o_result_count,       // 已匹配的正式结果数
	output [31:0] o_discard_count,      // 已匹配的discard数
	output [31:0] o_fail_count,         // 身份违例次数
	output [31:0] o_excl_count,         // F-3窗口内违例次数
	output o_fail_event,                // 本拍发生身份违例
	output [3:0] o_fail_code            // 本拍违例的失败码
);

	//---------------配置参数区域---------------//
	localparam [1:0] FRAME_TYPE_NORMAL = 2'b10; // NORMAL帧类型编码
	localparam [3:0] CODE_DOUBLE_COMMIT = 4'd1; // 重复提交
	localparam [3:0] CODE_RECORD = 4'd2;        // 提交后一拍三方记录不一致
	localparam [3:0] CODE_INFLIGHT = 4'd3;      // 三方在途标志不一致
	localparam [3:0] CODE_CLOSE_NO_OWNER = 4'd4; // 无owner时出现关闭
	localparam [3:0] CODE_CLOSE_IDX = 4'd5;     // 关闭序号与owner不符
	localparam [3:0] CODE_RESULT = 4'd6;        // 结果对不上待决owner
	localparam [3:0] CODE_DISCARD = 4'd7;       // discard对不上任何owner
	localparam [3:0] CODE_UNRESOLVED = 4'd8;    // 成功完成长期未了结
	localparam [3:0] CODE_OPEN_AT_START = 4'd9; // START时owner仍打开
	localparam [3:0] CODE_OVERFLOW = 4'd10;     // 待决表已满仍有成功完成

	//---------------计数信号---------------//
	// 各类统计与两项待决的年龄
	reg [31:0] cnt_commit;                  // 提交次数寄存
	reg [31:0] cnt_close;                   // 关闭次数寄存
	reg [31:0] cnt_result;                  // 匹配结果数寄存
	reg [31:0] cnt_discard;                 // 匹配discard数寄存
	reg [31:0] cnt_fail;                    // 违例次数寄存
	reg [31:0] cnt_excl;                    // 前提窗口违例次数寄存
	reg [31:0] cnt_wait_first;              // 先到待决项已等待的拍数
	reg [31:0] cnt_wait_second;             // 后到待决项的老化计时器

	//--------------寄存器信号--------------//
	// 当前owner、两项待决与两项关闭历史，待决键为{有效,帧号,序号,颜色,类型低位}
	reg [15:0] reg_own_frame;               // 当前owner帧号
	reg [15:0] reg_own_idx;                 // 当前owner序号
	reg reg_own_color;                      // 当前owner颜色
	reg [1:0] reg_own_type;                 // 当前owner帧类型
	reg reg_own_prec;                       // 当前owner精度
	reg [34:0] reg_wait_first;              // 先入表的成功完成身份，有效位在最高位
	reg [34:0] reg_wait_second;             // 先到项被占时，第二笔成功完成落在这里
	reg [35:0] reg_closed_last;             // 最近一次关闭的owner：有效位与完整身份
	reg [35:0] reg_closed_prev;             // 更早一次关闭的owner，由最近记录下移得到

	//---------------标志信号---------------//
	// owner开闭状态与组合判定
	reg flag_open;                          // 当前有owner打开
	reg flag_commit_d1;                     // 上一拍发生提交
	reg flag_first_timeout_seen;            // 先到待决项已经报过一次超时
	reg flag_second_timeout_seen;           // 后到待决项的超时只计一次的闩
	wire [34:0] flag_own_key;               // 当前owner的身份键与有效位
	wire flag_close;                        // 本拍完成或作废
	wire flag_record_bad;                   // 提交后一拍记录或标志不符
	wire flag_inflight_bad;                 // 稳定期三方标志不一致
	wire flag_double_commit;                // 打开期间再次提交
	wire flag_close_no_owner;               // 无owner的关闭
	wire flag_close_idx_bad;                // 关闭序号不符
	wire flag_push;                         // 本拍成功NORMAL完成需入待决表
	wire flag_store_first;                  // 本拍成功完成写进先到项
	wire flag_store_second;                 // 先到项已占用，本拍写进后到项
	wire flag_res_first;                    // 正式结果与先到项身份相同
	wire flag_res_second;                   // 正式结果只与后到项身份相同
	wire flag_disc_first;                   // discard了结先到项
	wire flag_disc_second;                  // discard只能了结后到项
	wire flag_hist_hit;                     // discard命中关闭历史
	wire flag_late_first;                   // 先到项本拍首次越过了结时限
	wire flag_late_second;                  // 后到项等结果超过C_RESOLVE_MAX
	wire flag_result_bad;                   // 结果无命中
	wire flag_disc_bad;                     // discard无命中
	wire flag_unresolved;                   // 有待决项刚超时
	wire flag_open_at_start;                // START时仍有owner
	wire flag_overflow;                     // 入表时无空位
	wire flag_any_bad;                      // 本拍任一违例

	//---------------编码信号---------------//
	// 违例优先级编码
	reg [3:0] enc_fail_code;                // 本拍违例的最高优先失败码

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 单owner生命周期判定
	assign flag_own_key = {1'b1, reg_own_frame, reg_own_idx, reg_own_color, reg_own_type[0]}; // 待决项恒为NORMAL，类型只需留低位
	assign flag_close = i_done || i_lost;   // 完成或作废即关闭
	assign flag_record_bad = flag_commit_d1 && flag_open && (!i_sched_inflight || !i_ssw_inflight || !i_ami_inflight || (i_ssw_frame != reg_own_frame) || (i_ssw_idx != reg_own_idx) || (i_ssw_color != reg_own_color) || (i_ssw_type != reg_own_type) || (i_ssw_prec != reg_own_prec) || (i_ami_frame != reg_own_frame) || (i_ami_idx != reg_own_idx) || (i_ami_color != reg_own_color) || (i_ami_type != reg_own_type) || (i_ami_prec != reg_own_prec)); // 提交后一拍三方身份与标志必须一致
	assign flag_inflight_bad = !i_commit && !flag_commit_d1 && !flag_close && (flag_open ? !(i_sched_inflight && i_ssw_inflight && i_ami_inflight) : (i_sched_inflight || i_ssw_inflight || i_ami_inflight)); // 非过渡拍三方标志须与记分板开闭一致
	assign flag_double_commit = i_commit && flag_open && !flag_close; // 未关闭又提交
	assign flag_close_no_owner = flag_close && !flag_open; // 关闭时记分板没有打开的owner
	assign flag_close_idx_bad = flag_close && flag_open && (i_close_idx != reg_own_idx); // 关闭事件序号与打开的owner不同
	assign flag_push = i_done && i_done_success && flag_open && (i_close_idx == reg_own_idx) && (reg_own_type == FRAME_TYPE_NORMAL); // 成功NORMAL完成入表
	assign flag_store_first = flag_push && !reg_wait_first[34]; // 先到项空闲时由它接收
	assign flag_store_second = flag_push && reg_wait_first[34] && !reg_wait_second[34]; // 先到项被占而后到项空闲时转写后到项
	assign flag_res_first = i_result && reg_wait_first[34] && (reg_wait_first[33:0] == {i_res_frame, i_res_idx, i_res_color, i_res_type[0]}) && (i_res_type == FRAME_TYPE_NORMAL); // 结果四元身份与先到项相符
	assign flag_res_second = i_result && reg_wait_second[34] && (reg_wait_second[33:0] == {i_res_frame, i_res_idx, i_res_color, i_res_type[0]}) && (i_res_type == FRAME_TYPE_NORMAL) && !flag_res_first; // 先到项未命中时再比后到项
	assign flag_disc_first = i_disc && reg_wait_first[34] && (reg_wait_first[33:0] == {i_disc_frame, i_disc_idx, i_disc_color, i_disc_type[0]}) && (i_disc_type == FRAME_TYPE_NORMAL); // 测量discard按身份了结先到项
	assign flag_disc_second = i_disc && reg_wait_second[34] && (reg_wait_second[33:0] == {i_disc_frame, i_disc_idx, i_disc_color, i_disc_type[0]}) && (i_disc_type == FRAME_TYPE_NORMAL) && !flag_disc_first; // 先到项未被discard命中时检查后到项
	assign flag_hist_hit = i_disc && ((reg_closed_last[35] && (reg_closed_last[34:0] == {i_disc_frame, i_disc_idx, i_disc_color, i_disc_type})) || (reg_closed_prev[35] && (reg_closed_prev[34:0] == {i_disc_frame, i_disc_idx, i_disc_color, i_disc_type}))); // discard属于最近两次关闭的owner
	assign flag_late_first = reg_wait_first[34] && !flag_first_timeout_seen && (cnt_wait_first >= C_RESOLVE_MAX); // 先到项年龄达到时限且尚未报过
	assign flag_late_second = reg_wait_second[34] && !flag_second_timeout_seen && (cnt_wait_second >= C_RESOLVE_MAX); // 后到项第一次超时的那一拍
	assign flag_result_bad = i_result && !flag_res_first && !flag_res_second; // 结果没有对应的成功完成
	assign flag_disc_bad = i_disc && !flag_disc_first && !flag_disc_second && !flag_hist_hit; // discard既不在待决也不在历史
	assign flag_unresolved = flag_late_first || flag_late_second; // 任一待决项刚超时
	assign flag_open_at_start = i_start_ack && flag_open; // START时owner未关
	assign flag_overflow = flag_push && reg_wait_first[34] && reg_wait_second[34]; // 两项都占用仍要入表
	assign flag_any_bad = flag_double_commit || flag_record_bad || flag_inflight_bad || flag_close_no_owner || flag_close_idx_bad || flag_result_bad || flag_disc_bad || flag_unresolved || flag_open_at_start || flag_overflow; // 汇总违例

	//-------------输出信号连线-------------//
	// 统计与违例事件送出
	assign o_commit_count = cnt_commit;     // 提交次数送汇总
	assign o_close_count = cnt_close;       // 关闭次数送汇总
	assign o_result_count = cnt_result;     // 匹配结果数送汇总
	assign o_discard_count = cnt_discard;   // 匹配discard数送汇总
	assign o_fail_count = cnt_fail;         // 违例次数送结论
	assign o_excl_count = cnt_excl;         // 前提窗口违例次数送汇总
	assign o_fail_event = flag_any_bad;     // 违例单拍供明细
	assign o_fail_code = enc_fail_code;     // 违例码供明细

	//-------------主要任务处理区域-------------//
	// 失败码按优先级编码
	always@(*)begin
		enc_fail_code = 4'd0;                   // 默认无违例
		if(flag_double_commit)begin
			enc_fail_code = CODE_DOUBLE_COMMIT; // 重复提交优先
		end else if(flag_record_bad)begin
			enc_fail_code = CODE_RECORD;        // 记录不一致
		end else if(flag_inflight_bad)begin
			enc_fail_code = CODE_INFLIGHT;      // 在途标志不一致
		end else if(flag_close_no_owner)begin
			enc_fail_code = CODE_CLOSE_NO_OWNER; // 编码为无owner关闭
		end else if(flag_close_idx_bad)begin
			enc_fail_code = CODE_CLOSE_IDX;     // 编码为关闭序号错配
		end else if(flag_result_bad)begin
			enc_fail_code = CODE_RESULT;        // 结果无owner
		end else if(flag_disc_bad)begin
			enc_fail_code = CODE_DISCARD;       // discard无owner
		end else if(flag_unresolved)begin
			enc_fail_code = CODE_UNRESOLVED;    // 编码为完成后久未出结果
		end else if(flag_open_at_start)begin
			enc_fail_code = CODE_OPEN_AT_START; // 编码为新RUN残留owner
		end else if(flag_overflow)begin
			enc_fail_code = CODE_OVERFLOW;      // 待决表溢出
		end else begin
			enc_fail_code = 4'd0;               // 本拍无任何违例
		end
	end

	// owner开闭状态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_open <= 1'b0;                  // 复位无owner
		end else if(i_commit == 1'b1)begin
			flag_open <= 1'b1;                  // 提交打开owner
		end else if(flag_close == 1'b1)begin
			flag_open <= 1'b0;                  // 完成或作废关闭owner
		end else begin
			flag_open <= flag_open;             // 其余保持开闭
		end
	end

	// 提交延迟一拍，供提交后一拍的三方记录比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_commit_d1 <= 1'b0;             // 复位无提交历史
		end else begin
			flag_commit_d1 <= i_commit;         // 记录本拍是否提交
		end
	end

	// 打开的owner帧号快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_own_frame <= 16'd0;             // 复位清owner帧号
		end else if(i_commit == 1'b1)begin
			reg_own_frame <= i_commit_frame;    // 提交拍锁存帧号
		end else begin
			reg_own_frame <= reg_own_frame;     // 帧号保持到下次提交
		end
	end

	// 打开的owner序号快照，关闭事件据此核对
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_own_idx <= 16'd0;               // 复位清owner序号
		end else if(i_commit == 1'b1)begin
			reg_own_idx <= i_commit_idx;        // 提交拍锁存序号
		end else begin
			reg_own_idx <= reg_own_idx;         // 序号快照不随关闭清除
		end
	end

	// 打开的owner颜色快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_own_color <= 1'b0;              // 复位颜色为RED
		end else if(i_commit == 1'b1)begin
			reg_own_color <= i_commit_color;    // 提交拍锁存颜色
		end else begin
			reg_own_color <= reg_own_color;     // 颜色快照维持
		end
	end

	// 打开的owner类型快照，决定是否进入待决表
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_own_type <= 2'b00;              // 复位类型清零
		end else if(i_commit == 1'b1)begin
			reg_own_type <= i_commit_type;      // 提交拍锁存类型
		end else begin
			reg_own_type <= reg_own_type;       // 类型快照维持
		end
	end

	// 打开的owner精度快照，供三方精度比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_own_prec <= 1'b0;               // 复位精度为SAR9
		end else if(i_commit == 1'b1)begin
			reg_own_prec <= i_commit_prec;      // 提交拍锁存精度
		end else begin
			reg_own_prec <= reg_own_prec;       // 精度快照维持
		end
	end

	// 先到待决项：成功NORMAL完成写入，结果或discard了结，START清空
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_wait_first <= 35'd0;            // 复位清空先到项
		end else if(i_start_ack == 1'b1)begin
			reg_wait_first <= 35'd0;            // 新RUN丢弃上一RUN的先到项
		end else if(flag_store_first == 1'b1)begin
			reg_wait_first <= flag_own_key;     // 先到项记下成功完成的身份
		end else if(flag_res_first || flag_disc_first)begin
			reg_wait_first <= 35'd0;            // 先到项被结果或discard了结
		end else begin
			reg_wait_first <= reg_wait_first;   // 先到项状态不变
		end
	end

	// 后到待决项：同帧第二笔成功完成在先到项未了结时的去处
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_wait_second <= 35'd0;           // 上电时后到项为空
		end else if(i_start_ack == 1'b1)begin
			reg_wait_second <= 35'd0;           // START开启新RUN，旧RUN的后到项作废
		end else if(flag_store_second == 1'b1)begin
			reg_wait_second <= flag_own_key;    // 后到项记下第二笔成功完成
		end else if(flag_res_second || flag_disc_second)begin
			reg_wait_second <= 35'd0;           // 命中后到项的结果或discard让它空出
		end else begin
			reg_wait_second <= reg_wait_second; // 后到项内容维持
		end
	end

	// 先到项超时只报一次的闩
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_first_timeout_seen <= 1'b0;    // 复位时先到项尚未报过超时
		end else if(flag_store_first || flag_res_first || flag_disc_first || i_start_ack)begin
			flag_first_timeout_seen <= 1'b0;    // 先到项换新、了结或START时解除闩
		end else if(flag_late_first == 1'b1)begin
			flag_first_timeout_seen <= 1'b1;    // 先到项首次超时即置闩
		end else begin
			flag_first_timeout_seen <= flag_first_timeout_seen; // 先到项闩维持
		end
	end

	// 后到项的超时报告状态，换新、了结或START时解除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_second_timeout_seen <= 1'b0;   // 上电时后到项闩清零
		end else if(flag_store_second || flag_res_second || flag_disc_second || i_start_ack)begin
			flag_second_timeout_seen <= 1'b0;   // 后到项被替换、了结或START时允许再次报告
		end else if(flag_late_second == 1'b1)begin
			flag_second_timeout_seen <= 1'b1;   // 后到项首次超时后置闩
		end else begin
			flag_second_timeout_seen <= flag_second_timeout_seen; // 未发生变化时闩维持原值
		end
	end

	// 先到项从入表起算的等待时长
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_wait_first <= 32'd0;            // 复位清先到项计时
		end else if(flag_store_first == 1'b1)begin
			cnt_wait_first <= 32'd0;            // 先到项新写入从0计
		end else if(reg_wait_first[34] == 1'b1)begin
			cnt_wait_first <= cnt_wait_first + 32'd1; // 先到项有效时逐拍老化
		end else begin
			cnt_wait_first <= 32'd0;            // 先到项空闲时计时为0
		end
	end

	// 后到项老化计时，空闲时停在0
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_wait_second <= 32'd0;           // 上电时后到项计时器为0
		end else if(flag_store_second == 1'b1)begin
			cnt_wait_second <= 32'd0;           // 后到项刚写入，计时器归零
		end else if(reg_wait_second[34] == 1'b1)begin
			cnt_wait_second <= cnt_wait_second + 32'd1; // 后到项有效期间每拍加一
		end else begin
			cnt_wait_second <= 32'd0;           // 后到项空闲，计时器停在0
		end
	end

	// 最近一次关闭的owner
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_closed_last <= 36'd0;           // 复位清最近关闭记录
		end else if(flag_close && flag_open)begin
			reg_closed_last <= {1'b1, reg_own_frame, reg_own_idx, reg_own_color, reg_own_type}; // 记下刚关闭的owner
		end else begin
			reg_closed_last <= reg_closed_last; // 无关闭时最近记录不动
		end
	end

	// 每次关闭时把最近记录下移一级
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_closed_prev <= 36'd0;           // 复位清次近关闭记录
		end else if(flag_close && flag_open)begin
			reg_closed_prev <= reg_closed_last; // 最近记录退到次近位置
		end else begin
			reg_closed_prev <= reg_closed_prev; // 无关闭时次近记录不动
		end
	end

	// 统计调度器提交事件的总数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_commit <= 32'd0;                // 复位清提交计数
		end else if(i_commit == 1'b1)begin
			cnt_commit <= cnt_commit + 32'd1;   // 每次提交加一
		end else begin
			cnt_commit <= cnt_commit;           // 无提交保持
		end
	end

	// 完成与作废合计的关闭次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_close <= 32'd0;                 // 复位清关闭计数
		end else if(flag_close == 1'b1)begin
			cnt_close <= cnt_close + 32'd1;     // 完成或作废加一
		end else begin
			cnt_close <= cnt_close;             // 无关闭保持
		end
	end

	// 匹配结果数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_result <= 32'd0;                // 复位清结果匹配数
		end else if(i_result && !flag_result_bad)begin
			cnt_result <= cnt_result + 32'd1;   // 命中待决项的结果
		end else begin
			cnt_result <= cnt_result;           // 未命中或无结果保持
		end
	end

	// 匹配discard数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_discard <= 32'd0;               // 复位清discard匹配数
		end else if(i_disc && !flag_disc_bad)begin
			cnt_discard <= cnt_discard + 32'd1; // 能对上owner的discard
		end else begin
			cnt_discard <= cnt_discard;         // 未命中或无discard保持
		end
	end

	// 违例次数：前提窗口外计入
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_fail <= 32'd0;                  // 复位清违例计数
		end else if(flag_any_bad && !i_excl_window)begin
			cnt_fail <= cnt_fail + 32'd1;       // 窗口外违例加一
		end else begin
			cnt_fail <= cnt_fail;               // 无违例或窗口内保持
		end
	end

	// 前提窗口内违例次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_excl <= 32'd0;                  // 复位清前提窗口计数
		end else if(flag_any_bad && i_excl_window)begin
			cnt_excl <= cnt_excl + 32'd1;       // F-3窗口内的违例单独记
		end else begin
			cnt_excl <= cnt_excl;               // 窗口外或无违例保持
		end
	end

endmodule
