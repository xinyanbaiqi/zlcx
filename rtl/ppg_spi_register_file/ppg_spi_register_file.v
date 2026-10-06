`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/09/06
// Design Name:     PPG SPI Slave Register File
// Module Name:     ppg_spi_register_file
// Description:     Description/ppg_spi_register_file_Design.pdf
// Simulations:     ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// Referrences:     ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md section 8.1
//
// Dependencies:    ppg_pulse_cdc_sync
//
// Version:         V1.4
// Revision Date:   2026/10/06
// History:
//     Time          Version     Revised by     Contents
// 2026/10/06        V1.4        Erie          ABCD review F-005: fix the Mode 0 read phase. cnt_bit_in_byte updates on the SCLK rising edge, so the old negedge load at cnt==7 happened after the 7th rising edge of a byte, one bit early: a real Mode 0 master sampling on rising edges read {b6..b0, next_b7}. The read byte is now loaded on the falling edge where state==ST_DATA, the command is a read and cnt==0 (right after the previous byte's 8th rising edge, including the first data byte after the dummy bytes) and shifted on the other seven falling edges; since reg_byte_addr has already advanced at that byte boundary, the V1.1 '+1' load-address compensation is removed. Write path, CDC paths and the 38-byte snapshot are unchanged.
// 2026/09/14        V1.3        Erie          Fix a real structural CDC defect found by a Stage 3 Item 4a extension audit and confirmed by an independent re-derivation against contract section 8.1's own timing-margin table (full reasoning in memory project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914): reg_diag_sync_meta (renamed reg_diag_snapshot_gated below) unconditionally double-flopped the full 304-bit reg_diag_snapshot bus every single i_source_clk cycle with no gating signal at all -- exactly the "direct two-flop synchronization of a wide bus" pattern this project's own CDC three-class taxonomy forbids as a tearing risk, and structurally different from ppg_config_cdc_bridge.v's actual Class-3(a) pattern (destination_config_o there is captured only when an already-synchronized single-bit handshake flag says so, deferring the sampling edge until well after the source has settled). The contract's section 8.1 dummy-byte margin table is numerically accurate (independently re-verified: 3 CLK_2M cycles / 1.5us forward latency, and total round-trip margin stays positive even after folding in the previously-unlisted 2-cycle return-path latency) but answers a different question (how long until the value is safe to read) than the one that matters here (was the capture edge itself atomic); no amount of margin fixes an already-torn capture, since reg_diag_snapshot does not change again during a read transaction to give the destination a chance to re-sample correctly. Fixed by adding a 7th ppg_pulse_cdc_sync instance (ppg_pulse_cdc_sync_diag_ready_Inst) carrying w_capture_trigger -- the same i_clk-domain event that completes reg_diag_snapshot's own update -- across into the i_source_clk domain as a new single-cycle gate pulse (w_diag_snapshot_gate_event), and gating the former reg_diag_sync_meta (renamed reg_diag_snapshot_gated, ASYNC_REG attribute removed since it no longer directly samples an asynchronous signal) to capture reg_diag_snapshot only when that pulse fires, matching ppg_config_cdc_bridge.v's gated-capture structure exactly instead of relying on timing margin. reg_diag_sync_stable is now an ordinary same-domain pipeline register (its source, reg_diag_snapshot_gated, is already in the i_source_clk domain), kept unchanged in name/role as an extra settling stage before read consumption; dec_read_byte's read of reg_diag_sync_stable is unchanged. No port list change (the new wire is purely internal). Read-side snapshot capture path (flag_read_start -> w_capture_trigger -> reg_diag_snapshot) is untouched, as is the DBG_OUT select CDC and the ACTIVE-shadow write path -- both were independently confirmed safe by the same extension audit and are out of scope for this fix.
// 2026/09/07        V1.1        Erie          Fix a real off-by-one in the burst-read reload path found by tb_ppg_chip_digital_top.v's TC1 echo check: dec_read_byte was decoded straight off reg_byte_addr, but the per-byte reload (flag_load_read_byte's ST_DATA branch) fires one full clock edge before reg_byte_addr's own auto-increment takes effect, so every byte from the second one onward in a burst read shifted out the PREVIOUS byte's content instead of its own (byte[i] read as byte[i-1]'s value for all i>=1; only the first byte, loaded during the dummy-byte phase before any increment, was ever correct). Fixed by adding dec_read_load_addr (reg_byte_addr+1 during ST_DATA, reg_byte_addr unchanged during ST_DUMMY) and rewiring dec_read_byte/diag_byte_offset to decode off it instead of the raw address, so the reload always uses the address the NEXT byte will actually carry. No port list change; verified against the actual ACTIVE-shadow 128-byte burst read.
// 2026/09/06        V1.0        Erie          Create file. Mode 0 (CPOL=0,CPHA=0) MSB-first SPI slave register file per PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md section 8.1/8.2: 1-byte command (bit7=R/W) + 2-byte address + N-byte variable burst for register access, fixed 32-bit frame for the shared one-shot command register at 0x0090, 2 dummy bytes on read to cover the read-side CDC round trip. Write region 0x0000-0x007F is the 1024-bit V4+V5 ACTIVE shadow (byte-addressed, LSB-first byte order), 0x0080 the characterization/STATIC_BIAS control byte, 0x0081 the DBG_OUT select, 0x0090 the shared command byte (bit0=START,bit1=STOP,bit2=COMMIT,bit3=DIAG_CLEAR,bit4=ABORT,bit5=characterization-update-trigger, all may fire together in one write, disambiguated by ppg_control_top's own existing merge/priority logic, not by this module). START/STOP/DIAG_CLEAR/ABORT and the read-side capture trigger each cross into CLK_2M via a dedicated ppg_pulse_cdc_sync instance, since ppg_control_top's own port comments mark those four inputs "already synchronized" (no internal bridge exists for them); COMMIT and the characterization trigger stay in the SPI_SCLK/source domain since ppg_config_cdc_bridge/ppg_characterization_control_cdc already do that crossing internally. Read region 0x0100-0x0125 (38 bytes, 36 exhaustively confirmed with the user across two rounds) is captured as one atomic 304-bit CLK_2M-domain snapshot on the read-side trigger, held frozen, and continuously double-flopped bit-by-bit back into the SPI_SCLK domain (safe because the source is frozen for the whole transaction); the two discard-event groups (0x0114-0x011A, 0x011B-0x0125) are additionally latched independently of any SPI read, each carrying a toggle bit so a host can tell a fresh event apart from a stale one between polls.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年09月06日
// 设计名称:        PPG SPI从机寄存器文件
// 模块名称:        ppg_spi_register_file
// 模块说明:        Description/ppg_spi_register_file_Design.pdf
// 仿真工程:        ../ppg_chip_digital_top/tb_ppg_chip_digital_top.v
//
// 参考资料:        ../ppg_system_integration/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md第8.1节
//
// 依赖文件:        ppg_pulse_cdc_sync
//
// 当前版本:        V1.4
// 修订日期:        2026年10月06日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月06日   V1.4        Erie          ABCD复核F-005：修正Mode 0读相位。cnt_bit_in_byte在SCLK上升沿更新，原先在cnt==7时的负沿装载发生在本字节第7个上升沿之后，早了一位，真实Mode 0主机按上升沿采样读到的是{b6..b0, 下一字节b7}。现在在state==ST_DATA、读命令且cnt==0的下降沿装载（即上一字节第8个上升沿之后，含哑字节后的首个数据字节），其余7个下降沿移位；由于reg_byte_addr在该字节边界已自增，去掉V1.1的'+1'装载地址补偿。写路径、CDC路径与38字节快照不变
// 2026年09月14日   V1.3        Erie          修复Stage 3 Item 4a延伸审计发现、并经对照合同第8.1节时序余量表独立复核后确认维持的一处真实结构性CDC缺陷（完整推导见memory project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914）：reg_diag_sync_meta（下方已改名reg_diag_snapshot_gated）原先无条件、每个i_source_clk周期都直接对304-bit的reg_diag_snapshot总线打两级触发器，没有任何门控信号——正是本项目CDC三分类定义里明文禁止的"对总线直接打两级触发器（撕裂风险）"模式，与ppg_config_cdc_bridge.v真正的Class 3(a)范式（destination_config_o只在一个已同步安全的单bit握手标志为真时才采样，把采样时刻推迟到源端确认稳定之后）在结构上并不相同。合同第8.1节的哑字节时序余量表本身数字是准确的（独立复核确认：前段3个CLK_2M周期=1.5us，把此前分解式未列出的返程2拍也补算进去后总余量依然为正），但回答的是"值多久能传到位"，回答不了这次真正的问题"采样那一拍本身是不是原子的"——源端一次读事务内不会再变化，一旦某一拍采样撕裂，之后无论等多久都不会自我纠正。修复方式：新增第七个ppg_pulse_cdc_sync实例（ppg_pulse_cdc_sync_diag_ready_Inst），把reg_diag_snapshot真正完成更新的同一个i_clk域事件w_capture_trigger再桥接一次，跨入i_source_clk域产生一个新的单周期门控脉冲w_diag_snapshot_gate_event；原reg_diag_sync_meta改名为reg_diag_snapshot_gated（去掉ASYNC_REG属性，因为它不再直接采样异步信号），采样条件改为只在该脉冲为真时才捕获reg_diag_snapshot，与ppg_config_cdc_bridge.v的门控捕获结构完全对齐，不再依赖时序余量兜底。reg_diag_sync_stable现在只是同域（i_source_clk）流水线寄存器（其来源reg_diag_snapshot_gated已经在i_source_clk域），名称与职责基本不变，继续为读方向取值多留一拍裕量；dec_read_byte对reg_diag_sync_stable的读取不变。端口列表无变化（新增wire纯内部）。读方向快照捕获段（flag_read_start→w_capture_trigger→reg_diag_snapshot）、DBG_OUT选择值CDC与ACTIVE影子区写方向均未触及——同一次延伸审计已独立确认这三处安全，不在本次修复范围内。
// 2026年09月07日   V1.1        Erie          修复tb_ppg_chip_digital_top.v TC1回读比对发现的一个真实突发读重加载错位缺陷：原先dec_read_byte直接按reg_byte_addr译码，但每字节重加载（flag_load_read_byte的ST_DATA分支）比reg_byte_addr自身的自增提前整整一拍触发，导致突发读中第二字节起每个字节都错误移出上一字节的内容（byte[i]读出byte[i-1]的值，i>=1；只有第一字节因为在哑字节阶段、自增发生前加载而始终正确）。修复方式：新增dec_read_load_addr（ST_DATA阶段取reg_byte_addr+1，ST_DUMMY阶段保持reg_byte_addr原样），dec_read_byte与diag_byte_offset改为按此地址译码，使重加载始终对齐下一字节真正将使用的地址。端口列表无变化；已用ACTIVE影子区128字节真实突发读验证。
// 2026年09月06日   V1.0        Erie          创建文件。按PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md第8.1/8.2节实现Mode 0（CPOL=0,CPHA=0）MSB-first SPI从机寄存器文件：1字节命令（bit7=读写）+2字节地址+N字节变长突发用于普通寄存器访问，固定32-bit帧用于0x0090共享命令寄存器，读命令额外插入2个哑字节覆盖读方向CDC往返延迟。写方向0x0000-0x007F是1024-bit V4+V5联合ACTIVE影子区（按字节寻址，字节内低位在前），0x0080是表征/STATIC_BIAS控制字节，0x0081是DBG_OUT选择，0x0090是共享命令字节（bit0=START、bit1=STOP、bit2=COMMIT、bit3=DIAG_CLEAR、bit4=ABORT、bit5=表征更新触发，允许一次写入同时置位多个bit，由ppg_control_top自己既有的合并/优先级逻辑消歧，本模块不做额外互斥）。START/STOP/DIAG_CLEAR/ABORT和读方向捕获触发各自经一个独立的ppg_pulse_cdc_sync实例跨入CLK_2M域，因为ppg_control_top自己的端口注释把这四个输入标注为"已同步"（内部没有现成桥接）；COMMIT和表征触发留在SPI_SCLK/source域，因为ppg_config_cdc_bridge/ppg_characterization_control_cdc内部已经做过这段跨域。读方向0x0100-0x0125（38字节，与用户两轮核对穷尽确认）在读方向触发时整体捕获成一份304-bit CLK_2M域快照并冻结，再逐bit连续两级同步回SPI_SCLK域（因为整个事务期间源端已冻结，逐bit同步是安全的）；两组discard事件（0x0114-0x011A、0x011B-0x0125）各自独立锁存，不依赖任何SPI读取时机，各带一个翻转位供主机在两次轮询之间区分是不是同一次事件。

// SPI Mode 0从机寄存器文件，写方向直连ppg_control_top配置总线，读方向整体快照冻结回读
module ppg_spi_register_file
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字系统域时钟，驱动只读诊断快照捕获
	input i_rstn,                           // 2 MHz数字系统域复位，驱动只读诊断快照与discard锁存
	input i_source_clk,                     // SPI_SCLK，同时是本模块写方向的工作时钟
	input i_source_rstn,                    // SPI配置源域复位，驱动写方向寄存器文件与移位引擎

	//---------------用户接口---------------//
	//-------------SPI物理接口-------------//
	input i_spi_cs_n,                      // 片选，低有效，上升沿即完成/放弃当前事务
	input i_spi_sdi,                       // 主机到从机串行数据，MSB-first
	output o_spi_sdo,                      // 从机到主机串行数据

	//-------------V4V5联合ACTIVE写方向-------------//
	output [1023:0] o_source_config_snapshot,       // source域完整V4+V5联合shadow快照，实时提供，COMMIT前不生效
	output o_source_config_update_event,            // COMMIT位命中当拍的单周期source域事件

	//-------------表征控制写方向-------------//
	output o_source_characterization_update_valid, // 保持型请求，直到CDC握手接受才回落
	output o_source_static_characterization_enable, // 待传输的STATIC_BIAS模式使能位
	output [4:0] o_source_test_mux_ctrl,      // 待传输的五位模拟测试MUX选择码
	input i_source_config_update_ready,       // ACTIVE邮箱可接受下一笔快照资格，也用于只读区0x0109
	input i_source_characterization_update_ready, // 表征CDC邮箱资格，用于自动回落held请求，也用于只读区0x0109

	//-------------生命周期一次性命令脉冲-------------//
	output o_start_event,                             // 启动请求经跨域桥接重生的单周期脉冲
	output o_stop_event,                              // 停止请求经跨域桥接重生的单周期脉冲
	output o_diag_clear_event,                        // 诊断清除请求经跨域桥接重生的单周期脉冲
	output o_control_abort_event,                     // 异常终止请求经跨域桥接重生的单周期脉冲

	//-------------DBG_OUT选择-------------//
	output [2:0] o_dbg_out_select,         // 6选1候选选择值，其余取值保留
	output o_dbg_out_select_update_event,  // 选择值真实更新时的单周期CLK_2M域事件，供下游安全锁存该值

	//-------------生命周期与ACK诊断输入-------------//
	input [1:0] i_lifecycle_state,                   // 生命周期编码，CONFIG/READY/RUN/STOPPING四态
	input i_start_ready,                             // READY且启动资格满足
	input i_commit_ack_sticky,                       // 配置成功sticky状态
	input i_error_sticky,                            // 错误汇总sticky状态
	input [7:0] i_last_error_code,                   // 最近一次错误分类码
	input [7:0] i_schema_version,                    // V4快照格式版本
	input [7:0] i_config_epoch,                      // 完整配置版本
	input [7:0] i_coef_epoch,                        // Stage1系数版本
	input [7:0] i_stage2_coef_epoch,                 // Stage2增益/偏置字段版本
	input [7:0] i_dc_recovery_coef_epoch,            // DC恢复系数版本

	//-------------调度器AMI SSW诊断输入-------------//
	input i_scheduler_idle,                          // 调度器数字与物理时序均排空
	input i_scheduler_launch_timeout_sticky,         // 调度器波形接管错过诊断
	input i_scheduler_owner_deadline_timeout_sticky, // 调度器ADC owner截止错过诊断
	input i_scheduler_completion_mismatch_sticky,    // 调度器DONE身份错配诊断
	input i_scheduler_protocol_error_sticky,         // 调度器握手或编码协议诊断
	input i_ami_datapath_empty,                      // AMI保持型数据链已经排空
	input i_ami_idac_idle,                           // AMI IDAC控制器真实空闲状态
	input i_active_precision_mode,                   // 系统唯一committed采集精度实时电平
	input i_ami_integration_protocol_error_sticky,   // AMI集成协议异常历史诊断
	input i_ssw_wrapper_idle,                        // SSW封装完整空闲状态
	input i_ssw_switch_protocol_error_sticky,        // SSW切换协议错误保持
	input i_ssw_transaction_mismatch_sticky,         // SSW事务失配保持
	input i_ssw_owner_deadline_timeout_sticky,       // SSW结果所有权截止超时保持
	input i_ssw_calibration_timeout_sticky,          // SSW校准超时保持

	//-------------表征控制诊断输入-------------//
	input i_characterization_control_valid,     // 复位后已存在一笔合法提交控制
	input i_characterization_protocol_error_sticky, // 运行期模式变更违反合同的sticky诊断

	//-------------系统故障诊断输入-------------//
	input i_system_fault_blocking,              // 注册式系统阻断故障汇总状态
	input i_system_fault_cause_valid,           // first-fault快照有效位
	input i_system_fault_identity_valid,        // first-fault身份字段有效位
	input i_system_fault_color_ir,              // first-fault颜色身份
	input [1:0] i_system_fault_frame_type,      // first-fault事务类型
	input i_system_fault_precision,             // first-fault精度身份
	input i_result_discard_summary_sticky,      // 非blocking正式结果discard历史summary
	input [7:0] i_system_fault_cause,           // 固定blocking cause编码，取值范围见supervisor自身合同
	input [3:0] i_system_fault_source,          // 固定blocking来源子模块编号
	input [15:0] i_system_fault_frame_id,       // first-fault物理帧身份
	input [15:0] i_system_fault_sample_index,   // first-fault事务序号
	input [7:0] i_system_fault_run_generation,  // first-fault所属RUN代际
	input [15:0] i_system_fault_summary,        // 历史blocking-cause summary位图

	//-------------正式结果discard锁存输入-------------//
	input i_measurement_result_discard_event,          // 正式结果生命周期丢弃单拍观测，触发锁存
	input [1:0] i_measurement_result_discard_reason,   // STOP、abort或系统故障三态丢弃原因
	input i_measurement_result_discard_identity_valid, // 事件为高时恒为1
	input i_measurement_result_discard_sample_valid,   // 被丢弃正式结果的独立样本资格快照
	input [15:0] i_measurement_result_discard_frame_id, // 被丢弃事务的真实物理帧号
	input [15:0] i_measurement_result_discard_sample_index, // 被丢弃事务的全局顺序编号
	input i_measurement_result_discard_color_ir,       // 被丢弃事务的颜色身份
	input [1:0] i_measurement_result_discard_frame_type, // 被丢弃事务的帧类型编码
	input i_measurement_result_discard_precision,      // 被丢弃事务建立时所属的精度模式
	input [7:0] i_measurement_result_discard_run_generation, // 被丢弃事务所属的RUN代际

	//-------------检测代际清空discard锁存输入-------------//
	input i_detection_discard_event,                       // 检测代际清空广播的公开单拍观测，触发锁存
	input [1:0] i_detection_discard_reason,                // STOP、abort或系统故障三态原因编码
	input i_detection_discard_identity_valid,              // 触发广播时是否命中真实保留检测分支事务
	input i_detection_discard_sample_valid,                // 触发事务的独立样本资格快照
	input [15:0] i_detection_discard_frame_id,             // 触发事务的真实物理帧号
	input [15:0] i_detection_discard_sample_index,         // 触发事务的全局顺序编号
	input i_detection_discard_color_ir,                    // 触发事务的颜色身份
	input [1:0] i_detection_discard_frame_type,            // 触发事务的帧类型编码
	input i_detection_discard_precision,                   // 触发事务建立时所属的精度模式
	input [7:0] i_detection_discard_config_epoch,          // 触发事务ACTIVE配置版本
	input [7:0] i_detection_discard_coef_epoch,            // 触发事务Stage1系数版本
	input [7:0] i_detection_discard_dc_recovery_epoch,     // 触发事务DC恢复版本
	input [3:0] i_detection_discard_amb_code_epoch,        // 触发事务环境光抵消码提交版本
	input [3:0] i_detection_discard_dc_code_epoch,         // 触发事务颜色DC码提交版本
	input [7:0] i_detection_discard_run_generation         // 触发广播目标的RUN代际
);

	//-------------状态参数区域-------------//
	// 传输FSM的五个真实阶段
	localparam ST_IDLE = 3'd0;              // 片选未拉低，等待新事务
	localparam ST_CMD = 3'd1;               // 正在接收1字节命令
	localparam ST_ADDR = 3'd2;              // 正在接收2字节地址
	localparam ST_DUMMY = 3'd3;             // 仅读命令：2个哑字节覆盖CDC往返延迟
	localparam ST_DATA = 3'd4;              // 突发读或写数据阶段

	//-------------模块实例化信号-------------//
	// 7个脉冲同步子模块各自的目标域输出：前6个目标域为CLK_2M，第7个（诊断快照就绪）方向相反，目标域为SPI_SCLK
	wire w_capture_trigger;                   // 捕获触发脉冲同步子模块的目标域输出，内部驱动快照捕获，不直接对外输出
	wire w_start_event;                       // 启动请求专属实例的目标域输出
	wire w_stop_event;                        // 停止请求专属实例的目标域输出
	wire w_diag_clear_event;                  // 诊断清除请求专属实例的目标域输出
	wire w_abort_event;                       // 异常终止请求专属实例的目标域输出
	wire w_dbg_select_update_event;           // DBG_OUT选择值更新脉冲专属实例的目标域输出
	wire w_diag_snapshot_gate_event;          // 诊断快照门控脉冲专属实例的目标域输出，门控reg_diag_snapshot_gated的采样时刻

	//---------------计数信号---------------//
	// 字节内比特位置与2字节字段内的字节位置各自独立计数
	reg [2:0] cnt_bit_in_byte;              // 当前字节已移入的比特数，0~7循环
	reg cnt_field_byte;                     // ADDR/DUMMY阶段各自的字节位置，0=第一字节，1=第二字节

	//-------------状态机信号-------------//
	// 三段式FSM的当前态与次态
	reg [2:0] state_current;              // 当前拍传输阶段
	reg [2:0] state_next;                 // 下一拍传输阶段目标

	//--------------寄存器信号--------------//
	// 每次事务的移位与地址状态，随CS_N上升沿清空
	reg [7:0] reg_shift_in;                 // 输入移位寄存器，持续接收SDI，MSB-first
	reg [15:0] reg_byte_addr;               // 当前字节地址，突发访问按字节自增
	// 跨事务保持的寄存器文件真实内容，只在i_source_rstn复位时清零
	reg [1023:0] reg_active_shadow;         // V4+V5联合ACTIVE影子区，128字节按字节寻址
	reg [5:0] reg_characterization;         // 0x0080内容：bit0使能，bits[5:1]测试MUX选择码
	reg [2:0] reg_dbg_out_select;           // 0x0081内容：DBG_OUT候选选择值
	// SPI_SCLK域读方向输出移位寄存器，负沿更新以满足Mode 0建立时间
	reg [7:0] reg_read_byte;                // 当前正在向SDO移出的字节
	// CLK_2M域只读诊断快照与discard事件独立锁存
	reg [303:0] reg_diag_snapshot;          // 0x0100-0x0125整体冻结快照，读事务期间保持不变
	reg [303:0] reg_diag_snapshot_gated;    // 门控捕获寄存器：仅在w_diag_snapshot_gate_event为真时才采样reg_diag_snapshot，采样时刻已被动推迟到源端确认稳定之后，不再是对总线的无门控直接双触发器
	reg [303:0] reg_diag_sync_stable;       // 门控捕获后的同域（i_source_clk）流水线寄存器，供读方向取值多留一拍裕量
	reg [48:0] reg_mr_latch;                // 正式结果discard锁存：{precision,run_generation,sample_index,frame_id,frame_type,color_ir,sample_valid,identity_valid,reason,toggle}
	reg [80:0] reg_dd_latch;                // 检测代际清空discard锁存：{precision,run_generation,dc_code_epoch,amb_code_epoch,dc_recovery_epoch,coef_epoch,config_epoch,sample_index,frame_id,frame_type,color_ir,sample_valid,identity_valid,reason,toggle}

	//---------------标志信号---------------//
	// 事务推进相关的组合与保持型标志
	wire flag_byte_boundary;                // 本拍完成一个完整字节的移位
	wire flag_write_commit;                 // 本拍在ST_DATA阶段真实提交一次写字节
	wire flag_cmd_reg_hit;                  // 本拍写命中0x0090共享命令字节
	wire flag_load_read_byte;               // 本拍需要为下一字节重新加载读方向移位寄存器
	wire flag_read_start;                   // 本拍确认为一次读事务并到达地址阶段末尾
	wire flag_trigger_start;                // 最低位命中，需要跨域才能驱动启动
	wire flag_trigger_stop;                 // 次低位命中，需要跨域才能驱动停止
	wire flag_trigger_commit;               // 中间位命中，同域直接生效无需跨域
	wire flag_trigger_diag_clear;           // 第四位命中，需要跨域才能驱动诊断清除
	wire flag_trigger_abort;                // 第五位命中，需要跨域才能驱动异常终止
	wire flag_trigger_char_update;          // 最高有效位命中，置位表征保持请求
	wire flag_dbg_select_write;             // 本拍真实写命中0x0081，需要跨域才能安全驱动CLK_2M域选择器
	reg flag_char_request_held;             // 表征更新保持型请求，直到CDC ready被观察到才回落
	reg flag_cmd_is_read;                   // 命令字节最高位锁存，1为读、0为写

	//---------------译码信号---------------//
	// 按当前字节地址译码出应加载的字节内容
	reg [7:0] dec_read_byte;                // 覆盖写影子回读、表征、DBG选择、命令与只读诊断区
	wire [15:0] dec_read_load_addr;         // 本拍reg_read_byte实际应加载的字节地址

	//---------------其他信号---------------//
	// 下一拍将移入的完整字节值，供本拍各状态转移和提交逻辑组合读取
	wire [7:0] shift_in_next;               // 本拍移入后即将成立的完整字节

	// 只读诊断区38个字节各自的组合拼装
	wire [7:0] byte_0100;                   // 生命周期与ACK汇总
	wire [7:0] byte_0101;                   // 最近错误分类码
	wire [7:0] byte_0102;                   // 只读区偏移2，转发schema版本输入
	wire [7:0] byte_0103;                   // 只读区偏移3，转发配置版本输入
	wire [7:0] byte_0104;                   // Stage1版本
	wire [7:0] byte_0105;                   // Stage2版本
	wire [7:0] byte_0106;                   // DC恢复版本
	wire [7:0] byte_0107;                   // 调度器与AMI诊断汇总
	wire [7:0] byte_0108;                   // SSW诊断汇总
	wire [7:0] byte_0109;                   // 表征控制握手与诊断汇总
	wire [7:0] byte_010A;                   // 系统故障汇总首字节
	wire [7:0] byte_010B;                   // 系统故障阻断原因分类码
	wire [7:0] byte_010C;                   // 系统故障来源子模块编号
	wire [7:0] byte_010D;                   // 帧号低
	wire [7:0] byte_010E;                   // 帧号高
	wire [7:0] byte_010F;                   // 序号低
	wire [7:0] byte_0110;                   // 序号高
	wire [7:0] byte_0111;                   // 系统故障run_generation
	wire [7:0] byte_0112;                   // 汇总低
	wire [7:0] byte_0113;                   // 汇总高
	wire [7:0] byte_0114;                   // 正式结果discard控制字节
	wire [7:0] byte_0115;                   // 帧号低
	wire [7:0] byte_0116;                   // 帧号高
	wire [7:0] byte_0117;                   // 序号低
	wire [7:0] byte_0118;                   // 序号高
	wire [7:0] byte_0119;                   // 正式结果discard run_generation
	wire [7:0] byte_011A;                   // 正式结果discard精度位
	wire [7:0] byte_011B;                   // 检测discard控制字节
	wire [7:0] byte_011C;                   // 帧号低
	wire [7:0] byte_011D;                   // 帧号高
	wire [7:0] byte_011E;                   // 序号低
	wire [7:0] byte_011F;                   // 序号高
	wire [7:0] byte_0120;                   // 检测discard config_epoch
	wire [7:0] byte_0121;                   // 检测discard coef_epoch
	wire [7:0] byte_0122;                   // 检测discard dc_recovery_epoch
	wire [7:0] byte_0123;                   // 检测discard amb/dc_code_epoch
	wire [7:0] byte_0124;                   // 检测discard run_generation
	wire [7:0] byte_0125;                   // 检测discard精度位
	wire [303:0] diag_snapshot_next;        // 38字节按地址倒序拼装的完整304-bit待捕获快照
	wire [8:0] diag_byte_offset;            // 只读区地址相对0x0100的字节偏移

	//---------------输出信号---------------//
	// 全部端口均由组合assign或子模块直接导出，不需要额外的_o输出桥接寄存器

	//-------------其他信号连线-------------//
	// 下一拍即将成立的完整字节，供状态转移和提交逻辑组合读取
	assign shift_in_next = {reg_shift_in[6:0], i_spi_sdi}; // MSB-first移入，最后一比特是本拍SDI

	// 字节边界即比特计数到达第7个位置的那一拍
	assign flag_byte_boundary = (cnt_bit_in_byte == 3'd7); // 第8拍采样完成整字节

	// 写提交只在ST_DATA阶段且命令为写时成立
	assign flag_write_commit = flag_byte_boundary && (state_current == ST_DATA) && (flag_cmd_is_read == 1'b0); // 读事务不产生写提交

	// 命中0x0090命令字节的写提交
	assign flag_cmd_reg_hit = flag_write_commit && (reg_byte_addr == 16'd144); // 0x0090十进制为144

	// 命令字节6个独立触发位，允许同拍多位同时命中
	assign flag_trigger_start = flag_cmd_reg_hit && shift_in_next[0]; // 取最低位，供启动跨域桥接引用
	assign flag_trigger_stop = flag_cmd_reg_hit && shift_in_next[1]; // 取次低位，供停止跨域桥接引用
	assign flag_trigger_commit = flag_cmd_reg_hit && shift_in_next[2]; // 取中间位，直接驱动同域事件
	assign flag_trigger_diag_clear = flag_cmd_reg_hit && shift_in_next[3]; // 取第四位，供诊断清除跨域桥接引用
	assign flag_trigger_abort = flag_cmd_reg_hit && shift_in_next[4]; // 取第五位，供异常终止跨域桥接引用
	assign flag_trigger_char_update = flag_cmd_reg_hit && shift_in_next[5]; // 取最高有效位，置位表征保持请求
	assign flag_dbg_select_write = flag_write_commit && (reg_byte_addr == 16'd129); // 与reg_dbg_out_select自身的更新条件完全一致，作为跨域桥接触发源

	// 读事务在地址阶段第二字节结束、且命令已锁存为读时确认
	assign flag_read_start = flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b1) && flag_cmd_is_read; // 尽早触发，为哑字节窗口留出CDC往返时间

	// 读方向输出字节需要重新加载的两种情形：哑字节阶段末尾的第一字节，或数据阶段每个字节边界
	assign flag_load_read_byte = flag_cmd_is_read && (state_current == ST_DATA) && (cnt_bit_in_byte == 3'd0); // 负沿装载：上一字节第8个上升沿之后的下降沿（含哑字节结束后的首个数据字节），使主机本字节第1个上升沿采到bit7（合同第8.1节Mode 0上升沿采样；芯片层无验收ID，服务于ABCD F-005）

	// ST_DATA阶段每字节边界的重加载发生在地址真正自增之前一拍，需提前补偿+1才能对齐即将到来的新字节；
	// ST_DUMMY阶段的首次加载对应的正是当前已锁存地址本身，不需要补偿
	assign dec_read_load_addr = reg_byte_addr; // 装载点已在字节边界之后，地址已自增到本字节，无需补偿

	// 只读区地址相对0x0100的字节偏移，仅在地址落入只读区时有意义
	assign diag_byte_offset = dec_read_load_addr[8:0] - 9'd256; // 只读区首地址0x0100折算为十进制256后相减

	//-------------只读诊断区字节拼装-------------//
	// 生命周期状态与ACK/错误sticky汇总
	assign byte_0100 = {3'b000, i_error_sticky, i_commit_ack_sticky, i_start_ready, i_lifecycle_state}; // bits[7:5]保留
	assign byte_0101 = i_last_error_code;         // 单字节分类码，取值定义见C01合同错误编码表
	assign byte_0102 = i_schema_version;          // 单字节版本号，标识V4快照的字段布局代际
	assign byte_0103 = i_config_epoch;            // 单字节版本号，每次COMMIT整体递增
	assign byte_0104 = i_coef_epoch;              // 单字节版本号，随Stage1系数更新递增
	assign byte_0105 = i_stage2_coef_epoch;       // 单字节版本号，随Stage2增益偏置字段更新递增
	assign byte_0106 = i_dc_recovery_coef_epoch;  // 单字节版本号，随DC恢复系数更新递增
	assign byte_0107 = {i_active_precision_mode, i_ami_idac_idle, i_ami_datapath_empty, i_scheduler_protocol_error_sticky, i_scheduler_completion_mismatch_sticky, i_scheduler_owner_deadline_timeout_sticky, i_scheduler_launch_timeout_sticky, i_scheduler_idle}; // 调度器与AMI诊断按bit7到bit0排列
	assign byte_0108 = {2'b00, i_ssw_calibration_timeout_sticky, i_ssw_owner_deadline_timeout_sticky, i_ssw_transaction_mismatch_sticky, i_ssw_switch_protocol_error_sticky, i_ssw_wrapper_idle, i_ami_integration_protocol_error_sticky}; // SSW诊断按bit5到bit0排列，bits[7:6]保留
	assign byte_0109 = {4'b0000, i_characterization_protocol_error_sticky, i_characterization_control_valid, i_source_characterization_update_ready, i_source_config_update_ready}; // 表征与ACTIVE两路握手资格按bit3到bit0排列
	assign byte_010A = {i_result_discard_summary_sticky, i_system_fault_precision, i_system_fault_frame_type, i_system_fault_color_ir, i_system_fault_identity_valid, i_system_fault_cause_valid, i_system_fault_blocking}; // first-fault身份与discard汇总按bit7到bit0排列
	assign byte_010B = i_system_fault_cause;      // 单字节cause编码，取值范围见supervisor自身合同
	assign byte_010C = {4'b0000, i_system_fault_source}; // 低4位为来源子模块编号，bits[7:4]保留
	assign byte_010D = i_system_fault_frame_id[7:0]; // 帧号低
	assign byte_010E = i_system_fault_frame_id[15:8]; // 帧号高
	assign byte_010F = i_system_fault_sample_index[7:0]; // 序号低
	assign byte_0110 = i_system_fault_sample_index[15:8]; // 序号高
	assign byte_0111 = i_system_fault_run_generation; // 单字节RUN代际，first-fault快照建立时锁定
	assign byte_0112 = i_system_fault_summary[7:0]; // 汇总低
	assign byte_0113 = i_system_fault_summary[15:8]; // 汇总高
	assign byte_0114 = reg_mr_latch[7:0];         // 正式结果控制位
	assign byte_0115 = reg_mr_latch[15:8];        // 帧号低
	assign byte_0116 = reg_mr_latch[23:16];       // 帧号高
	assign byte_0117 = reg_mr_latch[31:24];       // 序号低
	assign byte_0118 = reg_mr_latch[39:32];       // 序号高
	assign byte_0119 = reg_mr_latch[47:40];       // 锁存的RUN代际字节
	assign byte_011A = {7'b0000000, reg_mr_latch[48]}; // bits[7:1]保留，bit0=precision
	assign byte_011B = reg_dd_latch[7:0];         // 检测清空控制位
	assign byte_011C = reg_dd_latch[15:8];        // 帧号低
	assign byte_011D = reg_dd_latch[23:16];       // 帧号高
	assign byte_011E = reg_dd_latch[31:24];       // 序号低
	assign byte_011F = reg_dd_latch[39:32];       // 序号高
	assign byte_0120 = reg_dd_latch[47:40];       // 锁存的ACTIVE配置版本字节
	assign byte_0121 = reg_dd_latch[55:48];       // 锁存的Stage1系数版本字节
	assign byte_0122 = reg_dd_latch[63:56];       // 锁存的DC恢复版本字节
	assign byte_0123 = reg_dd_latch[71:64];       // 锁存的颜色DC码与环境光抵消码版本各占4-bit
	assign byte_0124 = reg_dd_latch[79:72];       // 检测代际清空的RUN代际字节
	assign byte_0125 = {7'b0000000, reg_dd_latch[80]}; // bits[7:1]保留，bit0=precision

	// 38字节按地址倒序拼装，offset0（0x0100）落在最低8位
	assign diag_snapshot_next = {byte_0125, byte_0124, byte_0123, byte_0122, byte_0121, byte_0120, byte_011F, byte_011E, byte_011D, byte_011C, byte_011B, byte_011A, byte_0119, byte_0118, byte_0117, byte_0116, byte_0115, byte_0114, byte_0113, byte_0112, byte_0111, byte_0110, byte_010F, byte_010E, byte_010D, byte_010C, byte_010B, byte_010A, byte_0109, byte_0108, byte_0107, byte_0106, byte_0105, byte_0104, byte_0103, byte_0102, byte_0101, byte_0100}; // 与+:变量位选的偏移约定一致

	//-------------输出信号连线-------------//
	// SDO直接读出方向移位寄存器的最高位
	assign o_spi_sdo = reg_read_byte[7];    // 每次负沿更新后MSB即为本拍应采样值
	// V4+V5联合ACTIVE快照实时提供，COMMIT前不代表已生效
	assign o_source_config_snapshot = reg_active_shadow; // 突发写只更新影子区，本身即为待提交内容
	assign o_source_config_update_event = flag_trigger_commit; // 单周期source域事件，忙碌丢弃由既有CDC桥内部处理
	assign o_source_characterization_update_valid = flag_char_request_held; // 保持型请求，直到CDC ready被观察到
	assign o_source_static_characterization_enable = reg_characterization[0]; // STATIC_BIAS使能位，取0x0080寄存器bit0
	assign o_source_test_mux_ctrl = reg_characterization[5:1]; // 五位模拟测试MUX选择码，取0x0080寄存器bits[5:1]
	assign o_dbg_out_select = reg_dbg_out_select; // 直接导出6选1候选选择值，本身仍是SPI_SCLK域寄存器，须配合下方更新事件在CLK_2M域安全锁存后才可使用
	assign o_dbg_out_select_update_event = w_dbg_select_update_event; // 直接导出选择值更新桥接产物
	assign o_start_event = w_start_event;   // 直接导出启动桥接产物
	assign o_stop_event = w_stop_event;     // 直接导出停止桥接产物
	assign o_diag_clear_event = w_diag_clear_event; // 直接导出诊断清除桥接产物
	assign o_control_abort_event = w_abort_event; // 直接导出异常终止桥接产物

	//-----------状态机区域-----------//
	// 当前态寄存器在片选释放或复位时清空，否则每拍锁存组合次态
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			state_current <= ST_IDLE; // 片选释放视为事务结束，回到空闲
		end else begin
			state_current <= state_next; // 每拍无条件锁存组合次态
		end
	end

	// 次态组合逻辑先默认维持当前态，再按各阶段的字节边界条件覆盖
	always@(*)begin
		state_next = state_current;   // 默认维持当前态，避免遗漏分支产生锁存
		case(state_current)
			ST_IDLE:begin
				state_next = ST_CMD;  // 片选已低（异步分支已排除高电平情形），立即开始接收命令字节
			end
			ST_CMD:begin
				if(flag_byte_boundary)begin
					state_next = ST_ADDR; // 命令字节接收完毕，进入地址阶段
				end
			end
			ST_ADDR:begin
				if(flag_byte_boundary && (cnt_field_byte == 1'b1))begin
					state_next = flag_cmd_is_read ? ST_DUMMY : ST_DATA; // 地址两字节接收完毕，按读写分流
				end
			end
			ST_DUMMY:begin
				if(flag_byte_boundary && (cnt_field_byte == 1'b1))begin
					state_next = ST_DATA; // 两个哑字节结束，进入真实数据阶段
				end
			end
			ST_DATA:begin
				state_next = ST_DATA; // 变长突发，只由片选释放结束，不在此处主动退出
			end
			default:begin
				state_next = ST_IDLE; // 非法态兜底回到安全空闲态
			end
		endcase
	end

	//-----------状态任务处理区域-----------//
	// ADDR/DUMMY阶段各自的字节位置计数，直接依据state_current分支
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			cnt_field_byte <= 1'b0;         // 新事务起点，字节位置计数从0开始
		end else if(flag_byte_boundary && (state_current == ST_CMD))begin
			cnt_field_byte <= 1'b0;         // 进入ADDR，从第一字节开始计
		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b0))begin
			cnt_field_byte <= 1'b1;         // ADDR第一字节完成，进入第二字节
		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b1))begin
			cnt_field_byte <= 1'b0;         // ADDR第二字节完成，为DUMMY或DATA重新计数
		end else if(flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b0))begin
			cnt_field_byte <= 1'b1;         // DUMMY第一字节完成
		end else if(flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b1))begin
			cnt_field_byte <= 1'b0;         // DUMMY第二字节完成，为DATA重新计数（DATA不使用该计数）
		end else begin
			cnt_field_byte <= cnt_field_byte; // 非字节边界拍，字节位置计数原样保持
		end
	end

	// 事务地址寄存器：地址阶段两字节锁存，数据阶段按字节自增
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			reg_byte_addr <= 16'd0;         // 新事务起点，地址寄存器清零等待接收
		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b0))begin
			reg_byte_addr[15:8] <= shift_in_next; // 地址高字节先到
		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b1))begin
			reg_byte_addr[7:0] <= shift_in_next; // 地址低字节到齐，完整16-bit地址就绪
		end else if(flag_byte_boundary && (state_current == ST_DATA))begin
			reg_byte_addr <= reg_byte_addr + 16'd1; // 突发访问按字节自增
		end else begin
			reg_byte_addr <= reg_byte_addr; // 尚未到达下一个字节边界，地址原样保持
		end
	end

	// 命令字节最高位（读写方向）只在ST_CMD结束时锁存
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			flag_cmd_is_read <= 1'b0;       // 新事务起点，默认按写方向处理直到命令字节到齐
		end else if(flag_byte_boundary && (state_current == ST_CMD))begin
			flag_cmd_is_read <= shift_in_next[7]; // 命令字节bit7区分读写
		end else begin
			flag_cmd_is_read <= flag_cmd_is_read; // 命令字节已锁存，本次事务余下阶段维持该读写方向
		end
	end

	// 读方向输出移位寄存器在负沿更新，满足Mode 0建立时间；直接依据state_current分支
	always@(negedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			reg_read_byte <= 8'h00;         // 新事务起点，SDO移位寄存器清零等待首次加载
		end else if(flag_load_read_byte)begin
			reg_read_byte <= dec_read_byte; // 加载当前地址译码出的字节
		end else if(flag_cmd_is_read && (state_current == ST_DATA))begin
			reg_read_byte <= {reg_read_byte[6:0], 1'b0}; // 字节内其余7个负沿各左移一位，主机在随后上升沿依次采到bit6..bit0
		end else begin
			reg_read_byte <= reg_read_byte; // 非读方向数据阶段，SDO内容不需要变化
		end
	end

	//-----------主要任务处理区域-----------//
	// 字节内比特计数循环0~7，天然溢出回绕，不需要显式清零分支
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			cnt_bit_in_byte <= 3'd0;        // 新事务起点，比特计数从0开始
		end else begin
			cnt_bit_in_byte <= cnt_bit_in_byte + 3'd1; // 每拍推进，第7拍后自然回绕到0
		end
	end

	// 每个SPI_SCLK上升沿采样一次SDI，向左移入
	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
			reg_shift_in <= 8'h00;          // 新事务起点，移位寄存器清零等待首个比特
		end else begin
			reg_shift_in <= shift_in_next;  // 每拍左移并接入本拍SDI
		end
	end

	// V4+V5联合ACTIVE影子区跨事务保持，只按字节地址写入对应8-bit切片
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_active_shadow <= {1024{1'b0}}; // 上电或系统复位才清零，片选释放不影响已写入的配置
		end else if(flag_write_commit && (reg_byte_addr[15:7] == 9'd0))begin
			reg_active_shadow[({reg_byte_addr[6:0], 3'b000}) +: 8] <= shift_in_next; // 地址0-127命中影子区
		end else begin
			reg_active_shadow <= reg_active_shadow; // 本拍未命中影子区地址，1024-bit内容原样保持
		end
	end

	// 0x0080表征控制字节跨事务保持
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_characterization <= 6'd0;   // 仅响应源域真实复位，日常事务切换不触碰该字节
		end else if(flag_write_commit && (reg_byte_addr == 16'd128))begin
			reg_characterization <= shift_in_next[5:0]; // bit0使能，bits[5:1]测试MUX选择码
		end else begin
			reg_characterization <= reg_characterization; // 本拍未命中0x0080地址，内容原样保持
		end
	end

	// 0x0081 DBG_OUT选择字节跨事务保持
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_dbg_out_select <= 3'd0;     // 上电或系统复位才清零，默认选择候选0
		end else if(flag_write_commit && (reg_byte_addr == 16'd129))begin
			reg_dbg_out_select <= shift_in_next[2:0]; // 仅低3位有效
		end else begin
			reg_dbg_out_select <= reg_dbg_out_select; // 本拍未命中0x0081地址，选择值原样保持
		end
	end

	// 表征更新保持型请求：触发即置位，观察到ready才回落，跨事务保持
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			flag_char_request_held <= 1'b0; // 上电或系统复位才清零，片选释放不打断在途请求
		end else if(flag_trigger_char_update)begin
			flag_char_request_held <= 1'b1; // 新请求置位，优先于同拍ready回落
		end else if(flag_char_request_held && i_source_characterization_update_ready)begin
			flag_char_request_held <= 1'b0; // 已发出的请求被CDC邮箱接受，回落
		end else begin
			flag_char_request_held <= flag_char_request_held; // 既无新请求也无回落条件，维持原状态
		end
	end

	// CLK_2M域只读诊断快照：仅在读方向捕获触发时整体刷新，其余时刻冻结
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_diag_snapshot <= {304{1'b0}}; // 系统复位清零，等待第一次真实捕获
		end else if(w_capture_trigger)begin
			reg_diag_snapshot <= diag_snapshot_next; // 新读事务到达地址阶段末尾，整体捕获当前状态
		end else begin
			reg_diag_snapshot <= reg_diag_snapshot; // 冻结，保证同一读事务内前后字节一致
		end
	end

	// 诊断快照门控捕获：仅在w_diag_snapshot_gate_event（已独立2FF同步安全的单bit事件）为真时才采样整条总线，
	// 此刻reg_diag_snapshot已经历完整的事件跨域延迟、早已稳定多拍，不是对304-bit总线的无门控直接双触发器
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_diag_snapshot_gated <= {304{1'b0}}; // 源域复位清零，等待第一次真实门控捕获
		end else if(w_diag_snapshot_gate_event)begin
			reg_diag_snapshot_gated <= reg_diag_snapshot; // 门控为真的这一拍，源端早已稳定多拍，安全整体捕获
		end else begin
			reg_diag_snapshot_gated <= reg_diag_snapshot_gated; // 无新事件，保持上一次门控捕获的内容
		end
	end

	// 门控捕获后的同域流水线寄存器：与reg_diag_snapshot_gated同为i_source_clk域，属于普通同域转发，不存在跨域撕裂风险
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_diag_sync_stable <= {304{1'b0}}; // 源域复位清零，为读方向取值提供确定初值
		end else begin
			reg_diag_sync_stable <= reg_diag_snapshot_gated; // 同域寄存器转发，为读方向取值多留一拍裕量
		end
	end

	// 正式结果discard独立锁存，翻转位供主机区分是否为新事件，不依赖任何SPI读取时机
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_mr_latch <= 49'd0;          // 系统复位清零，翻转位归零等待第一次真实discard
		end else if(i_measurement_result_discard_event)begin
			reg_mr_latch <= {i_measurement_result_discard_precision, i_measurement_result_discard_run_generation, i_measurement_result_discard_sample_index, i_measurement_result_discard_frame_id, i_measurement_result_discard_frame_type, i_measurement_result_discard_color_ir, i_measurement_result_discard_sample_valid, i_measurement_result_discard_identity_valid, i_measurement_result_discard_reason, ~reg_mr_latch[0]}; // 整体重新锁存并翻转标志位
		end else begin
			reg_mr_latch <= reg_mr_latch;   // 无新事件，保持上一次锁存内容
		end
	end

	// 检测代际清空discard独立锁存，翻转位供主机区分是否为新事件，不依赖任何SPI读取时机
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_dd_latch <= 81'd0;          // 上电初值全零，尚未观察到任何一次代际清空广播
		end else if(i_detection_discard_event)begin
			reg_dd_latch <= {i_detection_discard_precision, i_detection_discard_run_generation, i_detection_discard_dc_code_epoch, i_detection_discard_amb_code_epoch, i_detection_discard_dc_recovery_epoch, i_detection_discard_coef_epoch, i_detection_discard_config_epoch, i_detection_discard_sample_index, i_detection_discard_frame_id, i_detection_discard_frame_type, i_detection_discard_color_ir, i_detection_discard_sample_valid, i_detection_discard_identity_valid, i_detection_discard_reason, ~reg_dd_latch[0]}; // 含4个版本字段的完整payload覆盖旧值，末位翻转供主机识别
		end else begin
			reg_dd_latch <= reg_dd_latch;   // 广播未触发，保持既有锁存字段不变
		end
	end

	// 按即将加载的有效字节地址译码出应加载的字节内容，覆盖写影子回读、表征、DBG选择、命令与只读诊断区
	always@(*)begin
		if(dec_read_load_addr[15:7] == 9'd0)begin
			dec_read_byte = reg_active_shadow[({dec_read_load_addr[6:0], 3'b000}) +: 8]; // 影子区按写入内容原样回读
		end else if(dec_read_load_addr == 16'd128)begin
			dec_read_byte = {2'b00, reg_characterization}; // 0x0080：bits[7:6]保留
		end else if(dec_read_load_addr == 16'd129)begin
			dec_read_byte = {5'b00000, reg_dbg_out_select}; // 0x0081：bits[7:3]保留
		end else if(dec_read_load_addr == 16'd144)begin
			dec_read_byte = 8'h00;          // 0x0090命令寄存器一次性写入，无持久内容，回读固定为0
		end else if((dec_read_load_addr >= 16'd256) && (dec_read_load_addr < 16'd294))begin
			dec_read_byte = reg_diag_sync_stable[({diag_byte_offset[5:0], 3'b000}) +: 8]; // 0x0100-0x0125只读诊断区
		end else begin
			dec_read_byte = 8'h00;          // 未定义地址统一回读0
		end
	end

	//-----------模块实例化区域-----------//
	// 启动命令需要跨入数字系统域，ppg_control_top自身端口标注"已同步"，本模块提供唯一桥接
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_start_Inst(
		.i_source_clk(i_source_clk),      // 启动桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 启动桥接第一级：接配置源复位
		.i_source_pulse(flag_trigger_start), // 启动桥接触发源：命令字节最低位
		.i_dest_clk(i_clk),               // 启动桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 启动桥接第二级：接数字系统域复位
		.o_dest_pulse(w_start_event)      // 启动桥接产物：转发交给下方assign对外输出
	);

	// 停止命令同样要跨入数字系统域，复用同一桥接子模块的第二份独立例化
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_stop_Inst(
		.i_source_clk(i_source_clk),      // 停止桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 停止桥接第一级：接配置源复位
		.i_source_pulse(flag_trigger_stop), // 停止桥接触发源：命令字节次低位
		.i_dest_clk(i_clk),               // 停止桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 停止桥接第二级：接数字系统域复位
		.o_dest_pulse(w_stop_event)       // 停止桥接产物：转发交给下方assign对外输出
	);

	// 诊断清除同样要跨入数字系统域，复用同一桥接子模块的第三份独立例化
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_diag_clear_Inst(
		.i_source_clk(i_source_clk),      // 诊断清除桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 诊断清除桥接第一级：接配置源复位
		.i_source_pulse(flag_trigger_diag_clear), // 诊断清除桥接触发源：命令字节第4位
		.i_dest_clk(i_clk),               // 诊断清除桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 诊断清除桥接第二级：接数字系统域复位
		.o_dest_pulse(w_diag_clear_event) // 诊断清除桥接产物：转发交给下方assign对外输出
	);

	// 异常终止同样要跨入数字系统域，复用同一桥接子模块的第四份独立例化
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_abort_Inst(
		.i_source_clk(i_source_clk),      // 终止桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 终止桥接第一级：接配置源复位
		.i_source_pulse(flag_trigger_abort), // 终止桥接触发源：命令字节第5位
		.i_dest_clk(i_clk),               // 终止桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 终止桥接第二级：接数字系统域复位
		.o_dest_pulse(w_abort_event)      // 终止桥接产物：转发交给下方assign对外输出
	);

	// 读取捕获是第五份并非源自命令字节的独立例化，驱动只读诊断快照的整体捕获
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_capture_Inst(
		.i_source_clk(i_source_clk),      // 捕获桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 捕获桥接第一级：接配置源复位
		.i_source_pulse(flag_read_start), // 捕获桥接触发源：读事务抵达地址阶段末尾
		.i_dest_clk(i_clk),               // 捕获桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 捕获桥接第二级：接数字系统域复位
		.o_dest_pulse(w_capture_trigger)  // 捕获桥接产物：驱动快照寄存器，本身不导出端口
	);

	// DBG_OUT选择值更新是第六份独立例化：合同8.3节要求该多bit值必须经小型CDC才能驱动CLK_2M域选择器，
	// 不得零同步级直接跨域；本实例只桥接"更新事件"这一单比特脉冲，reg_dbg_out_select真实取值本身仍留在
	// SPI_SCLK域读出，由CLK_2M域消费者收到本事件后再锁存，同DBG_OUT选择值CDC推荐做法
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_dbg_select_Inst(
		.i_source_clk(i_source_clk),      // 选择值更新桥接第一级：接配置源时钟
		.i_source_rstn(i_source_rstn),    // 选择值更新桥接第一级：接配置源复位
		.i_source_pulse(flag_dbg_select_write), // 选择值更新桥接触发源：真实写命中0x0081
		.i_dest_clk(i_clk),               // 选择值更新桥接第二级：接数字系统域时钟
		.i_dest_rstn(i_rstn),             // 选择值更新桥接第二级：接数字系统域复位
		.o_dest_pulse(w_dbg_select_update_event) // 选择值更新桥接产物：转发交给上方assign对外输出
	);

	// 诊断快照就绪事件是第七份独立例化，方向与其余六份相反：源域改为i_clk（reg_diag_snapshot所在域），目标域为i_source_clk，
	// 把reg_diag_snapshot_gated的采样时刻主动推迟到reg_diag_snapshot确认稳定之后，消除对304-bit总线无门控直接双触发器的撕裂风险，
	// 修复依据见memory project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914
	ppg_pulse_cdc_sync ppg_pulse_cdc_sync_diag_ready_Inst(
		.i_source_clk(i_clk),             // 就绪桥接第一级：接数字系统域时钟，reg_diag_snapshot所在域
		.i_source_rstn(i_rstn),           // 就绪桥接第一级：接数字系统域复位
		.i_source_pulse(w_capture_trigger), // 就绪桥接触发源：reg_diag_snapshot真正完成捕获的同一事件，不新增额外触发条件
		.i_dest_clk(i_source_clk),        // 就绪桥接第二级：接配置源时钟
		.i_dest_rstn(i_source_rstn),      // 就绪桥接第二级：接配置源复位
		.o_dest_pulse(w_diag_snapshot_gate_event) // 门控桥接产物：门控reg_diag_snapshot_gated的采样时刻
	);

endmodule
