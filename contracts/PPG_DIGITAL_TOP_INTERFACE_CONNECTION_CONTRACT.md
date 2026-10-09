# PPG数字功能顶层接口连接合同

> V1.18 errata, 2026-10-09: B merge batch (`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-061, 111, 113, 116, 117; checked against baseline `7a8eabf` `ppg_control_top.v`; symbol anchors are "file + symbol (section)"). (1) §4.2 records the new Top output `o_ami_owner_lost_sticky` (owner-lifecycle round). (2) §4.2 port table: the public measurement-discard identity group is narrowed to `TXN_KEY` (F-008). (3) §4.1 V1.10: the frozen width/watchdog parameters are fixed product values checked at simulation start; RTL performs no elaboration reject (F-014/F-024). (4) §4.0/§4.1 V1.10: `flag_diag_clear_event` fans out to five direct consumers, including the characterization CDC (F-048). (5) The V1.3.4 status line "Scheduler FSC-01～57、AMI AMI-01～45和SSW SSW-01～52均已有当前单模块PASS证据" is dated history and, per the supersession note below, non-normative; it is kept unchanged. The unit-TB check labels do not all share meaning with the same-numbered contract IDs; the current evidence state is kept in the alias table and matrix §13. No port, width or connection changes beyond these records.
> V1.10 fail-closed integration review, 2026-08-20: the direct-child hierarchy, system-blocking manager gate, wrapper generation/stop-episode forwarding, supervisor boundary, clear, external-abort, discard and watchdog connections remain normative, but system closure is `NOT_CLOSED` until the matrix audit records zero defects. Implementation evidence is `EVIDENCE_PENDING`.
> V1.10 change record: replaces two nonexistent Scheduler input mappings with the only declared AMI and SSW blocking-gate paths; no Scheduler timing, owner, RAW or sample-index rule changes.
>
> V1.11 errata, 2026-08-31: package/top-level integration design session. Adds one new Top output, `o_active_precision_mode`, to Section 4.2 -- a pure pass-through of AMI's already-existing `o_active_precision_mode` (the same wire Scheduler `i_active_precision_mode` and SSW `i_precision_mode_committed` already consume internally), exposed at the Top boundary for the first time. This is a live, continuously-valid committed-precision level, distinct from the existing per-result snapshot `o_result_precision_mode`; it does not replace, gate, or reinterpret any existing output. User-confirmed rationale: the off-chip SPI/glue integration top (outside this module, not yet implemented) needs this signal for two purposes -- (1) selecting which physical ADC stage's DONE (Stage1 for 9-bit, Stage2 for 15-bit) feeds the dedicated single-point synchronizer that produces `i_adc_physical_idle`, confirming that Section 6.2.1's `flag_adc_physical_idle` formula is precision-mode-selected between Stage1/Stage2 DONE, not an unconditional AND of both; and (2) a fixed field in the P2S debug packet so lab test can identify which cycle belongs to which precision mode. Implemented in `ppg_control_top.v` V1.3 as a pure internal-wire-then-assign forward, same pattern as `o_ami_idac_idle`; no existing port, connection table, or safety-path rule changed. This errata does not close the V1.10 `NOT_CLOSED` gate and does not certify TOP-01~24 evidence.
>
> V1.12 errata, 2026-08-31: same session, second addition. Adds `o_source_config_update_ready` to Section 4.2 -- the ready-polarity complement of the internal wire `wrapper_config_transport_busy_o` (ACTIVE wrapper `o_config_transport_busy`, itself a pure forward of `ppg_config_cdc_bridge.o_source_busy`), exposed at the Top boundary for the first time. Closes the asymmetry between the two source-domain write channels: the characterization channel already had `o_source_characterization_update_ready` telling the SPI/glue-top source domain when its CDC mailbox can accept the next transaction, but the 1024-bit V4+V5 ACTIVE channel had no equivalent, forcing the glue top to guess a conservative worst-case pacing delay before re-pulsing `i_source_config_update_event`. User confirmed exposing it in `ready` polarity (matching the sibling signal), the one deliberate inversion in `ppg_control_top.v`: `o_source_config_update_ready = !wrapper_config_transport_busy_o`. Implemented in `ppg_control_top.v` V1.4; no ACTIVE wrapper (C03) change was needed since `o_config_transport_busy` already existed at its boundary and was already captured into this Top-internal wire. Smoke TB re-run bit-identical (`SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32`). This errata does not close the V1.10 `NOT_CLOSED` gate and does not certify TOP-01~24 evidence.
>
> V1.13 errata, 2026-09-02: Priority-1b acceptance-evidence reconciliation, not a new architecture or port change. Section 10's TOP-01~24 table gained a dated evidence-cross-reference block (each row now cites its real `tb_ppg_control_top.v`/`tb_ppg_control_top_injection.v`/`tb_ppg_control_top_startup_idac_calibration.v` scenario, plus the 2026-08-31 full-system audit for TOP-10's static hierarchy-isolation claim). Result: 23 of 24 items are `CLOSED` with real dual-tool evidence; TOP-06's dynamic-switch-triggered half remains genuinely open (pre-existing Phase 3 Stage 3/4 deferral, not newly found). Section 11's stale "TOP-21 to TOP-24 ... EVIDENCE_PENDING" sentence is superseded by this errata -- unlike V1.11/V1.12, this one DOES certify TOP-01~24 evidence (except TOP-06's open half), though it does not touch the separate G-FP-01~07 exhaustive port/CDC ledger closure, which remains `NOT_CLOSED` and out of scope here.
>
> V1.14 errata, 2026-09-05: correction to V1.13's TOP-06 disposition, not a new architecture or port change. V1.13 reported TOP-06's dynamic-switch-triggered half ("旧15-bit尾部不启动新事务") as genuinely open because its Priority-1b evidence sweep only checked `tb_ppg_control_top.v`/`tb_ppg_control_top_injection.v`/`tb_ppg_control_top_startup_idac_calibration.v` and never checked the Phase 3 Stage 4 files. Real, already-existing evidence was found in `ppg_control_top/tb_ppg_control_top_fir_tail_isolation.v` (created 2026-08-24/25, the same day as the original SMOKE-16 deferral note) -- its GROUP4 checks directly prove the old-precision FIR tail (bounded to `C_FIR_GROUP_DELAY_SAMPLES`=10 samples) cannot arm or start a new detection candidate (`flag_below_seen`/`flag_previous_valid` read back 0, `flag_candidate_start` never fires during the tail) and that the system genuinely recovers to form a second real CROSS from rebuilt post-tail evidence. Real dual-tool evidence: iverilog (650- and 900-sample runs, all GROUP4 checks PASS) and Vivado 2022.2 xsim (`FIR_TAIL_ISOLATION_TB_PASS real_red=900 real_ir=899 real_cal=0 measurement_result_valid=1798 peak_count=5 valley_count=4 cross_count=2 return_count=1`, identical to iverilog). Section 10's TOP-06 row and conclusion updated: all 24 TOP-01~24 items are now `CLOSED`. This errata does not touch G-FP-01~07, which remains its own separate, already-closed ledger-completeness effort (distinct from TOP-01~24 acceptance evidence).
>
> V1.15 errata, 2026-09-30: SID-05 contract sync, internal wiring only -- no new Top port and no Top-level logic. Records the Top-internal net `sched_cal_owner_deadline_event_o` added by `ppg_control_top.v` V1.6 (2026-09-18; declared at `ppg_control_top.v:553`). It connects Scheduler output `o_cal_owner_deadline_event` (Scheduler instance connection `:963`; Scheduler RTL V1.8, C08 V1.9) point-to-point to AMI input `i_cal_owner_deadline_event` (AMI instance connection `:1151`; AMI RTL V1.15, C10 V2.2). Why: without it, a calibration candidate suppressed at the local-tick-248 owner deadline left AMI's calibration request permanently in flight and stalled the whole AMB/DCS_CAL search (real RTL defect, `verification_reports/WORKLINE_D_SID05_SID06_20260918.md`). Section 6.3 gains this connection in its calibration-request row plus one paragraph. Evidence: `tb_ppg_control_top_startup_idac_calibration.v` V1.2, iverilog and Vivado 2022.2 xsim 83 PASS/0 FAIL; 2026-09-19 full 19-TB xsim regression 19/19 PASS, 0 FAIL, 1208 PASS total. Like V1.11-V1.14 this is an erratum under the supersession clause below: the normative label stays V1.10, so no dependency citation of C01 changes. Sync record: `verification_reports/CONTRACT_SYNC_SID05_20260930.md`.
>
> V1.16 errata, 2026-09-30: contract sync batch 2 -- records five Top boundary ports that `ppg_control_top.v` already has but this contract never listed; no RTL change. (1) Verification-injection pair `i_test_calibration_loss_inject_valid` (`ppg_control_top.v:135`) / `o_test_calibration_loss_inject_ready` (`:242`), added by Top V1.2 (2026-08-31, Stage 5 PRC-09/10): Sections 4.1, 4.2, 4.3 and 6.7 now list them in the same verification-only group as the identity/invalid pairs. They connect directly to AMI (`:1372-1373`, `:1551`) and are inert when `C_ENABLE_TEST_INJECTION=0`. (2) P2S telemetry outputs `o_s1_calibration_applied`, `o_s1_raw[9:0]`, `o_s2_raw[9:0]` (`:292-294`), added by Top V1.5 (2026-09-05): Section 4.2 records them as bit-exact pass-throughs of the same-name AMI outputs (`:1375-1377`, `:1601-1603`); their field meaning is owned by `PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md` Section 8.4.5. As with V1.11-V1.15, this is an erratum and the normative label stays V1.10. Sync record: `verification_reports/CONTRACT_SYNC_BATCH2_20260930.md`.
>
> V1.17 errata, 2026-10-01: contract sync batch 3 -- internal wiring record only; no new Top port and no RTL change. Records the Top-internal net `ssw_owner_q3_window_closed_o` (`ppg_control_top.v:602`), which carries SSW output `o_owner_q3_window_closed` (SSW instance connection `:1076`) to Scheduler input `i_owner_q3_window_closed` (Scheduler instance connection `:941`). It came with the 2026-08-30 Bucket-1 RTL session (Scheduler C08 V1.8, SSW C09 V1.9) but was never listed here. Section 6.2 gains one paragraph. As with V1.11-V1.16, this is an erratum and the normative label stays V1.10. Sync record: `verification_reports/CONTRACT_SYNC_BATCH3_20261001.md`.
>
> Normative supersession: V1.10 is this file's only current normative revision. Every V1.3.x/V1.4/V1.9 status, scope, dependency-version or implementation-readiness statement below is retained only as historical context and is expressly non-normative where it differs from V1.10 or the current dependency table in Section 2.1. In particular, no older statement may claim that the final port table is incomplete, defer the required supervisor boundary, permit an alternative supervisor implementation, or redefine contract closure from implementation evidence.

> 历史冻结记录（非规范）：V1.3.5验证专用异常注入接口形状曾被冻结；该记录不定义当前顶层端口、层次、合同状态或实现状态。  
> 本标题至“目标RTL/目标TB”之前的全部 V1.3.x/V1.4 记录均为非规范历史或历史证据；它们不定义当前端口、依赖、连接、验收状态或实现资格。  
> 冻结日期：2026-08-15  
> V1.3.1勘误日期：2026-08-15  
> V1.3.1勘误范围：删除旧单一fire同时驱动AMI与SSW的连接语义；不扩展最终顶层端口表，不替代后续V1.4  
> V1.3.2勘误日期：2026-08-15  
> V1.3.2勘误范围：冻结共享物理ADC空闲状态的唯一顶层来源、端口名、内部网名和四消费者同源扇出；不替代后续V1.4  
> V1.3.3勘误日期：2026-08-16  
> V1.3.3勘误范围：更新表征与STATIC_BIAS配置资格依赖及模拟/测量RUN许可状态；不改变模块端口、事务时序或模拟波形语义  
> V1.3.4勘误日期：2026-08-16  
> V1.3.4勘误范围：校核模拟RUN与测量RUN许可的唯一连接、信号极性和STATIC_BIAS隔离；不重新设计Scheduler或AMI时序接口，最终顶层RTL仍未编写  
> V1.3.4 STATIC_BIAS资格所有权勘误日期：2026-08-16  
> V1.3.4 STATIC_BIAS资格所有权勘误：冻结表征控制CDC已提交使能的唯一2 MHz内部网及其到配置管理器、许可拆分和SSW的同源扇出；不修改ACTIVE位图或三模块时序  
> V1.3.4校准责任边界勘误日期：2026-08-16  
> V1.3.4校准责任边界勘误：配置管理器只检查COMMIT/START前静态组合，AMI/Scheduler检查RUN期间实际校准事务；不增加`calibration_plan`字段、端口或顶层反馈路径  
> V1.3.4实现证据状态更新日期：2026-08-17  
> V1.3.4实现证据状态更新：Scheduler FSC-01～57、AMI AMI-01～45和SSW SSW-01～52均已有当前单模块PASS证据；JNT-01～09已在当前Scheduler、SSW和AMI RTL下通过52个子检查，作为当前联合基线PASS保留；该基线不覆盖新增联合矩阵，`ppg_control_top.v`仍未实现  
> V1.3.4联合基线日志更新日期：2026-08-17  
> V1.3.4联合基线日志更新：使用`C_CLK_PERIOD_NS=500`（2 MHz，500 ns）重新完成xvlog、xelab和xsim；证据文件为`joint_tb_500ns_baseline_xvlog.log`、`joint_tb_500ns_baseline_xelab.log`和`joint_tb_500ns_baseline_xsim.log`；XSim报告`JOINT_TB_PASS scenarios=52 waveform=12 owner=7 completion=6`。该结果只更新JNT-01～09当前基线，不覆盖新增联合矩阵或最终顶层闭合  
> V1.3.5修订日期：2026-08-20  
> V1.3.5修订：冻结最终顶层对AMI验证专用identity/invalid-sample接口的逐位连接、默认关闭参数、reset/生产旁路及AMI fault到注册式system fault/abort supervisor的传播位置；不修改Scheduler固定接管点、owner deadline、Q1/Q2/Q3或正常事务路径。  
> Historical V1.4 status note: superseded by the V1.10 fail-closed audit. Historical V1.3.4 logs are not PASS or closure evidence.  
> V1.3.5 P1语义补充日期：2026-08-20  
> V1.3.5 P1语义补充：冻结所有AMI completion identity mismatch先形成AMI本地blocking cause、再由注册式system supervisor发布统一abort；同时冻结STOP与该abort对AMI缓存真实完成的单次幂等失败释放。  
> 目标RTL：`ppg_control_top.v`  
> 目标TB：`tb_ppg_control_top.v`  
> 工作时钟：2 MHz数字系统域；SPI配置源域必须经CDC进入系统域  
> 适用范围：芯片内数字功能顶层的真实模块实例化、连接、事务所有权和模拟控制输出归属

## 1. 合同目的与替代关系

本合同冻结最终数字功能顶层 `ppg_control_top` 的内部连接。它只按照各模块合同分别记录的语义、历史回归证据、当前证据状态和待实现项进行连接约束，不在顶层重新实现、重新认证或重新宣称任何子模块算法已经闭合。

本合同正式替代 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT_DRAFT.md`。旧草案保留为历史记录，不得再用于推导端口、位宽、时序或最终实现。

历史 V1.2 记录曾纳入表征控制CDC V1.0合同的实例和连接约束；当前规范只引用
`PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md` V1.1，顶层不重复认证其CCC证据。

当前联合ACTIVE固定1024 bit；V4 `[639:0]` 保持原位图，V5检测 `[1023:640]` 只经ACTIVE wrapper/manager/unpacker/AMI/PWI链路传播。V1.3历史文字仅用于追溯，不得定义当前配置宽度。

1. START后先发布一次不启动ADC的IDAC启动安全提交边界，消除AMI、IDAC与调度器的首帧循环等待；
2. 将RED/IR共享模拟包络所有权与单笔ADC结果事务所有权分离，保留用户确认可跨颜色连续保持的四个SAR15控制信号；
3. 拆分模拟RUN许可与测量RUN许可，使STATIC_BIAS严格只驱动SSW静态netlist向量，不启动AMI或400 Hz调度器；
4. 保留SPI配置的纯RED固定SAR9/SAR15间歇测量，并由AMI按MANUAL模式原子提交AMB和DC_R数字码。

V1.3.1历史上只修正V1.3第6.1节及其直接引用中残留的旧单一fire语义。模拟波形上下文与ADC结果事务上下文必须保持为两个独立接口；关于“未补写最终逐端口连接表”或实施前置条件的历史限定，已由V1.10的第2.1、3.1和4.0节明确废止。

V1.3.2只冻结物理ADC/DONE空闲状态的唯一连接真源。顶层边界端口固定为`i_adc_physical_idle`，内部唯一扇出网固定为`flag_adc_physical_idle`；该网不得由AMI内部数字流水空闲、调度器空闲、SSW空闲或固定计数替代。本次勘误不提前补写其余最终V1.4逐端口连接，也不表示顶层RTL实施前置条件已经全部满足。

V1.3的上述系统级连接决议是后续调度器、AMI、SSW和表征子合同小版本修订的上位约束。在第9节列出的实现前置条件全部闭合前，不得直接编写或宣称最终顶层RTL已具备集成资格。

冲突优先级：

```text
用户最新明确确认
    > 本合同
    > 所列冻结子模块合同
    > 历史顶层、旧时序核、旧草案和旧handoff
```

现有 RTL、TB、历史 PASS、仿真日志和验证摘要仅可用于发现与上述合同
冲突的事实，绝不是规范来源、优先级层级或合同闭合证据。

## 2. 依赖追踪

### 2.1 V1.10 current normative dependency set

The following table supersedes every older version reference in this document.
Each named contract supplies one boundary only; historical logs, evidence
baselines and drafts are not dependencies and cannot override this table.

| Contract | Current version | Top use |
| --- | --- | --- |
| C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` | V1.7 | ACTIVE, manager-wrapper, generation, fault-blocking and lifecycle routes |
| C02 — `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.10 | sole generation production and STOPPING lifecycle |
| C03 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V1.7 | sole manager parent and transparent manager port forwarding |
| C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` | V1.13 | Rule A, owner deadline and scheduler fault records |
| C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.5 | completion, discard, drain, AMI feedback/blocking gate and fault records |
| C18 — `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.2 | internal detection-chain lifecycle forwarding |
| C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | V1.11 | waveform/physical owner and SSW fault records |
| C07 — `ppg_system_integration/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md` | V1.2 | dedicated characterization CDC boundary |
| C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` | V1.7 | mandatory dedicated registered supervisor boundary |

### 2.2 Historical dependency list

The following earlier list is retained for document history only. It is not a
second dependency table and has no normative force.

**Historical non-normative prior list (do not use for implementation)**

1. `PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.2；
2. `ppg_system_config_manager_semantic_contract.md` V4.3；
3. `PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.0；
4. `PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.3；
5. `PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.3.4；
6. `PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.2；
7. `PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.3.2；
8. `PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.2；
9. `PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md` V1.0。

**一致性引用（只用于派生核对，不覆盖上游合同）**

1. `PPG_IMPLEMENTATION_EVIDENCE_BASELINE_20260816.md`当前证据基线。

Port checklist V1.3是本合同的下游派生核对表，不列为Top的反向依赖；它可以引用本合同，但不得覆盖本合同或模块合同状态。

The preceding version list is historical only. Scheduler, AMI and SSW dependencies are exclusively the V1.10 Section 2.1 revisions. Port checklist and evidence baselines only support consistency review and never override a module contract or the current fail-closed verdict.

AMI已经包含precision-window integration；顶层不得再次独立实例化其内部的FIR、动态基线、峰谷或精度窗口子模块。

## 3. 冻结层次与唯一所有权

### 3.1 V1.10 authoritative direct-child hierarchy

This hierarchy supersedes every earlier enumeration in this document. The
final Top directly instantiates exactly the following functional children:

```text
ppg_active_v4_control_plane_integration
ppg_characterization_control_cdc
ppg_400hz_frame_calibration_scheduler
ppg_adc_measurement_idac_integration
ppg_sar9_sar15_safe_selection_wrapper
ppg_system_fault_abort_supervisor
```

`ppg_system_config_manager` is instantiated inside the ACTIVE control-plane
wrapper only. Top shall not directly instantiate manager, AMI-internal Router,
reconstructor, FIR, PWI, baseline/cross, peak/valley or precision-controller
modules. `ppg_system_fault_abort_supervisor` is a mandatory dedicated
registered module; separately reviewed replacement logic is not permitted.

以下V1.3历史五模块列举仅保留以解释早期文档；它已由第3.1节完整替代。不得据此省略专用`ppg_system_fault_abort_supervisor`，也不得使用替代逻辑实现supervisor边界：

```text
ppg_active_v4_control_plane_integration    // ACTIVE V4、生命周期和配置CDC
ppg_characterization_control_cdc           // 表征6-bit控制的独立原子CDC
ppg_400hz_frame_calibration_scheduler      // 唯一400 Hz/625-tick物理相位所有者
ppg_adc_measurement_idac_integration       // ADC捕获、处理、IDAC和精度窗口链
ppg_sar9_sar15_safe_selection_wrapper      // 唯一模拟时序与控制向量输出者
```

| 资源 | 唯一所有者 | 顶层禁止行为 |
| --- | --- | --- |
| 1024-bit联合ACTIVE快照和生命周期 | V4/V5控制平面 | 重复解包、隐式拼接/截断或从SPI shadow直连功能模块 |
| 6-bit表征控制快照和source握手 | 表征控制CDC | 拆分bit同步、覆盖在途快照或从SPI shadow旁路到SSW |
| `frame_id`、`sample_index`和物理相位 | 400 Hz调度器 | 再起400 Hz/3200 Hz计数器 |
| START后IDAC启动安全提交边界 | 400 Hz调度器 | 用伪造宏帧、ADC事务或顶层组合脉冲代替 |
| AMB/DC committed码及epoch | AMI | 顶层缓存、改写或用V4手动码覆盖运行状态 |
| 唯一ADC事务fire | AMI | 产生第二个启动脉冲 |
| 验证专用异常注入请求及事务绑定 | AMI | 在Scheduler、SSW、Router、FIR或顶层组合逻辑中第二次注入、直接置fault或改写owner |
| 系统blocking fault汇总与abort发布 | 最终system fault/abort supervisor | 组合OR后直接反馈ready/valid、由任一功能模块自行生成全局abort或用diag clear掩盖活动根因 |
| SAR和模拟控制向量 | SSW | 组合选择旧SAR核输出或附加模拟时序驱动 |
| RED/IR共享模拟包络状态 | SSW | 用单笔ADC在途标志提前切断跨颜色共享控制 |

## 4. 顶层边界

### 4.0 V1.10 authoritative safety-path connection table

These are the only legal paths for the lifecycle signals that cross the
manager-wrapper boundary. Every signal is a registered 2 MHz signal, resets
low, has no implicit width conversion, and is not recreated by an intermediate
module.

| Producer | Top net / operation | Direct consumer | Rule |
| --- | --- | --- | --- |
| supervisor `o_system_fault_blocking` | `flag_system_fault_blocking`; also Top observation `o_system_fault_blocking` | ACTIVE wrapper `i_system_fault_blocking` -> manager `i_system_fault_blocking` | High rejects START before RUN/generation mutation; it is not STOP, abort or clear. |
| manager `o_run_generation` | wrapper `o_run_generation` -> `flag_run_generation` | Scheduler/AMI/SSW `i_run_generation` | Manager is the sole producer; Top only fans out. |
| manager `o_stop_episode_active` | wrapper `o_stop_episode_active` -> `flag_stop_episode_active` | supervisor `i_stop_episode_active` | Sole proof of an accepted drain episode; normal RUN busy cannot replace it. |
| external STOP, supervisor stop request, registered external-abort drain request | one registered `flag_stop_request_event` merge | ACTIVE wrapper `i_stop_event` -> manager `i_stop_event` | Sole manager terminal control; STOP wins same-cycle START/COMMIT/clear. |
| supervisor `o_system_abort_event` plus external `i_control_abort_event` | one registered `flag_owner_abort_event` merge | AMI/Scheduler/SSW `i_control_abort_event` | The sole owner-abort fanout. It never enters manager; the external contribution is not a blocking cause by itself. |
| Top registered `flag_diag_clear_event` | unchanged direct fanout | AMI/Scheduler/SSW/supervisor `i_diag_clear_event`; V1.18 (F-048): also the characterization CDC `i_diag_clear_event` (five direct consumers in `ppg_control_top.v`) | Cannot release owner, active fault, injection request or generation. |

No table elsewhere in this document may replace or bypass these paths. The
wrapper is transparent for the manager-owned signals above; the Top is
transparent for `run_generation` and `stop_episode_active`; the supervisor is
the sole system-fault aggregate owner.

### 4.1 输入

顶层至少接收以下输入组：

| 输入组 | 归属/语义 |
| --- | --- |
| `i_clk`、`i_rstn` | 唯一2 MHz系统时钟和低有效复位 |
| `i_source_clk`、`i_source_rstn` | SPI配置源域时钟和低有效复位，同时连接V4控制平面与表征控制CDC的source端 |
| V4 SPI源域快照与提交事件 | 640-bit V4快照及其源域更新事件，直接进入V4控制平面 |
| 表征SPI source保持型事务 | `i_source_characterization_update_valid`、`i_source_static_characterization_enable`和`i_source_test_mux_ctrl[4:0]`，只进入表征控制CDC |
| 已同步START、STOP、诊断清除和`control_abort` | START/STOP只进入V4控制平面；abort和诊断清除同步送调度器、AMI、SSW |
| ADC物理接口 | 两路RAW码和两路`CLK_DOUT`异步完成电平进入AMI；2 MHz域物理空闲输入`i_adc_physical_idle`形成唯一内部网`flag_adc_physical_idle`并同源扇出 |
| 正式结果消费者ready | 只接AMI测量结果输出 |
| 验证专用异常注入 | `i_test_inject_enable`、`i_test_identity_inject_valid`、`i_test_identity_inject_sample_index[C_SAMPLE_INDEX_WIDTH-1:0]`和`i_test_invalid_sample_valid`；只有验证构建可用，生产构建必须静态关闭；V1.16勘误补记`i_test_calibration_loss_inject_valid`（PRC-09/10），同样只在验证构建可用 |

`static_characterization_enable`与`test_mux_ctrl[4:0]`不属于640-bit ACTIVE V4。顶层只能把SPI source字段接入表征控制CDC；配置管理器、许可拆分和SSW只能接收该CDC的2 MHz域已提交输出，禁止SPI shadow、source快照或bridge内部总线直连资格检查或模拟MUX。

### 4.2 输出

模拟顶层输出只能原样来自SSW：LED、LEDDAC、`EN_TEST`、`S[4:0]`、所有Q1/Q2/Q3/IREF/TIA/SAR/IDAC控制和`o_clk_2m`。顶层不得反相、屏蔽、合并或延迟任一模拟控制输出。

顶层还应输出AMI正式测量结果、V4生命周期ACK/错误、ACTIVE版本、调度器/AMI/SSW诊断和只读空闲状态。

V1.18补记（owner生命周期轮）：AMI/SSW诊断输出组新增`o_ami_owner_lost_sticky`（1 bit，复位0），逐位直连AMI `o_owner_lost_sticky`（C10 §6.9、§7.1a）。它是ADC完成丢失超时作废的历史诊断，非阻断，新START不清，只由复位或合法诊断清除清零（C10 §15.1）；芯片顶层经SPI读地图0x0108 bit6导出。

AMI正式测量输出必须新增逐位直连的`o_result_sample_valid`。它与`o_measurement_result_valid`、全部数值和身份属于同一保持型事务；顶层不得把它与calibration-valid、饱和或RAW数值组合后再导出。

顶层必须新增`o_source_config_update_ready`（V1.12勘误），是ACTIVE平面`o_config_transport_busy`的ready极性取反转发，归入表征控制source握手输出组，紧邻`o_source_characterization_update_ready`。它告诉SPI/glue顶层source域"V4+V5联合ACTIVE的CDC邮箱当前是否可以接受下一笔快照"，`=1`时才允许再次拉高`i_source_config_update_event`；顶层不得脱离`wrapper_config_transport_busy_o`另建判据，也不得在此信号外对该CDC邮箱状态做二次编码。

顶层必须新增`o_active_precision_mode`（V1.11勘误），是AMI `o_active_precision_mode`的逐位直连转发，归入调度器/AMI/SSW只读诊断输出组，紧邻`o_ami_idac_idle`。它是实时、任意时刻有效的系统唯一committed采集精度电平，不是`o_result_precision_mode`那种只在结果事务边界有效的快照；顶层不得对它做保持、锁存或与结果事务绑定。它的唯一权威来源是AMI内部wire（经Scheduler`i_active_precision_mode`和SSW`i_precision_mode_committed`同源消费的那一根），顶层不得另建第二个精度状态寄存器。

顶层必须输出`o_s1_calibration_applied`、`o_s1_raw[9:0]`和`o_s2_raw[9:0]`（V1.16勘误补记；Top V1.5于2026-09-05实现，`ppg_control_top.v:292-294`），分别逐位直连AMI同名输出（AMI例化连接`:1375-1377`，边界赋值`:1601-1603`），Top层没有任何逻辑。它们是芯片顶层glue模块中P2S打包器的遥测字段；字段语义、来源以及“不得改用pad级`DOUT_STAGE1/2_LOW`”等约束，以`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`第8.4.5节为准，本合同不另作定义。它们不属于`o_result_sample_valid`所在的正式测量保持型事务，AMI侧的来源见C10第6.7节。

验证专用握手返回固定为：

```text
o_test_identity_inject_ready = AMI.o_test_identity_inject_ready
o_test_invalid_sample_ready  = AMI.o_test_invalid_sample_ready
o_test_calibration_loss_inject_ready = AMI.o_test_calibration_loss_inject_ready
```

顶层还必须导出注册式`o_system_fault_blocking`和可追踪的`o_system_abort_event`诊断旁带；它们的生产实现与清除规则按第6.7节执行。

表征控制source握手与目标域诊断必须通过下列顶层输出导出：

```text
o_source_characterization_update_ready
o_characterization_control_valid
o_characterization_control_update_event
o_characterization_control_reject_event
o_characterization_protocol_error_sticky
```

其中`o_source_characterization_update_ready`只表示独立CDC邮箱可以接受一笔完整6-bit事务，不表示目标域已经接受该配置，也不表示STATIC_BIAS START已经获准。

### 4.3 验证专用参数与生产默认值

最终顶层和AMI共同使用以下默认关闭参数：

```verilog
parameter integer C_ENABLE_TEST_INJECTION = 0
```

最终顶层验证组端口冻结为：

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_test_inject_enable` | 1 | 验证构建运行使能；与默认0参数共同限定 |
| input | `i_test_identity_inject_valid` | 1 | 保持型one-shot错误完成身份请求 |
| input | `i_test_identity_inject_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 显式错误完成sample index payload |
| output | `o_test_identity_inject_ready` | 1 | AMI当前可原子绑定identity请求 |
| input | `i_test_invalid_sample_valid` | 1 | 保持型one-shot invalid-sample请求 |
| output | `o_test_invalid_sample_ready` | 1 | AMI当前可原子绑定invalid请求 |
| input | `i_test_calibration_loss_inject_valid` | 1 | 保持型one-shot calibration-loss请求（V1.16勘误，PRC-09/10），经AMI、PWI原样直通到粗检测FIR |
| output | `o_test_calibration_loss_inject_ready` | 1 | 粗检测FIR当前可原子绑定calibration-loss请求，经PWI、AMI原样返回（V1.16勘误） |
| output | `o_result_sample_valid` | 1 | 与正式measurement事务绑定的独立sample qualification |
| output | `o_system_fault_blocking` | 1 | 注册式系统阻断故障汇总状态 |
| output | `o_system_abort_event` | 1 | 注册式单周期系统abort诊断/扇出事件 |
| output | `o_system_stop_request_event` | 1 | supervisor产生的注册式单周期STOP请求观测；Top已将其纳入唯一manager STOP合并路径 |
| output | `o_system_fault_discard_event` | 1 | supervisor产生的注册式单周期fault-discard选择事件；只连接AMI并选择`DISCARD_SYSTEM_FAULT` |
| output | `o_system_fault_cause_valid` | 1 | first-fault快照有效位 |
| output | `o_system_fault_cause` | 8 | 固定blocking cause编码 |
| output | `o_system_fault_source` | 4 | 固定blocking source编码 |
| output | `o_system_fault_identity_valid` | 1 | 以下first-fault身份字段有效位；无效时全部字段为0 |
| output | `o_system_fault_frame_id` | `C_FRAME_ID_WIDTH` | first-fault物理帧身份 |
| output | `o_system_fault_sample_index` | `C_SAMPLE_INDEX_WIDTH` | first-fault事务序号 |
| output | `o_system_fault_color_ir` | 1 | first-fault颜色身份 |
| output | `o_system_fault_frame_type` | 2 | first-fault事务类型 |
| output | `o_system_fault_precision` | 1 | first-fault精度身份 |
| output | `o_system_fault_run_generation` | `C_RUN_GENERATION_WIDTH` | first-fault所属RUN代际；仅manager产生、Top不重建 |
| output | `o_system_fault_summary` | 16 | 历史blocking-cause summary位图 |
| output | `o_result_discard_summary_sticky` | 1 | 非blocking正式结果discard历史summary；只由AMI measurement-discard事件置位 |
| output | `o_measurement_result_discard_event` / `reason` / `identity_valid` / `sample_valid` / ~~`<TXN_ID>`~~ `<TXN_KEY>`（V1.18，F-008） | `1/2/1/1/each field` | AMI正式结果discard公开观测；identity-valid必须为1，完整字段在事件采样沿稳定，且不产生成功transfer。V1.18补记：身份组为矩阵§1.1 `TXN_KEY`，即RTL实际的`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`六项，不含epoch；在16位计数回绕窗口内唯一；reason可为`2'b11` COMPLETION_LOST（C10 §6.10） |
| output | `o_detection_discard_event` / `reason` / `identity_valid` / `sample_valid` / `<TXN_ID>` | `1/2/1/1/each field` | AMI检测generation-scoped discard公开观测；identity-valid为0时除目标`run_generation`外的触发身份与sample-valid为0，PWI内部无ready广播使用同一稳定字段 |

只有联合验证或最终顶层验证构建可显式覆盖为1。生产网表、流片配置和普通功能回归必须保持0，并把`i_test_inject_enable`及三个请求/payload输入（V1.16起连同`i_test_calibration_loss_inject_valid`共四个）约束为非活动值。有效使能定义为：

```text
flag_test_inject_effective =
    C_ENABLE_TEST_INJECTION
 && flag_test_inject_mode_latched
```

当其为0或`i_rstn=0`时，顶层必须向AMI驱动注入enable为0，两个ready输出为0（V1.16：`o_test_calibration_loss_inject_ready`同样为0，由粗检测FIR的ready条件保证）；任何外部请求变化均不得影响Q1/Q2/Q3、RAW、owner、正式结果、算法状态、fault、IDAC、epoch或`sample_index`。顶层不缓存、不重定向、不重新编码请求；参数为1时仍只逐位连接AMI V1.3.4接口，由AMI决定ready和事务绑定。

### 4.1 V1.10 final system boundary and one-to-one connection requirements

The following parameters are declared by Top and passed unchanged to every
consumer. Top is the sole width authority but is not a second state owner:

```verilog
parameter integer C_FRAME_ID_WIDTH = 16;
parameter integer C_SAMPLE_INDEX_WIDTH = 16;
parameter integer C_CONFIG_WIDTH = 1024;
parameter integer C_CONFIG_EPOCH_WIDTH = 8;
parameter integer C_COEF_EPOCH_WIDTH = 8;
parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 8;
parameter integer C_CODE_EPOCH_WIDTH = 4;
parameter integer C_RUN_GENERATION_WIDTH = 8;
parameter integer C_ENABLE_TEST_INJECTION = 0;
parameter integer C_ADC_DRAIN_WATCHDOG_CYCLES = 5000;
parameter integer C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH = 13;
```

~~Elaboration rejects mismatched child widths, including `C_CONFIG_WIDTH` against
the wrapper, manager, unpacker and configuration-CDC bridge (all must equal
1024), a zero watchdog count, or a
watchdog counter narrower than `$clog2(C_ADC_DRAIN_WATCHDOG_CYCLES + 1)`.~~
V1.18 (F-014/F-024): the width and watchdog values above are **fixed product values** and shall not
be overridden: `C_CONFIG_WIDTH=1024`; config/coef/DC-recovery epoch width 8;
code epoch width 4; generation width 8; frame/sample width 16/16; watchdog
5000/13. The Verilog-2001 RTL performs no elaboration-time reject. Instead the
actually elaborated values are read hierarchically and checked at simulation
start in `tb_ppg_control_top.v` (TB-local checks `PARAM-FIXED`, `PARAM-WDOG`),
`tb_ppg_chip_digital_top.v` (`PARAM-FIXED`, `PARAM-WDOG`) and the supervisor
unit TB (`WDPARM`) (C24 §1).
`5000` cycles is a provisional product policy, not macro timing signoff.

`ppg_system_config_manager.o_run_generation` leaves its only parent as
`ACTIVE-wrapper.o_run_generation`, then connects to the one Top net
`flag_run_generation` and unchanged only to direct children Scheduler, AMI and
SSW. Top has no generation register. AMI forwards the same value to its
internal Router, reconstructor and PWI; PWI forwards it to FIR,
baseline/cross, peak/valley and precision-window controller. Top neither
directly connects nor separately instantiates any AMI internal child. AMI alone
produces `o_datapath_empty`; Top connects it unchanged to
`ACTIVE-wrapper.i_datapath_empty`, whose only internal consumer is manager
`i_datapath_empty`. Top never rebuilds a second digital-empty expression.

Top accepts the public verification group only from an already registered
2 MHz verification-control source:

```text
i_test_inject_enable
i_test_identity_inject_valid
i_test_identity_inject_sample_index[C_SAMPLE_INDEX_WIDTH-1:0]
o_test_identity_inject_ready
i_test_invalid_sample_valid
o_test_invalid_sample_ready
```

There is no alternative mailbox inside Top or AMI. The source holds valid and
payload until ready/fire; an asynchronous or multi-bit external source must be
synchronized before this boundary. `C_ENABLE_TEST_INJECTION=0`, reset, an
unlatched test mode, STOP or abort force both ready outputs low. Test mode is
configured only in CONFIG/READY, locked by accepted START, immutable in RUN,
and cleared by STOP/abort/reset. It has no effect on production Q1/Q2/Q3, RAW,
owner, normal `sample_index` or algorithm path.

The public `i_test_inject_enable` is a CONFIG/READY configuration request, not
the AMI runtime enable. Top alone maps its registered
`flag_test_inject_mode_latched` to `AMI.i_test_inject_enable`; therefore a
source deassertion during RUN cannot revoke an accepted AMI request.

Top creates one registered `flag_diag_clear_event` from its sole 2 MHz
diagnostic-clear source and fans it unchanged only to the direct diagnostic
consumers AMI, Scheduler, SSW and supervisor (V1.18, F-048: and the characterization CDC, which uses it only for its own sticky diagnostics). AMI/PWI forward that same event
to every internal diagnostic consumer. Manager status clear remains local.
Diagnostic clear cannot release an owner or active blocking fault and START
cannot clear a first-fault snapshot.

Top connects the supervisor without inferred ORs or width conversion:

| Local producer | Supervisor input | Required record |
| --- | --- | --- |
| AMI | `i_ami_fault_*` | `valid`, `active`, `cause`, `identity_valid`, complete `FAULT_ID` |
| Scheduler | `i_scheduler_fault_*` | `valid`, `active`, `cause`, `identity_valid`, complete `FAULT_ID` |
| SSW | `i_ssw_fault_*` | `valid`, `active`, `cause`, `identity_valid`, complete `FAULT_ID` |
| ACTIVE wrapper `o_stop_episode_active` | `i_stop_episode_active` | manager-originated registered lifecycle drain level, transparently forwarded through wrapper and Top |
| physical boundary | `i_adc_physical_idle` | one synchronized held physical-idle level |
| `flag_diag_clear_event` | `i_diag_clear_event` | one registered clear event |
| AMI | `i_measurement_result_discard_event` | registered non-blocking result-discard observation |

Every supervisor output is an explicit Top logical observation port:
`o_system_fault_blocking`, `o_system_abort_event`,
`o_system_stop_request_event`, `o_system_fault_discard_event`, first-fault cause/source/identity fields,
`o_system_fault_summary`, `o_result_discard_summary_sticky`, plus AMI
measurement/detection discard event, reason and complete per-branch identity
groups. They are internal diagnostic/verification visibility, not new package
PAD requirements.

`o_system_abort_event` and external `i_control_abort_event` enter the one
registered `flag_owner_abort_event` merge, which alone fans to AMI, Scheduler
and SSW `i_control_abort_event`. `o_system_fault_discard_event` fans only to
AMI `i_system_fault_discard_event`. `o_system_stop_request_event` is registered
once with external STOP and the registered external-abort drain request, then
solely drives manager `i_stop_event`; abort is never a manager port. STOP wins
over same-cycle START/COMMIT/clear. The manager's
`o_stop_episode_active` permits the supervisor watchdog to begin only for an
accepted external/system STOP or registered abort drain, never normal RUN busy.

External `i_control_abort_event` is sampled only at the Top boundary. Top
registers its contribution to the sole owner-abort merge for AMI, Scheduler and
SSW, then separately registers one abort-drain stop request. The abort-drain stop request
participates in the sole STOP merge above. It never enters the supervisor as a
blocking-fault source and therefore cannot allocate a first-fault snapshot,
cause code or `o_system_fault_discard_event` by itself.

`i_adc_physical_idle` is synchronized exactly once before Top, produces
`flag_adc_physical_idle`, and fans unchanged by the following explicit mapping:

| Top net | Direct consumer port |
| --- | --- |
| `flag_adc_physical_idle` | `AMI.i_adc_idle` |
| `flag_adc_physical_idle` | `Scheduler.i_adc_idle` |
| `flag_adc_physical_idle` | `SSW.i_adc_idle` |
| `flag_adc_physical_idle` | `supervisor.i_adc_physical_idle` |
| `flag_adc_physical_idle` | `ACTIVE-wrapper.i_adc_idle` |

It means no physical conversion and inactive Stage1/Stage2 DONE/CLK_DOUT only.
It cannot create completion, RAW, `success=0`, owner release or
`datapath_empty`. No direct child may expose both an independently driven
`i_adc_idle` and an unmapped `i_adc_physical_idle` for this same fact.
The wrapper's `i_adc_idle` is the sole parent-side physical-idle input; it
forwards the exact level internally to manager `i_adc_idle`. Top shall not
drive a second direct manager physical-idle port.

## 5. V4控制平面连接

| V4控制平面输出 | 调度器输入 | AMI输入 | SSW输入 |
| --- | --- | --- | --- |
| `o_active_valid` | `i_active_config_valid` | `i_active_config_valid` | 不直接连接 |
| `o_run_enable` | 测量RUN许可 | 测量RUN许可 | 模拟RUN许可 |
| `o_allow_new_transaction` | 测量新事务许可 | 测量新事务许可 | 不直接连接 |
| `o_start_ack_event` | 测量START事件 | 测量START事件 | 模拟START事件 |
| `o_stop_ack_event` | `i_stop_ack_event` | `i_stop_ack_event` | `i_stop_ack_event` |
| `o_run_profile` | `i_run_profile` | `i_run_profile` | `i_run_profile` |
| `o_input_source` | `i_input_source` | 不直接连接 | `i_input_source` |
| `o_optical_mode` | `i_optical_mode` | 不直接连接 | `i_optical_mode` |
| `o_initial_precision` | 不直接连接 | `i_initial_precision` | 不直接连接 |

所有IDAC、Stage1/Stage2、DC恢复和检测配置按 AMI V1.3.3 的同名端口逐位连接。版本号只能按下列关系使用：

```text
o_config_epoch            -> AMI i_config_epoch
o_coef_epoch              -> AMI i_stage1_coef_epoch
o_stage2_coef_epoch       -> AMI i_stage2_coef_epoch
o_dc_recovery_coef_epoch  -> AMI i_dc_recovery_coef_epoch
```

原始START/STOP命令不得送下游；下游只消费V4控制平面的ACK事件。

### 5.1 模拟RUN与测量RUN许可拆分

顶层必须把表征控制CDC在2 MHz域已提交的`o_static_characterization_enable`接入唯一内部网`flag_static_characterization_enable`。该网同时送配置管理器资格检查、许可拆分和SSW静态向量资格，不允许复制第二个状态寄存器或从ACTIVE重新生成。

下列内部许可必须只使用该唯一网：

```verilog
analog_run_enable = run_enable;

measurement_run_enable =
    run_enable
  && !flag_static_characterization_enable;

measurement_allow_new_transaction =
    allow_new_transaction
  && !flag_static_characterization_enable;

analog_start_ack_event =
    start_ack_event;

measurement_start_ack_event =
    start_ack_event
  && !flag_static_characterization_enable;
```

上述许可和事件信号均为高有效（事件为单拍高有效）；顶层不得在目标模块端口处再次反相、脉冲化或与其他RUN信号OR/AND重解释。

许可连接逐项冻结为：

| 顶层内部网 | 目标端口 | 极性 | 非STATIC_BIAS | STATIC_BIAS |
| --- | --- | --- | --- | --- |
| `analog_run_enable` | `SSW.i_run_enable` | 高有效 | `1`跟随RUN | `1`，允许建立静态向量 |
| `measurement_run_enable` | `Scheduler.i_run_enable`、`AMI.i_run_enable` | 高有效 | `1`跟随RUN | `0`，保持测量链空闲 |
| `measurement_allow_new_transaction` | `Scheduler.i_allow_new_transaction`、`AMI.i_allow_new_transaction` | 高有效 | 跟随`allow_new_transaction` | `0`，禁止新事务 |
| `analog_start_ack_event` | `SSW.i_start_ack_event` | 单拍高有效 | 转发`start_ack_event` | 转发完整START |
| `measurement_start_ack_event` | `Scheduler.i_start_ack_event`、`AMI.i_start_ack_event` | 单拍高有效 | 转发`start_ack_event` | `0`，不得观察测量START |

`analog_run_enable`不得连接Scheduler或AMI；`measurement_run_enable`不得连接SSW。STOP、abort、reset和诊断清除事件仍按原合同同步送达三模块，不得被STATIC_BIAS许可屏蔽。

连接固定为：

| 内部许可/事件 | 连接目标 |
| --- | --- |
| `analog_run_enable` | SSW `i_run_enable` |
| `analog_start_ack_event` | SSW `i_start_ack_event` |
| `measurement_run_enable` | 调度器和AMI的`i_run_enable` |
| `measurement_start_ack_event` | 调度器和AMI的`i_start_ack_event` |
| `measurement_allow_new_transaction` | 调度器和AMI的`i_allow_new_transaction` |

`i_stop_ack_event`、`i_control_abort_event`、`i_diag_clear_event`和复位不得被`flag_static_characterization_enable`屏蔽，必须同步送达调度器、AMI和SSW。

`static_characterization_enable=1`时，SSW依然消费完整START并建立用户netlist冻结的STATIC_BIAS向量；调度器和AMI不得观察到测量START，不得启动400 Hz计数、IDAC控制、ADC事务或`frame_id/sample_index`推进。

`run_profile=CHARACTERIZATION`不等于STATIC_BIAS。只要`static_characterization_enable=0`，固定精度、光电二极管纯RED和外部固定电流表征均必须获得正常测量RUN许可。

### 5.2 表征控制CDC连接

顶层SPI source端口与表征控制CDC source端必须逐位连接：

| 顶层端口 | 表征控制CDC端口 |
| --- | --- |
| `i_source_clk` | `i_source_clk` |
| `i_source_rstn` | `i_source_rstn` |
| `i_source_characterization_update_valid` | `i_source_update_valid` |
| `i_source_static_characterization_enable` | `i_source_static_characterization_enable` |
| `i_source_test_mux_ctrl[4:0]` | `i_source_test_mux_ctrl[4:0]` |
| `o_source_characterization_update_ready` | `o_source_update_ready` |

表征控制CDC目标域连接固定为：

| 表征控制CDC端口 | 连接目标 |
| --- | --- |
| `i_clk`、`i_rstn` | 顶层同名2 MHz系统时钟和复位 |
| `i_run_enable` | V4控制平面`o_run_enable` |
| `i_diag_clear_event` | 顶层诊断清除事件 |
| `o_static_characterization_enable` | 顶层唯一`flag_static_characterization_enable`；同源扇出到V4控制平面`i_static_characterization_enable`、SSW `i_static_characterization_enable`和第5.1节许可拆分 |
| `o_test_mux_ctrl[4:0]` | SSW `i_test_mux_ctrl[4:0]` |
| `o_control_valid` | 顶层`o_characterization_control_valid`及STATIC_BIAS启动资格检查 |
| `o_control_update_event` | 顶层`o_characterization_control_update_event` |
| `o_control_reject_event` | 顶层`o_characterization_control_reject_event` |
| `o_protocol_error_sticky` | 顶层`o_characterization_protocol_error_sticky` |

`o_control_update_event`只表示一笔6-bit快照在2 MHz域合法提交，不得连接为START、STOP、调度器事务valid或SAR fire。RUN期间非法改变`static_characterization_enable`时，整笔快照必须由CDC拒绝，SSW继续使用此前已提交的完整控制值。

唯一所有权连接逐项冻结为：

```text
ppg_characterization_control_cdc.o_static_characterization_enable
    -> flag_static_characterization_enable
        -> ppg_active_v4_control_plane_integration.i_static_characterization_enable
        -> ppg_sar9_sar15_safe_selection_wrapper.i_static_characterization_enable
        -> measurement_run_enable / measurement_allow_new_transaction / measurement_start_ack_event
```

`flag_static_characterization_enable`为2 MHz域高有效电平，不是单拍事件。顶层不得对三个消费者分别同步，不得从`i_source_static_characterization_enable`、640-bit ACTIVE、`run_profile`或`input_source`生成替代网。配置管理器使用它检查`static_characterization_enable=1 -> run_profile=CHARACTERIZATION && input_source=1`；SSW仍独立执行相同组合的防御性安全资格。

## 6. 调度器、AMI与SSW闭环

### 6.1 保持型事务载荷

调度器至AMI必须逐位连接并保持至接收：

| 调度器输出 | AMI输入 |
| --- | --- |
| `o_transaction_start_valid` | `i_transaction_start_valid` |
| `o_transaction_precision_mode` | `i_transaction_precision_mode` |
| `o_transaction_frame_id` | `i_transaction_frame_id` |
| `o_transaction_sample_index` | `i_transaction_sample_index` |
| `o_transaction_color_ir` | `i_transaction_color_ir` |
| `o_transaction_frame_type` | `i_transaction_frame_type` |
| `o_transaction_amb_code_snapshot` | `i_transaction_amb_code_snapshot` |
| `o_transaction_dc_code_snapshot` | `i_transaction_dc_code_snapshot` |
| `o_transaction_amb_code_epoch` | `i_transaction_amb_code_epoch` |
| `o_transaction_dc_code_epoch` | `i_transaction_dc_code_epoch` |
| `o_safe_frame_id` | `i_safe_frame_id` |

本节`o_transaction_*`只属于调度器到AMI的ADC结果事务通道，不得并联至SSW，也不得使用同一个fire同时表示模拟波形接管和ADC结果owner提交。AMI `o_transaction_start_ready`只回连调度器 `i_transaction_start_ready`。调度器到SSW的独立模拟波形上下文通道，以及调度器与SSW之间的ADC owner资格和身份核对通道，均以本合同第4.1节、闭合矩阵第5节和调度器/SSW现行端口表为唯一权威定义；不得建立第二份并行顶层连接表。

### 6.2 固定相位和启动资格

| Producer | Scheduler input |
| --- | --- |
| AMI `o_wrapper_fault_blocking` | `i_ami_fault_blocking` |
| SSW `o_wrapper_fault_blocking` | `i_ssw_fault_blocking` |
| SSW `o_analog_safe` | `i_analog_safe` |
| SSW `o_sar_timing_idle` | `i_sar_timing_idle` |

`i_sar_launch_ready` and `i_wrapper_fault_blocking` are not Scheduler ports
and shall not appear in any Top connection, instance map or verification
expectation. The two blocking inputs above are independent registered levels:
they prevent only new Scheduler owner creation and do not substitute for the
supervisor fault-record path, abort, STOP request or manager lifecycle input.

#### 6.2.1 共享物理ADC空闲网络

物理ADC/DONE空闲状态的顶层边界端口和内部网名正式冻结为：

```text
顶层输入端口：i_adc_physical_idle
内部唯一网名：flag_adc_physical_idle

flag_adc_physical_idle = i_adc_physical_idle
```

`i_adc_physical_idle`必须是已经处于2 MHz系统域、可被同步时序逻辑直接采样的高有效保持电平。其唯一上游语义来源是物理ADC宏及DONE返回状态，按当前committed精度模式二选一，不是两级DONE的无条件AND（V1.11勘误，纠正本节历史文字）：

```text
i_adc_physical_idle = 1
    <=> 当前无物理ADC转换活动
     && (当前committed精度 == SAR9
           ? Stage1 CLK_DOUT/DONE已回到允许下一事务的非活动状态
           : Stage2 CLK_DOUT/DONE已回到允许下一事务的非活动状态)
```

理由：Stage1、Stage2是两个独立物理转换级；9-bit事务只使用Stage1，15-bit事务的最终完成以Stage2为准（该级完成蕴含Stage1已完成，与AMI-37"9-bit等待Stage1、15-bit等待Stage1/Stage2"的事务级判据一致，二者不冲突）。9-bit模式下Stage2从不参与转换，其DONE电平不可信，不得纳入判断；因此选择而非AND。选择所依据的"当前committed精度"必须使用Top V1.11新增的`o_active_precision_mode`（`ppg_control_top.v`V1.3新增，AMI `o_active_precision_mode`的纯转发，实时有效，不是`o_result_precision_mode`那个按结果快照的字段）——该信号先从Top输出，进入`ppg_control_top`边界之外的同一个专用同步模块完成二选一与同步，再驱动回`i_adc_physical_idle`，属于时序回路而非组合环。

若模拟/ADC宏只提供异步原始空闲指示，必须在`ppg_control_top`边界之外通过一个专用单点同步边界先完成同步，再驱动`i_adc_physical_idle`；禁止scheduler、AMI、SSW和V4控制平面各自对同一异步源独立同步，否则可能因同步延迟不同观察到相互矛盾的空闲资格。`flag_adc_physical_idle`不得在顶层与其他idle、fault、valid、ready或固定计数执行AND/OR后再冒充物理空闲真源。

唯一逐端口扇出固定为：

| 顶层唯一内部网 | 直接消费者端口 | 用途 |
| --- | --- | --- |
| `flag_adc_physical_idle` | `ppg_active_v4_control_plane_integration.i_adc_idle` | START/STOP生命周期中的物理ADC排空证明 |
| `flag_adc_physical_idle` | `ppg_400hz_frame_calibration_scheduler.i_adc_idle` | 波形接管、owner调度和START后IDAC边界的物理资格 |
| `flag_adc_physical_idle` | `ppg_adc_measurement_idac_integration.i_adc_idle` | 新结果owner启动和物理DONE回空资格 |
| `flag_adc_physical_idle` | `ppg_sar9_sar15_safe_selection_wrapper.i_adc_idle` | wrapper完整idle和物理ADC排空判断 |
| `flag_adc_physical_idle` | `ppg_system_fault_abort_supervisor.i_adc_physical_idle` | STOP episode期间唯一的物理排空事实；用于watchdog计数与恢复，绝不表示完成事件 |

在最终RTL实例连接中，四个端口必须逐字使用同一根网：

```text
.i_adc_idle(flag_adc_physical_idle)
```

禁止将以下任何信号接到上述四个`i_adc_idle`端口：

```text
AMI.o_adc_chain_idle
AMI.o_normal_fork_idle
AMI.o_measurement_output_idle
AMI.o_datapath_empty
AMI.o_adc_transaction_complete_event
scheduler.o_scheduler_idle
SSW.o_wrapper_idle
固定延时、Q3末沿或SAR波形结束推导的伪空闲
```

这些信号描述数字流水、模块局部状态或身份化完成事件，与物理ADC/DONE空闲事实不同。尤其是`AMI.o_adc_chain_idle`只能证明AMI捕获至Stage1数字链排空，不能证明模拟ADC没有转换或异步DONE已经回到下一事务允许状态；将其反馈到AMI自身`i_adc_idle`还会形成错误的自依赖。

调度器对新包络或启动IDAC边界的资格必须来自以下三项独立真实状态，不得由顶层定时计数伪造：

```text
flag_adc_physical_idle
&& SSW.o_analog_safe
&& SSW.o_sar_timing_idle
```

| 调度器输出 | SSW输入 |
| --- | --- |
| `o_macro_tick` | `i_macro_tick` |
| `o_calibration_subframe_index` | `i_calibration_subframe_index` |
| `o_calibration_local_tick` | `i_calibration_local_tick` |
| `o_normal_frame_active` | `i_normal_frame_active` |
| `o_calibration_frame_active` | `i_calibration_frame_active` |
| `o_macro_frame_safe_boundary` | `i_macro_frame_safe_boundary` |
| `o_idac_code_safe_boundary` | `i_idac_code_safe_boundary` |

模拟波形上下文必须在固定接管点与SSW独立握手，ADC结果事务必须在匹配波形已经接管且SSW给出owner资格后再与AMI握手。顶层不得把两套ready/valid组合为同一个fire，也不得另行组合握手条件改变固定接管点或形成组合环。

V1.17勘误：SSW到调度器还有一条纯内部单向连线，它不是Top端口，Top层也没有逻辑：`ppg_sar9_sar15_safe_selection_wrapper.o_owner_q3_window_closed` → Top内部`wire ssw_owner_q3_window_closed_o`（`ppg_control_top.v:602`）→ `ppg_400hz_frame_calibration_scheduler.i_owner_q3_window_closed`。两端连接分别位于`:1076`（SSW例化）和`:941`（调度器例化）。该网唯一的生产者是SSW，唯一的消费者是调度器，只用于调度器的完成成功判定`flag_completion_success`，不参与owner释放（语义见C08第10.4节和C09）。

### 6.3 AMI状态回授

| AMI输出 | 连接目标 |
| --- | --- |
| `o_calibration_sample_valid`和全部请求载荷 | 调度器对应`i_calibration_sample_*`；调度器`o_calibration_sample_ready`回连AMI；调度器`o_cal_owner_deadline_event`经Top内部网`sched_cal_owner_deadline_event_o`回连AMI `i_cal_owner_deadline_event`（V1.15勘误，非Top端口） |
| `o_active_precision_mode` | 调度器`i_active_precision_mode`与SSW`i_precision_mode_committed` |
| `o_switch_hold_new_transaction` | 调度器`i_switch_hold_new_transaction` |
| `o_normal_measurement_eligible` | 调度器`i_normal_measurement_eligible` |
| AMB/DC committed码及epoch | 调度器同名码值与epoch输入 |
| AMI V1.3.3新增完成旁带 | 调度器和SSW对应ADC完成输入 |
| `o_idac_idle`、`o_datapath_empty` | V4控制平面`i_idac_idle`、`i_datapath_empty` |

校准事务固定使用SAR9。只有在625-tick子帧的local tick 0真实fire，才计入一次校准转换。

校准责任边界及唯一连接固定为：

```text
COMMIT/START前：V4配置管理器检查静态ACTIVE组合和已提交独立资格
RUN期间请求源：AMI检查NORMAL_PPG、自动IDAC模式和SAR9请求编码
RUN期间请求接收：Scheduler复核NORMAL_PPG、PHOTODIODE、AMB/DCS类型和SAR9
```

顶层只直连AMI与Scheduler的保持型校准请求接口，不把请求或请求reason反馈到配置管理器。640-bit ACTIVE、manager wrapper和顶层均不得增加`calibration_plan`、未来校准类型或预声明校准队列。非法CHARACTERIZATION、外部固定电流或SAR15校准请求必须在任何SSW波形上下文、ADC owner、IDAC自动pending或结果事务启动前被AMI/Scheduler拒绝；SSW保留最终防御性安全隔离。

V1.15勘误（SID-05）：调度器与AMI之间新增一条纯内部单向连线，不新增Top端口，Top层不含任何逻辑：`ppg_400hz_frame_calibration_scheduler.o_cal_owner_deadline_event` → Top内部`wire sched_cal_owner_deadline_event_o`（`ppg_control_top.v:553`）→ `ppg_adc_measurement_idac_integration.i_cal_owner_deadline_event`。两端连接分别位于`ppg_control_top.v:963`（调度器例化`ppg_400hz_frame_calibration_scheduler_Inst`）和`:1151`（AMI例化`ppg_adc_measurement_idac_integration_Inst`）。该网唯一生产者为调度器、唯一消费者为AMI，不得扇出到SSW、supervisor、配置管理器或任何Top输出。语义见C08第10.3节（校准owner在local tick 248截止被抑制时的单周期事件）和C10第11.3节（AMI据此释放校准在途请求并重新发起同一候选）。

AMI V1.3.3合同沿用已验证的ADC完成旁带语义，正式输出为：

```text
o_adc_transaction_complete_event
o_adc_transaction_success
o_adc_complete_sample_index[C_SAMPLE_INDEX_WIDTH-1:0]
```

这三项只能在`CLK_DOUT`完成已经两级同步、RAW已经锁存、AMI已经确认其属于当前事务后共同产生。旁带必须同时连接至调度器和SSW；顶层不得以Q3结束、SAR波形末沿、固定延迟或未经AMI确认的ADC idle替代。

### 6.4 双安全边界与停止排空

```text
scheduler.o_macro_frame_safe_boundary
    -> AMI.i_macro_frame_safe_boundary
    -> SSW.i_macro_frame_safe_boundary

scheduler.o_idac_code_safe_boundary
    -> AMI.i_idac_code_safe_boundary
    -> SSW.i_idac_code_safe_boundary
```

SSW `o_analog_safe`同时连接AMI和V4控制平面。V4的排空输入仍严格使用彼此独立的`i_adc_idle=flag_adc_physical_idle`、`i_datapath_empty=AMI.o_datapath_empty`、`i_idac_idle=AMI.o_idac_idle`和`i_analog_safe=SSW.o_analog_safe`语义；四项不得合并、互相替代或由顶层固定计数推断。

### 6.5 START后IDAC启动安全边界

对于任何非STATIC_BIAS的新RUN，调度器在消费`measurement_start_ack_event`后必须先建立一笔“启动IDAC安全提交待办”。当下列条件同时成立时，调度器在第一个可用的2 MHz时钟沿上仅发布一拍`o_idac_code_safe_boundary`：

```text
measurement_run_enable
&& active_config_valid
&& flag_adc_physical_idle
&& analog_safe
&& sar_timing_idle
&& scheduler内无预装上下文
&& scheduler内无ADC在途事务
```

该启动边界必须满足：

1. 不产生`o_macro_frame_start_event`、`o_macro_frame_safe_boundary`或任何`o_transaction_start_valid`/fire；
2. 不启动Q1/Q2/Q3、LED、SAR或ADC模拟包络；
3. 不改变`frame_id`、`sample_index`、颜色上下文或宏帧相位；
4. MANUAL模式在该边界原子装入SPI ACTIVE的AMB、DC_R和DC_IR手动码；
5. 自动模式在该边界装入首个AMB/DC启动候选码，随后才允许AMI提出AMB_CAL或DCS_CAL请求；
6. `STOP`、`control_abort`或复位在边界发布前到达时，必须撤销该待办，不得产生迟到提交。

在启动边界完成前，调度器不得以`i_normal_measurement_eligible=0`或AMI尚未形成校准请求为由取消该启动边界；AMI也不得在没有该边界时自行提交pending码。

### 6.6 双光共享模拟包络与单笔ADC所有权

NORMAL双光下必须分别管理三类状态：

```text
宏帧共享模拟控制所有权
RED与IR各自的颜色上下文快照
唯一单笔ADC结果事务所有权
```

用户已明确确认SAR15的下列四个信号允许在RED与IR模拟包络之间连续保持，不得因RED单笔ADC事务尚未释放而在颜色边界强制拉回非活动值：

```text
CLK_IREF_IDAC_SAR15_LOW
EN_SAR15_IREF
EN_SAR15_AMB_LOW
EN_SAR15_DC_LOW
```

这四个信号的逻辑值和连续区间仍必须严格来自用户netlist及SSW时序合同，本合同只冻结其“可跨颜色连续保持”属性，不根据信号名推断极性。

同时必须保持：

1. RED和IR各有独立且原子的颜色、精度、AMB/DC码、epoch、`frame_id`和`sample_index`快照；
2. 整个系统同时最多只有一笔ADC结果事务在途；
3. RED事务只有在AMI发出真实`CLK_DOUT`同步完成旁带且`sample_index`匹配后才释放ADC结果所有权；
4. IR模拟预建立不等于第二笔ADC结果事务已启动，不得使用同一个`transaction_inflight`标志同时代表共享模拟包络和ADC结果归属；
5. 顶层和TB不得用“fire后固定4拍完成”或其他伪延时替代真实Q3、`CLK_DOUT`同步、RAW捕获和AMI归属检查。

### 6.7 验证专用异常注入与system fault/abort传播

最终顶层的注入连接位置冻结在AMI公开边界，不能插入Scheduler完成输入之后、Router、FIR、检测fork或SSW模拟路径：

| 顶层端口/内部网 | 唯一连接目标 |
| --- | --- |
| `C_ENABLE_TEST_INJECTION` | AMI同名parameter逐值覆盖；生产构建两者均为0 |
| `flag_test_inject_effective` | `AMI.i_test_inject_enable` |
| `i_test_identity_inject_valid` | `AMI.i_test_identity_inject_valid` |
| `i_test_identity_inject_sample_index` | `AMI.i_test_identity_inject_sample_index` |
| `AMI.o_test_identity_inject_ready` | `o_test_identity_inject_ready` |
| `i_test_invalid_sample_valid` | `AMI.i_test_invalid_sample_valid` |
| `AMI.o_test_invalid_sample_ready` | `o_test_invalid_sample_ready` |
| `i_test_calibration_loss_inject_valid` | `AMI.i_test_calibration_loss_inject_valid`（V1.16勘误；AMI内部再经PWI直通粗检测FIR，见C10第6.5b节） |
| `AMI.o_test_calibration_loss_inject_ready` | `o_test_calibration_loss_inject_ready`（V1.16勘误） |

联合Scheduler+SSW+AMI TB在最终顶层RTL完成前，允许直接驱动同一组AMI公开端口；这只是最终顶层逐位直连的临时集成边界，不得使用层次化force、直接改AMI内部owner/matcher、替换fork ready或另建TB专用完成脉冲。Router-to-overlap不承担identity注入；invalid sample由AMI在DC恢复后形成独立`result_sample_valid`，经precision-window wrapper进入FIR。

最终Top必须连接已冻结的2 MHz注册式system fault/abort supervisor。唯一阻断故障传播路径为：

```text
AMI.o_ami_fault_valid/active/cause/identity_valid/<FAULT_ID>
Scheduler.o_scheduler_fault_valid/active/cause/identity_valid/<FAULT_ID>
SSW.o_ssw_fault_valid/active/cause/identity_valid/<FAULT_ID>
        -> registered system fault/abort supervisor
        -> o_system_fault_blocking
        -> registered o_system_abort_event
        -> Scheduler/AMI/SSW i_control_abort_event
```

`o_integration_protocol_error_sticky`, `o_wrapper_fault_blocking` and
`o_scheduler_local_fault_blocking` remain their local diagnostic or gating
signals. They are not supervisor inputs and may not bypass the complete
registered fault-record group above. Each source maps a qualifying local cause
to exactly one documented record before Top wiring.

系统监督规则冻结如下：

1. 受保护identity注入和生产路径真实completion identity mismatch都必须先经过AMI production matcher，置既有integration sticky、local blocking state以及带固定cause/source/`FAULT_ID`的AMI fault record；顶层不得直接由test valid、RAW值或未匹配completion组合生成system fault或abort，也不得把真实错配静默降级为仅记录诊断后继续该事务。
2. supervisor必须先寄存/保持fault cause，再针对每个新锁存的未解决blocking cause产生一次单周期registered abort；同一cause持续为高不得每拍重复发布abort。禁止fault到ready/valid、注入ready或任一模块fault输入的组合反馈环。
3. 外部已同步`i_control_abort_event`与supervisor abort必须在注册事件层合并后同源扇出Scheduler、AMI和SSW；不得由三个模块分别生成不同abort。
4. `i_diag_clear_event`只清历史sticky。活动blocking cause或未解决owner存在时，`o_system_fault_blocking`保持，clear不得释放owner或伪造恢复。
5. 受保护identity注入错配后的旧owner按AMI V1.3.4保留；受控abort不能直接清owner，AMI必须用缓存的原始正确DONE/RAW/identity产生一次匹配原`sample_index`、`success=0`完成旁带，Scheduler、SSW和AMI随后按既有合同释放。若STOP ack先于或同拍到达，AMI执行相同的本地受控失败释放；STOP与supervisor abort对同一owner必须幂等，合计最多一次完成旁带。reset可直接失效数字owner；恢复后下一合法START/事务不得观察旧注入payload、pending或fault上下文。
6. 生产路径真实identity mismatch若没有可证明的正确completion上下文，不得用owner快照重标错误DONE，也不得合成`success=0`释放。supervisor仍发布统一abort，但该owner只能等待合同允许的真实匹配完成或由reset失效；系统在此之前保持blocking。只有AMI合同明确分类为“原始owner仍可证明的内部处理失败”时，才允许使用原identity失败释放。
7. `i_rstn=0`清除supervisor历史、abort pending和全部验证注入控制；复位释放后生产默认参数保持注入关闭。
8. owner完成受控释放后，活动cause解除与历史sticky清除是两个步骤：supervisor停止阻断前必须观察根因已解除，历史诊断仅由合法`i_diag_clear_event`或复位清除；新RUN只建立新的run generation，不得清除历史诊断。clear不得抑制尚未处理的abort事件。

V1.10 specifies the dedicated supervisor module boundary, fault encoding, registered observability and required connections in Section 4.1 and the supervisor contract. LFA-08 final-Top implementation evidence is `EVIDENCE_PENDING` and historical logs are not a substitute.

## 7. 表征与AMB专用时序

1. NORMAL光电二极管输入：`run_profile=NORMAL_PPG`、`input_source=0`。AMB_CAL使用SSW V1.3.2冻结的专用SAR9波形，`CAL_Q3_TICK=266`。
2. 外部固定电流表征：`run_profile=CHARACTERIZATION`、`input_source=1`、`static_characterization_enable=0`。SAR9/SAR15仍按400 Hz间歇事务运行；SSW负责`EN_TEST=1`并抑制LEDEN/LEDDAC有效驱动窗口。
3. STATIC_BIAS：`static_characterization_enable=1`且`input_source=1`。SSW只输出冻结netlist定义的纯静态向量，`o_s_in[4:0]`只取已CDC提交的`test_mux_ctrl[4:0]`；不允许启动ADC事务。
4. AMB_CAL和DCS_CAL仅在NORMAL光电二极管输入语义下运行；固定电流和STATIC_BIAS不得进入自动校准。

第2项和第3项中的`static_characterization_enable`及`test_mux_ctrl[4:0]`均指表征控制CDC的2 MHz域已提交输出，不指SPI source shadow。STATIC_BIAS START前必须已经存在合法控制提交，且已提交使能为1；NORMAL和外部固定电流允许使用复位安全默认值0。

顶层不得根据信号名推断电平极性或补充脉冲窗口；所有模拟输出必须以SSW V1.3.2的netlist冻结规则为准。

### 7.1 纯RED固定精度运行矩阵

纯RED固定SAR9/SAR15是非STATIC_BIAS的400 Hz间歇测量模式。其SPI ACTIVE配置必须按下表解释：

| 配置字段 | 纯RED SAR9 | 纯RED SAR15 |
| --- | --- | --- |
| `run_profile` | `CHARACTERIZATION` | `CHARACTERIZATION` |
| `static_characterization_enable` | `0` | `0` |
| `optical_mode` | `RED_ONLY` | `RED_ONLY` |
| `initial_precision` | `SAR9` | `SAR15` |
| `idac_mode` | `MANUAL` | `MANUAL` |
| `amb_enable` | `1` | `1` |
| `dcs_enable` | `1` | `1` |
| AMB码 | `amb_manual_code` | `amb_manual_code` |
| RED DC码 | `dcs_r_manual_code` | `dcs_r_manual_code` |

上表不增加新的640-bit字段。`amb_manual_code`和`dcs_r_manual_code`在CONFIG阶段写入shadow，经合法COMMIT进入ACTIVE，再于第6.5节的启动IDAC安全边界原子成为committed码。RUN期间不允许SPI shadow或顶层组合逻辑直接改变这两组码。

纯RED模式的事务规则为：

1. 每个400 Hz宏帧最多启动一笔RED事务，不产生IR事务；
2. `frame_id`按400 Hz宏帧规则推进，`sample_index`只在RED真实fire时增加一次；
3. 事务必须原子锁存RED颜色、固定精度、AMB码、DC_R码、两类code epoch、`frame_id`和`sample_index`；
4. SAR9事务只在SAR9 AMB/DC有效窗口输出快照码，SAR15事务只在SAR15 AMB/DC有效窗口输出同一笔快照码；
5. `dcs_ir_manual_code`仍必须是合法ACTIVE字段，但RED_ONLY运行不得为它产生IR事务或IR有效输出窗口。

纯RED时的输入源语义必须继续独立解码：

| `input_source` | `EN_TEST` | LED行为 | 语义 |
| --- | --- | --- | --- |
| `PHOTODIODE` | `0` | 仅RED LED按netlist有效窗口工作 | 真实纯红光光电二极管测量 |
| `EXTERNAL_TEST_CURRENT` | `1` | LEDEN1/2保持0，LEDDAC无有效窗口 | 使用RED通道身份和数据路径的已知电流表征 |

NORMAL_PPG也允许`optical_mode=RED_ONLY`，但必须从SAR9启动并由精度窗口自动执行9→15→9切换。需要整个RUN固定SAR15时，必须使用上表的CHARACTERIZATION组合，不得绕过配置管理器构造`NORMAL_PPG + initial_precision=SAR15`。

## 8. 历史模块隔离

以下文件只可作为历史波形参考，禁止在 `ppg_control_top` 中实例化：

```text
ppg_dual_precision_top/ppg_dual_precision_top.v
ppg_dual_precision_top.v
ppg_timing_sar9.v
ppg_timing_sar15.v
tb_ppg_dual_precision_top.v
tb_ppg_timing_sar9.v
tb_ppg_timing_sar15.v
```

它们仍使用旧 `i_test_mode` 和静态SAR IDAC码接口，与V1.2的AMB专用时序、外部固定电流和STATIC_BIAS合同不兼容，不能通过补丁重新取得正式顶层资格。

## 9. 实现门禁与禁止连接

当前合同门禁为`NOT_CLOSED`：本合同、其列出的活跃子合同和闭合矩阵仍是唯一规范来源，但矩阵尚未完成逐端、逐pending、逐fault-source且带源定位的全量双向账本。因此`ppg_control_top.v`**不可进入 RTL 修改阶段**。

当前实现证据状态是`EVIDENCE_PENDING`，而非RTL/TB PASS；这不能掩盖当前合同审计缺口。所有新端口、层级扇出、discard、fault-record、watchdog、1024-bit联合配置和最终Top场景仍须由现行RTL和TB产生新的证据。历史XSim、基线、草案或交付日志只能作为参考，不能提升任何本版本验收项为PASS，也不能把系统合同改标为闭合。ACTIVE V5是当前联合载荷`[1023:640]`的固定检测扩展，必须经Top -> wrapper -> manager/unpacker -> AMI -> PWI端口链；它不是未来可选方案。

严格禁止：

1. SPI shadow或源域测试MUX直接接SSW模拟输出；
2. 顶层自行生成400 Hz、3200 Hz、Q1/Q2/Q3或ADC启动时钟；
3. 将SSW模拟控制与旧 `ppg_timing_sar9/15` 输出组合MUX；
4. 用单一通用安全边界代替宏帧与IDAC码安全边界；
5. 将模拟波形上下文与ADC结果事务重新合并为单一fire，或把AMI事务载荷并联为SSW波形接管载荷；
6. RUN期间绕过AMI修改AMB/DC committed码或epoch；
7. 将NORMAL、固定电流表征和STATIC_BIAS混写为同一种测试模式；
8. 在STATIC_BIAS下将未屏蔽的RUN、START或`allow_new_transaction`送入AMI或调度器；
9. 将`run_profile=CHARACTERIZATION`直接解释为停止测量链；
10. 用ADC在途标志切断第6.6节冻结的四个跨颜色共享控制信号；
11. 用伪造ADC完成脉冲、Q3末沿或固定延时释放ADC事务所有权；
12. 在没有启动IDAC安全边界时从顶层直接改写IDAC committed码；
13. 用AMI `o_adc_chain_idle`、`o_datapath_empty`、scheduler idle或SSW idle替代共享物理`flag_adc_physical_idle`；
14. 让四个物理`i_adc_idle`消费者使用不同来源、不同逻辑表达式或各自独立同步后的异步状态。
15. 从SPI source、ACTIVE字段或多个本地寄存器分别生成STATIC_BIAS资格，或让manager、SSW和许可拆分观察不同的`static_characterization_enable`状态。
16. 在ACTIVE、配置管理器、manager wrapper或顶层增加`calibration_plan`字段/端口，或把AMI实际校准请求反馈给manager预测未来事务；
17. 复用旧`i_test_mode`、CHARACTERIZATION或STATIC_BIAS使能作为验证异常注入enable；
18. 在`C_ENABLE_TEST_INJECTION=0`时让任何注入输入影响内部网或输出；
19. 在顶层、Scheduler、SSW、Router或FIR中修改completion identity、直接置fault、伪造DONE或改写owner；
20. 用层次化force、直接改内部fork ready或特殊RAW关闭LFA-08/PRC-08；
21. 把AMI/SSW/Scheduler blocking fault组合反馈到ready/valid或未经注册直接生成循环abort；
22. 用`diag_clear`清除活动fault cause、释放未解决owner或把system fault静默降级为历史诊断。

## 10. 顶层验收

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| TOP-01 | 复位 | 无事务valid；SSW为安全向量；无旧事务恢复 |
| TOP-02 | V4/V5 COMMIT/START | 1024-bit联合ACTIVE原子生效；V4/V5均合法才替换且`config_epoch`仅递增一次，下游只消费ACK事件 |
| TOP-03 | NORMAL双光 | 同一`frame_id`、连续`sample_index`、同一committed精度和固定Q3相位 |
| TOP-04 | AMB/DCS | local tick 0快照和`CAL_Q3_TICK=266`正确；不复用旧候选码伪造新样本 |
| TOP-05 | 双通道反压 | 波形上下文只在固定接管点与SSW握手；ADC owner和AMI事务独立反压；两套通道不共用单一fire且未完成ADC事务握手时不消费`sample_index` |
| TOP-06 | 精度切换 | AMI、调度器和SSW使用同一笔事务精度；旧15-bit尾部不启动新事务 |
| TOP-07 | 固定电流 | `EN_TEST=1`、LEDEN为0、LEDDAC无有效窗口、SAR仍按400 Hz间歇工作 |
| TOP-08 | STATIC_BIAS | 精确静态向量；`S[4:0]`只在CDC提交后更新；无ADC事务 |
| TOP-09 | STOP/abort/reset | STOP立即禁止新事务；正式结果按显式discard事件完成；检测链按discard事件排空；物理ADC继续等待真实idle；abort/reset幂等且迟到DONE不得重启波形 |
| TOP-10 | 历史链隔离 | 综合层次不存在旧dual-precision和旧SAR timing实例 |
| TOP-11 | IDAC启动边界 | START后在首帧前仅发布一次IDAC安全边界；无ADC、无宏帧、无索引消费 |
| TOP-12 | STATIC_BIAS测量隔离 | SSW建立netlist静态向量；AMI和调度器保持空闲且计数不变 |
| TOP-13 | 纯RED固定SAR9 | 每帧仅一笔RED SAR9；AMB/DC_R取SPI committed码；无IR事务 |
| TOP-14 | 纯RED固定SAR15 | 整个RUN固定SAR15且无fine-window切换事件；每帧仅一笔RED事务 |
| TOP-15 | 双光共享包络 | 四个已确认SAR15控制允许跨RED/IR连续保持，同时ADC结果事务仍严格单笔在途 |
| TOP-16 | 真实ADC完成 | RED/IR所有权只由`CLK_DOUT`同步、RAW捕获和`sample_index`匹配后的AMI旁带释放 |
| TOP-17 | 共享物理ADC idle | 唯一`i_adc_physical_idle`形成`flag_adc_physical_idle`并逐位同源扇出到V4、scheduler、AMI、SSW和supervisor；数字流水idle不得替代，supervisor仅将该事实用于watchdog排空/恢复而绝不解释为completion |
| TOP-18 | RUN许可极性与拆分 | `analog_run_enable`仅接SSW且高有效；`measurement_run_enable`仅接Scheduler/AMI且高有效；STATIC_BIAS下测量许可和新事务许可均为0 |
| TOP-19 | STATIC_BIAS资格唯一所有权 | 表征CDC已提交输出形成唯一`flag_static_characterization_enable`，同源扇出到manager wrapper、SSW和许可拆分；`flag=1 && input_source=0`拒绝COMMIT/START且无测量启动 |
| TOP-20 | 校准责任边界 | manager只检查静态配置且无`calibration_plan`；AMI/Scheduler分别对RUN期实际请求做源端/接收端资格检查，非法CHARACTERIZATION、外部电流或SAR15校准无波形、owner、pending和序号副作用 |
| TOP-21 | 注入生产旁路 | 默认参数0、生产enable 0及reset期间注入ready为0；正常Q1/Q2/Q3、RAW、owner、sample index、结果和fault与V1.3.4基线逐位一致 |
| TOP-22 | LFA-08顶层传播 | 合法identity注入只进入AMI production matcher；AMI/Scheduler/SSW owner不错误释放、无正式结果，AMI blocking fault经注册supervisor产生一次可追踪system fault/abort；STOP或该abort以缓存原identity产生且只产生一次`success=0`释放，清理后下一合法事务恢复 |
| TOP-23 | PRC-08顶层资格 | invalid请求绑定一笔真实身份匹配NORMAL事务；正式输出保留identity且sample-valid为0，FIR/基线/峰谷/精度不推进，后续合法样本按合同恢复 |
| TOP-24 | 注入安全与互斥 | 双请求、无owner、相等identity、运行中改绑、STOP/abort/reset及输出反压均无半提交、残留pending、重复abort/完成、组合环或正常事务副作用；禁止force和fork-ready改写 |

> **验收证据核销记录（2026-09-02，Priority-1b核对）**：本节24项此前长期停留在"最后一次已知状态是EVIDENCE_PENDING"（见下方11节旧文本），但从未逐条对照现有TB证据核实过是否仍然如此。本轮逐条对照`ppg_control_top/tb_ppg_control_top.v`（SMOKE-01~23）、`ppg_control_top/tb_ppg_control_top_injection.v`（INJ-00~04）和`ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v`（Stage 5 Group 6，SID-01~12）的真实场景内容，结果：
>
> | 编号 | 证据 | 状态 |
> | --- | --- | --- |
> | TOP-01~05, 07~09, 12~20 | `tb_ppg_control_top.v` SMOKE-01/02/23/15/17/18/19/05~07/19/12/13/14/09/fanout监测/11/19-20/21-22，逐条场景名与本表描述直接对应，均有真实iverilog+xsim双工具PASS证据 | `CLOSED` |
> | TOP-06 | ~~`tb_ppg_control_top.v` SMOKE-16只覆盖"AMI/调度器/SSW使用同一笔事务精度"的协议一致性切片；"旧15-bit尾部不启动新事务"这半条需要真实生理波形触发基线穿越精度切换，该文件V1.1/V1.4两次changelog都明确记录为推迟到Phase 3 Stage 3/4（真实基线穿越/峰谷检测算法层证据就绪后），截至本次核对（V1.6）仍未完成~~ **2026-09-05更正：动态触发半条其实在Priority-1b核对时就已经有真实证据存在，只是核对范围没有覆盖到——`ppg_control_top/tb_ppg_control_top_fir_tail_isolation.v`（Phase 3 Stage 4第4组，2026/08/24~25创建，即Priority-1b核对当天）逐字对应"旧15-bit尾部不启动新事务"：GROUP4系列检查实测确认尾部期间（precision_mode=1，≤`C_FIR_GROUP_DELAY_SAMPLES`=10个样本）`flag_below_seen`/`flag_previous_valid`全程读回0、`flag_candidate_start`全程不触发（尾部真的不能武装/启动新候选），随后尾部结束、系统从重建证据里真实恢复形成第二次CROSS——证明隔离机制不会永久卡死检测能力。真实双工具证据：iverilog 650/900样本两轮 GROUP4_TAIL_BOUNDED/GROUP4_REBUILD_EVIDENCE/GROUP4_EXISTENCE全部PASS，本地Vivado 2022.2 xsim完整流程（xvlog/xelab/xsim，5分56秒）`FIR_TAIL_ISOLATION_TB_PASS real_red=900 real_ir=899 real_cal=0 measurement_result_valid=1798 peak_count=5 valley_count=4 cross_count=2 return_count=1`，与iverilog逐值一致。** | `CLOSED`（协议一致性半条见SMOKE-16，动态触发半条见`tb_ppg_control_top_fir_tail_isolation.v` GROUP4，两份证据登记在不同文件、从未交叉引用，本次补齐） |
> | TOP-10 | 不是仿真场景，是综合层次静态检查：`ppg_dual_precision_top.v`/`ppg_timing_sar9.v`/`ppg_timing_sar15.v`虽编译进`rtl_filelist.f`但从未被`ppg_control_top.v`实例化，本合同自己8节"历史模块隔离"明文禁止实例化，2026-08-31全系统审计（`iverilog -Wall`全层次elaborate + 逐文件静态lint）已实测确认这一点，不是文档层面的推断 | `CLOSED`（静态证据，非TB PASS） |
> | TOP-11 | 未见任何TB用字面"TOP-11"标注，但`tb_ppg_control_top_startup_idac_calibration.v`（Stage 5 Group 6）的SID-01场景"START唯一安全边界+零副作用"实测的是完全相同的RTL行为：直接轮询`o_startup_idac_safe_boundary`确认START后到首次真实AMB请求发起前恰好一次脉冲（`cnt_boundary_pulses != 1`判FAIL），且同一窗口内owner/宏帧tick/正式结果计数均未推进——与本行"仅发布一次...无ADC、无宏帧、无索引消费"逐字对应，只是登记在C25（Group 6, SID-01~12）体系下，从未在C01这边交叉引用 | `CLOSED`（证据在SID-01，非TOP-编号本身） |
> | TOP-21~24 | `tb_ppg_control_top_injection.v`：TOP-21由INJ-01（运行时enable=0切片）+ SMOKE-01~23全程使用编译期默认`C_ENABLE_TEST_INJECTION=0`（该文件自身注释已交叉引用这一点）共同证明；TOP-22=INJ-02（即LFA-08）；TOP-23=INJ-03（即PRC-08）；TOP-24=INJ-04。均有真实iverilog+xsim证据，此前的`EVIDENCE_PENDING`是过期状态，未随证据积累同步更新 | `CLOSED` |
>
> **结论（2026-09-05更新）：24项全部`CLOSED`**——原结论"24项里23项CLOSED、1项TOP-06 PARTIAL"已被上表TOP-06行的更正取代：动态触发半条的真实证据在Priority-1b核对当时就已经存在（`tb_ppg_control_top_fir_tail_isolation.v`与Priority-1b同一天创建），只是核对范围只看了`tb_ppg_control_top.v`/`tb_ppg_control_top_injection.v`/`tb_ppg_control_top_startup_idac_calibration.v`三份文件，没有把Phase 3 Stage 4系列文件纳入，属于核对范围的疏漏，不是证据本身缺失。下方11节的过期`EVIDENCE_PENDING`断言据此更新。

## 11. 交付边界

V1.10 retains the normative requirements for verification injection, production default-disable, independent sample-valid, supervisor, generation, discard and direct connections. It does not claim that `ppg_control_top.v` or the system supervisor is implemented.

> **2026-09-02 update**: the TOP-21 to TOP-24 and LFA-08 final-Top `EVIDENCE_PENDING` status above is stale. Real dual-tool (iverilog + Vivado 2022.2 xsim) evidence for all four now exists in `tb_ppg_control_top_injection.v` (INJ-01~04) -- see the acceptance-evidence reconciliation table added above Section 10's TOP-01~24 list. 23 of the 24 top-level acceptance items are `CLOSED`; only TOP-06's dynamic-switch-triggered half remains genuinely open, deferred to Phase 3 Stage 3/4 real-waveform-generator work (a pre-existing, self-documented deferral in `tb_ppg_control_top.v`, not newly discovered here). This does not close the separate G-FP-01~07 exhaustive port/CDC ledger audit referenced by `PPG_CONTRACT_CLOSURE_MATRIX.md`, which remains a distinct, much larger documentation effort.
