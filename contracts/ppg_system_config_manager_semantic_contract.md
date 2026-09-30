# ppg_system_config_manager语义合同

> V4.9 fail-closed D01 revision, 2026-08-20: the manager is the sole committed 1024-bit joint ACTIVE and config_epoch owner. The system closure verdict is owned solely by the current matrix audit and is `NOT_CLOSED` until every final defect count is zero. Implementation evidence is `EVIDENCE_PENDING`.
> Normative status: V4.9 is the sole current manager interface and lifecycle authority. Earlier V4.3-V4.8 status, dependency-version and implementation-readiness statements are historical unless repeated by V4.9; they cannot remove a V4.9 port or change V4.9 lifecycle semantics.

> 历史冻结记录（非规范）：V4.3-V4.8接口与行为冻结内容保留用于变更追溯；当前唯一规范版本为本页眉声明的V4.9。  
> 时钟域：2 MHz系统域  
> 配置联合宽度：1024 bit；V4=`[639:0]`、V5检测payload=`[1023:640]`  
> epoch宽度：8 bit  
> RTL边界：不解析SPI，不实现跨时钟同步，不执行Stage1、Stage2或DC恢复算法
> V4.3修订：冻结ACTIVE合法组合、保留IDAC编码、校准事务责任边界和确定错误分类
> V4.3所有权一致性勘误日期：2026-08-16  
> V4.3所有权一致性勘误：冻结2 MHz域已提交`i_static_characterization_enable`资格输入的唯一来源、COMMIT/START复核和STATIC_BIAS错误分类；不修改640-bit ACTIVE位图、生命周期或既有算法
> V4.3校准责任边界勘误日期：2026-08-16  
> V4.3校准责任边界勘误：配置管理器只检查COMMIT/START前静态配置组合；不增加`calibration_plan`或实际校准请求输入，不预测RUN期间的AMB_CAL/DCS_CAL
> V4.3光学模式勘误日期：2026-08-17  
> V4.3光学模式勘误：固定`EXTERNAL_TEST_CURRENT`表征仅允许`BOTH`、`RED_ONLY`或`IR_ONLY`；`OFF`返回确定错误码`8'h16`，不属于固定电流测量资格。
> 历史证据说明（非规范）：V4.1 XSim定向回归日志仅用于追溯；当前RTL/TB证据仍按本轮矩阵标记为`EVIDENCE_PENDING`，不得由历史日志改变合同状态。

## 1. 依赖追踪与所有权

**规范依赖（可决定配置管理器语义）**

1. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
2. C03 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.6；
3. C05 — `ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md` V5字段解释；
4. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.5（仅定义经Top/wrapper转发的`i_system_fault_blocking`语义，不授予manager直接supervisor端口）。

**一致性引用（只用于对齐，不覆盖配置管理器责任）**

本合同是COMMIT/START前静态配置组合检查的责任来源，不反向依赖Characterization、CDC或Top合同；这些下游合同必须一致消费本合同的资格语义。

配置管理器拥有COMMIT/START前静态组合检查；一致性引用不得把RUN期间AMB_CAL/DCS_CAL责任转移给配置管理器，也不得引入`calibration_plan`字段。

### 1.1 V4.9 formal parameter contract

The manager module shall declare and expose the following parameters. Every
value is an elaboration-time constant; no parameter is writable through SPI or
RUN-time state.

| Parameter | Default | Legal range | Binding/check |
| --- | ---: | --- | --- |
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Must equal ACTIVE wrapper, unpacker and CDC bridge widths; mismatch is an elaboration error. |
| `C_FRAME_ID_WIDTH` | 16 | >=1 | Must equal Top/AMI/Scheduler/SSW identity width. |
| `C_SAMPLE_INDEX_WIDTH` | 16 | >=1 | Must equal Top/AMI/Scheduler/SSW identity width. |
| `C_CONFIG_EPOCH_WIDTH` | 8 | >=1 | Must equal ACTIVE/unpacker/AMI/PWI epoch width. |
| `C_COEF_EPOCH_WIDTH` | 8 | >=1 | Must equal AMI/child coefficient epoch width. |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | >=1 | Must equal DC-recovery/AMI epoch width. |
| `C_CODE_EPOCH_WIDTH` | 4 | >=1 | Must equal IDAC/AMI code epoch width. |
| `C_RUN_GENERATION_WIDTH` | 8 | >=1 | Must equal Top, wrapper, AMI and all generation-retaining children; manager is the sole producer. |

The accepted defaults are the current product values. Top passes each value
unchanged through the ACTIVE wrapper and rejects any child mismatch at
elaboration; the manager does not infer widths from a packed bus or silently
truncate a field.

## 2. 输入事件与资格电平

- `i_config_update_event`：配置CDC桥已经在2 MHz域重建的单周期完整快照到达事件。
- `i_start_event`：命令CDC已经在2 MHz域重建的单周期START事件。
- `i_stop_event`：命令CDC已经在2 MHz域重建的单周期STOP事件。
- `i_system_fault_blocking`：由Top经ACTIVE wrapper原样送达的2 MHz注册系统阻断故障电平。高电平时拒绝START，不能被本地status clear、START或COMMIT清除。
- `i_status_clear_event`：命令CDC已经在2 MHz域重建的单周期状态清除事件。
- `i_static_characterization_enable`：表征控制CDC在2 MHz域已经原子提交的高有效STATIC_BIAS资格电平；它不是事件，不属于640-bit ACTIVE，也不得来自SPI source shadow。
- 同拍命令采用第3.1节的固定优先级；`i_stop_event`是已经在Top单点合并的安全终止请求，优先于START、COMMIT和本地status clear。被STOP抢占的START/COMMIT不执行，并记录既有命令冲突诊断。

`i_static_characterization_enable`的唯一合法连接路径冻结为：

```text
ppg_characterization_control_cdc.o_static_characterization_enable
    -> 顶层唯一2 MHz内部网flag_static_characterization_enable
    -> ppg_active_v4_control_plane_integration.i_static_characterization_enable
    -> ppg_system_config_manager.i_static_characterization_enable
```

配置管理器不得重新同步、寄存复制、从ACTIVE字段推导或根据`run_profile`猜测该资格。表征控制CDC保证该电平在2 MHz域注册输出，并在RUN期间禁止改变；配置管理器只消费当前已提交值。

### 2.1 V4.9 complete module-port contract

All ports below are in the registered 2 MHz system domain. `i_rstn` is active
low; every event output resets low, every level/status output resets low, all
epochs and `o_run_generation` reset to zero, and the manager reset vector uses
the C04 V5 default profile with `o_active_valid=0`. No port is an implied
connection or an internal-only substitute for a listed boundary.

| Direction | Port | Width | Unique producer / consumer | Handshake, reset and lifecycle |
| --- | --- | --- | --- | --- |
| input | `i_clk`, `i_rstn` | 1 / 1 | Top/ACTIVE wrapper clock-reset boundary | `i_rstn=0` resets all manager state and produces no discard event. |
| input | `i_config_snapshot` | `C_CONFIG_WIDTH` | Wrapper CDC destination / manager | Held complete 1024-bit V4/V5 candidate when `i_config_update_event=1`; sampled once at the registered commit decision. |
| input | `i_config_update_event` | 1 | Wrapper CDC destination / manager | One 2 MHz cycle; legal only outside RUN; rejected commit preserves both ACTIVE halves and epochs. |
| input | `i_start_event`, `i_stop_event`, `i_status_clear_event` | 1 each | Wrapper/Top registered event paths / manager | One cycle. Priority is Section 3.1; Top-merged STOP is the sole terminal control. |
| input | `i_system_fault_blocking` | 1 | Supervisor -> Top -> wrapper / manager | Registered level; blocks START and is never released by local clear, START or COMMIT. |
| input | `i_static_characterization_enable` | 1 | characterization CDC -> Top -> wrapper / manager | Registered level, stable through RUN; participates in COMMIT/START legality only. |
| input | `i_analog_ready`, `i_adc_idle`, `i_datapath_empty`, `i_idac_idle`, `i_analog_safe` | 1 each | wrapper inputs from their named physical/AMI/SSW sources / manager | Registered qualification levels. `i_adc_idle` is physical idle only; `i_datapath_empty` is the sole AMI aggregate. All five are required for the stated start/drain condition, with `i_analog_safe` used only for STOPPING completion. |
| output | `o_active_config` | `C_CONFIG_WIDTH` | manager / wrapper -> unpacker | Sole committed joint V4/V5 ACTIVE. Atomically changes only on legal joint COMMIT; stable in RUN/STOPPING. |
| output | `o_active_valid`, `o_run_enable`, `o_allow_new_transaction` | 1 each | manager / wrapper -> AMI/Scheduler/Top consumers | Registered levels. New transactions stop immediately on accepted STOP; only the manager owns their lifecycle values. |
| output | `o_start_ack_event`, `o_stop_ack_event`, `o_commit_ack_event`, `o_error_event` | 1 each | manager / wrapper -> declared status/event observers | Registered one-cycle events; reset low. `o_stop_ack_event` establishes `o_stop_episode_active`. |
| output | `o_stop_episode_active` | 1 | manager / wrapper -> Top -> supervisor | Registered level, set by accepted Top-merged STOP, idempotent during STOPPING, reset low after drain/reset. |
| output | `o_run_generation` | `C_RUN_GENERATION_WIDTH` | manager / wrapper -> Top -> Scheduler/AMI/SSW | Sole generation producer; increments exactly once on accepted START and remains stable through RUN/STOPPING. |
| output | `o_config_epoch`, `o_coef_epoch`, `o_stage2_coef_epoch`, `o_dc_recovery_coef_epoch` | `C_CONFIG_EPOCH_WIDTH` / `C_COEF_EPOCH_WIDTH` / `C_COEF_EPOCH_WIDTH` / `C_DC_RECOVERY_EPOCH_WIDTH` | manager / wrapper -> named AMI/unpacker consumers | Registered epoch fields. Only legal COMMIT changes them according to Section 6. |
**D02 frozen decision (2026-08-31):** the external 2-bit lifecycle status and
detailed error-status observation ports described by the state/error rules
below are formally declared as the following six manager-sourced signals,
closing D02 (`PPG_CONTRACT_CLOSURE_MATRIX.md` Section 12.12a) without by
itself closing the broader G-FP-01/G-FP-06 port ledgers:

| Signal | Width | Manager source | Wrapper forwarding | Top observation endpoint |
| --- | --- | --- | --- | --- |
| `o_lifecycle_state` | `[1:0]` | `dec_lifecycle_state` (Section 3, line ~466-467: `flag_state_invalid ? 2'b00 : state_current[1:0]`) | `ppg_active_v4_control_plane_integration.v:296`, bit-identical passthrough (`assign o_lifecycle_state = lifecycle_state_o;`) | `ppg_control_top.v:1490`, bit-identical passthrough (`assign o_lifecycle_state = wrapper_lifecycle_state_o;`) |
| `o_commit_ack_event` | `1` | single-cycle event on accepted COMMIT | same passthrough pattern | production top-level output port |
| `o_commit_ack_sticky` | `1` | registered sticky companion of the above | same passthrough pattern | production top-level output port |
| `o_error_event` | `1` | single-cycle event on `dec_error_code != ERROR_NONE` | same passthrough pattern | production top-level output port |
| `o_error_sticky` | `1` | registered sticky companion of the above | same passthrough pattern | production top-level output port |
| `o_last_error_code` | `[7:0]` | `dec_error_code` (Section 3, `ERROR_*` classification table, currently 25 named causes `8'h00`-`8'h18`) | same passthrough pattern | production top-level output port |

Exposure mechanism: these are always-on, unconditional top-level `output`
ports on `ppg_control_top.v` -- not a CSR/register-map interface, and not
gated by `C_ENABLE_TEST_INJECTION` the way the verification-only injection
port groups are. `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md:205`
explicitly separates verification-only injection ("only available in
verification builds, must be statically disabled in production builds")
from this interface; line 209 groups "V4 lifecycle ACK/error" together with
the Scheduler/AMI/SSW diagnostic outputs and the read-only idle status as
one class of always-exposed production observation outputs -- the existing
plain-port implementation is exactly that class, not an invented shape.

Single-owner confirmation: `ppg_system_active_config_unpack.v` has zero
references to any of the six signals above (no second producer);
`ppg_active_v4_control_plane_integration.v`'s forwarding is pure bit-identical
passthrough with no re-encoding, so `ppg_system_config_manager` remains the
sole producer end to end.

Internal-width note: `state_current`/`state_next` (Section 3, `ST_CONFIG`
through `ST_STOPPING`) is declared `[2:0]` but only ever assigned the four
legal 3-bit values `3'b000`-`3'b011`; the reserved third bit is deliberately
never used for a fifth lifecycle state -- it exists only to give the illegal-
encoding safety detector (`flag_state_invalid`, Section 3 lines ~112-129)
room to fire without colliding with a legal encoding. `state_current[1:0]`
therefore captures the full legal state space with no truncation risk, and
the illegal-encoding fallback (safe return to `2'b00`, `error_event` with
`8'h0d`/`ERROR_FSM_STATE`, `active_valid` cleared) is real RTL behavior, not
just a documented rule.

**Scope of this decision:** D02 closes only the "what are the formal names/
widths/forwarding/exposure of this interface" product-decision gate. It does
not by itself close G-FP-01 (the full 89-input/85-output port ledger) or
G-FP-06 (the full CDC/reset/priority/clear ledger) -- ~~those remain
`NOT_CLOSED` pending the much larger row-by-row ledger work `PPG_CONTRACT_
CLOSURE_MATRIX.md` Section 12.12 still requires project-wide.~~ **Update,
2026-09-10 (Stage 2 batch 1 reconciliation): Section 12.12's row-by-row ledger
work this note anticipated is now `CLOSED` (2026-09-06, all nine batches --
see `PPG_CONTRACT_CLOSURE_MATRIX.md:3226` and
`project-ppg-gfp-ledger-batching-plan-20260902.md`); G-FP-01's 1803 port rows
and G-FP-06's CDC/reset/priority/clear rows are both materialized with real
source citations. This is still not a claim that G-FP-01/G-FP-06 are
`CONTRACT_CLOSED` -- 12.12's own closing note (matrix line 3233-3235) and
12.1's system-level status note (matrix line 1003-1014) are explicit that
ledger materialization is a narrower claim than system-level closure, and the
12.2/12.3 top-down/bottom-up audit chains that cite G-FP-01/G-FP-06 among
several ledgers together correctly remain `NOT_CLOSED` for reasons beyond
ledger completeness (e.g. exhaustive physical-signoff proof). This paragraph
only corrects the now-outdated "still requires project-wide" framing, which
described work that has since finished.**

The table intentionally has no `i_control_abort_event`, direct supervisor port,
direct AMI discard acknowledgement, SPI shadow input, or independent
`i_adc_physical_idle` alias. Those would violate the frozen hierarchy or create
a second owner/CDC boundary.

## 3. 状态和动作

| 当前状态 | 合法事件 | 动作 |
| --- | --- | --- |
| CONFIG | 合法配置更新 | V4/V5同时原子替换ACTIVE，config_epoch只更新一次，进入READY |
| READY | START且全部资格满足 | 进入RUN |
| RUN | STOP | 进入STOPPING并停止新事务 |
| STOPPING | 重复STOP | 幂等ACK，不改变排空过程 |
| STOPPING | 全部排空且模拟安全 | 返回CONFIG并清除active_valid |

外部生命周期编码继续使用2 bit。RTL内部状态寄存器使用3 bit并只定义
`3'b000`至`3'b011`四个合法状态，使硬件保留非法编码检测空间。检测到内部非法状态时：

- 当前拍产生`error_event`并记录`8'h0d`；
- 置位`error_sticky`；
- 清除`active_valid`，保持`run_enable`和`allow_new_transaction`为0；
- 下一拍回到CONFIG；
- ACTIVE快照和epoch保持不变，供软件诊断。

### 3.1 V4.5 lifecycle, generation and diagnostic integration

The manager is the sole producer and state owner of
`o_run_generation[C_RUN_GENERATION_WIDTH-1:0]`. It resets to zero and
increments exactly once on an accepted START. The accepted START exposes the
incremented value to the Top fanout before any new owner may be created. It is
held unchanged through RUN and STOPPING. Top and all downstream modules only
consume this value; none may regenerate, increment or truncate it. This field
never changes Scheduler Rule A or normal `sample_index` allocation.

`i_system_fault_blocking` is an explicit registered one-bit input, not an
inference from abort, STOPPING, local sticky state or `i_datapath_empty`. Its
only legal path is `supervisor.o_system_fault_blocking -> Top -> ACTIVE
wrapper.i_system_fault_blocking -> manager.i_system_fault_blocking`. When it
is high, a START is rejected before state transition and before generation
increment. It does not by itself release an owner or complete STOPPING; legal
restart additionally requires the normal ADC, datapath, IDAC and analog drain
predicates after the blocking level is low.

The manager accepts exactly one registered terminal control:
`i_stop_event`. Top is its sole producer and has already merged the external
STOP event, the registered supervisor system-stop request and the registered
external-abort drain request. `i_control_abort_event` is not a manager port and
the manager never derives a STOP from abort itself. Abort is separately fanned
by Top only to AMI, Scheduler and SSW transaction owners. A registered
`o_stop_episode_active` is asserted by an accepted `i_stop_event`, is
idempotent during STOPPING, and is the only manager-to-supervisor proof that a
physical-drain episode exists. The state reaches STOPPING only through this
merged STOP input.

STOPPING immediately blocks new waveform and ADC owners. It requests AMI
measurement and detection lifecycle discard, then may complete only when the
single AMI-owned `i_datapath_empty`, physical `i_adc_idle` (mapped only from
Top `flag_adc_physical_idle`), `i_idac_idle` and `i_analog_safe` are all true.
It does not recompute a second
digital-empty expression. A backpressured measurement result is removed only
by AMI's explicit discard event; reset is the only path that clears it without
an event.

Same-edge command priority is:

```text
reset > Top-merged STOP > fault recovery
> START/COMMIT > status clear > normal transaction
```

STOP wins over simultaneous START/COMMIT/status-clear and retains the existing
command-conflict diagnostic. The control plane provides one registered
`flag_diag_clear_event` through Top to all diagnostic consumers. It is distinct
from `i_status_clear_event`, cannot release an owner or active fault, and START
never clears system first-fault history. A legal restart requires system
blocking low plus the normal full-drain readiness predicates.

The manager does not own the ADC watchdog counter. The supervisor starts it
only when `o_stop_episode_active=1` and physical idle is low. A watchdog timeout
keeps the lifecycle safely blocked until true physical idle or reset; it never
creates a false DONE, RAW or idle condition.

## 4. 快照校验

校验顺序和错误码固定为：V4 schema/V5 schema合同绑定、V4/V5保留位、V5字段范围、枚举、运行profile/source/precision组合、CHARACTERIZATION光学模式资格、CHARACTERIZATION IDAC策略、
STATIC_BIAS输入源资格、IDAC码范围、阈值关系、确认次数、Stage1系数资格、Stage2系数资格、DC恢复系数资格。
任何失败均保持ACTIVE和epoch不变。完整位表见
`../ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`第10节。

V4新增检查如下：

- `schema_version==8'h04`；
- `[31:23]`与`[639:592]`必须全部为0；
- 联合候选快照严格为`i_config_snapshot[1023:0]`；`[639:0]`只按V4解释，
  `[1023:640]`只按V5解释；manager、CDC、wrapper、Top和unpacker的
  `C_CONFIG_WIDTH`必须显式为1024且在elaboration时相等；
- V5 schema固定为`8'h05`的合同绑定，不占payload。V5 `[383:370]`必须全0；
  `slope_mode`只能为0或1；`slope_min_q16 < slope_max_q16 < 0`；
  `fixed_slope_q16`必须在闭区间`[slope_min_q16,slope_max_q16]`且小于0；
  `alpha_q15`、`beta_q15`、`timing_adjust_ratio_q15`不得超过`16'h7fff`；
  `cross_hysteresis_q16`、`min_peak_valley_amplitude`、所有confirm count、
  所有max/min frame计数均不得为0；`lead_min_frames<=lead_max_frames`；
  `min_peak_to_valley_frames<=min_peak_to_peak_frames`；
- V5 reset/default profile的字段值由C04 5.2固定，复位后
  `peak_valley_config_valid=0`。该默认值是manager寄存器复位值，不是shadow、
  TB或表征模块的第二producer；
- `peak_valley_config_valid=1`只接受完整合法V5快照的联合COMMIT。manager不执行
  表征算法：source软件必须先完成表征、将完整结果写入同一1024-bit shadow，再请求
  同一CDC update；manager只验证位图/范围并原子提交。
- `run_profile==1'b0`表示NORMAL_PPG，此时`initial_precision`必须为`1'b0`，即SAR9；
- `run_profile==1'b0 && initial_precision==1'b1`属于非法配置组合，必须拒绝整笔COMMIT；
- `run_profile==1'b1`表示CHARACTERIZATION，此时`initial_precision`允许为SAR9或SAR15；
- `run_profile==1'b0 && input_source==1'b1`属于NORMAL外部固定电流非法组合，必须拒绝整笔COMMIT；
- `run_profile==1'b1 && idac_mode!=2'b00`属于CHARACTERIZATION自动IDAC非法组合，必须拒绝整笔COMMIT；
- `run_profile==1'b1 && input_source==1'b0`时，`optical_mode`必须为`RED_ONLY`，否则拒绝整笔COMMIT；
- `run_profile==1'b1 && i_static_characterization_enable==1'b0 && input_source==1'b1`时，`optical_mode`必须为`BOTH`、`RED_ONLY`或`IR_ONLY`；`optical_mode==OFF`属于非法固定电流测量组合，必须拒绝整笔COMMIT/START；
- 当`i_static_characterization_enable==1`时，候选或已提交ACTIVE必须为`run_profile=CHARACTERIZATION && input_source=1`，否则分别拒绝COMMIT或START；
- `idac_mode==2'b11`为保留编码，必须拒绝整笔COMMIT/START并保持ACTIVE和epoch不变；
- `AMB_CAL/DCS_CAL`是RUN期间的实际事务请求，不是640-bit ACTIVE字段；不得把`amb_enable/dcs_enable`误作校准请求或未来校准计划；
- 系统必须在校准波形、ADC owner或结果事务启动前拒绝`CHARACTERIZATION+AMB_CAL/DCS_CAL`和`SAR15+AMB_CAL/DCS_CAL`；该责任固定由Scheduler/AMI运行时资格层执行，配置管理器不得声称已经从ACTIVE快照判定；
- NORMAL_PPG要求`stage1_calibration_valid`、`stage2_calibration_valid`、`dc9_recovery_valid`和
  `dc15_recovery_valid`同时为1；
- 声明`stage2_calibration_valid=1`时，`stage2_gain_q16`必须为正值；
- 声明任一DC恢复资格为1时，对应signed Q16恢复gain必须为正值；
- `amb_recheck_interval_frames[15:0]`全部编码合法，0表示关闭周期AMB检查。

V5 schema/保留位错误返回`8'h17`；V5字段范围或关系错误返回`8'h18`。Stage2资格或增益错误返回`8'h0e`；DC恢复资格或增益错误返回`8'h0f`；NORMAL_PPG配置为
SAR15初始精度时返回`8'h10`；NORMAL外部固定电流返回`8'h11`；CHARACTERIZATION自动IDAC返回`8'h12`；
CHARACTERIZATION光电二极管非纯RED组合返回`8'h13`；STATIC_BIAS输入源非法返回`8'h14`；保留
`idac_mode=2'b11`返回`8'h15`；非STATIC_BIAS的`CHARACTERIZATION + EXTERNAL_TEST_CURRENT + optical_mode=OFF`返回`8'h16`。既有`8'h01`至`8'h0f`错误码保持不变。AMB_CAL/DCS_CAL的
运行时拒绝原因由Scheduler/AMI事务诊断旁带承载，不伪装成管理器ACTIVE错误码。配置管理器明确不增加
`calibration_plan`字段、校准计划输入或实际AMB_CAL/DCS_CAL请求输入，也不为未来事务预留推测性错误码。

`8'h10`的校验优先级位于枚举合法性之后、IDAC码范围之前。若同一快照同时包含更高优先级错误，
管理器按上述固定顺序报告首个错误；无论报告哪一项，ACTIVE快照、`active_valid`和全部epoch均不得改变。

COMMIT校验使用当前拍完整候选ACTIVE与当前已提交`i_static_characterization_enable`；START校验使用当前ACTIVE与START拍观察到的同一资格输入。若该输入在合法COMMIT后、START前由0变为1，管理器必须在START时重新执行STATIC_BIAS组合检查，不能沿用COMMIT时的旧判断。输入为0只表示本次RUN不是STATIC_BIAS，不得反向强制`input_source`取值。

## 5. START资格

```text
static_bias_config_legal =
    !i_static_characterization_enable
 || (active_run_profile == CHARACTERIZATION
  && active_input_source == 1'b1)

start_ready = active_valid
           && analog_ready
           && adc_idle
           && datapath_empty
           && idac_idle
           && static_bias_config_legal
           && !i_system_fault_blocking
           && !error_sticky
```

`analog_safe`只用于STOPPING完成，不参与READY到RUN的启动判断。`static_bias_config_legal=0`时必须以`8'h14`拒绝START，保持READY、ACTIVE和全部epoch不变，不得产生START ACK或`run_enable`。

## 6. 版本规则

- 每次合法的1024-bit联合COMMIT都让8-bit `config_epoch`按模256递增一次；V4/V5不得分别递增。
- 只有快照的 `stage1_calibration_valid=1` 时，合法COMMIT才让8-bit `coef_epoch`递增。
- 只有快照的 `stage2_calibration_valid=1` 时，合法COMMIT才让8-bit `stage2_coef_epoch`递增。
- 每次合法完整COMMIT都原子提交两组DC恢复gain和两个valid位，并让8-bit
  `dc_recovery_coef_epoch`递增。
- CHARACTERIZATION使用标称系数且资格位为0时，`coef_epoch`保持不变。
- CHARACTERIZATION使用临时Stage2参数且资格位为0时，`stage2_coef_epoch`保持不变。
- 复位把全部epoch清零；非法命令、非法V4/V5快照和START/STOP均不改变epoch、V4或V5 ACTIVE。

## 7. 自检用例

| 用例 | 期望 |
| --- | --- |
| MGR-01复位 | CONFIG、active_valid=0、四个epoch均为0 |
| MGR-02非法阈值提交 | error=0x07，ACTIVE和epoch不变 |
| MGR-03合法NORMAL提交 | READY、640-bit ACTIVE逐位一致、四个epoch均递增 |
| MGR-04合法START | RUN、run_enable=1、允许新事务 |
| MGR-05 RUN期COMMIT | error=0x02，ACTIVE和epoch不变 |
| MGR-06 STOP及排空 | STOPPING期间禁止新事务，全部idle/safe后回CONFIG |
| MGR-07重复STOP | 产生幂等ACK，不置错误 |
| MGR-08 CONFIG期START | error=0x0a，状态不变 |
| MGR-09标称CHARACTERIZATION提交 | READY、Stage1/Stage2校准epoch不变、DC恢复epoch递增 |
| MGR-10 START资格不足 | error=0x0b，保持READY |
| MGR-11命令冲突 | 无`i_stop_event`时维持既有拒绝/无动作规则；若同拍存在Top合并的`i_stop_event`，STOP优先进入或保持STOPPING，START/COMMIT/status-clear被拒绝并记录`error=0x01` |
| MGR-12配置拒绝矩阵 | 覆盖0x03至0x06、0x08、0x09、0x0e和0x0f，ACTIVE与全部epoch不变 |
| MGR-13 CONFIG期STOP与事件单拍 | error=0x0c，所有事件下一拍自动回低 |
| MGR-14 epoch回绕 | 四个8-bit epoch从8'hff合法递增后回到8'h00，interval=16'hffff合法 |
| MGR-15非法内部状态 | error=0x0d，撤销资格并安全返回CONFIG |
| MGR-16运行类型与初始精度组合 | NORMAL+SAR9提交成功；NORMAL+SAR15返回0x10且ACTIVE与全部epoch不变；CHARACTERIZATION+SAR9和CHARACTERIZATION+SAR15均允许进入READY |
| MGR-17合法组合矩阵 | NORMAL+PHOTODIODE+SAR9、CHARACTERIZATION+PHOTODIODE+RED_ONLY+SAR9/SAR15、CHARACTERIZATION+EXTERNAL_TEST_CURRENT+BOTH/RED_ONLY/IR_ONLY+SAR9/SAR15和STATIC_BIAS+input_source=1均可提交或启动 |
| MGR-18非法组合矩阵 | NORMAL+SAR15、NORMAL+EXTERNAL_TEST_CURRENT、CHARACTERIZATION+SEARCH_HOLD/SEARCH_TRACK、CHARACTERIZATION+PHOTODIODE非RED_ONLY和CHARACTERIZATION+EXTERNAL_TEST_CURRENT+OFF分别返回0x10/0x11/0x12/0x13/0x16 |
| MGR-19 STATIC_BIAS源资格 | `static_characterization_enable=1 && input_source=0`在COMMIT/START前返回0x14，ACTIVE和epoch保持 |
| MGR-20保留IDAC编码 | `idac_mode=2'b11`在COMMIT/START前返回0x15，ACTIVE和epoch保持 |
| MGR-21校准责任边界 | manager只验证静态ACTIVE组合且无`calibration_plan`字段/端口；RUN期间CHARACTERIZATION或SAR15的AMB_CAL/DCS_CAL由Scheduler/AMI在波形和owner启动前拒绝并报告 |
| MGR-22 STATIC_BIAS资格输入所有权 | `i_static_characterization_enable`仅由2 MHz域已提交表征控制输入驱动；合法COMMIT后在START前由0变1时重新检查ACTIVE，非法组合返回0x14且ACTIVE和epoch保持 |
| MGR-23 固定电流光学模式资格 | 非STATIC_BIAS的`CHARACTERIZATION + EXTERNAL_TEST_CURRENT`仅接受`BOTH/RED_ONLY/IR_ONLY`；`OFF`返回0x16，ACTIVE和epoch保持 |
| MGR-24 系统阻断START门 | `i_system_fault_blocking=1`时START被拒绝、不进RUN且`o_run_generation`不变；阻断解除并满足全部正常启动/排空资格后，下一次合法START才递增generation。 |

## 8. 综合实现约束

内部生命周期状态必须保持3-bit用户编码，不得由综合工具缩减或重新编码为2-bit。RTL中的
`fsm_encoding = "user_encoding"`和`fsm_safe_state = "default_state"`属性属于本合同的实现
约束，用于保留`3'b100`至`3'b111`非法编码空间以及`ERROR_FRAME_STATE=8'h0d`安全恢复路径。
该约束不改变外部2-bit生命周期编码、端口列表或周期级功能行为。

## 9. V4.3修订边界

本次小版本修订增加ACTIVE合法组合、固定电流光学模式资格、保留IDAC编码和校准事务责任边界，不修改：

- 640-bit ACTIVE V4位图及任何字段宽度；
- 640-bit ACTIVE字段位图；
- CONFIG、READY、RUN和STOPPING生命周期；
- 四类epoch的递增、保持和回绕规则；
- CHARACTERIZATION按`initial_precision`选择固定初始精度的能力；
- 下游精度控制器对异常NORMAL+SAR15组合执行强制SAR9和协议诊断的纵深保护。

后续RTL实现必须在`flag_snapshot_valid`汇总前加入这些ACTIVE组合检查，并在错误优先级链中返回
`8'h10`至`8'h16`。`i_static_characterization_enable`作为独立已提交表征控制资格，必须由manager
wrapper从顶层唯一2 MHz内部网逐位直连，不得从ACTIVE、SPI source或`run_profile`推导。在该输入的
RTL端口、wrapper连接及MGR-19/MGR-22回归尚未实现前，相关实现证据必须保持`EVIDENCE_PENDING`；
这不改变已冻结的合同所有权或合同级端口定义。MGR-21必须在三模块联合TB中以运行时事务拒绝场景验证，不能用
ACTIVE位替代校准请求。

责任边界统一冻结为：

```text
COMMIT/START前：配置管理器检查ACTIVE和已提交独立资格能够直接判定的静态配置组合
RUN期间：Scheduler/AMI检查实际到达或内部生成的AMB_CAL/DCS_CAL事务资格
```

配置管理器不接收、不存储、不输出校准计划，不预测本次RUN将来是否会请求校准。
