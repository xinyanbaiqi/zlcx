`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026-08-12
// Design Name: 	PPG ADC Measurement and IDAC Integration
// Module Name: 	ppg_adc_measurement_idac_integration
// Description: 	Integrates ADC reconstruction, IDAC control, DC recovery,
// Dependencies:
// Ten independently verified PPG datapath/control modules
// 十个已经独立验证的PPG数据与控制子模块
// Simulations:		tb_ppg_adc_measurement_idac_integration
//
// Referrences:		PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// Version:			V1.15
// Revision Date:	2026-09-18
// History:
//    Time			   Version	   Revised by			Contents
// 2026-08-12			V1.0		 Erie		Create file.
// 2026-08-13			V1.1		 Erie		Split macro-frame and IDAC code boundaries.
// 2026-08-14			V1.2		 Erie		Add reliable ADC completion sideband.
// 2026-08-15			V1.3		 Erie		Freeze ADC result ownership and late-DONE release.
// 2026-08-16			V1.3.2	 Erie		Permit an ADC owner after the preceding real DONE during the next waveform pre-establishment.
// 2026-08-22			V1.4		 Erie		Add i_run_generation, the o_ami_fault_* five-lane blocking-cause dispatcher (cause 8'h01-8'h05, only 8'h04/8'h05 wired to real sources), the private datapath_discard/detection_discard event generation logic, and wire the fork/router/overlap/IDAC/PWI generation and discard ports into their instantiations, per PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md sections 6.10/6.11.
// 2026-08-22			V1.5	 Erie		Wire cause 8'h01 (protected sample-index mismatch, section 6.5b) to flag_test_identity_inject_fire/flag_test_identity_hold; 8'h02/8'h03 remain deliberately unwired pending a contract-defined split.
// 2026-08-22			V1.6	 Erie		Fold flag_system_fault_discard_pending into flag_result_abort_discard so the existing calibrator/router masked-valid self-drain (and every other consumer of this flag) also releases on a pure supervisor system-fault episode, not only on abort/STOP; per section 2.2's re-verified conclusion the S1 calibrator and S1 redundancy corrector deliberately keep no dedicated i_run_generation/datapath_discard port group.
// 2026-08-23			V1.7	 Erie		Rename the internal flag_precision_takeover_adc_idle wire to flag_precision_takeover_safe and its PWI instance connection to i_precision_takeover_safe (pure rename, no logic change); the composite formula itself was already correct and already matched section 14.5 term for term.
// 2026-08-23			V1.8	 Erie		Wire the reconstructor's 8 previously-dangling diagnostic passthrough outputs (detect_code/stage1_raw/stage1_code_ext/stage2_raw/stage2_code_ext/nominal_15_code/nominal_15_valid/nominal_saturated) into the DC recovery instance's newly added same-name inputs per PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md section 11.3; DC recovery's own new outputs are left dangling pending a future consumer.
// 2026-08-23			V1.9	 Erie		Wire cause 8'h02 (unrecoverable owner/protocol error) and 8'h03 (unprovable controlled-recovery context) of the o_ami_fault_* dispatcher to real sources by cross-referencing section 6.11's cause names against section 15.2's blocking-fault wording: the four flag_integration_blocking protocol sub-conditions that break request/result correspondence (calibration result mismatch, capture without owner, calibration start type mismatch, startup/recheck request conflict) map to 8'h02; the one sub-condition matching section 15.2's "cannot prove the original owner can execute the contract-allowed failure release" (completion identity vs. owner mismatch) maps to 8'h03. Both lanes reuse the physical ADC owner snapshot for identity, forcing identity_valid/FAULT_ID to zero when no owner is held; dispatch priority updated to 8'h01>8'h02>8'h03>8'h04>8'h05 per section 6.11.
// 2026-08-23			V1.10	 Erie		Add the section 6.10 public o_measurement_result_discard and o_detection_discard port groups (prerequisite for the not-yet-written system fault/abort supervisor, C24). o_detection_discard is a pure re-export of the signals already wired into PWI's i_detection_discard group (factored into named wires, no logic change). o_measurement_result_discard is a new registered one-cycle event capturing the cycle flag_measurement_pending is released by flag_result_abort_discard instead of a real i_measurement_result_ready transfer; reason is bucketed system-fault/abort/stop from flag_result_abort_discard's own five sub-conditions, identity/TXN_ID sourced from the NORMAL fork's measurement-branch snapshot.
// 2026-08-23			V1.11	 Erie		Fix a real STOP-with-owner-inflight deadlock found via ppg_control_top's first system-level directed simulation of this exact timing window: flag_stop_result_draining only armed when flag_adc_transaction_inflight was already 0 at i_stop_ack_event, so a STOP that caught a real ADC owner still in flight left the flag disarmed. The scheduler has no discard/generation signal toward AMI, so when the real DONE for that owner later arrived, AMI treated it as an ordinary successful transaction and pushed it through the normal detection fork; flag_detection_pending then stuck forever because its downstream consumer (PWI) had already stopped operating once RUN ended, deadlocking o_measurement_output_idle/o_datapath_empty and therefore the manager's STOPPING-to-CONFIG drain, recoverable only by an explicit abort. Section 13's frozen late-DONE rule 1 requires unconditionally: "STOP接受时所有尚未完成owner都已经标记为丢弃" (at STOP-accept, ALL not-yet-complete owners are marked discarded, not only owners absent at that instant) with the resulting DONE limited to a single original-identity success=0 release that must never enter the formal result, IDAC, calibration or detection chain. Fix: drop the flag_adc_transaction_inflight==1'b0 guard so i_stop_ack_event unconditionally arms flag_stop_result_draining regardless of whether an owner happens to be in flight at that exact cycle; flag_result_abort_discard, the detection/measurement fork release paths and the DISCARD_REASON_STOP tagging were already correct and needed no change once the flag arms on time.
// 2026-08-24			V1.12	 Erie		Fix a real LFA-08 STOP/abort recovery deadlock found via the first directed injection-enabled system simulation (tb_ppg_control_top_injection.v, C_ENABLE_TEST_INJECTION=1): flag_adc_completion_abort_release required flag_s1_detect_valid (the redundancy corrector's own transient output-buffer valid, sourced from o_detect_valid at line ~2637 instantiation) in addition to flag_adc_completion_pending. flag_s1_detect_valid is cleared by the corrector itself within one to two cycles of the original real DONE (its own internal flag_detect_transfer consumes it into AMI's persistent flag_adc_completion_pending latch), while flag_test_identity_hold-gated STOP/abort recovery is by design meant to fire much later, whenever the operator actually issues STOP or abort after observing the mismatch fault -- by that time flag_s1_detect_valid has already been 0 for a long time, so the release condition as written was essentially unreachable outside an impossible same-cycle coincidence, permanently deadlocking the RUN in STOPPING with no clean recovery path once an LFA-08 mismatch fired (confirmed by the injection TB: 2000+ cycles with zero progress after both a plain STOP and a registered abort). The retained transaction's own identity fields (dec_s1_frame_id/dec_s1_sample_index/etc.) are unaffected by flag_s1_detect_valid falling to 0 -- they are separately held in the redundancy corrector's own metadata_o register, only overwritten on the next real capture -- so dropping this term does not risk emitting stale or corrupted identity data. Fix: flag_adc_completion_abort_release now depends only on flag_test_identity_hold, i_control_abort_event and flag_adc_completion_pending; the closure matrix's undisputed "AMI physical completion owner" row (STOP/abort replays original proven ID once with success=0) was already correct semantics, this was a pure implementation gap, not a semantic dispute. Per PPG_CONTRACT_CLOSURE_MATRIX.md this closes the implementation half of P07/P08 (previously EVIDENCE_PENDING); tb_ppg_control_top_injection.v INJ-02 is the first real simulation evidence for this path.
// 2026-08-31			V1.13	 Erie		Stage 5 bucket-2 RTL session, port-threading step: add a new AMI-level `i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` pair to the existing section 6.5b "验证专用异常注入" port group, threading through into PWI's newly-added same-purpose ports (ppg_precision_window_integration.v V1.4, itself threading into ppg_coarse_detection_fir.v V2.3). No new AMI parameter or enable port -- reuses the existing `C_ENABLE_TEST_INJECTION` parameter and passes AMI's own already-gated `flag_test_inject_effective` down as the child's `i_test_inject_enable`, the exact same composition pattern this file already uses for the IDAC controller's own saturation-injection group (line ~2340). Bit-identical production behavior confirmed by re-running the main smoke TB through the full ppg_control_top hierarchy (SMOKE_TB_PASS, identical counters) and the injection TB with C_ENABLE_TEST_INJECTION=1 actually live (INJ_TB_PASS, all existing INJ-00~04 unaffected).
// 2026-09-05			V1.14	 Erie		Add the section 8.4.5 P2S telemetry boundary passthrough group: new AMI-level outputs o_s1_calibration_applied (pure re-export of the existing flag_dc_s1_calibration_applied wire, i.e. ppg_adc_dc_recovery_Inst's own o_calibration_applied), o_s1_raw and o_s2_raw (newly wired from that same instance's previously-dangling o_stage1_raw/o_stage2_raw at line ~2284/2286 into two new wires dec_dc_stage1_raw/dec_dc_stage2_raw). Deliberately sources from ppg_adc_dc_recovery's own re-exported atomic payload_o register, not the reconstructor's earlier dec_reconstructor_stage1_raw/dec_reconstructor_stage2_raw (declared line 722/724, wired line 2180/2182) -- the reconstructor pair is not latched into the same atomic transaction as frame_id/sample_index/coarse/fine, so using it would misalign the P2S packet. Per PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md V1.6 section 8.4.5. No logic change to any existing port; bit-identical production behavior confirmed by re-running the main smoke TB through the full ppg_control_top hierarchy (SMOKE_TB_PASS, real_adc_responses=47 measurement_result_valid=32, identical to pre-change).
// 2026-09-18			V1.15	 Erie		Fix a real permanent calibration-search deadlock found while investigating workline-D's SID-05 pending item, confirmed by a real iverilog A/B trace: flag_calibration_request_inflight previously only cleared on flag_amb_sample_accepted/flag_dcs_sample_accepted (a genuine consumed search result) or STOP/abort. When the scheduler's own flag_cal_owner_deadline (ppg_400hz_frame_calibration_scheduler.v, tick-248 owner-commit deadline, C25 contract section 9.4.1) suppresses a candidate window because the physical ADC owner never committed in time, no ADC owner and no transaction ever existed for that request, so neither accepted-result condition can ever fire -- flag_calibration_request_inflight stayed 1 forever, calibration_sample_valid_o never re-armed, and the scheduler's own B_CAL_CONTEXT_SEEN permanently locked closed since it never saw a fresh pending request at any later subframe boundary, stranding the entire calibration search (AMB or DCS_CAL) with no self-recovery. Trace evidence: forcing i_adc_physical_idle=0 across a genuine mid-search DC_R candidate's deadline correctly suppressed that one candidate (matching design intent) but left all 12/12 subsequent retries permanently failing with no Q3 window ever opening again. Fix: added a new i_cal_owner_deadline_event input, wired to the scheduler's new V1.8 o_cal_owner_deadline_event output (itself a direct passthrough of the pre-existing, already self-clearing flag_cal_owner_deadline pulse), and added it as an additional flag_calibration_request_inflight clear condition alongside the existing accepted-result terms -- letting AMI immediately re-arm calibration_sample_valid_o for the same still-wanted candidate on the very next opportunity instead of stalling forever. No other logic touched; reg_inflight_frame_type/reg_inflight_color_ir are unaffected since they only update on the next calibration_request_fire_o, exactly as before.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026-08-12
// 设计名称: 		PPG ADC Measurement and IDAC Integration
// 模块名称: 		ppg_adc_measurement_idac_integration
// 模块说明:		Integrates ADC reconstruction, IDAC control, DC recovery,
// 依赖文件:
// Ten independently verified PPG datapath/control modules
// 十个已经独立验证的PPG数据与控制子模块
// 仿真工程: 		tb_ppg_adc_measurement_idac_integration
//
// 参考资料:		PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.15
// 修订日期:		2026-09-18
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026-08-12		V1.0		 Erie		创建文件
// 2026-08-13		V1.1		 Erie		拆分宏帧与IDAC码安全边界
// 2026-08-14		V1.2		 Erie		增加可靠ADC完成旁带
// 2026-08-15		V1.3		 Erie		冻结ADC结果owner与迟到DONE释放
// 2026-08-16		V1.3.2	 Erie		解除波形预建立期间对ADC结果owner提交的不当阻塞
// 2026-08-22		V1.4		 Erie		按合同6.10/6.11节新增i_run_generation、o_ami_fault_*五路阻断故障分发器（cause 8'h01~8'h05，仅8'h04/8'h05接入真实来源）、私有datapath_discard/detection_discard事件生成逻辑，并把fork/router/overlap/IDAC/PWI已就绪的代际与discard端口接入各自例化调用
// 2026-08-22		V1.5	 Erie		把cause 8'h01（受保护sample-index错配，合同6.5b节）接到flag_test_identity_inject_fire/flag_test_identity_hold；8'h02/8'h03暂不接，等待合同给出可区分的判据
// 2026-08-22		V1.6	 Erie		把flag_system_fault_discard_pending并入flag_result_abort_discard，使校准器/router既有的valid遮蔽自排空机制（以及这个信号的其它所有消费点）在纯系统故障episode下也能释放，不再只响应abort/STOP；按2.2节重新核实的结论，S1校准器和S1冗余校正器故意不加独立的i_run_generation/datapath_discard端口组
// 2026-08-23		V1.7	 Erie		把内部wire flag_precision_takeover_adc_idle改名为flag_precision_takeover_safe，并把接入PWI例化的端口连接改成i_precision_takeover_safe（纯改名，不改逻辑）——这个复合公式本身早就是对的，和合同14.5节逐项完全一致
// 2026-08-23		V1.8	 Erie		按合同DC恢复合同11.3节，把重构器原来留空的8个诊断透传输出（detect_code/stage1_raw/stage1_code_ext/stage2_raw/stage2_code_ext/nominal_15_code/nominal_15_valid/nominal_saturated）接进DC恢复实例新增的同名输入；DC恢复自己的新输出暂时留空，等以后有真实消费方再接
// 2026-08-23		V1.9	 Erie		把o_ami_fault_*分发器的cause 8'h02（无法恢复的owner/协议错误）和8'h03（无法证明的受控恢复上下文）接上真实来源——对照合同6.11节cause命名与15.2节判据文字，把flag_integration_blocking现有的4个"破坏请求/响应唯一对应关系"协议子条件（校准结果错配、无owner的RAW交接、校准start类型不匹配、启动/重检请求冲突）归为8'h02；唯一匹配15.2节"无法证明可用原owner执行合同允许的失败释放"语义的子条件（completion身份与owner错配）归为8'h03。两路identity均复用物理ADC owner快照，无owner时identity_valid/FAULT_ID强制清零；分发优先级按合同6.11节更新为8'h01>8'h02>8'h03>8'h04>8'h05
// 2026-08-23		V1.10	 Erie		按合同6.10节新增公开端口组o_measurement_result_discard与o_detection_discard（尚未编写的系统故障/abort supervisor即C24的前置依赖）。o_detection_discard是已经接入PWI的i_detection_discard那批信号的纯re-export（提取成具名wire，不改逻辑）。o_measurement_result_discard是全新的单周期注册事件，捕获flag_measurement_pending被flag_result_abort_discard释放而非真实i_measurement_result_ready消费的那一拍；原因按flag_result_abort_discard自己的5个子条件归类为系统故障、abort、STOP三态，身份与TXN_ID取自NORMAL fork测量分支快照
// 2026-08-23		V1.11	 Erie		修复ppg_control_top第一次针对这个精确时序窗口的整机定向仿真发现的真实"STOP恰好命中owner已在途"死锁：flag_stop_result_draining原来只在i_stop_ack_event到达时flag_adc_transaction_inflight已经是0才置位，STOP若恰好命中一笔真实ADC owner仍在途的时刻则该标志保持不置位。调度器没有任何discard/代际信号扇给AMI，于是等这笔owner的真实DONE后来到达时，AMI把它当成普通成功事务照常推入检测fork；flag_detection_pending从此永久卡住，因为它的下游消费者（PWI）在RUN结束后已经停止运作，进而死锁o_measurement_output_idle/o_datapath_empty，manager的STOPPING排空永远到不了CONFIG，只有显式abort才能解套。合同第13节冻结的迟到DONE规则第1条明确要求无条件："STOP接受时所有尚未完成owner都已经标记为丢弃"（不是只标记STOP那一刻恰好没有owner在途的情况），随后的DONE只能产生一次原身份success=0释放，绝不得进入正式结果、IDAC、校准或检测链。修复：去掉flag_adc_transaction_inflight==1'b0这个前置条件，让i_stop_ack_event无条件置位flag_stop_result_draining，不再区分STOP到达那一拍owner是否恰好在途；flag_result_abort_discard、检测/测量fork的释放路径和DISCARD_REASON_STOP归类原本就是对的，标志按时置位后不需要跟着改
// 2026-08-24		V1.12	 Erie		修复第一次真正打开注入的整机定向仿真（tb_ppg_control_top_injection.v，C_ENABLE_TEST_INJECTION=1）发现的真实LFA-08 STOP/abort恢复死锁：flag_adc_completion_abort_release原来除了flag_adc_completion_pending之外还要求flag_s1_detect_valid（S1冗余校正器自己输出缓存的瞬态valid，来自2637行例化里的o_detect_valid）同时为1。flag_s1_detect_valid在原始真实DONE到达后一两拍内就被校正器自己清掉（它自己的flag_detect_transfer把这笔结果交接进AMI持久锁存的flag_adc_completion_pending后就完成使命），而flag_test_identity_hold门控的STOP/abort恢复按设计本来就该在操作员观察到错配故障、之后任意时刻才真正发出——那时flag_s1_detect_valid早已回落了很久，导致这条释放条件实际上永远等不到（除非abort恰好落在与原始DONE完全同一拍这种不可能构造的巧合），一旦LFA-08错配触发就永久卡死在STOPPING、没有干净恢复路径（注入TB实测：无论纯STOP还是注册式abort，2000多拍毫无进展）。被保留事务自己的身份字段（dec_s1_frame_id/dec_s1_sample_index等）不会因为flag_s1_detect_valid回落到0而失真——它们单独保存在校正器自己的metadata_o寄存器里，只有下一次真实捕获才会覆写——所以去掉这一项不会有输出陈旧或身份损坏的风险。修复：flag_adc_completion_abort_release现在只依赖flag_test_identity_hold、i_control_abort_event和flag_adc_completion_pending；closure matrix里"AMI physical completion owner"这一行（STOP/abort以原身份重放一次success=0）语义本身没有争议，这纯粹是实现缺口，不是语义分歧。按PPG_CONTRACT_CLOSURE_MATRIX.md，这条关闭了P07/P08此前EVIDENCE_PENDING的实现证据部分；tb_ppg_control_top_injection.v的INJ-02是这条路径第一份真实仿真证据
// 2026-08-31		V1.13	 Erie		Stage 5桶2 RTL会话端口透传步骤：在既有6.5b节"验证专用异常注入"端口组里新增AMI层的`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`一对，透传进PWI新增的同名端口（`ppg_precision_window_integration.v`V1.4，继续透传进`ppg_coarse_detection_fir.v`V2.3）。没有新增AMI参数或enable端口——复用既有的`C_ENABLE_TEST_INJECTION`参数，并把AMI自己已经算好的`flag_test_inject_effective`原样传给子模块的`i_test_inject_enable`，和本文件已经用在IDAC控制器自己那组饱和注入上的组合方式（约2340行）完全一致。真实回归确认逐位不变：主烟雾TB跑通完整`ppg_control_top`层次（`SMOKE_TB_PASS`，计数与改动前逐字节一致）+`C_ENABLE_TEST_INJECTION=1`真实生效状态下的注入TB（`INJ_TB_PASS`，既有INJ-00~04全部不受影响）
// 2026-09-05		V1.14	 Erie		按合同8.4.5节新增P2S遥测边界透传端口组：新增AMI边界输出`o_s1_calibration_applied`（既有wire`flag_dc_s1_calibration_applied`即`ppg_adc_dc_recovery_Inst`自己`o_calibration_applied`输出的纯转发）、`o_s1_raw`/`o_s2_raw`（把同一例化第2284/2286行原来留空的`o_stage1_raw`/`o_stage2_raw`接进新增内部wire`dec_dc_stage1_raw`/`dec_dc_stage2_raw`后转发）。刻意使用`ppg_adc_dc_recovery`模块自己重新导出、已经跟frame_id/sample_index/coarse/fine结果锁在同一个原子事务`payload_o`寄存器里的版本，不使用重构器更早的`dec_reconstructor_stage1_raw`/`dec_reconstructor_stage2_raw`（第722/724行声明、第2180/2182行接入）——那两个不是同一个原子事务的锁存值，时序上跟frame_id/sample_index对不上号，用错会导致P2S包数据错位。依据`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`V1.6第8.4.5节。不改动任何既有端口逻辑；真实回归确认逐位不变：主烟雾TB跑通完整`ppg_control_top`层次（`SMOKE_TB_PASS`，real_adc_responses=47 measurement_result_valid=32，与改动前逐位一致）
// 2026-09-18		V1.15	 Erie		修复调查工作线D待查项SID-05时发现、真实iverilog A/B trace确认的一个永久校准搜索死锁：flag_calibration_request_inflight此前只在flag_amb_sample_accepted/flag_dcs_sample_accepted（真实消费到搜索结果）或STOP/abort时清零。当调度器自己的flag_cal_owner_deadline（`ppg_400hz_frame_calibration_scheduler.v`，tick-248 owner提交截止，C25合同9.4.1节）因物理ADC owner未及时提交而抑制某个候选窗口时，这笔请求从未真正建立过ADC owner或事务，两个"结果已消费"条件都不可能触发——flag_calibration_request_inflight从此永远保持1，calibration_sample_valid_o再也不会重新拉高，调度器自己的B_CAL_CONTEXT_SEEN也因为之后任何一次子帧边界都等不到新的pending请求而永久锁闭，整个校准搜索（AMB或DCS_CAL）从此搁浅、无法自行恢复。trace证据：对一笔真实进行中的DC_R候选，在其截止跨越期间强制i_adc_physical_idle=0，能正确抑制这一个候选（符合设计意图），但之后全部12/12次重试永久失败、再也等不到任何Q3窗口。修复：新增`i_cal_owner_deadline_event`输入，接到调度器V1.8新增的`o_cal_owner_deadline_event`输出（本身是对已有、本来就自清零的flag_cal_owner_deadline脉冲的直接转发），并把它加为flag_calibration_request_inflight的额外清零条件，与既有的"结果已消费"两项并列——让AMI能为同一个仍在等待的候选立即重新拉高calibration_sample_valid_o发起重试，而不是永久卡死。未改动其它逻辑；reg_inflight_frame_type/reg_inflight_color_ir不受影响，它们仍然只在下一次calibration_request_fire_o时更新，和改动前一致
module ppg_adc_measurement_idac_integration
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // 真实400 Hz物理帧编号字段宽度
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // ADC事务全局序号字段宽度
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // ACTIVE配置提交版本字段宽度
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1与Stage2系数版本字段宽度
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数版本字段宽度
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // 三路逻辑IDAC码字段宽度
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC安全提交版本字段宽度
	parameter integer C_DATA_WIDTH = 32'd24,    // 统一signed PPG结果字段宽度
	parameter integer C_SLOPE_WIDTH = 32'd32,   // 动态基线signed Q16斜率字段宽度
	parameter integer C_BASELINE_WIDTH = 32'd48, // 动态基线signed Q16内部字段宽度
	parameter integer C_RATIO_WIDTH = 32'd16,   // 自适应比例unsigned Q1.15字段宽度
	parameter integer C_CONFIRM_COUNT_WIDTH = 32'd4, // 检测连续确认计数字段宽度
	parameter integer C_INTERVAL_WIDTH = 32'd16, // 检测时间间隔字段宽度
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8, // manager唯一产生、经ACTIVE wrapper与Top扇出的RUN代际字段宽度；父级声明并原样透传给PWI(2457行)/IDAC(2313行) @satisfies: K03
	parameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用异常注入结构生成使能
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz数字处理域工作时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_active_config_valid,                // 当前ACTIVE配置整体合法资格
	input i_run_enable,                         // 当前生命周期处于RUN状态
	input i_allow_new_transaction,              // 配置管理器允许启动新ADC事务
	input i_start_ack_event,                    // 新RUN正式开始的单周期事件
	input i_stop_ack_event,                     // STOP进入排空的单周期事件
	input i_control_abort_event,                // 阻断异常撤销在途控制的单周期事件
	input i_diag_clear_event,                   // 软件清除sticky诊断的单周期事件
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // manager经ACTIVE wrapper与Top扇出的当前RUN代际，陈旧代际不得绑定新owner
	input i_system_fault_discard_event,         // supervisor产生的注册式故障episode丢弃选择器，外部abort不得驱动此端口

	//---------------事务版本接口---------------//
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 当前完整ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_stage1_coef_epoch, // 当前Stage1系数组版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_stage2_coef_epoch, // 接收 i_stage2_coef_epoch
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // 当前DC恢复系数组版本

	//-------------ADC事务启动接口--------------//

	//TRANSACTION_START接口
	input i_transaction_start_valid,            // 上层保持当前待启动事务有效
	output o_transaction_start_ready,           // Wrapper允许启动当前事务
	output o_transaction_start_fire,            // capture、S1和SAR共享的唯一启动单拍

	//ADC可靠完成旁带
	output o_adc_transaction_complete_event,    // CLK_DOUT同步、RAW锁存和S1归属后的唯一完成脉冲
	output o_adc_transaction_success,           // 与完成脉冲绑定的ADC结果有效资格
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_adc_complete_sample_index, // 与完成脉冲绑定的启动事务序号
	input i_transaction_precision_mode,         // 当前事务采用的9-bit或15-bit精度
	input [C_FRAME_ID_WIDTH - 1:0]i_transaction_frame_id, // 当前事务真实物理帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_transaction_sample_index, // 当前事务全局序号
	input i_transaction_color_ir,               // 低为红光且高为红外
	input [1:0]i_transaction_frame_type,        // AMB_CAL、DCS_CAL或NORMAL编码
	input [C_IDAC_CODE_WIDTH - 1:0]i_transaction_amb_code_snapshot, // 实际积分AMB码快照
	input [C_IDAC_CODE_WIDTH - 1:0]i_transaction_dc_code_snapshot, // 实际积分颜色DC码快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_transaction_amb_code_epoch, // AMB码提交版本快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_transaction_dc_code_epoch, // 当前颜色DC码版本快照

	//-------------异步ADC物理接口--------------//
	input [9:0]i_dout_stage1_low,               // Stage1物理判决码
	input i_clk_stage1_dout_low_async,          // Stage1异步完成保持电平
	input [9:0]i_dout_stage2_low,               // 接收 i_dout_stage2_low
	input i_clk_stage2_dout_low_async,          // 接收 i_clk_stage2_dout_low_async
	input i_adc_idle,                           // 模拟ADC当前已经排空
	input i_analog_safe,                        // 模拟相位允许安全提交
	input i_macro_frame_safe_boundary,          // 精度切换与重检使用的宏帧边界
	input i_idac_code_safe_boundary,            // IDAC pending码唯一提交边界
	input [C_FRAME_ID_WIDTH - 1:0]i_safe_frame_id, // 即将启动帧的真实编号
	input i_normal_frame_complete_event,        // 一帧完整NORMAL测量完成单拍
	input i_calibration_frame_complete_event,   // 当前校准帧物理完成单拍

	//---------------校准请求接口---------------//
	input i_calibration_sample_ready,           // 帧调度器接受当前SAR9校准请求
	input i_cal_owner_deadline_event,           // 帧调度器校准owner截止单周期事件，在途请求被抑制后据此立即重新发起同一候选
	output o_calibration_sample_valid,          // 启动搜索或周期重检保持型请求
	output [1:0]o_calibration_frame_type,       // 当前请求的AMB_CAL或DCS_CAL编码
	output o_calibration_color_ir,              // 当前DCS_CAL请求颜色
	output o_calibration_precision_mode,        // 校准固定采用SAR9精度
	output [1:0]o_calibration_request_reason,   // 启动搜索或周期重检原因
	output o_calibration_request_fire,          // 校准请求真实握手单拍

	//---------------正式测量接口---------------//
	input i_measurement_result_ready,           // 片外FIFO接受正式结果
	output o_measurement_result_valid,          // 正式结果保持有效至消费
	output signed [C_DATA_WIDTH - 1:0]o_coarse_ppg_value, // DC恢复后的粗PPG值
	output o_coarse_valid,                      // 粗结果有效资格
	output o_coarse_recovery_calibrated,        // 粗结果正式恢复资格
	output o_coarse_saturation_low,             // 粗结果负向饱和诊断
	output o_coarse_saturation_high,            // 粗结果正向饱和诊断
	output signed [C_DATA_WIDTH - 1:0]o_fine_ppg_value, // DC恢复后的精细PPG值
	output o_fine_valid,                        // 精细结果有效资格
	output o_fine_recovery_calibrated,          // 精细结果正式恢复资格
	output o_fine_saturation_low,               // 精细结果负向饱和诊断
	output o_fine_saturation_high,              // 精细结果正向饱和诊断
	output signed [11:0]o_calibrated_s1_value,  // 正式Stage1校准残差
	output signed [14:0]o_programmable_15_code, // 正式可编程15-bit残差
	output o_programmable_15_valid,             // 可编程精细结果资格
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 本笔结果ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 导出 o_coef_epoch
	output [C_COEF_EPOCH_WIDTH - 1:0]o_stage2_result_coef_epoch, // 导出 o_stage2_result_coef_epoch
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_dc_result_coef_epoch, // 本笔结果DC恢复版本
	output o_result_precision_mode,             // 本笔结果精度快照
	output [C_FRAME_ID_WIDTH - 1:0]o_result_frame_id, // 本笔结果物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_result_sample_index, // 本笔结果全局序号
	output o_result_color_ir,                   // 本笔结果颜色身份
	output [1:0]o_result_frame_type,            // 本笔结果NORMAL编码
	output [C_IDAC_CODE_WIDTH - 1:0]o_result_amb_code_snapshot, // 本笔结果AMB码快照
	output [C_IDAC_CODE_WIDTH - 1:0]o_result_dc_code_snapshot, // 本笔结果颜色DC码快照
	output [C_CODE_EPOCH_WIDTH - 1:0]o_result_amb_code_epoch, // 导出 o_result_amb_code_epoch
	output [C_CODE_EPOCH_WIDTH - 1:0]o_result_dc_code_epoch, // 本笔结果颜色DC版本
	output o_measurement_result_discard_event,  // 正式结果生命周期丢弃单拍观测，合同6.10节公开端口
	output [1:0]o_measurement_result_discard_reason, // STOP、abort或系统故障三态丢弃原因，随事件保持稳定
	output o_measurement_result_discard_identity_valid, // 事件为高时恒为1，绑定TXN_ID可信
	output o_measurement_result_discard_sample_valid, // 被丢弃正式结果的独立样本资格快照
	output [C_FRAME_ID_WIDTH - 1:0]o_measurement_result_discard_frame_id, // 被丢弃事务的真实物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_measurement_result_discard_sample_index, // 被丢弃事务的全局顺序编号
	output o_measurement_result_discard_color_ir, // 被丢弃事务的颜色身份
	output [1:0]o_measurement_result_discard_frame_type, // 被丢弃事务的帧类型编码
	output o_measurement_result_discard_precision, // 被丢弃事务建立时所属的精度模式
	output [C_RUN_GENERATION_WIDTH - 1:0]o_measurement_result_discard_run_generation, // 被丢弃事务所属的RUN代际

	//---------------IDAC配置接口---------------//
	input [1:0]i_idac_mode,                     // MANUAL、搜索保持或搜索跟踪模式
	input i_amb_enable,                         // 允许AMB逻辑码参与当前RUN
	input i_dcs_enable,                         // 允许R和IR两路DCS参与当前RUN
	input i_amb_polarity,                       // AMB残差到码值方向映射
	input i_dcs_polarity,                       // 接收 i_dcs_polarity
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_manual_code, // AMB手动目标码
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_min, // AMB自动控制下界
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_max, // AMB自动控制上界
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_manual_code, // 红光DC手动目标码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_min, // 红光DC控制下界
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_max, // 红光DC控制上界
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_manual_code, // 红外DC手动目标码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_min, // 红外DC控制下界
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_max, // 红外DC控制上界
	input signed [11:0]i_amb_threshold_low,     // AMB残差窗口下界
	input signed [11:0]i_amb_threshold_high,    // AMB残差窗口上界
	input signed [11:0]i_dcs_threshold_low,     // 两色DCS残差窗口下界
	input signed [11:0]i_dcs_threshold_high,    // 两色DCS残差窗口上界
	input [7:0]i_amb_confirm_count,             // AMB连续越界确认次数
	input [7:0]i_dcs_confirm_count,             // 接收 i_dcs_confirm_count

	//------------重构与恢复配置接口------------//
	input i_stage1_calibration_valid,           // Stage1拟合系数正式有效

	//STAGE1_WEIGHT_Q16接口
	input signed [25:0]i_stage1_weight_q16_0,   // Stage1物理位0的Q16权重
	input signed [25:0]i_stage1_weight_q16_1,   // 接收 i_stage1_weight_q16_1
	input signed [25:0]i_stage1_weight_q16_2,   // 接收 i_stage1_weight_q16_2
	input signed [25:0]i_stage1_weight_q16_3,   // 接收 i_stage1_weight_q16_3
	input signed [25:0]i_stage1_weight_q16_4,   // 接收 i_stage1_weight_q16_4
	input signed [25:0]i_stage1_weight_q16_5,   // 接收 i_stage1_weight_q16_5
	input signed [25:0]i_stage1_weight_q16_6,   // 接收 i_stage1_weight_q16_6
	input signed [25:0]i_stage1_weight_q16_7,   // 接收 i_stage1_weight_q16_7
	input signed [25:0]i_stage1_weight_q16_8,   // 接收 i_stage1_weight_q16_8
	input signed [25:0]i_stage1_weight_q16_9,   // 接收 i_stage1_weight_q16_9
	input signed [31:0]i_stage1_offset_q16,     // Stage1 signed Q16偏置
	input i_stage2_calibration_valid,           // 接收 i_stage2_calibration_valid
	input signed [19:0]i_stage2_gain_q16,       // Stage2 signed Q16增益
	input signed [31:0]i_stage2_offset_q16,     // Stage2 signed Q16加法偏置
	input i_dc9_recovery_valid,                 // SAR9 DC恢复系数正式有效
	input i_dc15_recovery_valid,                // 接收 i_dc15_recovery_valid
	input signed [31:0]i_dc9_recovery_gain_q16, // SAR9 DC恢复Q16系数
	input signed [31:0]i_dc15_recovery_gain_q16, // 接收 i_dc15_recovery_gain_q16

	//-------------精度检测配置接口-------------//
	input i_run_profile,                        // 低为NORMAL且高为CHARACTERIZATION
	input i_initial_precision,                  // 表征模式初始精度
	input i_slope_mode,                         // 固定或自适应基线斜率选择
	input signed [C_SLOPE_WIDTH - 1:0]i_fixed_slope_q16, // 固定signed Q16负斜率
	input [C_RATIO_WIDTH - 1:0]i_alpha_q15,     // 基础斜率幅度比例
	input [C_RATIO_WIDTH - 1:0]i_beta_q15,      // 活动斜率平滑比例
	input [C_RATIO_WIDTH - 1:0]i_timing_adjust_ratio_q15, // 相交时刻修正比例
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_min_q16, // 最负斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_max_q16, // 最接近零斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_baseline_delta_q16, // 波峰锚点基线偏置
	input [C_SLOPE_WIDTH - 1:0]i_cross_hysteresis_q16, // 向上相交迟滞量
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_min_frames, // 相交提前量合格下界
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_max_frames, // 相交提前量合格上界
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_cross_confirm_count, // 相交连续确认点数
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_no_cross_limit, // 连续无相交重新获取阈值
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_peak_confirm_count, // 波峰连续下降确认点数
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_valley_confirm_count, // 波谷连续上升确认点数
	input [C_DATA_WIDTH - 1:0]i_direction_deadband, // 相邻FIR方向分类死区
	input [C_DATA_WIDTH - 1:0]i_min_peak_valley_amplitude, // 合格峰谷最小幅度
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_valley_frames, // 波峰到波谷最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_peak_frames, // 相邻波峰最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_max_fine_window_frames, // 15-bit窗口最大持续帧数
	input [C_INTERVAL_WIDTH - 1:0]i_max_reacquire_frames, // 9-bit重新获取最大帧数
	input i_peak_valley_config_valid,           // 峰谷检测配置正式有效
	input [15:0]i_amb_recheck_interval_frames,  // 周期AMB重检间隔

	//---------------IDAC状态输出---------------//
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code, // 当前AMB committed码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_r_code, // 当前红光DC committed码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_ir_code, // 当前红外DC committed码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // AMB安全提交版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_r_code_epoch, // 红光DC安全提交版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_ir_code_epoch, // 红外DC安全提交版本
	output o_amb_code_update,                   // AMB码实际变化事件
	output o_dcs_r_code_update,                 // 红光DC码实际变化事件
	output o_dcs_ir_code_update,                // 红外DC码实际变化事件
	output o_dcs_r_track_adjust,                // 红光NORMAL慢速调码事件
	output o_dcs_ir_track_adjust,               // 红外NORMAL慢速调码事件
	output o_amb_search_done,                   // AMB启动搜索完成状态
	output o_dcs_r_search_done,                 // 红光DC启动搜索完成状态
	output o_dcs_ir_search_done,                // 红外DC启动搜索完成状态
	output o_amb_search_exhausted,              // AMB搜索耗尽状态
	output o_dcs_r_search_exhausted,            // 红光DC搜索耗尽状态
	output o_dcs_ir_search_exhausted,           // 红外DC搜索耗尽状态
	output o_amb_pending_valid,                 // AMB候选等待提交状态
	output o_dcs_r_pending_valid,               // 红光DC候选等待提交状态
	output o_dcs_ir_pending_valid,              // 红外DC候选等待提交状态
	output o_amb_code_at_min,                   // AMB committed码位于配置下界
	output o_amb_code_at_max,                   // AMB committed码位于配置上界
	output o_dcs_r_code_at_min,                 // 红光DC committed码位于配置下界
	output o_dcs_r_code_at_max,                 // 红光DC committed码位于配置上界
	output o_dcs_ir_code_at_min,                // 红外DC committed码位于配置下界
	output o_dcs_ir_code_at_max,                // 红外DC committed码位于配置上界
	output o_amb_fault,                         // AMB阻断故障
	output o_dcs_r_fault,                       // 红光DC阻断故障
	output o_dcs_ir_fault,                      // 红外DC阻断故障
	output o_idac_fault_blocking,               // IDAC阻断故障汇总
	output o_idac_protocol_error_sticky,        // IDAC协议异常历史诊断
	output o_startup_search_complete,           // 启动装码或搜索整体完成
	output o_idac_idle,                         // IDAC控制器真实空闲状态

	//-------------精度窗口状态输出-------------//
	output o_active_precision_mode,             // 系统唯一committed采集精度
	output o_fine_window_active,                // 正式15-bit窗口状态
	output o_fine_window_start_event,           // 真实进入15-bit窗口事件
	output [C_FRAME_ID_WIDTH - 1:0]o_fine_window_start_frame_id, // 首笔15-bit帧号
	output o_precision_15_to_9_event,           // 真实返回9-bit事件
	output [C_FRAME_ID_WIDTH - 1:0]o_precision_15_to_9_frame_id, // 首笔恢复9-bit帧号
	output o_reacquire_request_event,           // 异常返回重新获取请求
	output o_switch_hold_new_transaction,       // 精度切换要求暂停新事务
	output o_mode_fault_event,                  // 精度控制阻断故障事件
	output [15:0]o_normal_frame_count,          // 周期重检NORMAL帧累计值

	//AMB_RECHECK接口
	output o_amb_recheck_pending,               // 重检间隔到期等待切换状态
	output o_amb_recheck_accept,                // 重检安全接管事件
	output o_amb_recheck_busy,                  // 三阶段重检与恢复占用状态
	output o_normal_output_inhibit,             // 重检期间正式结果禁止状态
	output o_recheck_sequence_done,             // 固定三阶段重检成功事件
	output o_recheck_sequence_failed,           // 任一重检阶段失败事件
	output o_fir_history_full_r,                // 红光FIR历史预热完成
	output o_fir_history_full_ir,               // 红外FIR历史预热完成
	output o_fir_idle,                          // FIR内部真实空闲状态
	output o_detection_fork_idle,               // 检测双分支fork空闲状态
	output o_detector_idle,                     // 峰谷检测器安全空闲状态
	output o_controller_idle,                   // 精度控制器空闲状态
	output o_scheduler_idle,                    // AMB重检调度器空闲状态
	output o_cross_pending,                     // 动态基线相交请求保持状态
	output o_peak_pending,                      // 波峰事件保持状态
	output o_valley_pending,                    // 波谷事件保持状态
	output o_return_pending,                    // 返回9-bit请求保持状态
	output o_baseline_valid,                    // 动态基线当前有效资格
	output o_reacquire_active,                  // 9-bit重新获取活动状态
	output o_detector_fine_window_active,       // 峰谷检测器观察的fine状态
	output o_switch_pending,                    // 精度切换等待提交状态
	output o_switch_target_precision,           // 当前待提交目标精度
	output signed [C_SLOPE_WIDTH - 1:0]o_slope_current_q16, // 当前活动基线斜率
	output o_baseline_protocol_error_sticky,    // 动态基线协议异常历史
	output o_fine_window_timeout_sticky,        // 精细窗口超时历史
	output o_reacquire_timeout_sticky,          // 重新获取超时历史
	output o_peak_valley_protocol_error_sticky, // 峰谷检测协议异常历史
	output o_switch_timeout_sticky,             // 精度安全提交超时历史
	output o_precision_protocol_error_sticky,   // 精度控制协议异常历史

	//-------------Wrapper状态输出--------------//
	output o_integration_protocol_error_sticky, // 集成协议异常历史诊断
	output o_wrapper_fault_blocking,            // Wrapper当前阻断故障汇总
	output o_normal_measurement_eligible,       // 正式NORMAL测量资格
	output o_adc_chain_idle,                    // ADC捕获及Stage1流水空闲
	output o_normal_fork_idle,                  // NORMAL双分支fork空闲
	output o_measurement_output_idle,           // 恢复与正式输出路径空闲
	output o_datapath_empty,                    // Wrapper全部数据与控制事务排空

	//-------------AMI故障分发器输出-------------//
	output o_ami_fault_valid,                    // 五路阻断故障分发器本拍产生一条注册记录
	output o_ami_fault_active,                   // 五路lane-active按位或，仍有未解决阻断故障时为高
	output [7:0]o_ami_fault_cause,               // 本条记录锁定的故障来源编码，取值8'h01至8'h05
	output o_ami_fault_identity_valid,           // 本条记录是否绑定真实事务身份
	output [C_FRAME_ID_WIDTH - 1:0]o_ami_fault_frame_id, // 本条记录绑定事务的真实物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_ami_fault_sample_index, // 本条记录绑定事务的全局顺序编号
	output o_ami_fault_color_ir,                 // 本条记录绑定事务的颜色身份
	output [1:0]o_ami_fault_frame_type,          // 本条记录绑定事务的帧类型编码
	output o_ami_fault_precision,                // 本条记录绑定事务建立时所属的精度模式
	output [C_RUN_GENERATION_WIDTH - 1:0]o_ami_fault_run_generation, // 本条记录绑定事务所属的RUN代际

	//-------------检测代际清空公开观测-------------//
	output o_detection_discard_event,               // 检测代际清空广播的公开单拍观测，合同6.10节公开端口，与PWI私有输入同拍
	output [1:0]o_detection_discard_reason,         // STOP、abort或系统故障三态原因编码，与私有广播共用同一来源
	output o_detection_discard_identity_valid,      // 触发广播时是否命中真实保留检测分支事务
	output o_detection_discard_sample_valid,        // 触发事务的独立样本资格快照
	output [C_FRAME_ID_WIDTH - 1:0]o_detection_discard_frame_id, // 触发事务的真实物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_detection_discard_sample_index, // 触发事务的全局顺序编号
	output o_detection_discard_color_ir,            // 触发事务的颜色身份
	output [1:0]o_detection_discard_frame_type,     // 触发事务的帧类型编码
	output o_detection_discard_precision,           // 触发事务建立时所属的精度模式
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_detection_discard_config_epoch, // 触发事务ACTIVE配置版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_detection_discard_coef_epoch, // 触发事务Stage1系数版本
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_detection_discard_dc_recovery_epoch, // 触发事务DC恢复版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_detection_discard_amb_code_epoch, // 触发事务环境光抵消码提交版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_detection_discard_dc_code_epoch, // 触发事务颜色DC码提交版本
	output [C_RUN_GENERATION_WIDTH - 1:0]o_detection_discard_run_generation, // 触发广播目标的RUN代际

	//-------------验证专用异常注入-------------//
	input i_test_inject_enable,                 // 只在显式验证构建中允许异常注入
	input i_test_identity_inject_valid,         // 保持型一次错误完成身份请求
	output o_test_identity_inject_ready,        // AMI可原子绑定错误身份请求到当前owner
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_test_identity_inject_sample_index, // 一次错误完成样本序号
	input i_test_invalid_sample_valid,          // 保持型一次invalid-sample资格请求
	output o_test_invalid_sample_ready,         // AMI可原子绑定invalid请求到当前NORMAL结果
	input i_test_saturation_inject_valid,       // 保持型一次饱和注入请求，透传给内部IDAC控制器
	output o_test_saturation_inject_ready,      // IDAC控制器当前可原子绑定饱和注入请求
	input i_test_calibration_loss_inject_valid, // 保持型一次calibration-loss注入请求，透传给内部粗检测FIR
	output o_test_calibration_loss_inject_ready, // 粗检测FIR当前可原子绑定calibration-loss注入请求
	output o_result_sample_valid,               // 独立样本资格，invalid事务仍保留数值与身份

	//-------------P2S遥测边界透传-------------//
	output o_s1_calibration_applied,           // Stage1校准资格，与frame_id/sample_index/coarse/fine结果同一原子载荷锁存
	output [9:0]o_s1_raw,                      // Stage1物理判决位，取自DC恢复自己重新导出的atomic payload_o，非重构器早期dec_reconstructor_stage1_raw
	output [9:0]o_s2_raw                       // 第二级冗余物理判决位，取自DC恢复自己重新导出的atomic payload_o，非重构器早期dec_reconstructor_stage2_raw
);

	//---------------配置参数区域---------------//
	//===================<参数定义>===================//
	localparam [1:0]FRAME_TYPE_AMB = 2'b00;     // 环境光校准事务编码
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;     // 颜色直流校准事务编码
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;  // 正式PPG测量事务编码
	localparam [1:0]IDAC_MODE_MANUAL = 2'b00;   // 手动IDAC码模式
	localparam [1:0]IDAC_MODE_SEARCH_HOLD = 2'b01; // 启动搜索保持模式
	localparam [1:0]IDAC_MODE_SEARCH_TRACK = 2'b10; // NORMAL慢速跟踪模式
	localparam RUN_PROFILE_NORMAL = 1'b0;       // NORMAL_PPG运行档案
	localparam [1:0]REASON_STARTUP = 2'b00;     // 启动搜索请求来源编码
	localparam [1:0]REASON_RECHECK = 2'b01;     // 周期重检请求来源编码
	localparam [1:0]DISCARD_REASON_STOP = 2'b00; // 私有discard组STOP排空原因编码
	localparam [1:0]DISCARD_REASON_ABORT = 2'b01; // 私有discard组abort撤销原因编码
	localparam [1:0]DISCARD_REASON_SYSTEM_FAULT = 2'b10; // 私有discard组系统故障原因编码
	localparam integer FORK_PAYLOAD_WIDTH = (2 * C_DATA_WIDTH) + 43 + C_DC_RECOVERY_EPOCH_WIDTH + C_CONFIG_EPOCH_WIDTH + (2 * C_COEF_EPOCH_WIDTH) + C_FRAME_ID_WIDTH + C_SAMPLE_INDEX_WIDTH + (2 * C_IDAC_CODE_WIDTH) + (2 * C_CODE_EPOCH_WIDTH); // DC恢复完整事务保持槽字段总宽度

	//----------------寄存器信号----------------//
	reg [1:0]reg_inflight_frame_type = 2'b00;   // 在途校准结果期望类型
	reg reg_inflight_color_ir = 1'b0;           // 在途校准结果期望颜色
	reg [1:0]reg_inflight_reason = 2'b00;       // 在途校准结果来源
	reg [1:0]reg_held_start_frame_type = 2'b00; // 受反压启动载荷类型快照
	reg reg_held_start_precision = 1'b0;        // 受反压启动载荷精度快照
	reg [C_FRAME_ID_WIDTH - 1:0]reg_held_start_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 受反压启动帧号快照
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_held_start_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 受反压启动序号快照
	reg reg_held_start_color_ir = 1'b0;         // 受反压启动颜色快照
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_held_start_amb_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 受反压启动AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_held_start_dc_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 承载 reg_held_start_dc_code
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_held_start_amb_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 受反压启动AMB版本快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_held_start_dc_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 承载 reg_held_start_dc_epoch
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_adc_inflight_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 物理ADC在途事务的启动序号快照
	reg reg_adc_inflight_precision_mode = 1'b0; // 物理ADC owner锁存的SAR9或SAR15精度
	reg [C_FRAME_ID_WIDTH - 1:0]reg_adc_inflight_frame_id = {C_FRAME_ID_WIDTH{1'b0}}; // 物理ADC owner锁存的真实帧号
	reg reg_adc_inflight_color_ir = 1'b0;       // 物理ADC owner锁存的颜色身份
	reg [1:0]reg_adc_inflight_frame_type = 2'b00; // 物理ADC owner锁存的AMB、DCS或NORMAL类型
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_adc_inflight_amb_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 物理ADC owner锁存的AMB积分码
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_adc_inflight_dc_code = {C_IDAC_CODE_WIDTH{1'b0}}; // 物理ADC owner锁存的颜色DC积分码
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_adc_inflight_amb_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 物理ADC owner锁存的AMB码版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_adc_inflight_dc_epoch = {C_CODE_EPOCH_WIDTH{1'b0}}; // 物理ADC owner锁存的颜色DC码版本
	reg [FORK_PAYLOAD_WIDTH - 1:0]reg_result_fork_payload = {FORK_PAYLOAD_WIDTH{1'b0}}; // DC恢复双消费者载荷槽

	//-----------------标志信号-----------------//
	reg flag_system_fault_discard_pending = 1'b0; // supervisor故障episode丢弃选择器锁存，保持到本代际全部终端槽排空
	reg flag_ami_fault_pending_01 = 1'b0;       // cause 8'h01待分发标记，受保护测试身份注入被接纳时置位
	reg flag_ami_fault_pending_02 = 1'b0;       // cause 8'h02待分发标记，请求/响应对应关系被破坏的协议错误到达时置位
	reg flag_ami_fault_pending_03 = 1'b0;       // cause 8'h03待分发标记，completion身份无法证明可用原owner恢复时置位
	reg flag_ami_fault_pending_04 = 1'b0;       // cause 8'h04待分发标记，精度控制新episode到达时置位
	reg flag_ami_fault_pending_05 = 1'b0;       // cause 8'h05待分发标记，IDAC控制器新episode到达时置位
	reg flag_detection_discard_episode_active = 1'b0; // 检测代际清空episode锁存，抑制同一代际的重复广播
	reg flag_adc_transaction_inflight = 1'b0;   // 唯一ADC事务在途所有权
	reg flag_adc_transaction_abort = 1'b0;      // 当前ADC事务曾命中abort的不可成功资格
	reg flag_abort_draining = 1'b0;             // abort后等待旧数据真实丢弃排空
	reg flag_stop_result_draining = 1'b0;       // STOP取消无物理主事务后抑制迟到结果
	reg flag_calibration_request_inflight = 1'b0; // 调度器接受但结果尚未消费
	reg flag_held_start_valid = 1'b0;           // 标记当前valid曾经受到反压
	reg flag_integration_blocking = 1'b0;       // 严重错配阻断当前RUN
	reg flag_test_identity_hold = 1'b0;         // 测试错配后保留真实DONE和owner，等待受控恢复
	reg flag_owner_protocol_fault_hold = 1'b0;  // cause 8'h02请求/响应对应关系破坏，保持到本RUN结束
	reg flag_recovery_context_fault_hold = 1'b0; // cause 8'h03无法证明可用原owner恢复，保持到本RUN结束
	reg flag_detection_pending = 1'b0;          // 片内检测分支所有权
	reg flag_measurement_pending = 1'b0;        // 正式测量分支所有权
	reg flag_adc_completion_pending = 1'b0;     // S1已接纳RAW后等待元数据归属核对
	wire flag_capture_precision_mode;           // 捕获事务精度快照
	wire flag_capture_valid;                    // 捕获结果保持型valid
	wire flag_capture_ready;                    // S1固定重构接收许可
	wire flag_adc_capture_transfer;             // capture与S1的真实RAW交接事件
	wire flag_adc_capture_without_owner;        // 无AMI在途所有权时出现的非法RAW交接
	wire flag_adc_completion_emit;              // S1输出元数据可用于发布ADC完成旁带
	wire flag_adc_completion_normal_emit;       // 正常匹配路径发布真实完成旁带
	wire flag_adc_completion_abort_release;     // 测试错配后由受控abort发布原身份失败完成
	wire flag_adc_completion_owner_match;       // capture与S1完整身份同ADC owner逐位一致
	wire flag_adc_completion_success;           // 非abort且元数据一致的可继续处理资格
	wire flag_test_inject_effective;            // 参数和运行使能共同允许验证注入
	wire flag_test_identity_inject_fire;        // 错误identity请求唯一接纳事件
	wire idac_test_saturation_inject_ready_o;   // 内部转发：IDAC控制器当前可原子绑定饱和注入请求
	wire flag_test_invalid_sample_fire;         // invalid-sample请求唯一接纳事件
	wire flag_s1_transaction_ready;             // S1允许锁存下一事务上下文
	wire flag_s1_detect_valid;                  // 固定Stage1重构结果valid
	wire flag_s1_detect_ready;                  // 可编程Stage1校准接收许可
	wire flag_s1_precision_mode;                // 固定重构事务精度
	wire flag_s1_color_ir;                      // 固定重构事务颜色
	wire flag_calibrated_valid;                 // Stage1校准完整事务valid
	wire flag_calibrated_ready;                 // router接收Stage1校准事务许可
	wire flag_router_calibration_applied;       // router共享Stage1校准资格
	wire flag_router_saturation_low;            // router共享Stage1负饱和
	wire flag_router_saturation_high;           // router共享Stage1正饱和
	wire flag_router_precision_mode;            // router共享事务精度
	wire flag_router_color_ir;                  // router共享事务颜色
	wire flag_router_amb_valid;                 // AMB_CAL唯一分支valid
	wire flag_router_dcs_valid;                 // 承载 flag_router_dcs_valid
	wire flag_router_normal_valid;              // 承载 flag_router_normal_valid
	wire flag_router_frame_type_error;          // 非法类型错误电平
	wire flag_normal_fork_ready;                // NORMAL fork输入接收许可
	wire flag_measurement_branch_valid;         // NORMAL测量分支保持型valid
	wire flag_measurement_branch_ready;         // overlap接收测量分支许可
	wire flag_track_branch_valid;               // IDAC跟踪分支保持型valid
	wire flag_track_branch_ready;               // IDAC接收跟踪分支许可
	wire flag_measurement_calibration_applied;  // 测量分支Stage1资格
	wire flag_measurement_saturation_low;       // 测量分支Stage1负饱和
	wire flag_measurement_saturation_high;      // 测量分支Stage1正饱和
	wire flag_measurement_precision_mode;       // 测量分支精度快照
	wire flag_measurement_color_ir;             // 测量分支颜色
	wire flag_track_calibration_applied;        // IDAC跟踪分支校准资格
	wire flag_track_saturation_low;             // 跟踪分支负饱和
	wire flag_track_saturation_high;            // 跟踪分支正饱和
	wire flag_track_precision_mode;             // 跟踪分支精度
	wire flag_track_color_ir;                   // 跟踪分支颜色
	wire flag_overlap_result_valid;             // overlap完整事务输出valid
	wire flag_overlap_result_ready;             // 可编程重构接收许可
	wire flag_overlap_calibration_applied;      // overlap透传Stage1资格
	wire flag_overlap_saturation_low;           // overlap透传Stage1负饱和
	wire flag_overlap_saturation_high;          // overlap透传Stage1正饱和
	wire flag_overlap_nominal_15_valid;         // overlap标称码资格
	wire flag_overlap_nominal_saturated;        // overlap标称码饱和诊断
	wire flag_overlap_precision_mode;           // overlap事务精度
	wire flag_overlap_color_ir;                 // overlap事务颜色
	wire flag_reconstructor_result_valid;       // 可编程重构完整事务valid
	wire flag_reconstructor_result_ready;       // DC恢复接收许可
	wire flag_reconstructor_15_valid;           // 正式15-bit残差资格
	wire flag_reconstructor_15_calibrated;      // 两级重构正式校准资格
	wire flag_reconstructor_saturation_low;     // 可编程结果负饱和
	wire flag_reconstructor_saturation_high;    // 可编程结果正饱和
	wire flag_reconstructor_calibration_applied; // 重构器透传Stage1资格
	wire flag_reconstructor_s1_saturation_low;  // 重构器透传Stage1负饱和
	wire flag_reconstructor_s1_saturation_high; // 重构器透传Stage1正饱和
	wire flag_reconstructor_precision_mode;     // 重构器事务精度
	wire flag_reconstructor_color_ir;           // 重构器颜色
	wire flag_reconstructor_nominal_15_valid;   // 重构器透传固定标称15-bit结果资格
	wire flag_reconstructor_nominal_saturated;  // 重构器透传固定标称结果饱和诊断
	wire flag_dc_result_valid;                  // DC恢复完整结果valid
	wire flag_dc_result_ready;                  // Wrapper结果fork接收许可
	wire flag_dc_coarse_valid;                  // DC恢复粗结果资格
	wire flag_dc_coarse_calibrated;             // DC恢复粗结果正式资格
	wire flag_dc_coarse_saturation_low;         // DC恢复粗结果负饱和
	wire flag_dc_coarse_saturation_high;        // DC恢复粗结果正饱和
	wire flag_dc_fine_valid;                    // DC恢复精细结果资格
	wire flag_dc_fine_calibrated;               // DC恢复精细结果正式资格
	wire flag_dc_fine_saturation_low;           // DC恢复精细结果负饱和
	wire flag_dc_fine_saturation_high;          // DC恢复精细结果正饱和
	wire flag_dc_s1_calibration_applied;        // DC恢复透传Stage1资格
	wire flag_dc_s1_saturation_low;             // DC恢复透传Stage1负饱和
	wire flag_dc_s1_saturation_high;            // DC恢复透传Stage1正饱和
	wire flag_dc_programmable_15_valid;         // 承载 flag_dc_programmable_15_valid
	wire flag_dc_precision_mode;                // DC恢复事务精度
	wire flag_dc_color_ir;                      // DC恢复事务颜色
	wire flag_idac_amb_sample_request;          // IDAC请求AMB_CAL样本
	wire flag_idac_dcs_sample_request;          // 承载 flag_idac_dcs_sample_request
	wire flag_idac_dcs_sample_color_ir;         // IDAC请求DCS颜色
	wire flag_idac_dcs_revalidate_request;      // IDAC请求两色DC重验证
	wire flag_idac_dcs_revalidate_busy;         // IDAC两色DC重验证占用状态
	wire flag_idac_dcs_revalidate_done;         // IDAC两色DC重验证成功事件
	wire flag_idac_dcs_revalidate_failed;       // IDAC两色DC重验证失败事件
	wire flag_idac_search_amb_ready;            // IDAC接收AMB_CAL结果许可
	wire flag_idac_search_dcs_ready;            // 承载 flag_idac_search_dcs_ready
	wire flag_precision_dcs_revalidate_accept;  // precision接受两色DC重验证
	wire flag_precision_calibration_valid;      // precision周期重检校准请求valid
	wire flag_precision_calibration_color_ir;   // precision周期校准颜色
	wire flag_precision_calibration_ready;      // 顶层仲裁接受周期校准请求
	wire flag_amb_sample_accepted;              // AMB_CAL结果被IDAC消费事件
	wire flag_dcs_sample_accepted;              // 承载 flag_dcs_sample_accepted
	wire flag_precision_normal_result_ready;    // 精度窗口接受检测分支结果许可
	wire flag_precision_takeover_safe;          // 复合精度切换安全资格：物理ADC idle加数字流水排空，不是物理idle事实
	wire flag_normal_start_match;               // NORMAL载荷与committed状态匹配
	wire flag_calibration_start_match;          // 校准载荷与在途请求匹配
	wire flag_result_abort_discard;             // abort或无owner STOP期间结果fork进入丢弃汇点
	wire flag_measurement_result_discard_fire;  // 正式测量结果本拍因丢弃汇点释放而非真实消费，公开discard事件触发源
	wire [1:0]flag_measurement_result_discard_reason; // 本拍触发正式结果丢弃的STOP/abort/系统故障三态归类
	wire flag_detection_transfer;               // 检测分支本拍消费旧事务
	wire flag_measurement_transfer;             // 正式分支本拍消费旧事务
	wire flag_result_fork_all_released;         // 两分支在本拍均释放旧事务
	wire flag_dc_result_transfer;               // DC恢复结果装入fork事件
	wire flag_calibration_result_match;         // router校准结果与在途请求匹配
	wire flag_calibration_result_mismatch;      // router校准结果严重错配事件
	wire flag_calibration_result_consumed;      // 已由匹配的IDAC分支消费、但router valid尚未撤销
	wire flag_start_context_mismatch;           // 启动载荷与committed上下文不匹配
	wire flag_late_normal_result;               // 重检禁止期迟到NORMAL结果事件
	wire flag_start_payload_changed;            // 受反压启动载荷发生变化
	wire flag_startup_request_source;           // IDAC启动搜索请求存在
	wire flag_recheck_request_source;           // precision周期重检请求存在
	wire flag_startup_request_color_ir;         // IDAC启动搜索请求颜色
	wire flag_precision_fault_blocking;         // 精度控制阻断故障汇总
	wire flag_start_blocked;                    // STOP、abort或阻断故障禁止启动
	wire flag_unused_output_calibration;        // 正式输出未单独导出的Stage1资格
	wire flag_unused_output_s1_sat_low;         // 正式输出未单独导出的Stage1负饱和
	wire flag_unused_output_s1_sat_high;        // 正式输出未单独导出的Stage1正饱和

	wire flag_idac_amb_seq_busy;                // IDAC周期AMB序列占用状态
	wire flag_idac_amb_seq_done;                // IDAC周期AMB成功事件
	wire flag_idac_amb_seq_failed;              // IDAC周期AMB失败事件
	wire flag_precision_amb_seq_start;          // precision安全接管后启动AMB序列
	wire signed [11:0]flag_track_s1_value;      // IDAC跟踪分支Stage1残差
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]flag_track_config_epoch; // 跟踪分支ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]flag_track_coef_epoch; // 承载 flag_track_coef_epoch
	wire [C_FRAME_ID_WIDTH - 1:0]flag_track_frame_id; // 跟踪分支帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_track_sample_index; // 跟踪分支序号
	wire [1:0]flag_track_frame_type;            // 跟踪分支类型
	wire [C_IDAC_CODE_WIDTH - 1:0]flag_track_amb_code_snapshot; // 跟踪分支AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]flag_track_dc_code_snapshot; // 承载 flag_track_dc_code_snapshot
	wire [C_CODE_EPOCH_WIDTH - 1:0]flag_track_amb_code_epoch; // 承载 flag_track_amb_code_epoch
	wire [C_CODE_EPOCH_WIDTH - 1:0]flag_track_dc_code_epoch; // 承载 flag_track_dc_code_epoch
	wire flag_track_branch_valid_raw;           // fork产生的原始tracking valid
	wire [1:0]flag_startup_request_frame_type;  // IDAC启动搜索请求类型
	wire flag_normal_ppg_profile;               // 当前RUN是否为NORMAL_PPG
	wire flag_normal_start_search_qualified;    // NORMAL_PPG且SEARCH_HOLD或SEARCH_TRACK的启动搜索资格
	wire flag_normal_track_qualified;           // NORMAL_PPG且SEARCH_TRACK的tracking资格
	wire flag_idac_start_event_qualified;       // 允许进入IDAC启动状态机的START事件
	wire flag_normal_measurement_active_qualified; // 仅NORMAL用于精度和重检累计
	wire flag_dcs_revalidate_accept_qualified;  // 仅合法NORMAL_TRACK允许DC重检接管
	wire flag_precision_fault_event;            // 精度阻断故障新episode单周期脉冲，驱动cause 8'h04待分发标记置位
	wire flag_precision_fault_active;           // 精度阻断故障当前RUN代际保持电平，直接作为cause 8'h04的lane-active
	wire flag_precision_fault_identity_valid;   // 标记精度阻断故障是否绑定了真实检测事务身份
	wire [C_FRAME_ID_WIDTH - 1:0]flag_precision_fault_frame_id; // 精度阻断故障绑定事务的真实物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_precision_fault_sample_index; // 精度阻断故障绑定事务的全局事务号
	wire flag_precision_fault_color_ir;         // 精度控制器只处理RED来源事务，此位恒为0
	wire [1:0]flag_precision_fault_frame_type;  // 有效身份固定输出NORMAL类别编码
	wire flag_precision_fault_precision;        // 精度阻断故障绑定事务建立时所属的精度模式
	wire [C_RUN_GENERATION_WIDTH - 1:0]flag_precision_fault_run_generation; // 精度阻断故障绑定的RUN代际
	wire flag_idac_fault_event;                 // IDAC三路故障任一从0到1的注册单周期事件，驱动cause 8'h05待分发标记置位
	wire flag_idac_fault_active;                // IDAC三路故障汇总阻断电平，直接作为cause 8'h05的lane-active
	wire flag_idac_fault_identity_valid;        // 标记IDAC耗尽故障是否绑定了真实搜索样本身份
	wire [C_FRAME_ID_WIDTH - 1:0]flag_idac_fault_frame_id; // 耗尽故障样本所属的物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_idac_fault_sample_index; // 耗尽故障样本的全局顺序编号
	wire flag_idac_fault_color_ir;              // 耗尽故障样本的颜色，AMB耗尽时按诊断值恒为0
	wire [1:0]flag_idac_fault_frame_type;       // 区分耗尽故障来自AMB_CAL还是DCS_CAL搜索
	wire flag_idac_fault_precision;             // 耗尽故障样本采集时使用的精度身份
	wire [C_RUN_GENERATION_WIDTH - 1:0]flag_idac_fault_run_generation; // 耗尽故障样本所属的RUN代际
	wire flag_ami_fault_dispatch_01;            // 本拍轮到cause 8'h01占用唯一分发槽位，五路里优先级最高
	wire flag_ami_fault_dispatch_02;            // 协议对应关系错误占用分发槽位的判定，让位给更高优先级的01
	wire flag_ami_fault_dispatch_03;            // 无法证明恢复上下文占用分发槽位的判定，让位给01和02
	wire flag_ami_fault_dispatch_04;            // 精度阻断故障占用分发槽位的判定，让位给更高优先级的01/02/03
	wire flag_ami_fault_dispatch_05;            // IDAC阻断故障占用分发槽位的判定，让位给01/02/03/04
	wire flag_ami_terminal_action;              // STOP/abort/系统故障任一到达本拍的合并触发电平
	wire flag_pwi_detection_datapath_empty;     // PWI o_detection_datapath_empty桥接，判断检测代际是否仍需清空
	wire flag_detection_discard_trigger;        // 本拍需要新发出一次检测代际清空广播的唯一判定
	wire flag_fork_local_empty;                 // 测量与跟踪两分支均无pending时为高，仅供诊断观测
	wire flag_overlap_local_empty;              // 单元素输出缓存无pending事务时为高，仅供诊断观测
	wire [C_RUN_GENERATION_WIDTH - 1:0]flag_fork_tracking_run_generation; // fork跟踪分支pending所属的保持型RUN代际，仅供诊断观测
	wire [1:0]flag_terminal_discard_reason;     // STOP/abort/系统故障三态原因编码，datapath与detection两组discard共用
	wire flag_datapath_discard_identity_valid;  // 私有代际清空组身份是否可信，命中当前ADC在途owner时为1
	wire [C_FRAME_ID_WIDTH - 1:0]flag_datapath_discard_frame_id; // 私有代际清空组触发事务真实帧号，仅诊断用途
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_datapath_discard_sample_index; // 私有代际清空组触发事务全局序号，仅诊断用途
	wire flag_datapath_discard_color_ir;        // 私有代际清空组触发事务颜色，仅诊断用途
	wire [1:0]flag_datapath_discard_frame_type; // 私有代际清空组触发事务类型，仅诊断用途
	wire flag_datapath_discard_precision;       // 私有代际清空组触发事务精度，仅诊断用途
	wire flag_detection_discard_sample_valid;   // 检测代际清空组触发事务的独立样本资格快照
	wire flag_detection_discard_identity_valid; // 检测代际清空组身份是否可信，命中当前保留检测分支事务时为1
	wire [C_FRAME_ID_WIDTH - 1:0]flag_detection_discard_frame_id; // 检测代际清空组触发事务真实帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_detection_discard_sample_index; // 检测代际清空组触发事务全局序号
	wire flag_detection_discard_color_ir;       // 检测代际清空组触发事务颜色
	wire [1:0]flag_detection_discard_frame_type; // 检测代际清空组触发事务类型
	wire flag_detection_discard_precision;      // 检测代际清空组触发事务精度
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]flag_detection_discard_config_epoch; // 检测代际清空组触发事务ACTIVE配置版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]flag_detection_discard_coef_epoch; // 检测代际清空组触发事务Stage1系数版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]flag_detection_discard_dc_recovery_epoch; // 检测代际清空组触发事务DC恢复版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]flag_detection_discard_amb_code_epoch; // 检测代际清空组触发事务环境光抵消码版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]flag_detection_discard_dc_code_epoch; // 检测代际清空组触发事务颜色DC码版本
	//-----------------编码信号-----------------//
	wire [FORK_PAYLOAD_WIDTH - 1:0]enc_dc_result_payload; // DC恢复事务打包载荷
	wire enc_amb_sequence_start_qualified;      // 仅合法NORMAL_TRACK允许AMB重检启动

	//-----------------译码信号-----------------//
	wire [9:0]dec_capture_stage1_raw;           // 跨域稳定后的Stage1物理码
	wire [9:0]dec_capture_stage2_raw;           // 承载 dec_capture_stage2_raw
	wire [8:0]dec_s1_detect_code;               // 固定9-bit黄金检测码
	wire [9:0]dec_s1_stage1_raw;                // 固定重构对齐的Stage1物理码
	wire signed [10:0]dec_s1_stage1_code_ext;   // 固定公式未钳位Stage1码
	wire [9:0]dec_s1_stage2_raw;                // 同一事务Stage2物理码
	wire [C_FRAME_ID_WIDTH - 1:0]dec_s1_frame_id; // 固定重构事务帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_s1_sample_index; // 固定重构事务序号
	wire [1:0]dec_s1_frame_type;                // 固定重构事务类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_s1_amb_code_snapshot; // 固定重构AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_s1_dc_code_snapshot; // 承载 dec_s1_dc_code_snapshot
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_s1_amb_code_epoch; // 固定重构AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_s1_dc_code_epoch; // 承载 dec_s1_dc_code_epoch
	wire signed [11:0]dec_router_calibrated_s1_value; // router共享正式Stage1残差
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_router_config_epoch; // router共享ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_router_coef_epoch; // 承载 dec_router_coef_epoch
	wire [8:0]dec_router_detect_code;           // router共享黄金检测码
	wire [9:0]dec_router_stage1_raw;            // router共享Stage1物理码
	wire signed [10:0]dec_router_stage1_code_ext; // router共享固定Stage1扩展码
	wire [9:0]dec_router_stage2_raw;            // 承载 dec_router_stage2_raw
	wire [C_FRAME_ID_WIDTH - 1:0]dec_router_frame_id; // router共享事务帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_router_sample_index; // router共享事务序号
	wire [1:0]dec_router_frame_type;            // router共享事务类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_router_amb_code_snapshot; // router共享AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_router_dc_code_snapshot; // 承载 dec_router_dc_code_snapshot
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_router_amb_code_epoch; // 承载 dec_router_amb_code_epoch
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_router_dc_code_epoch; // 承载 dec_router_dc_code_epoch
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_completion_sample_index; // 进入生产matcher的真实或测试身份
	wire signed [11:0]dec_measurement_s1_value; // 测量分支Stage1残差
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_measurement_config_epoch; // 测量分支ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_measurement_coef_epoch; // 承载 dec_measurement_coef_epoch
	wire [8:0]dec_measurement_detect_code;      // 测量分支黄金检测码
	wire [9:0]dec_measurement_stage1_raw;       // 测量分支Stage1物理码
	wire signed [10:0]dec_measurement_stage1_code_ext; // 测量分支固定Stage1码
	wire [9:0]dec_measurement_stage2_raw;       // 承载 dec_measurement_stage2_raw
	wire [C_FRAME_ID_WIDTH - 1:0]dec_measurement_frame_id; // 测量分支帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_measurement_sample_index; // 测量分支序号
	wire [1:0]dec_measurement_frame_type;       // 测量分支类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_measurement_amb_code_snapshot; // 测量分支AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_measurement_dc_code_snapshot; // 承载 dec_measurement_dc_code_snapshot
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_measurement_amb_code_epoch; // 承载 dec_measurement_amb_code_epoch
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_measurement_dc_code_epoch; // 承载 dec_measurement_dc_code_epoch
	wire signed [11:0]dec_overlap_s1_value;     // overlap透传Stage1残差
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_overlap_config_epoch; // overlap透传ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_overlap_coef_epoch; // 承载 dec_overlap_coef_epoch
	wire [8:0]dec_overlap_detect_code;          // overlap透传黄金检测码
	wire [9:0]dec_overlap_stage1_raw;           // overlap透传Stage1物理码
	wire signed [10:0]dec_overlap_stage1_code_ext; // overlap透传固定Stage1码
	wire [9:0]dec_overlap_stage2_raw;           // 承载 dec_overlap_stage2_raw
	wire signed [10:0]dec_overlap_stage2_code_ext; // overlap生成Stage2扩展码
	wire signed [14:0]dec_overlap_nominal_15_code; // overlap标称黄金15-bit码
	wire [C_FRAME_ID_WIDTH - 1:0]dec_overlap_frame_id; // overlap事务帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_overlap_sample_index; // overlap事务序号
	wire [1:0]dec_overlap_frame_type;           // overlap事务类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_overlap_amb_code_snapshot; // overlap AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_overlap_dc_code_snapshot; // overlap DC快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_overlap_amb_code_epoch; // overlap AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_overlap_dc_code_epoch; // overlap DC版本
	wire signed [14:0]dec_reconstructor_15_code; // 承载 dec_reconstructor_15_code
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_reconstructor_stage2_epoch; // 本笔Stage2版本
	wire signed [11:0]dec_reconstructor_s1_value; // 重构器透传Stage1残差
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_reconstructor_config_epoch; // 重构器ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_reconstructor_coef_epoch; // 承载 dec_reconstructor_coef_epoch
	wire [8:0]dec_reconstructor_detect_code;    // 重构器透传固定黄金检测码
	wire [9:0]dec_reconstructor_stage1_raw;     // 重构器透传Stage1物理判决位
	wire signed [10:0]dec_reconstructor_stage1_code_ext; // 重构器透传固定D1_EXT诊断值
	wire [9:0]dec_reconstructor_stage2_raw;     // 重构器透传第二级冗余物理判决位
	wire signed [10:0]dec_reconstructor_stage2_code_ext; // 重构器透传第二级冗余解码诊断值
	wire signed [14:0]dec_reconstructor_nominal_15_code; // 重构器透传固定标称15-bit结果
	wire [C_FRAME_ID_WIDTH - 1:0]dec_reconstructor_frame_id; // 重构器帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_reconstructor_sample_index; // 重构器序号
	wire [1:0]dec_reconstructor_frame_type;     // 重构器事务类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_reconstructor_amb_code_snapshot; // 重构器AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_reconstructor_dc_code_snapshot; // 承载 dec_reconstructor_dc_code_snapshot
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_reconstructor_amb_code_epoch; // 承载 dec_reconstructor_amb_code_epoch
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_reconstructor_dc_code_epoch; // 承载 dec_reconstructor_dc_code_epoch
	wire signed [C_DATA_WIDTH - 1:0]dec_dc_coarse_ppg_value; // DC恢复粗结果
	wire signed [C_DATA_WIDTH - 1:0]dec_dc_fine_ppg_value; // DC恢复精细结果
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_dc_recovery_epoch; // DC恢复版本
	wire signed [11:0]dec_dc_s1_value;          // DC恢复透传Stage1残差
	wire signed [14:0]dec_dc_programmable_15_code; // 承载 dec_dc_programmable_15_code
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_dc_config_epoch; // DC恢复透传ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_dc_coef_epoch; // 承载 dec_dc_coef_epoch
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_dc_stage2_epoch; // 承载 dec_dc_stage2_epoch
	wire [C_FRAME_ID_WIDTH - 1:0]dec_dc_frame_id; // DC恢复事务帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_dc_sample_index; // DC恢复事务序号
	wire [1:0]dec_dc_frame_type;                // DC恢复事务类型
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_dc_amb_code_snapshot; // DC恢复AMB快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_dc_dc_code_snapshot; // DC恢复颜色DC快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_dc_amb_code_epoch; // 承载 dec_dc_amb_code_epoch
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_dc_dc_code_epoch; // 承载 dec_dc_dc_code_epoch
	wire [9:0]dec_dc_stage1_raw;                // Stage1物理判决位承接线，供P2S边界透传；取自DC恢复自己重新导出的atomic payload_o，非重构器早期dec_reconstructor_stage1_raw
	wire [9:0]dec_dc_stage2_raw;                // 第二级冗余物理判决位承接线，供P2S边界透传；同样取自DC恢复自己重新导出的atomic payload_o字段，与dec_dc_stage1_raw锁在同一拍
	wire [1:0]dec_precision_calibration_frame_type; // precision周期校准类型
	wire [C_RUN_GENERATION_WIDTH - 1:0]dec_router_run_generation; // router原样透传给overlap的当前RUN代际
	wire [C_RUN_GENERATION_WIDTH - 1:0]dec_overlap_run_generation; // overlap锁存输出的保持型RUN代际，仅供诊断观测
	wire [C_RUN_GENERATION_WIDTH - 1:0]dec_fork_measurement_run_generation; // fork测量分支pending所属的保持型RUN代际，仅供诊断观测

	//-----------------其他信号-----------------//

	//-----------------输出信号-----------------//
	//ADC事务启动接口
	wire transaction_start_ready_o;             // 当前启动载荷满足全部合同资格

	//ADC可靠完成旁带
	reg adc_transaction_complete_event_o = 1'b0; // 当前已归属ADC结果的单周期完成通知
	reg adc_transaction_success_o = 1'b0;       // 当前完成通知关联的有效结果资格
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]adc_complete_sample_index_o = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 完成通知绑定的稳定事务序号

	//正式结果生命周期丢弃公开观测
	reg measurement_result_discard_event_o = 1'b0; // 合同6.10节公开端口的单周期丢弃通知寄存
	reg [1:0]measurement_result_discard_reason_o = 2'b00; // 与丢弃通知同拍保持的STOP/abort/系统故障归类寄存
	reg measurement_result_discard_identity_valid_o = 1'b0; // 丢弃通知期间TXN_ID字段是否可信的寄存标志
	reg measurement_result_discard_sample_valid_o = 1'b0; // 丢弃前一拍独立样本资格的寄存镜像
	reg [C_FRAME_ID_WIDTH - 1:0]measurement_result_discard_frame_id_o = {C_FRAME_ID_WIDTH{1'b0}}; // TXN_ID分量之一，物理帧号寄存镜像
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]measurement_result_discard_sample_index_o = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // TXN_ID分量之一，全局序号寄存镜像
	reg measurement_result_discard_color_ir_o = 1'b0; // TXN_ID分量之一，颜色身份寄存镜像
	reg [1:0]measurement_result_discard_frame_type_o = 2'b00; // TXN_ID分量之一，帧类型编码寄存镜像
	reg measurement_result_discard_precision_o = 1'b0; // TXN_ID分量之一，精度模式寄存镜像
	reg [C_RUN_GENERATION_WIDTH - 1:0]measurement_result_discard_run_generation_o = {C_RUN_GENERATION_WIDTH{1'b0}}; // TXN_ID分量之一，RUN代际寄存镜像

	//校准请求接口
	reg calibration_sample_valid_o = 1'b0;      // 仲裁后保持型校准请求所有权
	reg [1:0]calibration_frame_type_o = 2'b00;  // 当前校准请求事务类型快照
	reg calibration_color_ir_o = 1'b0;          // 当前校准请求颜色快照
	reg [1:0]calibration_request_reason_o = 2'b00; // 当前校准请求来源快照
	wire calibration_request_fire_o;            // 外部调度器接受请求事件

	//IDAC状态输出
	wire [C_IDAC_CODE_WIDTH - 1:0]amb_code_o;   // 桥接 amb_code_o
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_r_code_o; // 桥接 dcs_r_code_o
	wire [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_code_o; // 桥接 dcs_ir_code_o
	wire [C_CODE_EPOCH_WIDTH - 1:0]amb_code_epoch_o; // 桥接 amb_code_epoch_o
	wire [C_CODE_EPOCH_WIDTH - 1:0]dcs_r_code_epoch_o; // 桥接 dcs_r_code_epoch_o
	wire [C_CODE_EPOCH_WIDTH - 1:0]dcs_ir_code_epoch_o; // 桥接 dcs_ir_code_epoch_o
	wire amb_code_update_o;                     // 桥接 amb_code_update_o
	wire dcs_r_code_update_o;                   // 桥接 dcs_r_code_update_o
	wire dcs_ir_code_update_o;                  // 桥接 dcs_ir_code_update_o
	wire dcs_r_track_adjust_o;                  // 桥接 dcs_r_track_adjust_o
	wire dcs_ir_track_adjust_o;                 // 桥接 dcs_ir_track_adjust_o
	wire amb_search_done_o;                     // 桥接 amb_search_done_o
	wire dcs_r_search_done_o;                   // 桥接 dcs_r_search_done_o
	wire dcs_ir_search_done_o;                  // 桥接 dcs_ir_search_done_o
	wire amb_search_exhausted_o;                // 桥接 amb_search_exhausted_o
	wire dcs_r_search_exhausted_o;              // 桥接 dcs_r_search_exhausted_o
	wire dcs_ir_search_exhausted_o;             // 桥接 dcs_ir_search_exhausted_o
	wire amb_pending_valid_o;                   // 桥接 amb_pending_valid_o
	wire dcs_r_pending_valid_o;                 // 桥接 dcs_r_pending_valid_o
	wire dcs_ir_pending_valid_o;                // 桥接 dcs_ir_pending_valid_o
	wire amb_code_at_min_o;                     // 桥接 amb_code_at_min_o
	wire amb_code_at_max_o;                     // 桥接 amb_code_at_max_o
	wire dcs_r_code_at_min_o;                   // 桥接 dcs_r_code_at_min_o
	wire dcs_r_code_at_max_o;                   // 桥接 dcs_r_code_at_max_o
	wire dcs_ir_code_at_min_o;                  // 桥接 dcs_ir_code_at_min_o
	wire dcs_ir_code_at_max_o;                  // 桥接 dcs_ir_code_at_max_o
	wire amb_fault_o;                           // 桥接 amb_fault_o
	wire dcs_r_fault_o;                         // 桥接 dcs_r_fault_o
	wire dcs_ir_fault_o;                        // 桥接 dcs_ir_fault_o
	wire idac_protocol_error_sticky_o;          // 桥接 idac_protocol_error_sticky_o
	wire startup_search_complete_o;             // 桥接 startup_search_complete_o
	wire idac_idle_o;                           // 桥接 idac_idle_o

	//精度窗口状态输出
	wire active_precision_mode_o;               // 桥接 active_precision_mode_o
	wire fine_window_active_o;                  // 桥接 fine_window_active_o
	wire fine_window_start_event_o;             // 桥接 fine_window_start_event_o
	wire [C_FRAME_ID_WIDTH - 1:0]fine_window_start_frame_id_o; // 桥接 fine_window_start_frame_id_o
	wire precision_15_to_9_event_o;             // 桥接 precision_15_to_9_event_o
	wire [C_FRAME_ID_WIDTH - 1:0]precision_15_to_9_frame_id_o; // 桥接 precision_15_to_9_frame_id_o
	wire reacquire_request_event_o;             // 桥接 reacquire_request_event_o
	wire switch_hold_new_transaction_o;         // 桥接 switch_hold_new_transaction_o
	wire [15:0]cnt_normal_frame_o;              // 桥接 cnt_normal_frame_o
	wire amb_recheck_pending_o;                 // 桥接 amb_recheck_pending_o
	wire amb_recheck_accept_o;                  // 桥接 amb_recheck_accept_o
	wire amb_recheck_busy_o;                    // 桥接 amb_recheck_busy_o
	wire normal_output_inhibit_o;               // 桥接 normal_output_inhibit_o
	wire recheck_seq_done_o;                    // 周期重检整体完成事件
	wire recheck_seq_failed_o;                  // 周期重检整体失败事件
	wire fir_history_full_r_o;                  // 桥接 fir_history_full_r_o
	wire fir_history_full_ir_o;                 // 桥接 fir_history_full_ir_o
	wire fir_idle_o;                            // 桥接 fir_idle_o
	wire detection_fork_idle_o;                 // 桥接 detection_fork_idle_o
	wire detector_idle_o;                       // 桥接 detector_idle_o
	wire controller_idle_o;                     // 桥接 controller_idle_o
	wire scheduler_idle_o;                      // 桥接 scheduler_idle_o
	wire cross_pending_o;                       // 桥接 cross_pending_o
	wire peak_pending_o;                        // 桥接 peak_pending_o
	wire valley_pending_o;                      // 桥接 valley_pending_o
	wire return_pending_o;                      // 桥接 return_pending_o
	wire baseline_valid_o;                      // 桥接 baseline_valid_o
	wire reacquire_active_o;                    // 桥接 reacquire_active_o
	wire detector_fine_window_active_o;         // 桥接 detector_fine_window_active_o
	wire switch_pending_o;                      // 桥接 switch_pending_o
	wire switch_target_precision_o;             // 桥接 switch_target_precision_o
	wire signed [C_SLOPE_WIDTH - 1:0]slope_current_q16_o; // 桥接 slope_current_q16_o
	wire baseline_protocol_error_sticky_o;      // 桥接 baseline_protocol_error_sticky_o
	wire fine_window_timeout_sticky_o;          // 桥接 fine_window_timeout_sticky_o
	wire reacquire_timeout_sticky_o;            // 桥接 reacquire_timeout_sticky_o
	wire peak_valley_protocol_error_sticky_o;   // 桥接 peak_valley_protocol_error_sticky_o
	wire switch_timeout_sticky_o;               // 桥接 switch_timeout_sticky_o
	wire precision_protocol_error_sticky_o;     // 桥接 precision_protocol_error_sticky_o

	//正式测量结果输出
	wire signed [C_DATA_WIDTH - 1:0]coarse_ppg_value_o; // 结果fork保持的粗PPG码
	wire coarse_valid_o;                        // 承载 coarse_valid_o
	wire coarse_recovery_calibrated_o;          // 粗PPG正式DC恢复资格
	wire coarse_saturation_low_o;               // 粗PPG负向饱和诊断
	wire coarse_saturation_high_o;              // 粗PPG正向饱和诊断
	wire signed [C_DATA_WIDTH - 1:0]fine_ppg_value_o; // 结果fork保持的精细PPG码
	wire fine_valid_o;                          // 承载 fine_valid_o
	wire fine_recovery_calibrated_o;            // 精细PPG正式DC恢复资格
	wire fine_saturation_low_o;                 // 精细PPG负向饱和诊断
	wire fine_saturation_high_o;                // 精细PPG正向饱和诊断
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dc_result_coef_epoch_o; // DC恢复系数版本快照
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]config_epoch_o; // ACTIVE配置版本快照
	wire [C_COEF_EPOCH_WIDTH - 1:0]coef_epoch_o; // Stage1系数版本快照
	wire [C_COEF_EPOCH_WIDTH - 1:0]stage2_result_coef_epoch_o; // 承载 stage2_result_coef_epoch_o
	wire signed [11:0]calibrated_s1_value_o;    // Stage1校准残差快照
	wire signed [14:0]programmable_15_code_o;   // 可编程15-bit残差快照
	wire programmable_15_valid_o;               // 可编程15-bit结果资格
	wire result_precision_mode_o;               // 结果事务精度快照
	wire [C_FRAME_ID_WIDTH - 1:0]result_frame_id_o; // 结果物理帧号快照
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]result_sample_index_o; // 结果全局序号快照
	wire result_color_ir_o;                     // 结果颜色快照
	wire [1:0]result_frame_type_o;              // 结果帧类型快照
	wire [C_IDAC_CODE_WIDTH - 1:0]result_amb_code_snapshot_o; // 结果AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]result_dc_code_snapshot_o; // 结果颜色DC码快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]result_amb_code_epoch_o; // 结果AMB码版本快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]result_dc_code_epoch_o; // 承载 result_dc_code_epoch_o
	reg result_sample_valid_o = 1'b0;           // 与正式和检测分支同拍锁存的独立样本资格

	//Wrapper状态输出
	reg integration_protocol_error_sticky_o = 1'b0; // 集成协议sticky内部存储

	//---------------其他信号连线---------------//
	//其他信号连线
	//===================<其他信号连线>===================//
	// 启动搜索请求来自IDAC当前期望样本，周期请求来自精度窗口调度器。
	assign flag_adc_capture_transfer = flag_capture_valid && flag_capture_ready; // 定义捕获RAW进入S1上下文的唯一交接沿
	assign flag_adc_capture_without_owner = flag_adc_capture_transfer && !flag_adc_transaction_inflight; // 无AMI在途所有权时拒绝把RAW宣布为完成
	assign flag_test_inject_effective = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable; // 生产构建固定旁路全部验证请求；默认参数0+生产enable 0双重旁路 @satisfies: TOP-21
	assign flag_test_identity_inject_fire = i_test_identity_inject_valid && o_test_identity_inject_ready; // ready/valid唯一接纳错误identity
	assign flag_test_invalid_sample_fire = i_test_invalid_sample_valid && o_test_invalid_sample_ready; // ready/valid唯一接纳invalid资格
	assign dec_completion_sample_index = flag_test_identity_inject_fire ? i_test_identity_inject_sample_index : dec_s1_sample_index; // 测试仅替换送入原matcher的比较输入；合法identity注入只进入production matcher比较端；SID-10同一注入通道用于校准(AMB_CAL)事务构造真实身份错配，验证搜索不因错配完成而推进 @satisfies: TOP-22, P07, SID-10
	assign flag_adc_completion_normal_emit = flag_adc_completion_pending && flag_s1_detect_valid && !flag_test_identity_hold && !flag_test_identity_inject_fire; // 错配注入当拍禁止完成旁带和owner释放；注入期间owner不错误释放、无正式结果 @satisfies: TOP-22
	assign flag_adc_completion_abort_release = flag_test_identity_hold && i_control_abort_event && flag_adc_completion_pending; // 受控abort只能以缓存真实上下文释放旧owner；不得再叠加flag_s1_detect_valid（S1重构器自身输出缓存的瞬态valid，交接给flag_adc_completion_pending后一两拍内即回落，abort/STOP在此之后任意时刻到达都会读到0，导致本条件几乎永远不可达——真正代表"完成仍缓存待核实"的持久状态是flag_adc_completion_pending本身，metadata_o系寄存保持值，不依赖detect_valid_o是否仍为1）
	assign flag_adc_completion_emit = flag_adc_completion_normal_emit || flag_adc_completion_abort_release; // 正常完成或受控失败释放均只产生一次旁带
	assign flag_adc_completion_owner_match = (flag_capture_precision_mode == reg_adc_inflight_precision_mode) && (flag_s1_precision_mode == reg_adc_inflight_precision_mode) && (dec_s1_frame_id == reg_adc_inflight_frame_id) && (dec_completion_sample_index == reg_adc_inflight_sample_index) && (flag_s1_color_ir == reg_adc_inflight_color_ir) && (dec_s1_frame_type == reg_adc_inflight_frame_type) && (dec_s1_amb_code_snapshot == reg_adc_inflight_amb_code) && (dec_s1_dc_code_snapshot == reg_adc_inflight_dc_code) && (dec_s1_amb_code_epoch == reg_adc_inflight_amb_epoch) && (dec_s1_dc_code_epoch == reg_adc_inflight_dc_epoch); // capture精度与S1全部返回身份必须命中同一物理ADC owner
	assign flag_adc_completion_success = flag_adc_completion_normal_emit && flag_adc_completion_owner_match && !flag_adc_transaction_abort && !flag_result_abort_discard; // 测试错配恢复只能输出success=0，绝不形成正式成功
	assign flag_normal_ppg_profile = (i_run_profile == RUN_PROFILE_NORMAL); // 运行档案低电平明确表示NORMAL_PPG
	assign flag_normal_start_search_qualified = i_run_enable && flag_normal_ppg_profile && ((i_idac_mode == IDAC_MODE_SEARCH_HOLD) || (i_idac_mode == IDAC_MODE_SEARCH_TRACK)); // 只有NORMAL_PPG正式搜索模式允许建立启动搜索来源
	assign flag_normal_track_qualified = i_run_enable && flag_normal_ppg_profile && (i_idac_mode == IDAC_MODE_SEARCH_TRACK); // 只有NORMAL_PPG的SEARCH_TRACK允许tracking和周期重检
	assign flag_idac_start_event_qualified = i_start_ack_event && i_run_enable && (flag_normal_ppg_profile || (i_idac_mode == IDAC_MODE_MANUAL)); // CHARACTERIZATION只接受MANUAL启动装码
	assign flag_normal_measurement_active_qualified = o_normal_measurement_eligible && flag_normal_ppg_profile; // 仅已完成启动且属于NORMAL_PPG的测量进入精度及重检累计
	assign enc_amb_sequence_start_qualified = flag_precision_amb_seq_start && flag_normal_track_qualified; // 周期AMB仅由NORMAL_TRACK安全接管
	assign flag_dcs_revalidate_accept_qualified = flag_precision_dcs_revalidate_accept && flag_normal_track_qualified; // 周期DC重验证仅由NORMAL_TRACK接管
	assign flag_track_branch_valid = flag_normal_track_qualified ? flag_track_branch_valid_raw : 1'b0; // 非NORMAL_TRACK运行档案丢弃tracking副本
	assign flag_startup_request_source = flag_normal_start_search_qualified && (flag_idac_amb_sample_request || flag_idac_dcs_sample_request) && (startup_search_complete_o == 1'b0) && (flag_precision_calibration_valid == 1'b0); // 仅NORMAL自动启动搜索请求成为启动来源
	assign flag_startup_request_frame_type = flag_idac_amb_sample_request ? FRAME_TYPE_AMB : FRAME_TYPE_DCS; // IDAC请求译码成帧类型
	assign flag_startup_request_color_ir = flag_idac_dcs_sample_request ? flag_idac_dcs_sample_color_ir : 1'b0; // AMB颜色固定为红光诊断值
	assign flag_recheck_request_source = flag_normal_track_qualified && flag_precision_calibration_valid; // 只有NORMAL_TRACK允许周期重检请求来源
	assign flag_precision_calibration_ready = (calibration_sample_valid_o == 1'b0) && (flag_calibration_request_inflight == 1'b0) && (flag_start_blocked == 1'b0); // 顶层仅在空闲时接纳新周期请求
	assign flag_precision_fault_blocking = flag_precision_fault_event || switch_timeout_sticky_o; // 精度提交故障阻断当前RUN
	assign flag_start_blocked = (i_run_enable == 1'b0) || (i_stop_ack_event == 1'b1) || i_control_abort_event || flag_abort_draining || flag_stop_result_draining || o_wrapper_fault_blocking; // 生命周期、STOP/abort排空和阻断故障关闭全部新事务
	assign calibration_request_fire_o = calibration_sample_valid_o && i_calibration_sample_ready; // 外部调度器真实取得所有权
	// 当前启动载荷必须与精度、IDAC committed码和已接受校准请求逐项匹配。
	assign flag_normal_start_match = (i_transaction_frame_type == FRAME_TYPE_NORMAL) && (i_transaction_precision_mode == active_precision_mode_o) && (i_transaction_amb_code_snapshot == amb_code_o) && (i_transaction_amb_code_epoch == amb_code_epoch_o) && (i_transaction_dc_code_snapshot == (i_transaction_color_ir ? dcs_ir_code_o : dcs_r_code_o)) && (i_transaction_dc_code_epoch == (i_transaction_color_ir ? dcs_ir_code_epoch_o : dcs_r_code_epoch_o)); // NORMAL快照必须来自唯一committed状态
	assign flag_calibration_start_match = flag_calibration_request_inflight && (i_transaction_precision_mode == 1'b0) && (i_transaction_frame_type == reg_inflight_frame_type) && ((reg_inflight_frame_type == FRAME_TYPE_AMB) || (i_transaction_color_ir == reg_inflight_color_ir)) && (i_transaction_amb_code_snapshot == amb_code_o) && (i_transaction_amb_code_epoch == amb_code_epoch_o) && ((reg_inflight_frame_type == FRAME_TYPE_AMB) || ((i_transaction_dc_code_snapshot == (reg_inflight_color_ir ? dcs_ir_code_o : dcs_r_code_o)) && (i_transaction_dc_code_epoch == (reg_inflight_color_ir ? dcs_ir_code_epoch_o : dcs_r_code_epoch_o)))); // 校准start必须匹配仲裁请求和实际IDAC码

	//其他信号连线
	assign transaction_start_ready_o = i_allow_new_transaction && i_active_config_valid && i_adc_idle && !flag_adc_transaction_inflight && flag_s1_transaction_ready && !switch_hold_new_transaction_o && !flag_start_blocked && (((i_transaction_frame_type == FRAME_TYPE_NORMAL) && o_normal_measurement_eligible && !normal_output_inhibit_o && flag_normal_start_match) || (((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match)); // 物理ADC排空后允许已预建立波形取得结果owner
	// 受反压valid载荷变化属于协议错误，已接受校准结果错配属于阻断故障。
	assign flag_start_payload_changed = flag_held_start_valid && i_transaction_start_valid && ((reg_held_start_frame_type != i_transaction_frame_type) || (reg_held_start_precision != i_transaction_precision_mode) || (reg_held_start_frame_id != i_transaction_frame_id) || (reg_held_start_sample_index != i_transaction_sample_index) || (reg_held_start_color_ir != i_transaction_color_ir) || (reg_held_start_amb_code != i_transaction_amb_code_snapshot) || (reg_held_start_dc_code != i_transaction_dc_code_snapshot) || (reg_held_start_amb_epoch != i_transaction_amb_code_epoch) || (reg_held_start_dc_epoch != i_transaction_dc_code_epoch)); // 检查保持型启动接口载荷稳定性
	assign flag_calibration_result_match = !flag_result_abort_discard && flag_calibration_request_inflight && (((flag_router_amb_valid == 1'b1) && (reg_inflight_frame_type == FRAME_TYPE_AMB)) || ((flag_router_dcs_valid == 1'b1) && (reg_inflight_frame_type == FRAME_TYPE_DCS) && (flag_router_color_ir == reg_inflight_color_ir))); // 非abort校准结果必须命中唯一在途请求
	assign flag_calibration_result_consumed = ((flag_router_amb_valid == 1'b1) && (flag_idac_search_amb_ready == 1'b1) && (reg_inflight_frame_type == FRAME_TYPE_AMB)) || ((flag_router_dcs_valid == 1'b1) && (flag_idac_search_dcs_ready == 1'b1) && (reg_inflight_frame_type == FRAME_TYPE_DCS) && (flag_router_color_ir == reg_inflight_color_ir)); // 允许已消费结果在router撤销valid前保持一个周期
	assign flag_calibration_result_mismatch = !flag_result_abort_discard && (flag_router_amb_valid || flag_router_dcs_valid) && (flag_calibration_result_match == 1'b0) && (flag_calibration_result_consumed == 1'b0); // 未消费或类型颜色不符才升级为严重错配
	assign flag_start_context_mismatch = i_transaction_start_valid && (((i_transaction_frame_type == FRAME_TYPE_NORMAL) && !flag_normal_start_match) || (((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && !flag_calibration_start_match)); // 有效启动载荷必须匹配唯一精度和校准上下文
	assign flag_late_normal_result = flag_dc_result_transfer && normal_output_inhibit_o && !flag_result_abort_discard; // 重检禁止期到达的非abort旧NORMAL结果只允许排空
	// 校准结果由IDAC真实ready消费，事件同时关闭仲裁在途所有权并反馈重检调度器。
	assign flag_amb_sample_accepted = flag_router_amb_valid && flag_idac_search_amb_ready && !flag_result_abort_discard; // 非abort的AMB结果真实进入IDAC控制器
	assign flag_dcs_sample_accepted = flag_router_dcs_valid && flag_idac_search_dcs_ready && !flag_result_abort_discard; // 非abort的DCS结果被消费后解除对应颜色校准请求所有权
	// DC恢复结果进入第二个无丢失双消费者保持型fork。
	assign enc_dc_result_payload = {dec_dc_fine_ppg_value, flag_dc_fine_valid, flag_dc_fine_calibrated, flag_dc_fine_saturation_low, flag_dc_fine_saturation_high, dec_dc_coarse_ppg_value, flag_dc_coarse_valid, flag_dc_coarse_calibrated, flag_dc_coarse_saturation_low, flag_dc_coarse_saturation_high, dec_dc_recovery_epoch, dec_dc_config_epoch, dec_dc_coef_epoch, dec_dc_stage2_epoch, dec_dc_s1_value, flag_dc_s1_calibration_applied, flag_dc_s1_saturation_low, flag_dc_s1_saturation_high, dec_dc_programmable_15_code, flag_dc_programmable_15_valid, flag_dc_precision_mode, dec_dc_frame_id, dec_dc_sample_index, flag_dc_color_ir, dec_dc_frame_type, dec_dc_amb_code_snapshot, dec_dc_dc_code_snapshot, dec_dc_amb_code_epoch, dec_dc_dc_code_epoch}; // 原子打包正式结果和全部元数据
	assign flag_result_abort_discard = flag_abort_draining || flag_stop_result_draining || i_control_abort_event || flag_integration_blocking || flag_system_fault_discard_pending; // abort、无owner STOP、完成身份故障或supervisor系统故障均转向丢弃汇点
	assign flag_measurement_result_discard_fire = flag_measurement_pending && flag_result_abort_discard; // 正式结果仍保持在途且本拍被丢弃汇点释放，而非片外FIFO真实消费
	assign flag_measurement_result_discard_reason = (flag_system_fault_discard_pending || flag_integration_blocking) ? DISCARD_REASON_SYSTEM_FAULT : ((flag_abort_draining || i_control_abort_event) ? DISCARD_REASON_ABORT : DISCARD_REASON_STOP); // 系统故障类丢弃优先于abort类，其余归入STOP排空
	assign flag_detection_transfer = flag_detection_pending && (flag_result_abort_discard || flag_precision_normal_result_ready); // 检测分支只由真实ready或abort丢弃消费

	//其他信号连线
	assign flag_measurement_transfer = flag_measurement_pending && (flag_result_abort_discard || i_measurement_result_ready); // 正式分支独立消费当前事务
	assign flag_result_fork_all_released = (!flag_detection_pending || flag_result_abort_discard || flag_precision_normal_result_ready) && (!flag_measurement_pending || flag_result_abort_discard || i_measurement_result_ready); // 本拍两分支都能释放旧载荷
	assign flag_dc_result_ready = (!flag_detection_pending && !flag_measurement_pending) || flag_result_fork_all_released; // 空槽或同沿完全释放允许零气泡替换
	assign flag_dc_result_transfer = flag_dc_result_valid && flag_dc_result_ready; // DC恢复事务进入fork唯一事件
	assign {fine_ppg_value_o, fine_valid_o, fine_recovery_calibrated_o, fine_saturation_low_o, fine_saturation_high_o, coarse_ppg_value_o, coarse_valid_o, coarse_recovery_calibrated_o, coarse_saturation_low_o, coarse_saturation_high_o, dc_result_coef_epoch_o, config_epoch_o, coef_epoch_o, stage2_result_coef_epoch_o, calibrated_s1_value_o, flag_unused_output_calibration, flag_unused_output_s1_sat_low, flag_unused_output_s1_sat_high, programmable_15_code_o, programmable_15_valid_o, result_precision_mode_o, result_frame_id_o, result_sample_index_o, result_color_ir_o, result_frame_type_o, result_amb_code_snapshot_o, result_dc_code_snapshot_o, result_amb_code_epoch_o, result_dc_code_epoch_o} = reg_result_fork_payload; // 固定字段顺序恢复正式结果
	assign flag_precision_takeover_safe = i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle; // precision安全接管同时要求物理和数字链排空
	// AMI私有故障分发器与两套discard私有事件生成逻辑的组合判定。
	assign flag_ami_terminal_action = i_stop_ack_event || i_control_abort_event || flag_system_fault_discard_pending || i_system_fault_discard_event; // STOP、abort和系统故障pending合并为唯一终端触发电平
	assign flag_ami_fault_dispatch_01 = flag_ami_fault_pending_01; // cause 8'h01五路里优先级最高，随时可以占槽
	assign flag_ami_fault_dispatch_02 = flag_ami_fault_pending_02 && !flag_ami_fault_pending_01; // 仅01本拍未占用分发槽位时才轮到02出槽
	assign flag_ami_fault_dispatch_03 = flag_ami_fault_pending_03 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02; // 01和02本拍都未占用分发槽位时才轮到03出槽
	assign flag_ami_fault_dispatch_04 = flag_ami_fault_pending_04 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03; // 更高优先级的01/02/03若本拍都未取得分发槽位，PWI精度阻断记录接手04
	assign flag_ami_fault_dispatch_05 = flag_ami_fault_pending_05 && !flag_ami_fault_pending_01 && !flag_ami_fault_pending_02 && !flag_ami_fault_pending_03 && !flag_ami_fault_pending_04; // 五路里剩余优先级最低，01至04全部未命中本拍槽位后IDAC阻断记录才能出槽
	assign flag_detection_discard_trigger = flag_ami_terminal_action && !flag_pwi_detection_datapath_empty && !flag_detection_discard_episode_active; // 检测代际未排空且本episode尚未广播过时才新触发一次；无条件广播,LFA-02a实测确认下一拍empty @satisfies: P02, N01
	assign flag_terminal_discard_reason = (flag_system_fault_discard_pending || i_system_fault_discard_event) ? DISCARD_REASON_SYSTEM_FAULT : (i_control_abort_event ? DISCARD_REASON_ABORT : DISCARD_REASON_STOP); // 系统故障优先于abort，abort优先于STOP
	// 私有datapath_discard组身份：命中当前ADC在途owner时绑定真实身份，否则按合同要求全零。
	assign flag_datapath_discard_identity_valid = flag_adc_transaction_inflight; // 有唯一在途ADC owner时才承认这次清空绑定了真实身份
	assign flag_datapath_discard_frame_id = flag_adc_transaction_inflight ? reg_adc_inflight_frame_id : {C_FRAME_ID_WIDTH{1'b0}}; // 无owner时按合同要求强制清零
	assign flag_datapath_discard_sample_index = flag_adc_transaction_inflight ? reg_adc_inflight_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 借用owner锁存的启动序号快照
	assign flag_datapath_discard_color_ir = flag_adc_transaction_inflight && reg_adc_inflight_color_ir; // 与身份有效位共享同一AND门，无owner时自然归零
	assign flag_datapath_discard_frame_type = flag_adc_transaction_inflight ? reg_adc_inflight_frame_type : 2'b00; // 区分当前owner属于AMB_CAL、DCS_CAL还是NORMAL
	assign flag_datapath_discard_precision = flag_adc_transaction_inflight && reg_adc_inflight_precision_mode; // 借用owner锁存的SAR9或SAR15精度快照
	// 私有detection_discard组身份：命中当前保留的检测分支事务时绑定真实身份，否则按合同要求全零。
	assign flag_detection_discard_sample_valid = flag_detection_pending && result_sample_valid_o; // 快照保留分支当前保存事务的独立样本资格
	assign flag_detection_discard_identity_valid = flag_detection_pending; // 命中当前保留检测分支事务时才承认身份可信；交接给PWI后触发的discard属于scope-only，正确置0；交接前AMI自身仍持有身份时discard同样验证过正确置1 @satisfies: N08
	assign flag_detection_discard_frame_id = flag_detection_pending ? result_frame_id_o : {C_FRAME_ID_WIDTH{1'b0}}; // 取自结果fork保存事务的物理帧号快照
	assign flag_detection_discard_sample_index = flag_detection_pending ? result_sample_index_o : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 取自结果fork保存事务的全局序号快照
	assign flag_detection_discard_color_ir = flag_detection_pending && result_color_ir_o; // 取自结果fork保存事务的颜色身份快照
	assign flag_detection_discard_frame_type = flag_detection_pending ? result_frame_type_o : 2'b00; // 取自结果fork保存事务的帧类型快照
	assign flag_detection_discard_precision = flag_detection_pending && result_precision_mode_o; // 取自结果fork保存事务的精度模式快照
	assign flag_detection_discard_config_epoch = flag_detection_pending ? config_epoch_o : {C_CONFIG_EPOCH_WIDTH{1'b0}}; // 触发事务ACTIVE版本，仅诊断用途
	assign flag_detection_discard_coef_epoch = flag_detection_pending ? coef_epoch_o : {C_COEF_EPOCH_WIDTH{1'b0}}; // 触发事务Stage1系数版本，仅诊断用途
	assign flag_detection_discard_dc_recovery_epoch = flag_detection_pending ? dc_result_coef_epoch_o : {C_DC_RECOVERY_EPOCH_WIDTH{1'b0}}; // 触发事务DC恢复版本，仅诊断用途
	assign flag_detection_discard_amb_code_epoch = flag_detection_pending ? result_amb_code_epoch_o : {C_CODE_EPOCH_WIDTH{1'b0}}; // 触发事务环境光抵消码提交版本，仅诊断用途
	assign flag_detection_discard_dc_code_epoch = flag_detection_pending ? result_dc_code_epoch_o : {C_CODE_EPOCH_WIDTH{1'b0}}; // 触发事务颜色DC码提交版本，仅诊断用途

	//---------------输出信号连线---------------//
	//ADC事务启动接口
	assign o_transaction_start_ready = transaction_start_ready_o; // ready仅表示当前完整载荷可在本沿启动
	assign o_transaction_start_fire = i_transaction_start_valid && o_transaction_start_ready; // 唯一ADC启动fire
	assign o_adc_transaction_complete_event = adc_transaction_complete_event_o; // 同一可靠归属点向两个未来消费者广播完成脉冲
	assign o_adc_transaction_success = adc_transaction_success_o; // 完成脉冲有效时导出不可重新编码的成功资格
	assign o_adc_complete_sample_index = adc_complete_sample_index_o; // 完成脉冲有效时导出本笔启动事务的稳定索引
	assign o_measurement_result_discard_event = measurement_result_discard_event_o; // 桥接导出寄存事件到公开端口
	assign o_measurement_result_discard_reason = measurement_result_discard_reason_o; // 桥接导出寄存归类到公开端口
	assign o_measurement_result_discard_identity_valid = measurement_result_discard_identity_valid_o; // 桥接导出寄存身份标志到公开端口
	assign o_measurement_result_discard_sample_valid = measurement_result_discard_sample_valid_o; // 桥接导出寄存样本资格到公开端口
	assign o_measurement_result_discard_frame_id = measurement_result_discard_frame_id_o; // 桥接导出寄存帧号到公开端口
	assign o_measurement_result_discard_sample_index = measurement_result_discard_sample_index_o; // 桥接导出寄存序号到公开端口
	assign o_measurement_result_discard_color_ir = measurement_result_discard_color_ir_o; // 桥接导出寄存颜色到公开端口
	assign o_measurement_result_discard_frame_type = measurement_result_discard_frame_type_o; // 桥接导出寄存类型到公开端口
	assign o_measurement_result_discard_precision = measurement_result_discard_precision_o; // 桥接导出寄存精度到公开端口
	assign o_measurement_result_discard_run_generation = measurement_result_discard_run_generation_o; // 桥接导出寄存代际到公开端口

	//验证专用异常注入接口
	assign o_test_identity_inject_ready = flag_test_inject_effective && flag_adc_transaction_inflight && flag_adc_completion_pending && flag_s1_detect_valid && !flag_test_identity_hold && !i_test_invalid_sample_valid && (i_test_identity_inject_sample_index != reg_adc_inflight_sample_index); // 只在真实完成尚未消费时绑定不同的错误序号；与invalid请求互斥(!i_test_invalid_sample_valid) @satisfies: TOP-24
	assign o_test_invalid_sample_ready = flag_test_inject_effective && flag_dc_result_valid && flag_dc_result_ready && (dec_dc_frame_type == FRAME_TYPE_NORMAL) && !flag_test_identity_hold && !i_test_identity_inject_valid; // invalid只绑定一笔已经完成身份匹配的NORMAL结果；绑定真实身份匹配NORMAL事务 @satisfies: TOP-23, TOP-24, PRC-08
	assign o_test_saturation_inject_ready = idac_test_saturation_inject_ready_o; // 透传IDAC控制器自身的饱和注入ready

	//校准请求接口
	// 校准请求端口由单元素保持寄存器输出，确保任意反压期间载荷稳定。
	assign o_calibration_sample_valid = calibration_sample_valid_o; // 导出保持型校准请求valid
	assign o_calibration_frame_type = calibration_frame_type_o; // 导出当前校准事务类型快照
	assign o_calibration_color_ir = calibration_color_ir_o; // 导出当前DCS颜色快照
	assign o_calibration_precision_mode = 1'b0; // 所有AMB和DCS校准固定使用SAR9
	assign o_calibration_request_reason = calibration_request_reason_o; // 导出请求来源诊断
	assign o_calibration_request_fire = calibration_request_fire_o; // 导出校准请求握手事件

	//正式测量接口
	// 正式测量输出逐位译码自保持载荷，任一分支反压不会改变数据。
	assign o_measurement_result_valid = flag_measurement_pending && !flag_result_abort_discard; // 已装入正式分支的结果保持至真实消费；与discard共用同一abort_discard项，二者结构性互斥，同拍不会既报成功又报丢弃；OIB-03要求的held结果稳定持有直到valid&&ready，或STOP/abort走discard分支产生唯一DISCARD_STOP，或复位无discard地清空 @satisfies: P01, OIB-03
	assign o_result_sample_valid = result_sample_valid_o; // 独立资格与正式结果载荷一起保持到正式消费
	assign o_s1_calibration_applied = flag_dc_s1_calibration_applied; // 导出Stage1校准资格，与frame_id/sample_index/coarse/fine结果同一原子载荷锁存
	assign o_s1_raw = dec_dc_stage1_raw;        // 导出Stage1物理判决位，取自DC恢复自己重新导出的atomic payload_o
	assign o_s2_raw = dec_dc_stage2_raw;        // 导出第二级冗余物理判决位，与o_s1_raw同一原子载荷锁存，同样取自DC恢复自己重新导出的atomic payload_o
	assign o_coarse_ppg_value = coarse_ppg_value_o; // 导出粗PPG码
	assign o_coarse_valid = coarse_valid_o;     // 导出粗结果有效资格
	assign o_coarse_recovery_calibrated = coarse_recovery_calibrated_o; // 导出粗结果恢复资格
	assign o_coarse_saturation_low = coarse_saturation_low_o; // 导出粗结果负饱和诊断
	assign o_coarse_saturation_high = coarse_saturation_high_o; // 导出粗结果正饱和诊断
	assign o_fine_ppg_value = fine_ppg_value_o; // 导出精细PPG码
	assign o_fine_valid = fine_valid_o;         // 导出精细结果有效资格
	assign o_fine_recovery_calibrated = fine_recovery_calibrated_o; // 导出精细结果恢复资格
	assign o_fine_saturation_low = fine_saturation_low_o; // 导出精细结果负饱和诊断
	assign o_fine_saturation_high = fine_saturation_high_o; // 导出精细结果正饱和诊断
	assign o_dc_result_coef_epoch = dc_result_coef_epoch_o; // 导出DC恢复系数版本
	assign o_config_epoch = config_epoch_o;     // 导出ACTIVE配置版本
	assign o_coef_epoch = coef_epoch_o;         // 导出Stage1系数版本
	assign o_stage2_result_coef_epoch = stage2_result_coef_epoch_o; // 驱动 o_stage2_result_coef_epoch
	assign o_calibrated_s1_value = calibrated_s1_value_o; // 导出Stage1校准残差
	assign o_programmable_15_code = programmable_15_code_o; // 导出15-bit可编程残差
	assign o_programmable_15_valid = programmable_15_valid_o; // 导出15-bit结果资格
	assign o_result_precision_mode = result_precision_mode_o; // 导出结果精度快照
	assign o_result_frame_id = result_frame_id_o; // 导出结果物理帧号
	assign o_result_sample_index = result_sample_index_o; // 导出结果全局序号
	assign o_result_color_ir = result_color_ir_o; // 导出结果颜色快照
	assign o_result_frame_type = result_frame_type_o; // 导出结果帧类型
	assign o_result_amb_code_snapshot = result_amb_code_snapshot_o; // 导出结果AMB码快照
	assign o_result_dc_code_snapshot = result_dc_code_snapshot_o; // 驱动 o_result_dc_code_snapshot
	assign o_result_amb_code_epoch = result_amb_code_epoch_o; // 导出结果AMB码版本
	assign o_result_dc_code_epoch = result_dc_code_epoch_o; // 驱动 o_result_dc_code_epoch

	//IDAC状态输出
	assign o_amb_code = amb_code_o;             // 导出 o_amb_code
	assign o_dcs_r_code = dcs_r_code_o;         // 导出 o_dcs_r_code
	assign o_dcs_ir_code = dcs_ir_code_o;       // 导出 o_dcs_ir_code
	assign o_amb_code_epoch = amb_code_epoch_o; // 导出 o_amb_code_epoch
	assign o_dcs_r_code_epoch = dcs_r_code_epoch_o; // 导出 o_dcs_r_code_epoch
	assign o_dcs_ir_code_epoch = dcs_ir_code_epoch_o; // 导出 o_dcs_ir_code_epoch
	assign o_amb_code_update = amb_code_update_o; // 导出 o_amb_code_update
	assign o_dcs_r_code_update = dcs_r_code_update_o; // 导出 o_dcs_r_code_update
	assign o_dcs_ir_code_update = dcs_ir_code_update_o; // 导出 o_dcs_ir_code_update
	assign o_dcs_r_track_adjust = dcs_r_track_adjust_o; // 导出 o_dcs_r_track_adjust
	assign o_dcs_ir_track_adjust = dcs_ir_track_adjust_o; // 导出 o_dcs_ir_track_adjust
	assign o_amb_search_done = amb_search_done_o; // 导出 o_amb_search_done
	assign o_dcs_r_search_done = dcs_r_search_done_o; // 导出 o_dcs_r_search_done
	assign o_dcs_ir_search_done = dcs_ir_search_done_o; // 导出 o_dcs_ir_search_done
	assign o_amb_search_exhausted = amb_search_exhausted_o; // 导出 o_amb_search_exhausted
	assign o_dcs_r_search_exhausted = dcs_r_search_exhausted_o; // 导出 o_dcs_r_search_exhausted
	assign o_dcs_ir_search_exhausted = dcs_ir_search_exhausted_o; // 导出 o_dcs_ir_search_exhausted
	assign o_amb_pending_valid = amb_pending_valid_o; // 导出 o_amb_pending_valid
	assign o_dcs_r_pending_valid = dcs_r_pending_valid_o; // 导出 o_dcs_r_pending_valid
	assign o_dcs_ir_pending_valid = dcs_ir_pending_valid_o; // 导出 o_dcs_ir_pending_valid
	assign o_amb_code_at_min = amb_code_at_min_o; // 导出 o_amb_code_at_min
	assign o_amb_code_at_max = amb_code_at_max_o; // 导出 o_amb_code_at_max
	assign o_dcs_r_code_at_min = dcs_r_code_at_min_o; // 导出 o_dcs_r_code_at_min
	assign o_dcs_r_code_at_max = dcs_r_code_at_max_o; // 导出 o_dcs_r_code_at_max
	assign o_dcs_ir_code_at_min = dcs_ir_code_at_min_o; // 导出 o_dcs_ir_code_at_min
	assign o_dcs_ir_code_at_max = dcs_ir_code_at_max_o; // 导出 o_dcs_ir_code_at_max
	assign o_amb_fault = amb_fault_o;           // 导出 o_amb_fault
	assign o_dcs_r_fault = dcs_r_fault_o;       // 导出 o_dcs_r_fault
	assign o_dcs_ir_fault = dcs_ir_fault_o;     // 导出 o_dcs_ir_fault
	assign o_idac_fault_blocking = amb_fault_o || dcs_r_fault_o || dcs_ir_fault_o; // 汇总三路IDAC阻断故障
	assign o_idac_protocol_error_sticky = idac_protocol_error_sticky_o; // 导出 o_idac_protocol_error_sticky
	assign o_startup_search_complete = startup_search_complete_o; // 导出 o_startup_search_complete
	assign o_idac_idle = idac_idle_o;           // 导出 o_idac_idle

	//精度窗口状态输出
	assign o_active_precision_mode = active_precision_mode_o; // 导出 o_active_precision_mode
	assign o_fine_window_active = fine_window_active_o; // 导出 o_fine_window_active
	assign o_fine_window_start_event = fine_window_start_event_o; // 导出 o_fine_window_start_event
	assign o_fine_window_start_frame_id = fine_window_start_frame_id_o; // 导出 o_fine_window_start_frame_id
	assign o_precision_15_to_9_event = precision_15_to_9_event_o; // 导出 o_precision_15_to_9_event
	assign o_precision_15_to_9_frame_id = precision_15_to_9_frame_id_o; // 导出 o_precision_15_to_9_frame_id
	assign o_reacquire_request_event = reacquire_request_event_o; // 导出 o_reacquire_request_event
	assign o_switch_hold_new_transaction = switch_hold_new_transaction_o; // 导出 o_switch_hold_new_transaction
	assign o_mode_fault_event = flag_precision_fault_event; // 导出 o_mode_fault_event
	assign o_normal_frame_count = cnt_normal_frame_o; // 导出 o_normal_frame_count
	assign o_amb_recheck_pending = amb_recheck_pending_o; // 导出 o_amb_recheck_pending
	assign o_amb_recheck_accept = amb_recheck_accept_o; // 导出 o_amb_recheck_accept
	assign o_amb_recheck_busy = amb_recheck_busy_o; // 导出 o_amb_recheck_busy
	assign o_normal_output_inhibit = normal_output_inhibit_o; // 导出 o_normal_output_inhibit
	assign o_recheck_sequence_done = recheck_seq_done_o; // 导出周期重检整体完成事件
	assign o_recheck_sequence_failed = recheck_seq_failed_o; // 导出周期重检整体失败事件
	assign o_fir_history_full_r = fir_history_full_r_o; // 导出 o_fir_history_full_r
	assign o_fir_history_full_ir = fir_history_full_ir_o; // 导出 o_fir_history_full_ir
	assign o_fir_idle = fir_idle_o;             // 导出 o_fir_idle
	assign o_detection_fork_idle = detection_fork_idle_o; // 导出 o_detection_fork_idle
	assign o_detector_idle = detector_idle_o;   // 导出 o_detector_idle
	assign o_controller_idle = controller_idle_o; // 导出 o_controller_idle
	assign o_scheduler_idle = scheduler_idle_o; // 导出 o_scheduler_idle
	assign o_cross_pending = cross_pending_o;   // 导出 o_cross_pending
	assign o_peak_pending = peak_pending_o;     // 导出 o_peak_pending
	assign o_valley_pending = valley_pending_o; // 导出 o_valley_pending
	assign o_return_pending = return_pending_o; // 导出 o_return_pending
	assign o_baseline_valid = baseline_valid_o; // 导出 o_baseline_valid
	assign o_reacquire_active = reacquire_active_o; // 导出 o_reacquire_active
	assign o_detector_fine_window_active = detector_fine_window_active_o; // 导出 o_detector_fine_window_active
	assign o_switch_pending = switch_pending_o; // 导出 o_switch_pending
	assign o_switch_target_precision = switch_target_precision_o; // 导出 o_switch_target_precision
	assign o_slope_current_q16 = slope_current_q16_o; // 导出 o_slope_current_q16
	assign o_baseline_protocol_error_sticky = baseline_protocol_error_sticky_o; // 导出 o_baseline_protocol_error_sticky
	assign o_fine_window_timeout_sticky = fine_window_timeout_sticky_o; // 导出 o_fine_window_timeout_sticky
	assign o_reacquire_timeout_sticky = reacquire_timeout_sticky_o; // 导出 o_reacquire_timeout_sticky
	assign o_peak_valley_protocol_error_sticky = peak_valley_protocol_error_sticky_o; // 导出 o_peak_valley_protocol_error_sticky
	assign o_switch_timeout_sticky = switch_timeout_sticky_o; // 导出 o_switch_timeout_sticky
	assign o_precision_protocol_error_sticky = precision_protocol_error_sticky_o; // 导出 o_precision_protocol_error_sticky

	//Wrapper状态输出
	assign o_integration_protocol_error_sticky = integration_protocol_error_sticky_o; // 导出wrapper协议异常历史
	assign o_wrapper_fault_blocking = o_idac_fault_blocking || flag_precision_fault_blocking || flag_integration_blocking; // 汇总wrapper阻断资格
	assign o_normal_measurement_eligible = i_run_enable && i_active_config_valid && startup_search_complete_o && !o_idac_fault_blocking && !flag_precision_fault_blocking && !flag_integration_blocking; // 正式NORMAL必须在启动搜索及控制链均合法后开放
	// Wrapper idle汇总覆盖物理ADC所有权、所有缓存和精度控制流水。
	assign o_adc_chain_idle = !flag_adc_transaction_inflight && !flag_capture_valid && !flag_s1_detect_valid && !flag_calibrated_valid; // ADC到Stage1校准流水完全排空
	assign o_normal_fork_idle = !flag_measurement_branch_valid && !flag_track_branch_valid; // NORMAL两个pending均释放
	assign o_measurement_output_idle = !flag_overlap_result_valid && !flag_reconstructor_result_valid && !flag_dc_result_valid && !flag_detection_pending && !flag_measurement_pending; // 测量重构和结果fork均空闲
	assign o_datapath_empty = o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle && fir_idle_o && detection_fork_idle_o && detector_idle_o && controller_idle_o && scheduler_idle_o && !calibration_sample_valid_o && !flag_calibration_request_inflight; // 全部测量及控制事务真实排空

	//AMI故障分发器输出
	// lane 8'h01已接第6.5b节受保护身份注入的接纳沿；8'h02/8'h03按合同6.11节cause命名与15.2节
	// 判据文字比对flag_integration_blocking现有5个协议子条件后拆分：凡破坏请求/响应唯一对应
	// 关系的协议错误归8'h02，唯一"无法证明可用原owner执行失败释放"语义的completion身份错配
	// 归8'h03；两路identity均复用物理ADC owner快照，无owner时identity_valid强制为0。
	assign o_ami_fault_active = flag_test_identity_hold || flag_owner_protocol_fault_hold || flag_recovery_context_fault_hold || flag_precision_fault_active || flag_idac_fault_active; // 五路lane-active按位或，分别镜像各自保持电平
	// 分发槽位每拍最多命中一路，01固定优先，其锁存的身份字段直接来自对应子模块或本地owner快照的当前保持输出。
	assign o_ami_fault_valid = flag_ami_fault_dispatch_01 || flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03 || flag_ami_fault_dispatch_04 || flag_ami_fault_dispatch_05; // 本拍恰好命中一路时才产生记录脉冲
	assign o_ami_fault_cause = flag_ami_fault_dispatch_01 ? 8'h01 : (flag_ami_fault_dispatch_02 ? 8'h02 : (flag_ami_fault_dispatch_03 ? 8'h03 : (flag_ami_fault_dispatch_04 ? 8'h04 : (flag_ami_fault_dispatch_05 ? 8'h05 : 8'h00)))); // 未分发时保持全零，不得被下游误读为有效原因；5车道分发器,8'h04=精度链终点,8'h05=IDAC链终点 @satisfies: K01
	assign o_ami_fault_identity_valid = flag_ami_fault_dispatch_01 ? 1'b1 : (flag_ami_fault_dispatch_02 ? flag_adc_transaction_inflight : (flag_ami_fault_dispatch_03 ? flag_adc_transaction_inflight : (flag_ami_fault_dispatch_04 ? flag_precision_fault_identity_valid : (flag_ami_fault_dispatch_05 ? flag_idac_fault_identity_valid : 1'b0)))); // 01接纳条件恒为可信身份；02/03借用物理ADC owner的当前所有权状态
	assign o_ami_fault_frame_id = flag_ami_fault_dispatch_01 ? reg_adc_inflight_frame_id : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? (flag_adc_transaction_inflight ? reg_adc_inflight_frame_id : {C_FRAME_ID_WIDTH{1'b0}}) : (flag_ami_fault_dispatch_04 ? flag_precision_fault_frame_id : (flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_id : {C_FRAME_ID_WIDTH{1'b0}}))); // 选中路的真实物理帧号，02/03无owner时强制清零
	assign o_ami_fault_sample_index = flag_ami_fault_dispatch_01 ? reg_adc_inflight_sample_index : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? (flag_adc_transaction_inflight ? reg_adc_inflight_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}}) : (flag_ami_fault_dispatch_04 ? flag_precision_fault_sample_index : (flag_ami_fault_dispatch_05 ? flag_idac_fault_sample_index : {C_SAMPLE_INDEX_WIDTH{1'b0}}))); // 选中路的全局事务顺序编号，02/03无owner时强制清零
	assign o_ami_fault_color_ir = flag_ami_fault_dispatch_01 ? reg_adc_inflight_color_ir : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? (flag_adc_transaction_inflight && reg_adc_inflight_color_ir) : (flag_ami_fault_dispatch_04 ? flag_precision_fault_color_ir : (flag_ami_fault_dispatch_05 ? flag_idac_fault_color_ir : 1'b0))); // 选中路绑定事务的颜色身份，02/03与所有权状态共享同一AND门
	assign o_ami_fault_frame_type = flag_ami_fault_dispatch_01 ? reg_adc_inflight_frame_type : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? (flag_adc_transaction_inflight ? reg_adc_inflight_frame_type : 2'b00) : (flag_ami_fault_dispatch_04 ? flag_precision_fault_frame_type : (flag_ami_fault_dispatch_05 ? flag_idac_fault_frame_type : 2'b00))); // 选中路绑定事务的帧类型编码，02/03无owner时强制清零
	assign o_ami_fault_precision = flag_ami_fault_dispatch_01 ? reg_adc_inflight_precision_mode : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? (flag_adc_transaction_inflight && reg_adc_inflight_precision_mode) : (flag_ami_fault_dispatch_04 ? flag_precision_fault_precision : (flag_ami_fault_dispatch_05 ? flag_idac_fault_precision : 1'b0))); // 选中路绑定事务建立时所属的精度模式，02/03与所有权状态共享同一AND门
	assign o_ami_fault_run_generation = flag_ami_fault_dispatch_01 ? i_run_generation : ((flag_ami_fault_dispatch_02 || flag_ami_fault_dispatch_03) ? i_run_generation : (flag_ami_fault_dispatch_04 ? flag_precision_fault_run_generation : (flag_ami_fault_dispatch_05 ? flag_idac_fault_run_generation : {C_RUN_GENERATION_WIDTH{1'b0}}))); // 选中路绑定事务所属的RUN代际，02/03取本地实时代际

	//检测代际清空公开观测输出
	// 直接镜像已经喂给PWI私有输入的同一批信号，公开端口与私有广播逐拍同值，不引入额外延迟。
	assign o_detection_discard_event = flag_detection_discard_trigger; // 合同6.10节公开端口，与PWI私有输入严格同拍
	assign o_detection_discard_reason = flag_terminal_discard_reason; // 桥接私有原因编码到公开端口
	assign o_detection_discard_identity_valid = flag_detection_discard_identity_valid; // 桥接私有身份可信位到公开端口
	assign o_detection_discard_sample_valid = flag_detection_discard_sample_valid; // 桥接私有样本资格位到公开端口
	assign o_detection_discard_frame_id = flag_detection_discard_frame_id; // 桥接私有帧号线到公开端口
	assign o_detection_discard_sample_index = flag_detection_discard_sample_index; // 桥接私有序号线到公开端口
	assign o_detection_discard_color_ir = flag_detection_discard_color_ir; // 桥接私有颜色线到公开端口
	assign o_detection_discard_frame_type = flag_detection_discard_frame_type; // 桥接私有类型线到公开端口
	assign o_detection_discard_precision = flag_detection_discard_precision; // 桥接私有精度线到公开端口
	assign o_detection_discard_config_epoch = flag_detection_discard_config_epoch; // 桥接私有ACTIVE版本线到公开端口
	assign o_detection_discard_coef_epoch = flag_detection_discard_coef_epoch; // 桥接私有系数版本线到公开端口
	assign o_detection_discard_dc_recovery_epoch = flag_detection_discard_dc_recovery_epoch; // 桥接私有DC恢复版本线到公开端口
	assign o_detection_discard_amb_code_epoch = flag_detection_discard_amb_code_epoch; // 桥接私有环境光抵消码版本线到公开端口
	assign o_detection_discard_dc_code_epoch = flag_detection_discard_dc_code_epoch; // 桥接私有颜色DC码版本线到公开端口
	assign o_detection_discard_run_generation = i_run_generation; // 触发广播目标的RUN代际，与实时广播值相同

	//-------------输出信号处理区域-------------//
	//Wrapper状态输出
	// 非法类型、载荷漂移和请求冲突形成sticky，严重校准错配同时锁存阻断状态。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			integration_protocol_error_sticky_o <= 1'b0; // 复位清除集成协议历史
		end else if(i_start_ack_event == 1'b1 || i_diag_clear_event == 1'b1)begin
			integration_protocol_error_sticky_o <= 1'b0; // 新RUN或软件命令冻结清除历史
		end else if(flag_router_frame_type_error == 1'b1 || flag_start_payload_changed == 1'b1 || flag_start_context_mismatch == 1'b1 || flag_calibration_result_mismatch == 1'b1 || flag_late_normal_result == 1'b1 || flag_adc_capture_without_owner == 1'b1 || flag_test_identity_inject_fire == 1'b1 || (flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1) || (i_transaction_start_valid == 1'b1 && (i_transaction_frame_type == 2'b11)))begin
			integration_protocol_error_sticky_o <= 1'b1; // 任一明确协议异常锁存sticky
		end
	end

	// 完成脉冲由S1归属确认点产生，禁止以ADC idle、SAR相位或固定时延替代。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			adc_transaction_complete_event_o <= 1'b0; // 复位期间不产生伪造完成事件
		end else if(i_start_ack_event == 1'b1)begin
			adc_transaction_complete_event_o <= 1'b0; // 新RUN禁止补发前一生命周期的完成脉冲
		end else if(flag_adc_completion_emit == 1'b1)begin
			adc_transaction_complete_event_o <= 1'b1; // 已同步RAW与S1元数据共同确认当前事务完成；owner只由CLK_DOUT同步+RAW捕获+sample_index匹配后释放 @satisfies: TOP-16
		end else begin
			adc_transaction_complete_event_o <= 1'b0; // 完成旁带严格保持一个2 MHz时钟周期
		end
	end

	// 成功资格仅在完成脉冲同拍锁存，abort或S1身份不一致均通知消费者释放但禁止计为成功。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			adc_transaction_success_o <= 1'b0;  // 复位默认所有完成结果均无资格
		end else if(i_start_ack_event == 1'b1)begin
			adc_transaction_success_o <= 1'b0;  // 新RUN不保留前一完成通知的成功状态
		end else if(flag_adc_completion_emit == 1'b1)begin
			adc_transaction_success_o <= flag_adc_completion_success; // 逐位身份核对和abort状态决定本笔可处理资格
		end else begin
			adc_transaction_success_o <= 1'b0;  // 脉冲以外的周期明确报告无完成成功资格
		end
	end

	// 完成载荷在发布沿复制独立快照，允许下一笔事务同拍启动而不会覆盖当前完成索引。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			adc_complete_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位清除无效完成载荷
		end else if(i_start_ack_event == 1'b1)begin
			adc_complete_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 新RUN清除不可消费的旧完成索引
		end else if(flag_adc_completion_emit == 1'b1)begin
			adc_complete_sample_index_o <= reg_adc_inflight_sample_index; // 原子发布与capture对应的启动序号快照；exactly-once原identity success=0释放,LFA-04/LFA-02a/OIB-08实测确认 @satisfies: P14, LFA-04, OIB-08
		end
	end

	// 独立样本资格随结果fork原子锁存；invalid只禁止算法历史，不改写数值或身份。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_sample_valid_o <= 1'b0;      // 复位时不存在可消费的样本资格
		end else if(flag_result_abort_discard == 1'b1)begin
			result_sample_valid_o <= 1'b0;      // abort或阻断排空立即撤销未消费资格
		end else if(flag_dc_result_transfer == 1'b1)begin
			result_sample_valid_o <= !flag_test_invalid_sample_fire; // 注入invalid仅改变本笔算法资格
		end else if(flag_measurement_transfer == 1'b1)begin
			result_sample_valid_o <= 1'b0;      // 正式测量分支消费后清除旧样本资格
		end
	end

	// 正式结果生命周期丢弃单拍事件，合同6.10节公开端口；捕获仍在途结果被丢弃汇点释放而非真实消费的那一拍。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_event_o <= 1'b0; // 复位不产生伪造正式结果丢弃事件
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_event_o <= 1'b0; // 新RUN不得补发前一生命周期的正式结果丢弃事件
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_event_o <= 1'b1; // 已同步在途正式结果与丢弃汇点确认本笔丢弃
		end else begin
			measurement_result_discard_event_o <= 1'b0; // 脉冲以外的周期明确报告无正式结果丢弃事件
		end
	end

	// 正式结果丢弃归类快照，与丢弃事件同拍锁存，事件为低期间保持上一次归类。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_reason_o <= 2'b00; // 复位归零丢弃归类编码
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_reason_o <= 2'b00; // 新RUN不继承旧丢弃归类
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_reason_o <= flag_measurement_result_discard_reason; // 锁存丢弃汇点当前命中的STOP/abort/系统故障归类
		end
	end

	// 正式结果丢弃身份可信位，事件为高时恒为1，供TXN_ID字段判读用。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_identity_valid_o <= 1'b0; // 复位默认丢弃身份不可信
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_identity_valid_o <= 1'b0; // 新RUN不继承旧丢弃身份
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_identity_valid_o <= 1'b1; // 触发沿本身要求真实在途正式结果存在，恒为可信身份
		end
	end

	// 被丢弃正式结果的独立样本资格快照，取自丢弃前一拍的result_sample_valid_o。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_sample_valid_o <= 1'b0; // 复位清除样本资格快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_sample_valid_o <= 1'b0; // 新RUN不继承旧样本资格快照
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_sample_valid_o <= result_sample_valid_o; // 锁存丢弃前一拍的独立样本资格
		end
	end

	// 被丢弃正式结果绑定事务的真实物理帧号，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除丢弃帧号快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 新RUN清除不可消费的旧丢弃帧号
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_frame_id_o <= dec_measurement_frame_id; // 锁存被丢弃事务的真实物理帧号
		end
	end

	// 被丢弃正式结果绑定事务的全局顺序编号，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位清除丢弃序号快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 新RUN清除不可消费的旧丢弃序号
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_sample_index_o <= dec_measurement_sample_index; // 锁存被丢弃事务的全局顺序编号
		end
	end

	// 被丢弃正式结果绑定事务的颜色身份，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_color_ir_o <= 1'b0; // 复位清除丢弃颜色快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_color_ir_o <= 1'b0; // 新RUN清除不可消费的旧丢弃颜色
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_color_ir_o <= flag_measurement_color_ir; // 锁存被丢弃事务的颜色身份，与frame_type/sample_index一起构成discard记录的branch ID字段 @satisfies: P01
		end
	end

	// 被丢弃正式结果绑定事务的帧类型编码，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_frame_type_o <= 2'b00; // 复位清除丢弃类型快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_frame_type_o <= 2'b00; // 新RUN清除不可消费的旧丢弃类型
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_frame_type_o <= dec_measurement_frame_type; // 锁存被丢弃事务的帧类型编码
		end
	end

	// 被丢弃正式结果绑定事务建立时所属的精度模式，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_precision_o <= 1'b0; // 复位清除丢弃精度快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_precision_o <= 1'b0; // 新RUN清除不可消费的旧丢弃精度
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_precision_o <= flag_measurement_precision_mode; // 锁存被丢弃事务建立时所属的精度模式
		end
	end

	// 被丢弃正式结果绑定事务所属的RUN代际，取自NORMAL fork测量分支快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_result_discard_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位清除丢弃代际快照
		end else if(i_start_ack_event == 1'b1)begin
			measurement_result_discard_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 新RUN清除不可消费的旧丢弃代际
		end else if(flag_measurement_result_discard_fire == 1'b1)begin
			measurement_result_discard_run_generation_o <= dec_fork_measurement_run_generation; // 锁存被丢弃事务所属的RUN代际
		end
	end

	//校准请求接口
	// 校准仲裁寄存器优先接纳周期重检，再接纳IDAC启动搜索请求。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_sample_valid_o <= 1'b0; // 复位撤销未提交校准请求
		end else if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || flag_integration_blocking == 1'b1)begin
			calibration_sample_valid_o <= 1'b0; // 生命周期阻断撤销尚未接受请求
		end else if(calibration_request_fire_o == 1'b1)begin
			calibration_sample_valid_o <= 1'b0; // 调度器接受后转交在途所有权
		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
			if(flag_recheck_request_source == 1'b1)begin
				calibration_sample_valid_o <= 1'b1; // 周期重检请求具有更高仲裁优先级
			end else if(flag_startup_request_source == 1'b1)begin
				calibration_sample_valid_o <= 1'b1; // 启动搜索空闲时建立请求所有权
			end
		end
	end

	// 锁存校准请求的帧类型并在外部反压期间保持不变。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_color_ir_o <= 1'b0;     // 复位颜色固定为红光
		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
			if(flag_recheck_request_source == 1'b1)begin
				calibration_color_ir_o <= flag_precision_calibration_color_ir; // 锁存周期重检颜色
			end else if(flag_startup_request_source == 1'b1)begin
				calibration_color_ir_o <= flag_startup_request_color_ir; // 锁存启动搜索颜色
			end
		end
	end

	// 锁存校准请求来源以区分启动搜索与周期重检。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_frame_type_o <= FRAME_TYPE_AMB; // 复位使用安全AMB诊断值
		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
			if(flag_recheck_request_source == 1'b1)begin
				calibration_frame_type_o <= dec_precision_calibration_frame_type; // 锁存周期重检类型
			end else if(flag_startup_request_source == 1'b1)begin
				calibration_frame_type_o <= flag_startup_request_frame_type; // 锁存启动搜索类型
			end
		end
	end

	// 校准请求载荷只在新所有权建立时锁存，反压期间保持逐位稳定。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_request_reason_o <= REASON_STARTUP; // 复位来源固定启动搜索
		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
			if(flag_recheck_request_source == 1'b1)begin
				calibration_request_reason_o <= REASON_RECHECK; // 标记周期重检来源
			end else if(flag_startup_request_source == 1'b1)begin
				calibration_request_reason_o <= REASON_STARTUP; // 标记启动搜索来源
			end
		end
	end

	//-------------主要任务处理区域-------------//
	//===================<主要任务处理区域>===================//
	// supervisor单周期脉冲锁存丢弃原因，直到本代际全部终端槽真实排空才清除，新代际不得继承。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_system_fault_discard_pending <= 1'b0; // 复位清除锁存，不产生事件
		end else if(i_system_fault_discard_event == 1'b1)begin
			flag_system_fault_discard_pending <= 1'b1; // supervisor到达时置位并保持原因
		end else if(o_datapath_empty == 1'b1)begin
			flag_system_fault_discard_pending <= 1'b0; // 已证明全部数字数据与控制事务排空，episode结束
		end
	end

	// cause 8'h01待分发标记，受保护测试身份注入被唯一owner接纳时置位，本拍出槽后清除。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ami_fault_pending_01 <= 1'b0;  // 复位清除待分发标记
		end else if(flag_test_identity_inject_fire == 1'b1)begin
			flag_ami_fault_pending_01 <= 1'b1;  // 错误sample_index请求进入production matcher前的接纳沿
		end else if(flag_ami_fault_dispatch_01 == 1'b1)begin
			flag_ami_fault_pending_01 <= 1'b0;  // 本拍已经占用分发槽位，清除待分发标记
		end
	end

	// cause 8'h02待分发标记，校准结果错配、无owner的RAW交接、校准start类型不匹配或启动/重检请求冲突任一到达时置位，本拍出槽后清除。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ami_fault_pending_02 <= 1'b0;  // 复位归零8'h02待分发标记，不残留跨代际协议错误
		end else if(flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
			flag_ami_fault_pending_02 <= 1'b1;  // 四类请求/响应对应关系被破坏的协议错误共用同一lane
		end else if(flag_ami_fault_dispatch_02 == 1'b1)begin
			flag_ami_fault_pending_02 <= 1'b0;  // 占槽发布本拍cause 8'h02记录后清除待分发标记
		end
	end

	// cause 8'h03待分发标记，completion到达但身份与当前owner不匹配、无法证明可用原owner执行失败释放时置位，本拍出槽后清除。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ami_fault_pending_03 <= 1'b0;  // 复位归零8'h03待分发标记，不残留跨代际恢复错配
		end else if(flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0)begin
			flag_ami_fault_pending_03 <= 1'b1;  // 完成旁带与当前owner逐位身份核对失败
		end else if(flag_ami_fault_dispatch_03 == 1'b1)begin
			flag_ami_fault_pending_03 <= 1'b0;  // 无法证明恢复上下文的记录本拍已出槽，撤销待分发标记
		end
	end

	// cause 8'h04待分发标记，精度控制新episode到达时置位，本拍出槽后清除。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ami_fault_pending_04 <= 1'b0;  // 复位撤销尚未分发的历史标记
		end else if(flag_precision_fault_event == 1'b1)begin
			flag_ami_fault_pending_04 <= 1'b1;  // PWI精度阻断故障新episode到达
		end else if(flag_ami_fault_dispatch_04 == 1'b1)begin
			flag_ami_fault_pending_04 <= 1'b0;  // 分发完成，让出这一拍的唯一分发槽位
		end
	end

	// cause 8'h05待分发标记，IDAC控制器新episode到达时置位，仅在04不占槽位时才能出槽。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_ami_fault_pending_05 <= 1'b0;  // 复位同步清除该lane的待分发标记
		end else if(flag_idac_fault_event == 1'b1)begin
			flag_ami_fault_pending_05 <= 1'b1;  // IDAC控制器阻断故障新episode到达
		end else if(flag_ami_fault_dispatch_05 == 1'b1)begin
			flag_ami_fault_pending_05 <= 1'b0;  // 本拍轮到该lane出槽，随即清除待分发标记
		end
	end

	// 检测代际清空episode锁存，确保同一代际内每次终端动作只广播一次，直到PWI真实报告排空才允许下一次。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_detection_discard_episode_active <= 1'b0; // 复位清除episode锁存
		end else if(flag_detection_discard_trigger == 1'b1)begin
			flag_detection_discard_episode_active <= 1'b1; // 本拍新广播一次，抑制同代际重复触发
		end else if(flag_pwi_detection_datapath_empty == 1'b1)begin
			flag_detection_discard_episode_active <= 1'b0; // PWI真实报告检测链排空，允许下一次新episode
		end
	end

	// 启动沿冻结唯一的sample_index，完成旁带绝不读取可能被下一笔事务改写的实时输入载荷。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位删除未归属ADC事务的历史索引
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_sample_index <= i_transaction_sample_index; // 唯一启动沿原子冻结当前物理转换的序号；owner身份绑定,LFA-04/LFA-02a/LFA-02b/OIB-08三终止路径实测确认 @satisfies: P08, LFA-04, OIB-08
		end
	end

	// ADC结果owner在正式fire沿锁存精度，迟到DONE不得改用实时精度解释。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_precision_mode <= 1'b0; // 复位默认保存SAR9身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_precision_mode <= i_transaction_precision_mode; // 锁存本笔物理转换的精度身份
		end
	end

	// ADC结果owner在正式fire沿锁存物理帧号，S1返回后必须逐位核验。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位删除无效帧号身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_frame_id <= i_transaction_frame_id; // 锁存本笔ADC结果所属物理帧号
		end
	end

	// ADC结果owner在正式fire沿锁存颜色，防止返回结果跨颜色误归属。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_color_ir <= 1'b0;  // 复位颜色身份回到红光诊断值
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_color_ir <= i_transaction_color_ir; // 锁存当前红光或红外结果身份
		end
	end

	// ADC结果owner在正式fire沿锁存事务类型，防止校准和NORMAL结果交叉解释。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_frame_type <= FRAME_TYPE_AMB; // 复位类型采用安全AMB诊断值
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_frame_type <= i_transaction_frame_type; // 锁存本笔AMB、DCS或NORMAL类型
		end
	end

	// ADC结果owner在正式fire沿锁存AMB积分码，完成后禁止读取当前committed码补写。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 复位清除AMB积分码身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_amb_code <= i_transaction_amb_code_snapshot; // 锁存实际参与积分的AMB码
		end
	end

	// ADC结果owner在正式fire沿锁存颜色DC积分码，完成后禁止被慢速调码覆盖。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 复位清除颜色DC积分码身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_dc_code <= i_transaction_dc_code_snapshot; // 锁存实际参与积分的颜色DC码
		end
	end

	// ADC结果owner在正式fire沿锁存AMB码epoch，完成后必须与S1上下文逐位匹配。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 复位清除AMB版本身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_amb_epoch <= i_transaction_amb_code_epoch; // 锁存实际AMB码对应的提交版本
		end
	end

	// 颜色DC版本在owner commit时固定，避免同色调码后使迟到DONE误配新epoch。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adc_inflight_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 复位清除颜色DC版本身份
		end else if(o_transaction_start_fire == 1'b1)begin
			reg_adc_inflight_dc_epoch <= i_transaction_dc_code_epoch; // 锁存实际颜色DC码对应的提交版本
		end
	end

	// 错配身份只锁存一次并保留原始真实完成；abort或复位后该测试上下文完全失效，enable拉低不在清零条件之列；SID-10 TB直接轮询本sticky确认校准错配注入真实fire。 @satisfies: P06, SID-10
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_test_identity_hold <= 1'b0;    // 复位立即失效测试错配上下文
		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
			flag_test_identity_hold <= 1'b0;    // 新RUN或受控abort不得保留旧测试身份
		end else if(flag_test_identity_inject_fire == 1'b1)begin
			flag_test_identity_hold <= 1'b1;    // 错配进入原matcher后保留真实完成等待恢复
		end
	end

	// cause 8'h02 active电平；触发条件与flag_integration_blocking的协议子集共享同一来源，保持到本RUN结束。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_owner_protocol_fault_hold <= 1'b0; // 复位立即失效协议错误保持状态
		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
			flag_owner_protocol_fault_hold <= 1'b0; // 新RUN或受控abort结束当前RUN上下文
		end else if(flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
			flag_owner_protocol_fault_hold <= 1'b1; // 四类协议错误任一到达即置位并保持
		end
	end

	// cause 8'h03 active电平；触发条件为completion身份与owner错配，保持到本RUN结束。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_recovery_context_fault_hold <= 1'b0; // 复位立即失效恢复上下文保持状态
		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
			flag_recovery_context_fault_hold <= 1'b0; // 新RUN重建协议上下文或受控abort清空未决恢复判定
		end else if(flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0)begin
			flag_recovery_context_fault_hold <= 1'b1; // 无法证明可用原owner执行失败释放
		end
	end

	// capture与S1的真实交接先建立完成待发布状态，随后等待S1锁存并导出完整元数据。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_adc_completion_pending <= 1'b0; // 复位后没有待核验的ADC完成旁带
		end else if(flag_adc_completion_emit == 1'b1)begin
			flag_adc_completion_pending <= 1'b0; // 元数据确认后只允许发布一次完成旁带
		end else if(flag_adc_capture_transfer == 1'b1 && flag_adc_transaction_inflight == 1'b1)begin
			flag_adc_completion_pending <= 1'b1; // 当前在途RAW已交给S1，等待稳定事务身份
		end
	end

	// 唯一ADC结果owner从start fire保持到真实完成旁带发布，RAW进入S1不能提前释放物理owner。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_adc_transaction_inflight <= 1'b0; // 复位后不存在ADC在途事务
		end else if(o_transaction_start_fire == 1'b1)begin
			flag_adc_transaction_inflight <= 1'b1; // 唯一fire建立本笔事务所有权
		end else if(flag_adc_completion_emit == 1'b1)begin
			flag_adc_transaction_inflight <= 1'b0; // 成功或失败完成旁带发布后才释放物理ADC owner
		end
	end

	// abort资格与物理ADC事务绑定，不能因通用排空状态提前清除而将迟到RAW标为成功。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_adc_transaction_abort <= 1'b0; // 复位后没有需降级的ADC事务
		end else if(o_transaction_start_fire == 1'b1 || flag_adc_completion_emit == 1'b1)begin
			flag_adc_transaction_abort <= 1'b0; // 新事务建立或旧事务发布完成后释放专属abort资格
		end else if(i_control_abort_event == 1'b1 && (flag_adc_transaction_inflight == 1'b1 || flag_adc_completion_pending == 1'b1))begin
			flag_adc_transaction_abort <= 1'b1; // 已启动或已捕获但未归属的事务必须以失败完成通知下游
		end
	end

	// 启动valid第一次受反压时保存载荷，后续逐拍检查保持型协议稳定性。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_held_start_valid <= 1'b0;      // 复位没有受反压启动事务
		end else if(i_transaction_start_valid == 1'b0 || o_transaction_start_fire == 1'b1)begin
			flag_held_start_valid <= 1'b0;      // valid撤销或握手后结束稳定性观察
		end else if(o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			flag_held_start_valid <= 1'b1;      // 第一次阻塞时建立载荷快照
		end
	end

	// 保存受阻启动事务携带的AMB码版本。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 复位清除AMB码快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_amb_code <= i_transaction_amb_code_snapshot; // 保存首次受阻AMB码
		end
	end

	// 保存受阻启动事务携带的红光或红外颜色选择。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 复位清除AMB版本
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_amb_epoch <= i_transaction_amb_code_epoch; // 保存首次受阻AMB版本
		end
	end

	// 保存受阻启动事务携带的颜色DC码快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_color_ir <= 1'b0;    // 复位清除颜色快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_color_ir <= i_transaction_color_ir; // 保存首次受阻颜色
		end
	end

	// 保存受阻启动事务携带的颜色DC码版本。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}}; // 更新 reg_held_start_dc_code
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_dc_code <= i_transaction_dc_code_snapshot; // 更新 reg_held_start_dc_code
		end
	end

	// 保存受阻启动事务的真实400 Hz物理帧号。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}}; // 更新 reg_held_start_dc_epoch
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_dc_epoch <= i_transaction_dc_code_epoch; // 更新 reg_held_start_dc_epoch
		end
	end

	// 保存受阻启动事务的NORMAL或校准帧类型。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除帧号快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_frame_id <= i_transaction_frame_id; // 保存首次受阻帧号
		end
	end

	// 保存受阻启动事务申请的SAR9或SAR15精度。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_frame_type <= 2'b00; // 复位清除类型快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_frame_type <= i_transaction_frame_type; // 保存首次受阻事务类型
		end
	end

	// 保存受阻启动事务的全局样本序号。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_precision <= 1'b0;   // 复位清除精度快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_precision <= i_transaction_precision_mode; // 保存首次受阻精度
		end
	end

	// 受反压启动载荷的全部字段在同一观察沿原子保存。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_held_start_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位清除序号快照
		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
			reg_held_start_sample_index <= i_transaction_sample_index; // 保存首次受阻序号
		end
	end

	// 只有会破坏请求与结果唯一对应关系的错误升级为当前RUN阻断故障。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_integration_blocking <= 1'b0;  // 复位解除集成阻断状态
		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
			flag_integration_blocking <= 1'b0;  // 新RUN或明确abort重新建立协议上下文
		end else if(flag_test_identity_inject_fire == 1'b1 || flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0) || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
			flag_integration_blocking <= 1'b1;  // 请求冲突或结果错配禁止后续事务
		end
	end

	// DC恢复双消费者载荷槽支持两分支同沿释放并装入下一事务。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_result_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}}; // 复位清除无资格历史载荷
		end else if(i_start_ack_event == 1'b1 || (i_control_abort_event == 1'b1 && o_measurement_output_idle == 1'b1))begin
			reg_result_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}}; // 安全生命周期边界清理载荷内容
		end else if(flag_dc_result_transfer == 1'b1)begin
			reg_result_fork_payload <= enc_dc_result_payload; // 原子装入下一完整恢复事务；OIB-07要求的frame/sample/color/type/precision/AMB与DC快照/各epoch身份，均在此单一原子commit时刻一次性锁存，958行按固定字段顺序逐位展开为o_result_*导出端口；同一原子寄存器保证反压期间全部数值/资格/诊断/身份位联动保持，直到下一次真实valid&&ready才会整体替换 @satisfies: OIB-07, ADCN-07, ADCN-08
		end
	end

	// 检测分支pending只由其独立消费释放，新事务同沿到达时重新取得所有权。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_detection_pending <= 1'b0;     // 复位后检测分支无所有权
		end else if(flag_result_abort_discard == 1'b1)begin
			flag_detection_pending <= 1'b0;     // abort丢弃汇点立即释放检测分支
		end else if(flag_dc_result_transfer == 1'b1 && normal_output_inhibit_o == 1'b0)begin
			flag_detection_pending <= 1'b1;     // 每笔恢复事务必须由检测链消费一次
		end else if(flag_detection_transfer == 1'b1)begin
			flag_detection_pending <= 1'b0;     // 检测链握手后释放当前事务
		end
	end

	// 正式测量pending与检测分支独立，单侧反压不会覆盖另一侧所有权。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_measurement_pending <= 1'b0;   // 复位后正式分支无所有权
		end else if(flag_result_abort_discard == 1'b1)begin
			flag_measurement_pending <= 1'b0;   // abort禁止产生迟到正式输出
		end else if(flag_dc_result_transfer == 1'b1 && normal_output_inhibit_o == 1'b0)begin
			flag_measurement_pending <= 1'b1;   // 每笔恢复事务必须由正式输出消费一次
		end else if(flag_measurement_transfer == 1'b1)begin
			flag_measurement_pending <= 1'b0;   // 片外FIFO握手后释放当前事务
		end
	end

	// abort保持排空状态直到全部既有流水真实回到空闲。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_abort_draining <= 1'b0;        // 复位不处于abort排空
		end else if(i_start_ack_event == 1'b1)begin
			flag_abort_draining <= 1'b0;        // 新RUN清除旧abort上下文
		end else if(i_control_abort_event == 1'b1)begin
			flag_abort_draining <= 1'b1;        // abort后所有迟到数据转入丢弃汇点
		end else if(o_adc_chain_idle == 1'b1 && o_normal_fork_idle == 1'b1 && o_measurement_output_idle == 1'b1)begin
			flag_abort_draining <= 1'b0;        // 数据流水排空后结束受控丢弃阶段
		end
	end

	// 调度器握手后保持在途请求，直到匹配校准结果被IDAC真实消费。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_calibration_request_inflight <= 1'b0; // 复位不存在校准结果期待
		end else if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || flag_integration_blocking == 1'b1)begin
			flag_calibration_request_inflight <= 1'b0; // 阻断边界撤销未启动请求上下文
		end else if(flag_amb_sample_accepted == 1'b1 || flag_dcs_sample_accepted == 1'b1 || i_cal_owner_deadline_event == 1'b1)begin
			flag_calibration_request_inflight <= 1'b0; // 匹配结果消费后，或在途请求被owner截止抑制后，均允许下一请求；SID-05 修复此前deadline抑制后永久卡住不重试的真实死锁 @satisfies: SID-05
		end else if(calibration_request_fire_o == 1'b1)begin
			flag_calibration_request_inflight <= 1'b1; // 保存调度器已经取得的请求所有权
		end
	end

	// 保存已接受校准请求的帧类型用于结果归属检查。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_inflight_color_ir <= 1'b0;      // 复位期待颜色为红光
		end else if(calibration_request_fire_o == 1'b1)begin
			reg_inflight_color_ir <= calibration_color_ir_o; // 保存接受请求颜色
		end
	end

	// 保存已接受校准请求的来源用于关闭对应所有权。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_inflight_frame_type <= FRAME_TYPE_AMB; // 复位期待类型为安全值
		end else if(calibration_request_fire_o == 1'b1)begin
			reg_inflight_frame_type <= calibration_frame_type_o; // 保存接受请求类型
		end
	end

	// 在途请求类型、颜色和来源与结果匹配检查使用同一握手沿原子快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_inflight_reason <= REASON_STARTUP; // 复位期待来源为启动搜索
		end else if(calibration_request_fire_o == 1'b1)begin
			reg_inflight_reason <= calibration_request_reason_o; // 保存接受请求来源
		end
	end

	// STOP到达时无条件标记所有尚未完成的owner为丢弃，并保持丢弃窗口直到下一次START；
	// 不区分STOP那一拍物理ADC owner是否恰好在途——合同13节冻结的迟到DONE规则第1条
	// 要求STOP接受时全部尚未完成owner都立即标记丢弃，owner在途时同样适用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_stop_result_draining <= 1'b0;  // 复位清除STOP结果排空状态
		end else if(i_start_ack_event == 1'b1)begin
			flag_stop_result_draining <= 1'b0;  // 新START边界清除旧STOP上下文
		end else if(i_stop_ack_event == 1'b1)begin
			flag_stop_result_draining <= 1'b1;  // STOP立即标记丢弃，不论此刻是否已有owner在途
		end
	end

	//--------------模块实例化区域--------------//
	// Stage1可编程校准器以ACTIVE逐物理位权重生成正式signed残差。
	ppg_adc_s1_programmable_calibrator #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH

	// Stage1校准单元接收固定重构事务并导出校准残差。
	)ppg_adc_s1_programmable_calibrator_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_active_valid(i_active_config_valid), // 输入 i_active_valid 用 i_active_config_valid
		.i_stage1_calibration_valid(i_stage1_calibration_valid), // 输入 i_stage1_calibration_valid 用 i_stage1_calibration_valid
		.i_config_epoch(i_config_epoch),        // 输入 i_config_epoch 用 i_config_epoch
		.i_coef_epoch(i_stage1_coef_epoch),     // 输入 i_coef_epoch 用 i_stage1_coef_epoch
		.i_stage1_weight_q16_0(i_stage1_weight_q16_0), // 输入 i_stage1_weight_q16_0 用 i_stage1_weight_q16_0
		.i_stage1_weight_q16_1(i_stage1_weight_q16_1), // 输入 i_stage1_weight_q16_1 用 i_stage1_weight_q16_1
		.i_stage1_weight_q16_2(i_stage1_weight_q16_2), // 输入 i_stage1_weight_q16_2 用 i_stage1_weight_q16_2
		.i_stage1_weight_q16_3(i_stage1_weight_q16_3), // 输入 i_stage1_weight_q16_3 用 i_stage1_weight_q16_3
		.i_stage1_weight_q16_4(i_stage1_weight_q16_4), // 输入 i_stage1_weight_q16_4 用 i_stage1_weight_q16_4
		.i_stage1_weight_q16_5(i_stage1_weight_q16_5), // 输入 i_stage1_weight_q16_5 用 i_stage1_weight_q16_5
		.i_stage1_weight_q16_6(i_stage1_weight_q16_6), // 输入 i_stage1_weight_q16_6 用 i_stage1_weight_q16_6
		.i_stage1_weight_q16_7(i_stage1_weight_q16_7), // 输入 i_stage1_weight_q16_7 用 i_stage1_weight_q16_7
		.i_stage1_weight_q16_8(i_stage1_weight_q16_8), // 输入 i_stage1_weight_q16_8 用 i_stage1_weight_q16_8
		.i_stage1_weight_q16_9(i_stage1_weight_q16_9), // 输入 i_stage1_weight_q16_9 用 i_stage1_weight_q16_9
		.i_stage1_offset_q16(i_stage1_offset_q16), // 输入 i_stage1_offset_q16 用 i_stage1_offset_q16
		.i_result_valid(flag_s1_detect_valid && !flag_result_abort_discard && !flag_test_identity_inject_fire && !flag_test_identity_hold), // 测试错配保留真实上下文，禁止进入下游数据链
		.i_stage1_raw(dec_s1_stage1_raw),       // 输入 i_stage1_raw 用 dec_s1_stage1_raw
		.i_detect_code(dec_s1_detect_code),     // 输入 i_detect_code 用 dec_s1_detect_code
		.i_stage1_code_ext(dec_s1_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_s1_stage1_code_ext
		.i_stage2_raw(dec_s1_stage2_raw),       // 输入 i_stage2_raw 用 dec_s1_stage2_raw
		.i_precision_mode(flag_s1_precision_mode), // 输入 i_precision_mode 用 flag_s1_precision_mode
		.i_frame_id(dec_s1_frame_id),           // 输入 i_frame_id 用 dec_s1_frame_id
		.i_sample_index(dec_s1_sample_index),   // 输入 i_sample_index 用 dec_s1_sample_index
		.i_color_ir(flag_s1_color_ir),          // 输入 i_color_ir 用 flag_s1_color_ir
		.i_frame_type(dec_s1_frame_type),       // 输入 i_frame_type 用 dec_s1_frame_type
		.i_amb_code_snapshot(dec_s1_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_s1_amb_code_snapshot
		.i_dc_code_snapshot(dec_s1_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_s1_dc_code_snapshot
		.i_amb_code_epoch(dec_s1_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_s1_amb_code_epoch
		.i_dc_code_epoch(dec_s1_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_s1_dc_code_epoch
		.o_result_ready(flag_s1_detect_ready),  // 输出 o_result_ready 到 flag_s1_detect_ready
		.i_calibrated_ready(flag_calibrated_ready), // 输入 i_calibrated_ready 用 flag_calibrated_ready
		.o_calibrated_valid(flag_calibrated_valid), // 输出 o_calibrated_valid 到 flag_calibrated_valid
		.o_calibrated_s1_value(dec_router_calibrated_s1_value), // 输出 o_calibrated_s1_value 到 dec_router_calibrated_s1_value
		.o_calibration_applied(flag_router_calibration_applied), // 输出 o_calibration_applied 到 flag_router_calibration_applied
		.o_saturation_low(flag_router_saturation_low), // 输出 o_saturation_low 到 flag_router_saturation_low
		.o_saturation_high(flag_router_saturation_high), // 输出 o_saturation_high 到 flag_router_saturation_high
		.o_config_epoch(dec_router_config_epoch), // 输出 o_config_epoch 到 dec_router_config_epoch
		.o_coef_epoch(dec_router_coef_epoch),   // 输出 o_coef_epoch 到 dec_router_coef_epoch
		.o_stage1_raw(dec_router_stage1_raw),   // 输出 o_stage1_raw 到 dec_router_stage1_raw
		.o_detect_code(dec_router_detect_code), // 输出 o_detect_code 到 dec_router_detect_code
		.o_stage1_code_ext(dec_router_stage1_code_ext), // 输出 o_stage1_code_ext 到 dec_router_stage1_code_ext
		.o_stage2_raw(dec_router_stage2_raw),   // 输出 o_stage2_raw 到 dec_router_stage2_raw
		.o_precision_mode(flag_router_precision_mode), // 输出 o_precision_mode 到 flag_router_precision_mode
		.o_frame_id(dec_router_frame_id),       // 输出 o_frame_id 到 dec_router_frame_id
		.o_sample_index(dec_router_sample_index), // 输出 o_sample_index 到 dec_router_sample_index
		.o_color_ir(flag_router_color_ir),      // 输出 o_color_ir 到 flag_router_color_ir
		.o_frame_type(dec_router_frame_type),   // 输出 o_frame_type 到 dec_router_frame_type
		.o_amb_code_snapshot(dec_router_amb_code_snapshot), // 输出 o_amb_code_snapshot 到 dec_router_amb_code_snapshot
		.o_dc_code_snapshot(dec_router_dc_code_snapshot), // 输出 o_dc_code_snapshot 到 dec_router_dc_code_snapshot
		.o_amb_code_epoch(dec_router_amb_code_epoch), // 输出 o_amb_code_epoch 到 dec_router_amb_code_epoch
		.o_dc_code_epoch(dec_router_dc_code_epoch) // 输出 o_dc_code_epoch 到 dec_router_dc_code_epoch
	);

	// 路由器只产生互斥分支valid，完整载荷与其输入组合保持同一事务。
	ppg_adc_result_router #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 参数 C_RUN_GENERATION_WIDTH 用 C_RUN_GENERATION_WIDTH

	// 结果路由单元将校准事务互斥分发至校准与NORMAL路径。
	)ppg_adc_result_router_Inst(
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_run_generation(i_run_generation),    // router只做纯组合透传，不做代际比较或丢弃判断
		.i_result_valid(flag_calibrated_valid && !flag_result_abort_discard), // abort数据仅排空校准缓存而不进入router
		.i_calibrated_s1_value(dec_router_calibrated_s1_value), // 输入 i_calibrated_s1_value 用 dec_router_calibrated_s1_value
		.i_calibration_applied(flag_router_calibration_applied), // 输入 i_calibration_applied 用 flag_router_calibration_applied
		.i_saturation_low(flag_router_saturation_low), // 输入 i_saturation_low 用 flag_router_saturation_low
		.i_saturation_high(flag_router_saturation_high), // 输入 i_saturation_high 用 flag_router_saturation_high
		.i_config_epoch(dec_router_config_epoch), // 输入 i_config_epoch 用 dec_router_config_epoch
		.i_coef_epoch(dec_router_coef_epoch),   // 输入 i_coef_epoch 用 dec_router_coef_epoch
		.i_detect_code(dec_router_detect_code), // 输入 i_detect_code 用 dec_router_detect_code
		.i_stage1_raw(dec_router_stage1_raw),   // 输入 i_stage1_raw 用 dec_router_stage1_raw
		.i_stage1_code_ext(dec_router_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_router_stage1_code_ext
		.i_stage2_raw(dec_router_stage2_raw),   // 输入 i_stage2_raw 用 dec_router_stage2_raw
		.i_precision_mode(flag_router_precision_mode), // 输入 i_precision_mode 用 flag_router_precision_mode
		.i_frame_id(dec_router_frame_id),       // 输入 i_frame_id 用 dec_router_frame_id
		.i_sample_index(dec_router_sample_index), // 输入 i_sample_index 用 dec_router_sample_index
		.i_color_ir(flag_router_color_ir),      // 输入 i_color_ir 用 flag_router_color_ir
		.i_frame_type(dec_router_frame_type),   // 输入 i_frame_type 用 dec_router_frame_type
		.i_amb_code_snapshot(dec_router_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_router_amb_code_snapshot
		.i_dc_code_snapshot(dec_router_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_router_dc_code_snapshot
		.i_amb_code_epoch(dec_router_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_router_amb_code_epoch
		.i_dc_code_epoch(dec_router_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_router_dc_code_epoch
		.i_amb_cal_ready(flag_idac_search_amb_ready), // 输入 i_amb_cal_ready 用 flag_idac_search_amb_ready
		.i_dc_cal_ready(flag_idac_search_dcs_ready), // 输入 i_dc_cal_ready 用 flag_idac_search_dcs_ready
		.i_normal_ready(flag_normal_fork_ready), // 输入 i_normal_ready 用 flag_normal_fork_ready
		.o_result_ready(flag_calibrated_ready), // 输出 o_result_ready 到 flag_calibrated_ready
		.o_amb_cal_valid(flag_router_amb_valid), // 输出 o_amb_cal_valid 到 flag_router_amb_valid
		.o_dc_cal_valid(flag_router_dcs_valid), // 输出 o_dc_cal_valid 到 flag_router_dcs_valid
		.o_normal_valid(flag_router_normal_valid), // 输出 o_normal_valid 到 flag_router_normal_valid
		.o_frame_type_error(flag_router_frame_type_error), // 输出 o_frame_type_error 到 flag_router_frame_type_error
		.o_calibrated_s1_value(),               // 留空 o_calibrated_s1_value
		.o_calibration_applied(),               // 留空 o_calibration_applied
		.o_saturation_low(),                    // 留空 o_saturation_low
		.o_saturation_high(),                   // 留空 o_saturation_high
		.o_config_epoch(),                      // 留空 o_config_epoch
		.o_coef_epoch(),                        // 留空 o_coef_epoch
		.o_detect_code(),                       // 留空 o_detect_code
		.o_stage1_raw(),                        // 留空 o_stage1_raw
		.o_stage1_code_ext(),                   // 留空 o_stage1_code_ext
		.o_stage2_raw(),                        // 留空 o_stage2_raw
		.o_precision_mode(),                    // 留空 o_precision_mode
		.o_frame_id(),                          // 留空 o_frame_id
		.o_sample_index(),                      // 留空 o_sample_index
		.o_color_ir(),                          // 留空 o_color_ir
		.o_frame_type(),                        // 留空 o_frame_type
		.o_amb_code_snapshot(),                 // 留空 o_amb_code_snapshot
		.o_dc_code_snapshot(),                  // 留空 o_dc_code_snapshot
		.o_amb_code_epoch(),                    // 留空 o_amb_code_epoch
		.o_dc_code_epoch(),                     // 留空 o_dc_code_epoch
		.o_run_generation(dec_router_run_generation) // 接住结果，供下一级overlap实例作为其i_run_generation输入
	);

	// NORMAL事务写入标准双消费者fork，测量和IDAC跟踪各自只消费一次。
	ppg_normal_transaction_fork #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 参数 C_RUN_GENERATION_WIDTH 用 C_RUN_GENERATION_WIDTH

	// NORMAL分叉单元向测量重构和IDAC跟踪各交付一次事务。
	)ppg_normal_transaction_fork_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_run_generation(i_run_generation),    // 两分支共用同一份AMI当前RUN代际
		.i_datapath_discard_event(flag_ami_terminal_action), // AMI私有代际清空广播，命中当前代际时无条件清两个分支
		.i_datapath_discard_reason(flag_terminal_discard_reason), // STOP/abort/系统故障三态原因编码，仅诊断用途
		.i_datapath_discard_identity_valid(flag_datapath_discard_identity_valid), // 触发事务身份是否可信，仅诊断用途
		.i_datapath_discard_frame_id(flag_datapath_discard_frame_id), // 触发事务帧号，仅诊断用途
		.i_datapath_discard_sample_index(flag_datapath_discard_sample_index), // 触发事务序号，仅诊断用途
		.i_datapath_discard_color_ir(flag_datapath_discard_color_ir), // 触发事务颜色，仅诊断用途
		.i_datapath_discard_frame_type(flag_datapath_discard_frame_type), // 触发事务类型，仅诊断用途
		.i_datapath_discard_precision(flag_datapath_discard_precision), // 触发事务精度，仅诊断用途
		.i_datapath_discard_run_generation(i_run_generation), // 本次清空目标RUN代际，与实时广播值相同
		.i_normal_valid(flag_router_normal_valid && !flag_result_abort_discard), // abort时禁止router把NORMAL结果交付两个消费者
		.i_calibrated_s1_value(dec_router_calibrated_s1_value), // 输入 i_calibrated_s1_value 用 dec_router_calibrated_s1_value
		.i_calibration_applied(flag_router_calibration_applied), // 输入 i_calibration_applied 用 flag_router_calibration_applied
		.i_saturation_low(flag_router_saturation_low), // 输入 i_saturation_low 用 flag_router_saturation_low
		.i_saturation_high(flag_router_saturation_high), // 输入 i_saturation_high 用 flag_router_saturation_high
		.i_config_epoch(dec_router_config_epoch), // 输入 i_config_epoch 用 dec_router_config_epoch
		.i_coef_epoch(dec_router_coef_epoch),   // 输入 i_coef_epoch 用 dec_router_coef_epoch
		.i_detect_code(dec_router_detect_code), // 输入 i_detect_code 用 dec_router_detect_code
		.i_stage1_raw(dec_router_stage1_raw),   // 输入 i_stage1_raw 用 dec_router_stage1_raw
		.i_stage1_code_ext(dec_router_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_router_stage1_code_ext
		.i_stage2_raw(dec_router_stage2_raw),   // 输入 i_stage2_raw 用 dec_router_stage2_raw
		.i_precision_mode(flag_router_precision_mode), // 输入 i_precision_mode 用 flag_router_precision_mode
		.i_frame_id(dec_router_frame_id),       // 输入 i_frame_id 用 dec_router_frame_id
		.i_sample_index(dec_router_sample_index), // 输入 i_sample_index 用 dec_router_sample_index
		.i_color_ir(flag_router_color_ir),      // 输入 i_color_ir 用 flag_router_color_ir
		.i_frame_type(dec_router_frame_type),   // 输入 i_frame_type 用 dec_router_frame_type
		.i_amb_code_snapshot(dec_router_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_router_amb_code_snapshot
		.i_dc_code_snapshot(dec_router_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_router_dc_code_snapshot
		.i_amb_code_epoch(dec_router_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_router_amb_code_epoch
		.i_dc_code_epoch(dec_router_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_router_dc_code_epoch
		.o_normal_ready(flag_normal_fork_ready), // 输出 o_normal_ready 到 flag_normal_fork_ready
		.i_measurement_ready(flag_measurement_branch_ready), // 输入 i_measurement_ready 用 flag_measurement_branch_ready
		.o_measurement_valid(flag_measurement_branch_valid), // 输出 o_measurement_valid 到 flag_measurement_branch_valid
		.o_measurement_calibrated_s1_value(dec_measurement_s1_value), // 输出 o_measurement_calibrated_s1_value 到 dec_measurement_s1_value
		.o_measurement_calibration_applied(flag_measurement_calibration_applied), // 输出 o_measurement_calibration_applied 到 flag_measurement_calibration_applied
		.o_measurement_saturation_low(flag_measurement_saturation_low), // 输出 o_measurement_saturation_low 到 flag_measurement_saturation_low
		.o_measurement_saturation_high(flag_measurement_saturation_high), // 输出 o_measurement_saturation_high 到 flag_measurement_saturation_high
		.o_measurement_config_epoch(dec_measurement_config_epoch), // 输出 o_measurement_config_epoch 到 dec_measurement_config_epoch
		.o_measurement_coef_epoch(dec_measurement_coef_epoch), // 输出 o_measurement_coef_epoch 到 dec_measurement_coef_epoch
		.o_measurement_detect_code(dec_measurement_detect_code), // 输出 o_measurement_detect_code 到 dec_measurement_detect_code
		.o_measurement_stage1_raw(dec_measurement_stage1_raw), // 输出 o_measurement_stage1_raw 到 dec_measurement_stage1_raw
		.o_measurement_stage1_code_ext(dec_measurement_stage1_code_ext), // 输出 o_measurement_stage1_code_ext 到 dec_measurement_stage1_code_ext
		.o_measurement_stage2_raw(dec_measurement_stage2_raw), // 输出 o_measurement_stage2_raw 到 dec_measurement_stage2_raw
		.o_measurement_precision_mode(flag_measurement_precision_mode), // 输出 o_measurement_precision_mode 到 flag_measurement_precision_mode
		.o_measurement_frame_id(dec_measurement_frame_id), // 输出 o_measurement_frame_id 到 dec_measurement_frame_id
		.o_measurement_sample_index(dec_measurement_sample_index), // 输出 o_measurement_sample_index 到 dec_measurement_sample_index
		.o_measurement_color_ir(flag_measurement_color_ir), // 输出 o_measurement_color_ir 到 flag_measurement_color_ir
		.o_measurement_frame_type(dec_measurement_frame_type), // 输出 o_measurement_frame_type 到 dec_measurement_frame_type
		.o_measurement_amb_code_snapshot(dec_measurement_amb_code_snapshot), // 输出 o_measurement_amb_code_snapshot 到 dec_measurement_amb_code_snapshot
		.o_measurement_dc_code_snapshot(dec_measurement_dc_code_snapshot), // 输出 o_measurement_dc_code_snapshot 到 dec_measurement_dc_code_snapshot
		.o_measurement_amb_code_epoch(dec_measurement_amb_code_epoch), // 输出 o_measurement_amb_code_epoch 到 dec_measurement_amb_code_epoch
		.o_measurement_dc_code_epoch(dec_measurement_dc_code_epoch), // 输出 o_measurement_dc_code_epoch 到 dec_measurement_dc_code_epoch
		.o_measurement_run_generation(dec_fork_measurement_run_generation), // 接住测量分支pending装入时锁存的代际快照
		.i_track_ready(flag_track_branch_ready), // 输入 i_track_ready 用 flag_track_branch_ready
		.o_track_valid(flag_track_branch_valid_raw), // 输出 o_track_valid 到原始tracking valid
		.o_track_calibrated_s1_value(flag_track_s1_value), // 输出 o_track_calibrated_s1_value 到 flag_track_s1_value
		.o_track_calibration_applied(flag_track_calibration_applied), // 输出 o_track_calibration_applied 到 flag_track_calibration_applied
		.o_track_saturation_low(flag_track_saturation_low), // 输出 o_track_saturation_low 到 flag_track_saturation_low
		.o_track_saturation_high(flag_track_saturation_high), // 输出 o_track_saturation_high 到 flag_track_saturation_high
		.o_track_config_epoch(flag_track_config_epoch), // 输出 o_track_config_epoch 到 flag_track_config_epoch
		.o_track_coef_epoch(flag_track_coef_epoch), // 输出 o_track_coef_epoch 到 flag_track_coef_epoch
		.o_track_precision_mode(flag_track_precision_mode), // 输出 o_track_precision_mode 到 flag_track_precision_mode
		.o_track_frame_id(flag_track_frame_id), // 输出 o_track_frame_id 到 flag_track_frame_id
		.o_track_sample_index(flag_track_sample_index), // 输出 o_track_sample_index 到 flag_track_sample_index
		.o_track_color_ir(flag_track_color_ir), // 输出 o_track_color_ir 到 flag_track_color_ir
		.o_track_frame_type(flag_track_frame_type), // 输出 o_track_frame_type 到 flag_track_frame_type
		.o_track_amb_code_snapshot(flag_track_amb_code_snapshot), // 输出 o_track_amb_code_snapshot 到 flag_track_amb_code_snapshot
		.o_track_dc_code_snapshot(flag_track_dc_code_snapshot), // 输出 o_track_dc_code_snapshot 到 flag_track_dc_code_snapshot
		.o_track_amb_code_epoch(flag_track_amb_code_epoch), // 输出 o_track_amb_code_epoch 到 flag_track_amb_code_epoch
		.o_track_dc_code_epoch(flag_track_dc_code_epoch), // 输出 o_track_dc_code_epoch 到 flag_track_dc_code_epoch
		.o_tracking_run_generation(flag_fork_tracking_run_generation), // 接住跟踪分支pending装入时锁存的代际快照
		.o_local_empty(flag_fork_local_empty)   // 接住结果，本模块内部不消费，仅供上层诊断观测
	);

	// overlap模块生成正式Stage2扩展码并保留标称结果作为黄金诊断。
	ppg_adc_pipeline_overlap_corrector #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 参数 C_RUN_GENERATION_WIDTH 用 C_RUN_GENERATION_WIDTH

	// 重叠修正单元生成Stage2扩展码与标称15-bit码。
	)ppg_adc_pipeline_overlap_corrector_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_datapath_discard_event(flag_ami_terminal_action), // overlap单元素输出缓存同样接入这条私有终止释放线
		.i_datapath_discard_reason(flag_terminal_discard_reason), // 与fork共用同一套STOP/abort/系统故障三态编码
		.i_datapath_discard_identity_valid(flag_datapath_discard_identity_valid), // overlap不据此判断，仅原样落入诊断寄存
		.i_datapath_discard_frame_id(flag_datapath_discard_frame_id), // 该值不参与overlap本地清除条件，只用于事后追溯
		.i_datapath_discard_sample_index(flag_datapath_discard_sample_index), // 与本地清除判断无关，仅保留供上层核对顺序号
		.i_datapath_discard_color_ir(flag_datapath_discard_color_ir), // overlap不比较颜色，此线只服务外部观测需求
		.i_datapath_discard_frame_type(flag_datapath_discard_frame_type), // overlap不比较类型，此线只服务外部观测需求
		.i_datapath_discard_precision(flag_datapath_discard_precision), // overlap不比较精度，此线只服务外部观测需求
		.i_datapath_discard_run_generation(i_run_generation), // overlap只比较该字段与自身锁存代际是否一致
		.i_normal_valid(flag_measurement_branch_valid && !flag_result_abort_discard), // abort时测量分支只由ready排空而不进入overlap
		.i_calibrated_s1_value(dec_measurement_s1_value), // 输入 i_calibrated_s1_value 用 dec_measurement_s1_value
		.i_calibration_applied(flag_measurement_calibration_applied), // 输入 i_calibration_applied 用 flag_measurement_calibration_applied
		.i_saturation_low(flag_measurement_saturation_low), // 输入 i_saturation_low 用 flag_measurement_saturation_low
		.i_saturation_high(flag_measurement_saturation_high), // 输入 i_saturation_high 用 flag_measurement_saturation_high
		.i_config_epoch(dec_measurement_config_epoch), // 输入 i_config_epoch 用 dec_measurement_config_epoch
		.i_coef_epoch(dec_measurement_coef_epoch), // 输入 i_coef_epoch 用 dec_measurement_coef_epoch
		.i_detect_code(dec_measurement_detect_code), // 输入 i_detect_code 用 dec_measurement_detect_code
		.i_stage1_raw(dec_measurement_stage1_raw), // 输入 i_stage1_raw 用 dec_measurement_stage1_raw
		.i_stage1_code_ext(dec_measurement_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_measurement_stage1_code_ext
		.i_stage2_raw(dec_measurement_stage2_raw), // 输入 i_stage2_raw 用 dec_measurement_stage2_raw
		.i_precision_mode(flag_measurement_precision_mode), // 输入 i_precision_mode 用 flag_measurement_precision_mode
		.i_frame_id(dec_measurement_frame_id),  // 输入 i_frame_id 用 dec_measurement_frame_id
		.i_sample_index(dec_measurement_sample_index), // 输入 i_sample_index 用 dec_measurement_sample_index
		.i_color_ir(flag_measurement_color_ir), // 输入 i_color_ir 用 flag_measurement_color_ir
		.i_frame_type(dec_measurement_frame_type), // 输入 i_frame_type 用 dec_measurement_frame_type
		.i_amb_code_snapshot(dec_measurement_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_measurement_amb_code_snapshot
		.i_dc_code_snapshot(dec_measurement_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_measurement_dc_code_snapshot
		.i_amb_code_epoch(dec_measurement_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_measurement_amb_code_epoch
		.i_dc_code_epoch(dec_measurement_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_measurement_dc_code_epoch
		.i_run_generation(dec_router_run_generation), // 沿router透传值锁存本地缓存的RUN代际
		.o_normal_ready(flag_measurement_branch_ready), // 输出 o_normal_ready 到 flag_measurement_branch_ready
		.i_result_ready(flag_overlap_result_ready), // 输入 i_result_ready 用 flag_overlap_result_ready
		.o_result_valid(flag_overlap_result_valid), // 输出 o_result_valid 到 flag_overlap_result_valid
		.o_calibrated_s1_value(dec_overlap_s1_value), // 输出 o_calibrated_s1_value 到 dec_overlap_s1_value
		.o_calibration_applied(flag_overlap_calibration_applied), // 输出 o_calibration_applied 到 flag_overlap_calibration_applied
		.o_saturation_low(flag_overlap_saturation_low), // 输出 o_saturation_low 到 flag_overlap_saturation_low
		.o_saturation_high(flag_overlap_saturation_high), // 输出 o_saturation_high 到 flag_overlap_saturation_high
		.o_config_epoch(dec_overlap_config_epoch), // 输出 o_config_epoch 到 dec_overlap_config_epoch
		.o_coef_epoch(dec_overlap_coef_epoch),  // 输出 o_coef_epoch 到 dec_overlap_coef_epoch
		.o_detect_code(dec_overlap_detect_code), // 输出 o_detect_code 到 dec_overlap_detect_code
		.o_stage1_raw(dec_overlap_stage1_raw),  // 输出 o_stage1_raw 到 dec_overlap_stage1_raw
		.o_stage1_code_ext(dec_overlap_stage1_code_ext), // 输出 o_stage1_code_ext 到 dec_overlap_stage1_code_ext
		.o_stage2_raw(dec_overlap_stage2_raw),  // 输出 o_stage2_raw 到 dec_overlap_stage2_raw
		.o_stage2_code_ext(dec_overlap_stage2_code_ext), // 输出 o_stage2_code_ext 到 dec_overlap_stage2_code_ext
		.o_nominal_15_code(dec_overlap_nominal_15_code), // 输出 o_nominal_15_code 到 dec_overlap_nominal_15_code
		.o_nominal_15_valid(flag_overlap_nominal_15_valid), // 输出 o_nominal_15_valid 到 flag_overlap_nominal_15_valid
		.o_nominal_saturated(flag_overlap_nominal_saturated), // 输出 o_nominal_saturated 到 flag_overlap_nominal_saturated
		.o_precision_mode(flag_overlap_precision_mode), // 输出 o_precision_mode 到 flag_overlap_precision_mode
		.o_frame_id(dec_overlap_frame_id),      // 输出 o_frame_id 到 dec_overlap_frame_id
		.o_sample_index(dec_overlap_sample_index), // 输出 o_sample_index 到 dec_overlap_sample_index
		.o_color_ir(flag_overlap_color_ir),     // 输出 o_color_ir 到 flag_overlap_color_ir
		.o_frame_type(dec_overlap_frame_type),  // 输出 o_frame_type 到 dec_overlap_frame_type
		.o_amb_code_snapshot(dec_overlap_amb_code_snapshot), // 输出 o_amb_code_snapshot 到 dec_overlap_amb_code_snapshot
		.o_dc_code_snapshot(dec_overlap_dc_code_snapshot), // 输出 o_dc_code_snapshot 到 dec_overlap_dc_code_snapshot
		.o_amb_code_epoch(dec_overlap_amb_code_epoch), // 输出 o_amb_code_epoch 到 dec_overlap_amb_code_epoch
		.o_dc_code_epoch(dec_overlap_dc_code_epoch), // 输出 o_dc_code_epoch 到 dec_overlap_dc_code_epoch
		.o_run_generation(dec_overlap_run_generation), // 与统一结果原子对齐、随载荷保持到消费或匹配清空的RUN代际
		.o_local_empty(flag_overlap_local_empty) // 输出缓存无pending事务时为高，仅供诊断观测
	);

	// 可编程重构器只使用overlap产生的Stage2扩展码形成正式15-bit结果。
	ppg_adc_programmable_reconstructor #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH

	// 可编程重构单元应用Stage2增益与加法offset形成精细残差。
	)ppg_adc_programmable_reconstructor_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_active_valid(i_active_config_valid), // 输入 i_active_valid 用 i_active_config_valid
		.i_stage2_calibration_valid(i_stage2_calibration_valid), // 输入 i_stage2_calibration_valid 用 i_stage2_calibration_valid
		.i_stage2_gain_q16(i_stage2_gain_q16),  // 输入 i_stage2_gain_q16 用 i_stage2_gain_q16
		.i_stage2_offset_q16(i_stage2_offset_q16), // 输入 i_stage2_offset_q16 用 i_stage2_offset_q16
		.i_stage2_coef_epoch(i_stage2_coef_epoch), // 输入 i_stage2_coef_epoch 用 i_stage2_coef_epoch
		.i_result_valid(flag_overlap_result_valid && !flag_result_abort_discard), // abort时禁止overlap结果进入可编程重构
		.i_calibrated_s1_value(dec_overlap_s1_value), // 输入 i_calibrated_s1_value 用 dec_overlap_s1_value
		.i_calibration_applied(flag_overlap_calibration_applied), // 输入 i_calibration_applied 用 flag_overlap_calibration_applied
		.i_saturation_low(flag_overlap_saturation_low), // 输入 i_saturation_low 用 flag_overlap_saturation_low
		.i_saturation_high(flag_overlap_saturation_high), // 输入 i_saturation_high 用 flag_overlap_saturation_high
		.i_config_epoch(dec_overlap_config_epoch), // 输入 i_config_epoch 用 dec_overlap_config_epoch
		.i_coef_epoch(dec_overlap_coef_epoch),  // 输入 i_coef_epoch 用 dec_overlap_coef_epoch
		.i_detect_code(dec_overlap_detect_code), // 输入 i_detect_code 用 dec_overlap_detect_code
		.i_stage1_raw(dec_overlap_stage1_raw),  // 输入 i_stage1_raw 用 dec_overlap_stage1_raw
		.i_stage1_code_ext(dec_overlap_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_overlap_stage1_code_ext
		.i_stage2_raw(dec_overlap_stage2_raw),  // 输入 i_stage2_raw 用 dec_overlap_stage2_raw
		.i_stage2_code_ext(dec_overlap_stage2_code_ext), // 输入 i_stage2_code_ext 用 dec_overlap_stage2_code_ext
		.i_nominal_15_code(dec_overlap_nominal_15_code), // 输入 i_nominal_15_code 用 dec_overlap_nominal_15_code
		.i_nominal_15_valid(flag_overlap_nominal_15_valid), // 输入 i_nominal_15_valid 用 flag_overlap_nominal_15_valid
		.i_nominal_saturated(flag_overlap_nominal_saturated), // 输入 i_nominal_saturated 用 flag_overlap_nominal_saturated
		.i_precision_mode(flag_overlap_precision_mode), // 输入 i_precision_mode 用 flag_overlap_precision_mode
		.i_frame_id(dec_overlap_frame_id),      // 输入 i_frame_id 用 dec_overlap_frame_id
		.i_sample_index(dec_overlap_sample_index), // 输入 i_sample_index 用 dec_overlap_sample_index
		.i_color_ir(flag_overlap_color_ir),     // 输入 i_color_ir 用 flag_overlap_color_ir
		.i_frame_type(dec_overlap_frame_type),  // 输入 i_frame_type 用 dec_overlap_frame_type
		.i_amb_code_snapshot(dec_overlap_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_overlap_amb_code_snapshot
		.i_dc_code_snapshot(dec_overlap_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_overlap_dc_code_snapshot
		.i_amb_code_epoch(dec_overlap_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_overlap_amb_code_epoch
		.i_dc_code_epoch(dec_overlap_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_overlap_dc_code_epoch
		.o_result_ready(flag_overlap_result_ready), // 输出 o_result_ready 到 flag_overlap_result_ready
		.i_result_ready(flag_reconstructor_result_ready), // 输入 i_result_ready 用 flag_reconstructor_result_ready
		.o_result_valid(flag_reconstructor_result_valid), // 输出 o_result_valid 到 flag_reconstructor_result_valid
		.o_programmable_15_code(dec_reconstructor_15_code), // 输出 o_programmable_15_code 到 dec_reconstructor_15_code
		.o_programmable_15_valid(flag_reconstructor_15_valid), // 输出 o_programmable_15_valid 到 flag_reconstructor_15_valid
		.o_programmable_15_calibration_applied(flag_reconstructor_15_calibrated), // 输出 o_programmable_15_calibration_applied 到 flag_reconstructor_15_calibrated
		.o_programmable_saturation_low(flag_reconstructor_saturation_low), // 输出 o_programmable_saturation_low 到 flag_reconstructor_saturation_low
		.o_programmable_saturation_high(flag_reconstructor_saturation_high), // 输出 o_programmable_saturation_high 到 flag_reconstructor_saturation_high
		.o_stage2_coef_epoch(dec_reconstructor_stage2_epoch), // 输出 o_stage2_coef_epoch 到 dec_reconstructor_stage2_epoch
		.o_calibrated_s1_value(dec_reconstructor_s1_value), // 输出 o_calibrated_s1_value 到 dec_reconstructor_s1_value
		.o_calibration_applied(flag_reconstructor_calibration_applied), // 输出 o_calibration_applied 到 flag_reconstructor_calibration_applied
		.o_stage1_saturation_low(flag_reconstructor_s1_saturation_low), // 输出 o_stage1_saturation_low 到 flag_reconstructor_s1_saturation_low
		.o_stage1_saturation_high(flag_reconstructor_s1_saturation_high), // 输出 o_stage1_saturation_high 到 flag_reconstructor_s1_saturation_high
		.o_config_epoch(dec_reconstructor_config_epoch), // 输出 o_config_epoch 到 dec_reconstructor_config_epoch
		.o_coef_epoch(dec_reconstructor_coef_epoch), // 输出 o_coef_epoch 到 dec_reconstructor_coef_epoch
		.o_detect_code(dec_reconstructor_detect_code), // 输出 o_detect_code 到 dec_reconstructor_detect_code
		.o_stage1_raw(dec_reconstructor_stage1_raw), // 输出 o_stage1_raw 到 dec_reconstructor_stage1_raw
		.o_stage1_code_ext(dec_reconstructor_stage1_code_ext), // 输出 o_stage1_code_ext 到 dec_reconstructor_stage1_code_ext
		.o_stage2_raw(dec_reconstructor_stage2_raw), // 输出 o_stage2_raw 到 dec_reconstructor_stage2_raw
		.o_stage2_code_ext(dec_reconstructor_stage2_code_ext), // 输出 o_stage2_code_ext 到 dec_reconstructor_stage2_code_ext
		.o_nominal_15_code(dec_reconstructor_nominal_15_code), // 输出 o_nominal_15_code 到 dec_reconstructor_nominal_15_code
		.o_nominal_15_valid(flag_reconstructor_nominal_15_valid), // 输出 o_nominal_15_valid 到 flag_reconstructor_nominal_15_valid
		.o_nominal_saturated(flag_reconstructor_nominal_saturated), // 输出 o_nominal_saturated 到 flag_reconstructor_nominal_saturated
		.o_precision_mode(flag_reconstructor_precision_mode), // 输出 o_precision_mode 到 flag_reconstructor_precision_mode
		.o_frame_id(dec_reconstructor_frame_id), // 输出 o_frame_id 到 dec_reconstructor_frame_id
		.o_sample_index(dec_reconstructor_sample_index), // 输出 o_sample_index 到 dec_reconstructor_sample_index
		.o_color_ir(flag_reconstructor_color_ir), // 输出 o_color_ir 到 flag_reconstructor_color_ir
		.o_frame_type(dec_reconstructor_frame_type), // 输出 o_frame_type 到 dec_reconstructor_frame_type
		.o_amb_code_snapshot(dec_reconstructor_amb_code_snapshot), // 输出 o_amb_code_snapshot 到 dec_reconstructor_amb_code_snapshot
		.o_dc_code_snapshot(dec_reconstructor_dc_code_snapshot), // 输出 o_dc_code_snapshot 到 dec_reconstructor_dc_code_snapshot
		.o_amb_code_epoch(dec_reconstructor_amb_code_epoch), // 输出 o_amb_code_epoch 到 dec_reconstructor_amb_code_epoch
		.o_dc_code_epoch(dec_reconstructor_dc_code_epoch) // 输出 o_dc_code_epoch 到 dec_reconstructor_dc_code_epoch
	);

	// DC恢复器把事务使用的DC码等效量加回统一signed 24-bit PPG标度。
	ppg_adc_dc_recovery #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH) // 参数 C_DC_RECOVERY_EPOCH_WIDTH 用 C_DC_RECOVERY_EPOCH_WIDTH

	// DC恢复单元将IDAC等效量加回粗细两路残差。
	)ppg_adc_dc_recovery_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_active_valid(i_active_config_valid), // 输入 i_active_valid 用 i_active_config_valid
		.i_dc9_recovery_valid(i_dc9_recovery_valid), // 输入 i_dc9_recovery_valid 用 i_dc9_recovery_valid
		.i_dc15_recovery_valid(i_dc15_recovery_valid), // 输入 i_dc15_recovery_valid 用 i_dc15_recovery_valid
		.i_dc9_recovery_gain_q16(i_dc9_recovery_gain_q16), // 输入 i_dc9_recovery_gain_q16 用 i_dc9_recovery_gain_q16
		.i_dc15_recovery_gain_q16(i_dc15_recovery_gain_q16), // 输入 i_dc15_recovery_gain_q16 用 i_dc15_recovery_gain_q16
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch), // 输入 i_dc_recovery_coef_epoch 用 i_dc_recovery_coef_epoch
		.i_result_valid(flag_reconstructor_result_valid && !flag_result_abort_discard), // abort时禁止重构结果进入DC恢复
		.o_result_ready(flag_reconstructor_result_ready), // 输出 o_result_ready 到 flag_reconstructor_result_ready
		.i_result_ready(flag_dc_result_ready),  // 输入 i_result_ready 用 flag_dc_result_ready
		.i_calibrated_s1_value(dec_reconstructor_s1_value), // 输入 i_calibrated_s1_value 用 dec_reconstructor_s1_value
		.i_calibration_applied(flag_reconstructor_calibration_applied), // 输入 i_calibration_applied 用 flag_reconstructor_calibration_applied
		.i_stage1_saturation_low(flag_reconstructor_s1_saturation_low), // 输入 i_stage1_saturation_low 用 flag_reconstructor_s1_saturation_low
		.i_stage1_saturation_high(flag_reconstructor_s1_saturation_high), // 输入 i_stage1_saturation_high 用 flag_reconstructor_s1_saturation_high
		.i_programmable_15_code(dec_reconstructor_15_code), // 输入 i_programmable_15_code 用 dec_reconstructor_15_code
		.i_programmable_15_valid(flag_reconstructor_15_valid), // 输入 i_programmable_15_valid 用 flag_reconstructor_15_valid
		.i_programmable_15_calibration_applied(flag_reconstructor_15_calibrated), // 输入 i_programmable_15_calibration_applied 用 flag_reconstructor_15_calibrated
		.i_programmable_saturation_low(flag_reconstructor_saturation_low), // 输入 i_programmable_saturation_low 用 flag_reconstructor_saturation_low
		.i_programmable_saturation_high(flag_reconstructor_saturation_high), // 输入 i_programmable_saturation_high 用 flag_reconstructor_saturation_high
		.i_config_epoch(dec_reconstructor_config_epoch), // 输入 i_config_epoch 用 dec_reconstructor_config_epoch
		.i_coef_epoch(dec_reconstructor_coef_epoch), // 输入 i_coef_epoch 用 dec_reconstructor_coef_epoch
		.i_stage2_coef_epoch(dec_reconstructor_stage2_epoch), // 输入 i_stage2_coef_epoch 用 dec_reconstructor_stage2_epoch
		.i_precision_mode(flag_reconstructor_precision_mode), // 输入 i_precision_mode 用 flag_reconstructor_precision_mode
		.i_frame_id(dec_reconstructor_frame_id), // 输入 i_frame_id 用 dec_reconstructor_frame_id
		.i_sample_index(dec_reconstructor_sample_index), // 输入 i_sample_index 用 dec_reconstructor_sample_index
		.i_color_ir(flag_reconstructor_color_ir), // 输入 i_color_ir 用 flag_reconstructor_color_ir
		.i_frame_type(dec_reconstructor_frame_type), // 输入 i_frame_type 用 dec_reconstructor_frame_type
		.i_amb_code_snapshot(dec_reconstructor_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 dec_reconstructor_amb_code_snapshot
		.i_dc_code_snapshot(dec_reconstructor_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 dec_reconstructor_dc_code_snapshot
		.i_amb_code_epoch(dec_reconstructor_amb_code_epoch), // 输入 i_amb_code_epoch 用 dec_reconstructor_amb_code_epoch
		.i_dc_code_epoch(dec_reconstructor_dc_code_epoch), // 输入 i_dc_code_epoch 用 dec_reconstructor_dc_code_epoch
		.i_detect_code(dec_reconstructor_detect_code), // 输入 i_detect_code 用 dec_reconstructor_detect_code
		.i_stage1_raw(dec_reconstructor_stage1_raw), // 输入 i_stage1_raw 用 dec_reconstructor_stage1_raw
		.i_stage1_code_ext(dec_reconstructor_stage1_code_ext), // 输入 i_stage1_code_ext 用 dec_reconstructor_stage1_code_ext
		.i_stage2_raw(dec_reconstructor_stage2_raw), // 输入 i_stage2_raw 用 dec_reconstructor_stage2_raw
		.i_stage2_code_ext(dec_reconstructor_stage2_code_ext), // 输入 i_stage2_code_ext 用 dec_reconstructor_stage2_code_ext
		.i_nominal_15_code(dec_reconstructor_nominal_15_code), // 输入 i_nominal_15_code 用 dec_reconstructor_nominal_15_code
		.i_nominal_15_valid(flag_reconstructor_nominal_15_valid), // 输入 i_nominal_15_valid 用 flag_reconstructor_nominal_15_valid
		.i_nominal_saturated(flag_reconstructor_nominal_saturated), // 输入 i_nominal_saturated 用 flag_reconstructor_nominal_saturated
		.o_result_valid(flag_dc_result_valid),  // 输出 o_result_valid 到 flag_dc_result_valid
		.o_coarse_ppg_value(dec_dc_coarse_ppg_value), // 输出 o_coarse_ppg_value 到 dec_dc_coarse_ppg_value
		.o_coarse_valid(flag_dc_coarse_valid),  // 输出 o_coarse_valid 到 flag_dc_coarse_valid
		.o_coarse_recovery_calibrated(flag_dc_coarse_calibrated), // 输出 o_coarse_recovery_calibrated 到 flag_dc_coarse_calibrated
		.o_coarse_saturation_low(flag_dc_coarse_saturation_low), // 输出 o_coarse_saturation_low 到 flag_dc_coarse_saturation_low
		.o_coarse_saturation_high(flag_dc_coarse_saturation_high), // 输出 o_coarse_saturation_high 到 flag_dc_coarse_saturation_high
		.o_fine_ppg_value(dec_dc_fine_ppg_value), // 输出 o_fine_ppg_value 到 dec_dc_fine_ppg_value
		.o_fine_valid(flag_dc_fine_valid),      // 输出 o_fine_valid 到 flag_dc_fine_valid
		.o_fine_recovery_calibrated(flag_dc_fine_calibrated), // 输出 o_fine_recovery_calibrated 到 flag_dc_fine_calibrated
		.o_fine_saturation_low(flag_dc_fine_saturation_low), // 输出 o_fine_saturation_low 到 flag_dc_fine_saturation_low
		.o_fine_saturation_high(flag_dc_fine_saturation_high), // 输出 o_fine_saturation_high 到 flag_dc_fine_saturation_high
		.o_dc_recovery_coef_epoch(dec_dc_recovery_epoch), // 输出 o_dc_recovery_coef_epoch 到 dec_dc_recovery_epoch
		.o_calibrated_s1_value(dec_dc_s1_value), // 输出 o_calibrated_s1_value 到 dec_dc_s1_value
		.o_calibration_applied(flag_dc_s1_calibration_applied), // 输出 o_calibration_applied 到 flag_dc_s1_calibration_applied
		.o_stage1_saturation_low(flag_dc_s1_saturation_low), // 输出 o_stage1_saturation_low 到 flag_dc_s1_saturation_low
		.o_stage1_saturation_high(flag_dc_s1_saturation_high), // 输出 o_stage1_saturation_high 到 flag_dc_s1_saturation_high
		.o_programmable_15_code(dec_dc_programmable_15_code), // 输出 o_programmable_15_code 到 dec_dc_programmable_15_code
		.o_programmable_15_valid(flag_dc_programmable_15_valid), // 输出 o_programmable_15_valid 到 flag_dc_programmable_15_valid
		.o_programmable_15_calibration_applied(), // 留空 o_programmable_15_calibration_applied
		.o_programmable_saturation_low(),       // 留空 o_programmable_saturation_low
		.o_programmable_saturation_high(),      // 留空 o_programmable_saturation_high
		.o_config_epoch(dec_dc_config_epoch),   // 输出 o_config_epoch 到 dec_dc_config_epoch
		.o_coef_epoch(dec_dc_coef_epoch),       // 输出 o_coef_epoch 到 dec_dc_coef_epoch
		.o_stage2_coef_epoch(dec_dc_stage2_epoch), // 输出 o_stage2_coef_epoch 到 dec_dc_stage2_epoch
		.o_precision_mode(flag_dc_precision_mode), // 输出 o_precision_mode 到 flag_dc_precision_mode
		.o_frame_id(dec_dc_frame_id),           // 输出 o_frame_id 到 dec_dc_frame_id
		.o_sample_index(dec_dc_sample_index),   // 输出 o_sample_index 到 dec_dc_sample_index
		.o_color_ir(flag_dc_color_ir),          // 输出 o_color_ir 到 flag_dc_color_ir
		.o_frame_type(dec_dc_frame_type),       // 输出 o_frame_type 到 dec_dc_frame_type
		.o_amb_code_snapshot(dec_dc_amb_code_snapshot), // 输出 o_amb_code_snapshot 到 dec_dc_amb_code_snapshot
		.o_dc_code_snapshot(dec_dc_dc_code_snapshot), // 输出 o_dc_code_snapshot 到 dec_dc_dc_code_snapshot
		.o_amb_code_epoch(dec_dc_amb_code_epoch), // 输出 o_amb_code_epoch 到 dec_dc_amb_code_epoch
		.o_dc_code_epoch(dec_dc_dc_code_epoch), // 输出 o_dc_code_epoch 到 dec_dc_dc_code_epoch
		.o_detect_code(),                       // 留空 o_detect_code
		.o_stage1_raw(dec_dc_stage1_raw),       // 输出 o_stage1_raw 到 dec_dc_stage1_raw，取自本实例自己重新导出的atomic payload_o，供P2S边界透传
		.o_stage1_code_ext(),                   // 留空 o_stage1_code_ext
		.o_stage2_raw(dec_dc_stage2_raw),       // 输出 o_stage2_raw 到 dec_dc_stage2_raw，与o_stage1_raw锁在同一拍atomic payload_o，供P2S边界透传
		.o_stage2_code_ext(),                   // 留空 o_stage2_code_ext
		.o_nominal_15_code(),                   // 留空 o_nominal_15_code
		.o_nominal_15_valid(),                  // 留空 o_nominal_15_valid
		.o_nominal_saturated()                  // 留空 o_nominal_saturated
	);

	// IDAC控制器直接观察未恢复Stage1残差并闭环管理启动搜索与慢速跟踪。
	ppg_idac_code_controller #(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH), // 参数 C_RUN_GENERATION_WIDTH 用 C_RUN_GENERATION_WIDTH
		.C_ENABLE_TEST_INJECTION(C_ENABLE_TEST_INJECTION) // IDAC控制器验证饱和注入结构生成开关，生产网表恒为0

	// IDAC控制单元完成启动搜索、周期重检和NORMAL慢速跟踪。
	)ppg_idac_code_controller_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_run_generation(i_run_generation),    // manager经AMI逐层传入的当前RUN代际，陈旧代际不得建立pending或改变committed码
		.i_run_enable(i_run_enable),            // 输入 i_run_enable 用 i_run_enable
		.i_start_ack_event(flag_idac_start_event_qualified), // 仅合法运行档案进入IDAC启动状态机
		.i_stop_ack_event(i_stop_ack_event),    // 输入 i_stop_ack_event 用 i_stop_ack_event
		.i_status_clear_event(i_diag_clear_event), // 输入 i_status_clear_event 用 i_diag_clear_event
		.i_control_abort_event(i_control_abort_event), // 输入 i_control_abort_event 用 i_control_abort_event
		.i_frame_safe_boundary(i_idac_code_safe_boundary), // IDAC候选仅在码安全边界提交
		.i_active_config_epoch(i_config_epoch), // 输入 i_active_config_epoch 用 i_config_epoch
		.i_idac_mode(i_idac_mode),              // 输入 i_idac_mode 用 i_idac_mode
		.i_amb_enable(i_amb_enable),            // 输入 i_amb_enable 用 i_amb_enable
		.i_dcs_enable(i_dcs_enable),            // 输入 i_dcs_enable 用 i_dcs_enable
		.i_amb_polarity(i_amb_polarity),        // 输入 i_amb_polarity 用 i_amb_polarity
		.i_dcs_polarity(i_dcs_polarity),        // 输入 i_dcs_polarity 用 i_dcs_polarity
		.i_amb_manual_code(i_amb_manual_code),  // 输入 i_amb_manual_code 用 i_amb_manual_code
		.i_amb_code_min(i_amb_code_min),        // 输入 i_amb_code_min 用 i_amb_code_min
		.i_amb_code_max(i_amb_code_max),        // 输入 i_amb_code_max 用 i_amb_code_max
		.i_dcs_r_manual_code(i_dcs_r_manual_code), // 输入 i_dcs_r_manual_code 用 i_dcs_r_manual_code
		.i_dcs_r_code_min(i_dcs_r_code_min),    // 输入 i_dcs_r_code_min 用 i_dcs_r_code_min
		.i_dcs_r_code_max(i_dcs_r_code_max),    // 输入 i_dcs_r_code_max 用 i_dcs_r_code_max
		.i_dcs_ir_manual_code(i_dcs_ir_manual_code), // 输入 i_dcs_ir_manual_code 用 i_dcs_ir_manual_code
		.i_dcs_ir_code_min(i_dcs_ir_code_min),  // 输入 i_dcs_ir_code_min 用 i_dcs_ir_code_min
		.i_dcs_ir_code_max(i_dcs_ir_code_max),  // 输入 i_dcs_ir_code_max 用 i_dcs_ir_code_max
		.i_amb_threshold_low(i_amb_threshold_low), // 输入 i_amb_threshold_low 用 i_amb_threshold_low
		.i_amb_threshold_high(i_amb_threshold_high), // 输入 i_amb_threshold_high 用 i_amb_threshold_high
		.i_dcs_threshold_low(i_dcs_threshold_low), // 输入 i_dcs_threshold_low 用 i_dcs_threshold_low
		.i_dcs_threshold_high(i_dcs_threshold_high), // 输入 i_dcs_threshold_high 用 i_dcs_threshold_high
		.i_amb_confirm_count(i_amb_confirm_count), // 输入 i_amb_confirm_count 用 i_amb_confirm_count
		.i_dcs_confirm_count(i_dcs_confirm_count), // 输入 i_dcs_confirm_count 用 i_dcs_confirm_count
		.i_search_amb_valid(flag_router_amb_valid && !flag_result_abort_discard), // abort时禁止AMB结果改变IDAC搜索状态
		.o_search_amb_ready(flag_idac_search_amb_ready), // 输出 o_search_amb_ready 到 flag_idac_search_amb_ready
		.i_search_dcs_valid(flag_router_dcs_valid && !flag_result_abort_discard), // abort时禁止DCS结果推进指定颜色的DC搜索状态机
		.o_search_dcs_ready(flag_idac_search_dcs_ready), // 输出 o_search_dcs_ready 到 flag_idac_search_dcs_ready
		.i_search_calibrated_s1_value(dec_router_calibrated_s1_value), // 输入 i_search_calibrated_s1_value 用 dec_router_calibrated_s1_value
		.i_search_calibration_applied(flag_router_calibration_applied), // 输入 i_search_calibration_applied 用 flag_router_calibration_applied
		.i_search_saturation_low(flag_router_saturation_low), // 输入 i_search_saturation_low 用 flag_router_saturation_low
		.i_search_saturation_high(flag_router_saturation_high), // 输入 i_search_saturation_high 用 flag_router_saturation_high
		.i_test_inject_enable(flag_test_inject_effective), // 只在显式验证构建中允许饱和注入，复用AMI自身既有的CONFIG/READY期间锁存请求
		.i_test_saturation_inject_valid(i_test_saturation_inject_valid), // 透传顶层保持型一次饱和注入请求
		.o_test_saturation_inject_ready(idac_test_saturation_inject_ready_o), // IDAC控制器当前可原子绑定饱和注入请求
		.i_search_config_epoch(dec_router_config_epoch), // 输入 i_search_config_epoch 用 dec_router_config_epoch
		.i_search_coef_epoch(dec_router_coef_epoch), // 输入 i_search_coef_epoch 用 dec_router_coef_epoch
		.i_search_precision_mode(flag_router_precision_mode), // 输入 i_search_precision_mode 用 flag_router_precision_mode
		.i_search_frame_id(dec_router_frame_id), // 输入 i_search_frame_id 用 dec_router_frame_id
		.i_search_sample_index(dec_router_sample_index), // 输入 i_search_sample_index 用 dec_router_sample_index
		.i_search_color_ir(flag_router_color_ir), // 输入 i_search_color_ir 用 flag_router_color_ir
		.i_search_frame_type(dec_router_frame_type), // 输入 i_search_frame_type 用 dec_router_frame_type
		.i_search_amb_code_snapshot(dec_router_amb_code_snapshot), // 输入 i_search_amb_code_snapshot 用 dec_router_amb_code_snapshot
		.i_search_dc_code_snapshot(dec_router_dc_code_snapshot), // 输入 i_search_dc_code_snapshot 用 dec_router_dc_code_snapshot
		.i_search_amb_code_epoch(dec_router_amb_code_epoch), // 输入 i_search_amb_code_epoch 用 dec_router_amb_code_epoch
		.i_search_dc_code_epoch(dec_router_dc_code_epoch), // 输入 i_search_dc_code_epoch 用 dec_router_dc_code_epoch
		.i_track_valid(flag_track_branch_valid && !flag_result_abort_discard), // abort时禁止NORMAL跟踪结果改变慢速IDAC状态
		.o_track_ready(flag_track_branch_ready), // 输出 o_track_ready 到 flag_track_branch_ready
		.i_track_calibrated_s1_value(flag_track_s1_value), // 输入 i_track_calibrated_s1_value 用 flag_track_s1_value
		.i_track_calibration_applied(flag_track_calibration_applied), // 输入 i_track_calibration_applied 用 flag_track_calibration_applied
		.i_track_saturation_low(flag_track_saturation_low), // 输入 i_track_saturation_low 用 flag_track_saturation_low
		.i_track_saturation_high(flag_track_saturation_high), // 输入 i_track_saturation_high 用 flag_track_saturation_high
		.i_track_config_epoch(flag_track_config_epoch), // 输入 i_track_config_epoch 用 flag_track_config_epoch
		.i_track_coef_epoch(flag_track_coef_epoch), // 输入 i_track_coef_epoch 用 flag_track_coef_epoch
		.i_track_precision_mode(flag_track_precision_mode), // 输入 i_track_precision_mode 用 flag_track_precision_mode
		.i_track_frame_id(flag_track_frame_id), // 输入 i_track_frame_id 用 flag_track_frame_id
		.i_track_sample_index(flag_track_sample_index), // 输入 i_track_sample_index 用 flag_track_sample_index
		.i_track_color_ir(flag_track_color_ir), // 输入 i_track_color_ir 用 flag_track_color_ir
		.i_track_frame_type(flag_track_frame_type), // 输入 i_track_frame_type 用 flag_track_frame_type
		.i_track_amb_code_snapshot(flag_track_amb_code_snapshot), // 输入 i_track_amb_code_snapshot 用 flag_track_amb_code_snapshot
		.i_track_dc_code_snapshot(flag_track_dc_code_snapshot), // 输入 i_track_dc_code_snapshot 用 flag_track_dc_code_snapshot
		.i_track_amb_code_epoch(flag_track_amb_code_epoch), // 输入 i_track_amb_code_epoch 用 flag_track_amb_code_epoch
		.i_track_dc_code_epoch(flag_track_dc_code_epoch), // 输入 i_track_dc_code_epoch 用 flag_track_dc_code_epoch
		.i_amb_sequence_start(enc_amb_sequence_start_qualified), // 仅NORMAL_TRACK允许周期AMB启动
		.o_amb_sample_request(flag_idac_amb_sample_request), // 输出 o_amb_sample_request 到 flag_idac_amb_sample_request
		.o_amb_sequence_busy(flag_idac_amb_seq_busy), // 输出 o_amb_sequence_busy 到 flag_idac_amb_seq_busy
		.o_amb_sequence_done(flag_idac_amb_seq_done), // 输出 o_amb_sequence_done 到 flag_idac_amb_seq_done
		.o_amb_sequence_failed(flag_idac_amb_seq_failed), // 输出 o_amb_sequence_failed 到 flag_idac_amb_seq_failed
		.o_dcs_sample_request(flag_idac_dcs_sample_request), // 输出 o_dcs_sample_request 到 flag_idac_dcs_sample_request
		.o_dcs_sample_color_ir(flag_idac_dcs_sample_color_ir), // 输出 o_dcs_sample_color_ir 到 flag_idac_dcs_sample_color_ir
		.o_dcs_revalidate_request(flag_idac_dcs_revalidate_request), // 输出 o_dcs_revalidate_request 到 flag_idac_dcs_revalidate_request
		.i_dcs_revalidate_accept(flag_dcs_revalidate_accept_qualified), // 仅NORMAL_TRACK允许周期DC重验证接管
		.o_dcs_revalidate_busy(flag_idac_dcs_revalidate_busy), // 输出 o_dcs_revalidate_busy 到 flag_idac_dcs_revalidate_busy
		.o_dcs_revalidate_done(flag_idac_dcs_revalidate_done), // 输出 o_dcs_revalidate_done 到 flag_idac_dcs_revalidate_done
		.o_dcs_revalidate_failed(flag_idac_dcs_revalidate_failed), // 输出 o_dcs_revalidate_failed 到 flag_idac_dcs_revalidate_failed
		.o_amb_code(amb_code_o),                // 输出 o_amb_code 到 amb_code_o
		.o_dcs_r_code(dcs_r_code_o),            // 输出 o_dcs_r_code 到 dcs_r_code_o
		.o_dcs_ir_code(dcs_ir_code_o),          // 输出 o_dcs_ir_code 到 dcs_ir_code_o
		.o_amb_code_epoch(amb_code_epoch_o),    // 输出 o_amb_code_epoch 到 amb_code_epoch_o
		.o_dcs_r_code_epoch(dcs_r_code_epoch_o), // 输出 o_dcs_r_code_epoch 到 dcs_r_code_epoch_o
		.o_dcs_ir_code_epoch(dcs_ir_code_epoch_o), // 输出 o_dcs_ir_code_epoch 到 dcs_ir_code_epoch_o
		.o_amb_code_update(amb_code_update_o),  // 输出 o_amb_code_update 到 amb_code_update_o
		.o_dcs_r_code_update(dcs_r_code_update_o), // 输出 o_dcs_r_code_update 到 dcs_r_code_update_o
		.o_dcs_ir_code_update(dcs_ir_code_update_o), // 输出 o_dcs_ir_code_update 到 dcs_ir_code_update_o
		.o_dcs_r_track_adjust(dcs_r_track_adjust_o), // 输出 o_dcs_r_track_adjust 到 dcs_r_track_adjust_o
		.o_dcs_ir_track_adjust(dcs_ir_track_adjust_o), // 输出 o_dcs_ir_track_adjust 到 dcs_ir_track_adjust_o
		.o_amb_search_done(amb_search_done_o),  // 输出 o_amb_search_done 到 amb_search_done_o
		.o_dcs_r_search_done(dcs_r_search_done_o), // 输出 o_dcs_r_search_done 到 dcs_r_search_done_o
		.o_dcs_ir_search_done(dcs_ir_search_done_o), // 输出 o_dcs_ir_search_done 到 dcs_ir_search_done_o
		.o_amb_search_exhausted(amb_search_exhausted_o), // 输出 o_amb_search_exhausted 到 amb_search_exhausted_o
		.o_dcs_r_search_exhausted(dcs_r_search_exhausted_o), // 输出 o_dcs_r_search_exhausted 到 dcs_r_search_exhausted_o
		.o_dcs_ir_search_exhausted(dcs_ir_search_exhausted_o), // 输出 o_dcs_ir_search_exhausted 到 dcs_ir_search_exhausted_o
		.o_amb_pending_valid(amb_pending_valid_o), // 输出 o_amb_pending_valid 到 amb_pending_valid_o
		.o_dcs_r_pending_valid(dcs_r_pending_valid_o), // 输出 o_dcs_r_pending_valid 到 dcs_r_pending_valid_o
		.o_dcs_ir_pending_valid(dcs_ir_pending_valid_o), // 输出 o_dcs_ir_pending_valid 到 dcs_ir_pending_valid_o
		.o_amb_code_at_min(amb_code_at_min_o),  // 输出 o_amb_code_at_min 到 amb_code_at_min_o
		.o_amb_code_at_max(amb_code_at_max_o),  // 输出 o_amb_code_at_max 到 amb_code_at_max_o
		.o_dcs_r_code_at_min(dcs_r_code_at_min_o), // 输出 o_dcs_r_code_at_min 到 dcs_r_code_at_min_o
		.o_dcs_r_code_at_max(dcs_r_code_at_max_o), // 输出 o_dcs_r_code_at_max 到 dcs_r_code_at_max_o
		.o_dcs_ir_code_at_min(dcs_ir_code_at_min_o), // 输出 o_dcs_ir_code_at_min 到 dcs_ir_code_at_min_o
		.o_dcs_ir_code_at_max(dcs_ir_code_at_max_o), // 输出 o_dcs_ir_code_at_max 到 dcs_ir_code_at_max_o
		.o_amb_fault(amb_fault_o),              // 输出 o_amb_fault 到 amb_fault_o
		.o_dcs_r_fault(dcs_r_fault_o),          // 输出 o_dcs_r_fault 到 dcs_r_fault_o
		.o_dcs_ir_fault(dcs_ir_fault_o),        // 输出 o_dcs_ir_fault 到 dcs_ir_fault_o
		.o_controller_fault_blocking(flag_idac_fault_active), // 汇总三路故障作为cause 8'h05的lane-active保持电平；IDAC child→AMI私有flag,链路终段 @satisfies: K01
		.o_controller_fault_event(flag_idac_fault_event), // 接住结果，作为cause 8'h05分发器的置位触发源
		.o_controller_fault_identity_valid(flag_idac_fault_identity_valid), // 本次故障是否绑定了真实搜索样本身份
		.o_controller_fault_frame_id(flag_idac_fault_frame_id), // 故障样本所属帧号
		.o_controller_fault_sample_index(flag_idac_fault_sample_index), // 故障样本全局序号
		.o_controller_fault_color_ir(flag_idac_fault_color_ir), // 故障样本颜色
		.o_controller_fault_frame_type(flag_idac_fault_frame_type), // 故障样本类型
		.o_controller_fault_precision(flag_idac_fault_precision), // 故障样本精度
		.o_controller_fault_run_generation(flag_idac_fault_run_generation), // 故障样本所属RUN代际
		.o_protocol_error_sticky(idac_protocol_error_sticky_o), // 输出 o_protocol_error_sticky 到 idac_protocol_error_sticky_o
		.o_startup_search_complete(startup_search_complete_o), // 输出 o_startup_search_complete 到 startup_search_complete_o
		.o_idac_idle(idac_idle_o)               // 输出 o_idac_idle 到 idac_idle_o
	);

	// 精度窗口集成使用DC恢复粗结果，并在安全接管后调度固定AMB、DC_R、DC_IR序列。
	ppg_precision_window_integration #(
		.C_DATA_WIDTH(C_DATA_WIDTH),            // 参数 C_DATA_WIDTH 用 C_DATA_WIDTH
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 参数 C_CONFIG_EPOCH_WIDTH 用 C_CONFIG_EPOCH_WIDTH
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 参数 C_COEF_EPOCH_WIDTH 用 C_COEF_EPOCH_WIDTH
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // 参数 C_DC_RECOVERY_EPOCH_WIDTH 用 C_DC_RECOVERY_EPOCH_WIDTH
		.C_SLOPE_WIDTH(C_SLOPE_WIDTH),          // 参数 C_SLOPE_WIDTH 用 C_SLOPE_WIDTH
		.C_BASELINE_WIDTH(C_BASELINE_WIDTH),    // 参数 C_BASELINE_WIDTH 用 C_BASELINE_WIDTH
		.C_RATIO_WIDTH(C_RATIO_WIDTH),          // 参数 C_RATIO_WIDTH 用 C_RATIO_WIDTH
		.C_CONFIRM_COUNT_WIDTH(C_CONFIRM_COUNT_WIDTH), // 参数 C_CONFIRM_COUNT_WIDTH 用 C_CONFIRM_COUNT_WIDTH
		.C_INTERVAL_WIDTH(C_INTERVAL_WIDTH),    // 参数 C_INTERVAL_WIDTH 用 C_INTERVAL_WIDTH
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH), // 参数 C_RUN_GENERATION_WIDTH 用 C_RUN_GENERATION_WIDTH
		.C_ENABLE_TEST_INJECTION(C_ENABLE_TEST_INJECTION) // PWI/FIR验证注入结构生成开关，逐层透传自AMI参数，生产网表恒为0

	// 精度窗口单元联合FIR、基线、峰谷和重检调度状态。
	)ppg_precision_window_integration_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_run_enable(i_run_enable),            // 输入 i_run_enable 用 i_run_enable
		.i_start_ack_event(i_start_ack_event),  // 输入 i_start_ack_event 用 i_start_ack_event
		.i_diag_clear_event(i_diag_clear_event), // 输入 i_diag_clear_event 用 i_diag_clear_event
		.i_detection_discard_event(flag_detection_discard_trigger), // AMI私有检测代际清空事件，无ready/ack
		.i_detection_discard_reason(flag_terminal_discard_reason), // 清空原因分类，取值含STOP排空、abort撤销、系统故障三类
		.i_detection_discard_identity_valid(flag_detection_discard_identity_valid), // 触发事务身份是否可信，命中当前保留检测分支事务时为1
		.i_detection_discard_sample_valid(flag_detection_discard_sample_valid), // PWI消费端接住独立样本资格连线
		.i_detection_discard_frame_id(flag_detection_discard_frame_id), // PWI消费端接住物理帧号连线
		.i_detection_discard_sample_index(flag_detection_discard_sample_index), // PWI消费端接住全局序号连线
		.i_detection_discard_color_ir(flag_detection_discard_color_ir), // PWI消费端接住颜色身份连线
		.i_detection_discard_frame_type(flag_detection_discard_frame_type), // PWI消费端接住帧类型连线
		.i_detection_discard_precision(flag_detection_discard_precision), // PWI消费端接住精度模式连线
		.i_detection_discard_config_epoch(flag_detection_discard_config_epoch), // PWI消费端接住ACTIVE版本连线，仅诊断用途
		.i_detection_discard_coef_epoch(flag_detection_discard_coef_epoch), // PWI消费端接住系数版本连线，仅诊断用途
		.i_detection_discard_dc_recovery_epoch(flag_detection_discard_dc_recovery_epoch), // PWI消费端接住DC恢复版本连线，仅诊断用途
		.i_detection_discard_amb_code_epoch(flag_detection_discard_amb_code_epoch), // PWI消费端接住环境光抵消码版本连线，仅诊断用途
		.i_detection_discard_dc_code_epoch(flag_detection_discard_dc_code_epoch), // PWI消费端接住颜色DC码版本连线，仅诊断用途
		.i_detection_discard_run_generation(i_run_generation), // PWI拿它与自身i_run_generation比较，判定是否命中当前代际
		.i_run_generation(i_run_generation),    // AMI逐层传入的当前RUN代际
		.o_detection_datapath_empty(flag_pwi_detection_datapath_empty), // fork、FIR、基线、峰谷、精度控制器和discard广播状态全部排空时为高
		.i_active_config_valid(i_active_config_valid), // 输入 i_active_config_valid 用 i_active_config_valid
		.i_run_profile(i_run_profile),          // 输入 i_run_profile 用 i_run_profile
		.i_initial_precision(i_initial_precision), // 输入 i_initial_precision 用 i_initial_precision
		.i_normal_measurement_active(flag_normal_measurement_active_qualified), // 仅NORMAL_PPG进入精度和重检累计
		.i_slope_mode(i_slope_mode),            // 输入 i_slope_mode 用 i_slope_mode
		.i_fixed_slope_q16(i_fixed_slope_q16),  // 输入 i_fixed_slope_q16 用 i_fixed_slope_q16
		.i_alpha_q15(i_alpha_q15),              // 输入 i_alpha_q15 用 i_alpha_q15
		.i_beta_q15(i_beta_q15),                // 输入 i_beta_q15 用 i_beta_q15
		.i_timing_adjust_ratio_q15(i_timing_adjust_ratio_q15), // 输入 i_timing_adjust_ratio_q15 用 i_timing_adjust_ratio_q15
		.i_slope_min_q16(i_slope_min_q16),      // 输入 i_slope_min_q16 用 i_slope_min_q16
		.i_slope_max_q16(i_slope_max_q16),      // 输入 i_slope_max_q16 用 i_slope_max_q16
		.i_baseline_delta_q16(i_baseline_delta_q16), // 输入 i_baseline_delta_q16 用 i_baseline_delta_q16
		.i_cross_hysteresis_q16(i_cross_hysteresis_q16), // 输入 i_cross_hysteresis_q16 用 i_cross_hysteresis_q16
		.i_lead_min_frames(i_lead_min_frames),  // 输入 i_lead_min_frames 用 i_lead_min_frames
		.i_lead_max_frames(i_lead_max_frames),  // 输入 i_lead_max_frames 用 i_lead_max_frames
		.i_cross_confirm_count(i_cross_confirm_count), // 输入 i_cross_confirm_count 用 i_cross_confirm_count
		.i_no_cross_limit(i_no_cross_limit),    // 输入 i_no_cross_limit 用 i_no_cross_limit
		.i_peak_confirm_count(i_peak_confirm_count), // 输入 i_peak_confirm_count 用 i_peak_confirm_count
		.i_valley_confirm_count(i_valley_confirm_count), // 输入 i_valley_confirm_count 用 i_valley_confirm_count
		.i_direction_deadband(i_direction_deadband), // 输入 i_direction_deadband 用 i_direction_deadband
		.i_min_peak_valley_amplitude(i_min_peak_valley_amplitude), // 输入 i_min_peak_valley_amplitude 用 i_min_peak_valley_amplitude
		.i_min_peak_to_valley_frames(i_min_peak_to_valley_frames), // 输入 i_min_peak_to_valley_frames 用 i_min_peak_to_valley_frames
		.i_min_peak_to_peak_frames(i_min_peak_to_peak_frames), // 输入 i_min_peak_to_peak_frames 用 i_min_peak_to_peak_frames
		.i_max_fine_window_frames(i_max_fine_window_frames), // 输入 i_max_fine_window_frames 用 i_max_fine_window_frames
		.i_max_reacquire_frames(i_max_reacquire_frames), // 输入 i_max_reacquire_frames 用 i_max_reacquire_frames
		.i_peak_valley_config_valid(i_peak_valley_config_valid), // AMI原样转发V5正式检测资格给PWI，是unpacker->AMI->PWI->C20/C22/C23唯一通路上的中段直通，不产生第二生产者 @satisfies: G-FP-01-D01-04
		.i_idac_mode(i_idac_mode),              // 输入 i_idac_mode 用 i_idac_mode
		.i_amb_enable(i_amb_enable),            // 输入 i_amb_enable 用 i_amb_enable
		.i_dcs_enable(i_dcs_enable),            // 输入 i_dcs_enable 用 i_dcs_enable
		.i_amb_recheck_interval_frames(i_amb_recheck_interval_frames), // 输入 i_amb_recheck_interval_frames 用 i_amb_recheck_interval_frames
		.i_normal_result_valid(flag_detection_pending && !flag_result_abort_discard), // 输入 i_normal_result_valid 用 flag_detection_pending && !flag_result_abort_discard
		.i_sample_valid(result_sample_valid_o), // 独立资格随检测fork保持，不得改写fork ready
		.o_normal_result_ready(flag_precision_normal_result_ready), // 输出 o_normal_result_ready 到 flag_precision_normal_result_ready
		.i_coarse_ppg_value(o_coarse_ppg_value), // 输入 i_coarse_ppg_value 用 o_coarse_ppg_value
		.i_coarse_valid(o_coarse_valid),        // 输入 i_coarse_valid 用 o_coarse_valid
		.i_coarse_recovery_calibrated(o_coarse_recovery_calibrated), // 输入 i_coarse_recovery_calibrated 用 o_coarse_recovery_calibrated
		.i_stage1_saturation_low(flag_unused_output_s1_sat_low), // 输入 i_stage1_saturation_low 用 flag_unused_output_s1_sat_low
		.i_stage1_saturation_high(flag_unused_output_s1_sat_high), // 输入 i_stage1_saturation_high 用 flag_unused_output_s1_sat_high
		.i_coarse_saturation_low(o_coarse_saturation_low), // 输入 i_coarse_saturation_low 用 o_coarse_saturation_low
		.i_coarse_saturation_high(o_coarse_saturation_high), // 输入 i_coarse_saturation_high 用 o_coarse_saturation_high
		.i_config_epoch(o_config_epoch),        // 输入 i_config_epoch 用 o_config_epoch
		.i_coef_epoch(o_coef_epoch),            // 输入 i_coef_epoch 用 o_coef_epoch
		.i_dc_recovery_coef_epoch(o_dc_result_coef_epoch), // 输入 i_dc_recovery_coef_epoch 用 o_dc_result_coef_epoch
		.i_precision_mode(o_result_precision_mode), // 输入 i_precision_mode 用 o_result_precision_mode
		.i_frame_id(o_result_frame_id),         // 输入 i_frame_id 用 o_result_frame_id
		.i_sample_index(o_result_sample_index), // 输入 i_sample_index 用 o_result_sample_index
		.i_color_ir(o_result_color_ir),         // 输入 i_color_ir 用 o_result_color_ir
		.i_frame_type(o_result_frame_type),     // 输入 i_frame_type 用 o_result_frame_type
		.i_amb_code_snapshot(o_result_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 o_result_amb_code_snapshot
		.i_dc_code_snapshot(o_result_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 o_result_dc_code_snapshot
		.i_amb_code_epoch(o_result_amb_code_epoch), // 输入 i_amb_code_epoch 用 o_result_amb_code_epoch
		.i_dc_code_epoch(o_result_dc_code_epoch), // 输入 i_dc_code_epoch 用 o_result_dc_code_epoch
		.i_frame_safe_boundary(i_macro_frame_safe_boundary), // 精度与重检仅消费宏帧边界
		.i_safe_frame_id(i_safe_frame_id),      // 输入 i_safe_frame_id 用 i_safe_frame_id
		.i_precision_takeover_safe(flag_precision_takeover_safe), // 输入 i_precision_takeover_safe 用 flag_precision_takeover_safe
		.i_analog_safe(i_analog_safe),          // 输入 i_analog_safe 用 i_analog_safe
		.i_normal_fork_idle(o_normal_fork_idle), // 输入 i_normal_fork_idle 用 o_normal_fork_idle
		.i_idac_idle(idac_idle_o),              // 输入 i_idac_idle 用 idac_idle_o
		.i_startup_search_complete(startup_search_complete_o), // 输入 i_startup_search_complete 用 startup_search_complete_o
		.i_normal_frame_complete_event(i_normal_frame_complete_event), // 输入 i_normal_frame_complete_event 用 i_normal_frame_complete_event
		.i_calibration_frame_complete_event(i_calibration_frame_complete_event), // 输入 i_calibration_frame_complete_event 用 i_calibration_frame_complete_event
		.i_amb_sample_request(flag_idac_amb_sample_request), // 输入 i_amb_sample_request 用 flag_idac_amb_sample_request
		.i_amb_sequence_done(flag_idac_amb_seq_done), // 输入 i_amb_sequence_done 用 flag_idac_amb_seq_done
		.i_amb_sequence_failed(flag_idac_amb_seq_failed), // 输入 i_amb_sequence_failed 用 flag_idac_amb_seq_failed
		.i_dcs_revalidate_request(flag_idac_dcs_revalidate_request), // 输入 i_dcs_revalidate_request 用 flag_idac_dcs_revalidate_request
		.i_dcs_sample_request(flag_idac_dcs_sample_request), // 输入 i_dcs_sample_request 用 flag_idac_dcs_sample_request
		.i_dcs_sample_color_ir(flag_idac_dcs_sample_color_ir), // 输入 i_dcs_sample_color_ir 用 flag_idac_dcs_sample_color_ir
		.i_dcs_revalidate_done(flag_idac_dcs_revalidate_done), // 输入 i_dcs_revalidate_done 用 flag_idac_dcs_revalidate_done
		.i_dcs_revalidate_failed(flag_idac_dcs_revalidate_failed), // 输入 i_dcs_revalidate_failed 用 flag_idac_dcs_revalidate_failed
		.i_amb_sample_accepted_event(flag_amb_sample_accepted), // 输入 i_amb_sample_accepted_event 用 flag_amb_sample_accepted
		.i_dcs_sample_accepted_event(flag_dcs_sample_accepted), // 输入 i_dcs_sample_accepted_event 用 flag_dcs_sample_accepted
		.o_amb_sequence_start(flag_precision_amb_seq_start), // 输出 o_amb_sequence_start 到 flag_precision_amb_seq_start
		.o_dcs_revalidate_accept(flag_precision_dcs_revalidate_accept), // 输出 o_dcs_revalidate_accept 到 flag_precision_dcs_revalidate_accept
		.i_calibration_sample_ready(flag_precision_calibration_ready), // 输入 i_calibration_sample_ready 用 flag_precision_calibration_ready
		.o_calibration_sample_valid(flag_precision_calibration_valid), // 输出 o_calibration_sample_valid 到 flag_precision_calibration_valid
		.o_calibration_frame_type(dec_precision_calibration_frame_type), // 输出 o_calibration_frame_type 到 dec_precision_calibration_frame_type
		.o_calibration_color_ir(flag_precision_calibration_color_ir), // 输出 o_calibration_color_ir 到 flag_precision_calibration_color_ir
		.o_calibration_precision_mode(),        // 留空 o_calibration_precision_mode
		.o_calibration_frame_start(),           // 留空 o_calibration_frame_start
		.o_calibration_stage(),                 // 留空 o_calibration_stage
		.o_active_precision_mode(active_precision_mode_o), // 输出 o_active_precision_mode 到 active_precision_mode_o
		.o_fine_window_active(fine_window_active_o), // 输出 o_fine_window_active 到 fine_window_active_o
		.o_fine_window_start_event(fine_window_start_event_o), // 输出 o_fine_window_start_event 到 fine_window_start_event_o
		.o_fine_window_start_frame_id(fine_window_start_frame_id_o), // 输出 o_fine_window_start_frame_id 到 fine_window_start_frame_id_o
		.o_precision_15_to_9_event(precision_15_to_9_event_o), // 输出 o_precision_15_to_9_event 到 precision_15_to_9_event_o
		.o_precision_15_to_9_frame_id(precision_15_to_9_frame_id_o), // 输出 o_precision_15_to_9_frame_id 到 precision_15_to_9_frame_id_o
		.o_reacquire_request_event(reacquire_request_event_o), // 输出 o_reacquire_request_event 到 reacquire_request_event_o
		.o_switch_hold_new_transaction(switch_hold_new_transaction_o), // 输出 o_switch_hold_new_transaction 到 switch_hold_new_transaction_o
		.o_mode_fault_event(flag_precision_fault_event), // 输出 o_mode_fault_event 到 flag_precision_fault_event
		.o_mode_fault_active(flag_precision_fault_active), // 当前RUN代际精度阻断故障保持电平，驱动cause 8'h04的lane-active；PWI输出→AMI私有flag,链路终段 @satisfies: K01
		.o_mode_fault_identity_valid(flag_precision_fault_identity_valid), // 精度阻断故障是否绑定真实事务身份
		.o_mode_fault_frame_id(flag_precision_fault_frame_id), // 接住帧号结果，留给AMI分发器组装cause 8'h04记录
		.o_mode_fault_sample_index(flag_precision_fault_sample_index), // 接住序号结果，留给AMI分发器组装cause 8'h04记录
		.o_mode_fault_color_ir(flag_precision_fault_color_ir), // 精度阻断故障绑定事务颜色
		.o_mode_fault_frame_type(flag_precision_fault_frame_type), // 精度阻断故障绑定事务类别
		.o_mode_fault_precision(flag_precision_fault_precision), // 接住精度模式结果，留给AMI分发器组装cause 8'h04记录
		.o_mode_fault_run_generation(flag_precision_fault_run_generation), // 接住RUN代际结果，留给AMI分发器组装cause 8'h04记录
		.o_normal_frame_count(cnt_normal_frame_o), // 输出 o_normal_frame_count 到 cnt_normal_frame_o
		.o_amb_recheck_pending(amb_recheck_pending_o), // 输出 o_amb_recheck_pending 到 amb_recheck_pending_o
		.o_amb_recheck_accept(amb_recheck_accept_o), // 输出 o_amb_recheck_accept 到 amb_recheck_accept_o
		.o_amb_recheck_busy(amb_recheck_busy_o), // 输出 o_amb_recheck_busy 到 amb_recheck_busy_o
		.o_normal_output_inhibit(normal_output_inhibit_o), // 输出 o_normal_output_inhibit 到 normal_output_inhibit_o
		.o_recheck_sequence_done(recheck_seq_done_o), // 输出 o_recheck_sequence_done 到 recheck_seq_done_o
		.o_recheck_sequence_failed(recheck_seq_failed_o), // 输出 o_recheck_sequence_failed 到 recheck_seq_failed_o
		.o_fir_history_full_r(fir_history_full_r_o), // 输出 o_fir_history_full_r 到 fir_history_full_r_o
		.o_fir_history_full_ir(fir_history_full_ir_o), // 输出 o_fir_history_full_ir 到 fir_history_full_ir_o
		.o_fir_idle(fir_idle_o),                // 输出 o_fir_idle 到 fir_idle_o
		.o_detection_fork_idle(detection_fork_idle_o), // 输出 o_detection_fork_idle 到 detection_fork_idle_o
		.o_detector_idle(detector_idle_o),      // 输出 o_detector_idle 到 detector_idle_o
		.o_controller_idle(controller_idle_o),  // 输出 o_controller_idle 到 controller_idle_o
		.o_scheduler_idle(scheduler_idle_o),    // 输出 o_scheduler_idle 到 scheduler_idle_o
		.o_cross_pending(cross_pending_o),      // 输出 o_cross_pending 到 cross_pending_o
		.o_peak_pending(peak_pending_o),        // 输出 o_peak_pending 到 peak_pending_o
		.o_valley_pending(valley_pending_o),    // 输出 o_valley_pending 到 valley_pending_o
		.o_return_pending(return_pending_o),    // 输出 o_return_pending 到 return_pending_o
		.o_baseline_valid(baseline_valid_o),    // 输出 o_baseline_valid 到 baseline_valid_o
		.o_reacquire_active(reacquire_active_o), // 输出 o_reacquire_active 到 reacquire_active_o
		.o_detector_fine_window_active(detector_fine_window_active_o), // 输出 o_detector_fine_window_active 到 detector_fine_window_active_o
		.o_switch_pending(switch_pending_o),    // 输出 o_switch_pending 到 switch_pending_o
		.o_switch_target_precision(switch_target_precision_o), // 输出 o_switch_target_precision 到 switch_target_precision_o
		.o_slope_current_q16(slope_current_q16_o), // 输出 o_slope_current_q16 到 slope_current_q16_o
		.o_baseline_protocol_error_sticky(baseline_protocol_error_sticky_o), // 输出 o_baseline_protocol_error_sticky 到 baseline_protocol_error_sticky_o
		.o_fine_window_timeout_sticky(fine_window_timeout_sticky_o), // 输出 o_fine_window_timeout_sticky 到 fine_window_timeout_sticky_o
		.o_reacquire_timeout_sticky(reacquire_timeout_sticky_o), // 输出 o_reacquire_timeout_sticky 到 reacquire_timeout_sticky_o
		.o_peak_valley_protocol_error_sticky(peak_valley_protocol_error_sticky_o), // 输出 o_peak_valley_protocol_error_sticky 到 peak_valley_protocol_error_sticky_o
		.o_switch_timeout_sticky(switch_timeout_sticky_o), // 输出 o_switch_timeout_sticky 到 switch_timeout_sticky_o
		.o_precision_protocol_error_sticky(precision_protocol_error_sticky_o), // 输出 o_precision_protocol_error_sticky 到 precision_protocol_error_sticky_o
		.i_test_inject_enable(flag_test_inject_effective), // 复用AMI自身既有的CONFIG/READY期间锁存请求，与IDAC控制器同一模式
		.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid), // 直通AMI顶层calibration-loss注入请求valid
		.o_test_calibration_loss_inject_ready(o_test_calibration_loss_inject_ready) // 直通PWI/FIR的注入绑定ready
	);

	//===================<模块实例化区域>===================//
	// 异步捕获器同步DONE电平，并按事务精度等待相应物理结果。
	ppg_adc_async_stage_capture ppg_adc_async_stage_capture_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_adc_transaction_start(o_transaction_start_fire), // 输入 i_adc_transaction_start 用 o_transaction_start_fire
		.i_precision_mode_committed(i_transaction_precision_mode), // 输入 i_precision_mode_committed 用 i_transaction_precision_mode
		.i_dout_stage1_low(i_dout_stage1_low),  // 输入 i_dout_stage1_low 用 i_dout_stage1_low
		.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async), // 输入 i_clk_stage1_dout_low_async 用 i_clk_stage1_dout_low_async
		.i_dout_stage2_low(i_dout_stage2_low),  // 输入 i_dout_stage2_low 用 i_dout_stage2_low
		.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async), // 输入 i_clk_stage2_dout_low_async 用 i_clk_stage2_dout_low_async
		.i_capture_ready(flag_capture_ready),   // 输入 i_capture_ready 用 flag_capture_ready
		.o_capture_stage1_raw(dec_capture_stage1_raw), // 输出 o_capture_stage1_raw 到 dec_capture_stage1_raw
		.o_capture_stage2_raw(dec_capture_stage2_raw), // 输出 o_capture_stage2_raw 到 dec_capture_stage2_raw
		.o_capture_precision_mode(flag_capture_precision_mode), // 输出 o_capture_precision_mode 到 flag_capture_precision_mode
		.o_capture_valid(flag_capture_valid)    // 输出 o_capture_valid 到 flag_capture_valid
	);

	// 固定冗余重构器与capture共用同一start fire以原子绑定上下文。
	ppg_adc_s1_redundancy_corrector
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 参数 C_FRAME_ID_WIDTH 用 C_FRAME_ID_WIDTH
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 参数 C_SAMPLE_INDEX_WIDTH 用 C_SAMPLE_INDEX_WIDTH
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 参数 C_IDAC_CODE_WIDTH 用 C_IDAC_CODE_WIDTH
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH) // 参数 C_CODE_EPOCH_WIDTH 用 C_CODE_EPOCH_WIDTH

	// Stage1冗余修正单元绑定ADC启动上下文与异步捕获结果。
	)ppg_adc_s1_redundancy_corrector_Inst(
		.i_clk(i_clk),                          // 输入 i_clk 用 i_clk
		.i_rstn(i_rstn),                        // 输入 i_rstn 用 i_rstn
		.i_adc_transaction_start(o_transaction_start_fire), // 输入 i_adc_transaction_start 用 o_transaction_start_fire
		.i_frame_id(i_transaction_frame_id),    // 输入 i_frame_id 用 i_transaction_frame_id
		.i_sample_index(i_transaction_sample_index), // 输入 i_sample_index 用 i_transaction_sample_index
		.i_color_ir(i_transaction_color_ir),    // 输入 i_color_ir 用 i_transaction_color_ir
		.i_frame_type(i_transaction_frame_type), // 输入 i_frame_type 用 i_transaction_frame_type
		.i_amb_code_snapshot(i_transaction_amb_code_snapshot), // 输入 i_amb_code_snapshot 用 i_transaction_amb_code_snapshot
		.i_dc_code_snapshot(i_transaction_dc_code_snapshot), // 输入 i_dc_code_snapshot 用 i_transaction_dc_code_snapshot
		.i_amb_code_epoch(i_transaction_amb_code_epoch), // 输入 i_amb_code_epoch 用 i_transaction_amb_code_epoch
		.i_dc_code_epoch(i_transaction_dc_code_epoch), // 输入 i_dc_code_epoch 用 i_transaction_dc_code_epoch
		.i_capture_stage1_raw(dec_capture_stage1_raw), // 输入 i_capture_stage1_raw 用 dec_capture_stage1_raw
		.i_capture_stage2_raw(dec_capture_stage2_raw), // 输入 i_capture_stage2_raw 用 dec_capture_stage2_raw
		.i_capture_precision_mode(flag_capture_precision_mode), // 输入 i_capture_precision_mode 用 flag_capture_precision_mode
		.i_capture_valid(flag_capture_valid),   // 输入 i_capture_valid 用 flag_capture_valid
		.i_detect_ready(flag_s1_detect_ready),  // 输入 i_detect_ready 用 flag_s1_detect_ready
		.o_transaction_ready(flag_s1_transaction_ready), // 输出 o_transaction_ready 到 flag_s1_transaction_ready
		.o_capture_ready(flag_capture_ready),   // 输出 o_capture_ready 到 flag_capture_ready
		.o_detect_code(dec_s1_detect_code),     // 输出 o_detect_code 到 dec_s1_detect_code
		.o_stage1_raw(dec_s1_stage1_raw),       // 输出 o_stage1_raw 到 dec_s1_stage1_raw
		.o_stage1_code_ext(dec_s1_stage1_code_ext), // 输出 o_stage1_code_ext 到 dec_s1_stage1_code_ext
		.o_stage2_raw(dec_s1_stage2_raw),       // 输出 o_stage2_raw 到 dec_s1_stage2_raw
		.o_precision_mode(flag_s1_precision_mode), // 输出 o_precision_mode 到 flag_s1_precision_mode
		.o_detect_valid(flag_s1_detect_valid),  // 输出 o_detect_valid 到 flag_s1_detect_valid
		.o_frame_id(dec_s1_frame_id),           // 输出 o_frame_id 到 dec_s1_frame_id
		.o_sample_index(dec_s1_sample_index),   // 输出 o_sample_index 到 dec_s1_sample_index
		.o_color_ir(flag_s1_color_ir),          // 输出 o_color_ir 到 flag_s1_color_ir
		.o_frame_type(dec_s1_frame_type),       // 输出 o_frame_type 到 dec_s1_frame_type
		.o_amb_code_snapshot(dec_s1_amb_code_snapshot), // 输出 o_amb_code_snapshot 到 dec_s1_amb_code_snapshot
		.o_dc_code_snapshot(dec_s1_dc_code_snapshot), // 输出 o_dc_code_snapshot 到 dec_s1_dc_code_snapshot
		.o_amb_code_epoch(dec_s1_amb_code_epoch), // 输出 o_amb_code_epoch 到 dec_s1_amb_code_epoch
		.o_dc_code_epoch(dec_s1_dc_code_epoch)  // 输出 o_dc_code_epoch 到 dec_s1_dc_code_epoch
	);

endmodule
