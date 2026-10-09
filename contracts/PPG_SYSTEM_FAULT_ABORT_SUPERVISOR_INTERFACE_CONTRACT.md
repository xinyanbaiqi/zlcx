# PPG System Fault / Abort Supervisor Interface Contract

> Version: V1.6, 2026-10-09.
> V1.6 change record (B merge batch, `verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-090~097, rewritten against baseline `7a8eabf` supervisor and AMI RTL; symbol anchors are "file + symbol (section)"): §1 watchdog parameters frozen as fixed product values 5000/13 with a simulation-start legality check instead of an elaboration reject (F-014/F-024); §2 reset port name corrected to `i_rstn` (F-051); §3 new AMI causes `8'h06`/`8'h07` (source `4'h1`, summary bits 9/10); §5 AMI active-fault fall conditions extended (abort, START, RUN ended by STOP and drained) and F-1/F-2 written into the recovery flow; §6 "a completion-loss timeout void is not fabrication" plus the RUN/drain loss and long-busy handling and the no-deadlock guarantee; §7 SUP-10 attributed to C10 AMI-53 and an evidence-state pointer added. No existing behavior, encoding or ID meaning changes.
> V1.5 record date: 2026-08-20.
> Status: normative supervisor source; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. RTL, final-Top and TB evidence are `EVIDENCE_PENDING`.
> V1.5 change record: freezes episode close/rearm independently of first-fault history and makes the fail-closed matrix, rather than this header, the sole closure verdict.
> Clock domain: one registered 2 MHz system domain. Reset asserts asynchronously and releases synchronously at the owning Top boundary.
> Boundary: the supervisor aggregates registered blocking fault records. It neither creates ADC completion nor releases an ADC owner, changes Scheduler timing, drives `ready`, or forms a combinational feedback path.

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C01 | `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` | V1.10 | Sole direct Top parent, external-abort registration and registered-event fanout boundary. |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.10 | Sole manager STOPPING lifecycle consumer via Top/wrapper forwarding. |
| C03 | `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V1.7 | Sole manager parent and `i_system_fault_blocking`/stop-episode forwarding boundary. |
| C08 | `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` | V1.13 | Scheduler registered fault-record source and stop-drain consumer. |
| C09 | `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | V1.11 | SSW registered fault-record source and stop-drain consumer. |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.5 | AMI registered fault-record source, discard owner and drain predicate source. |
| C17 | `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` | V2.4 | IDAC blocking fault is promoted only through AMI's record path. |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.2 | PWI/precision blocking fault is promoted only through AMI's record path. |

## 1. Ownership and Parameters

The supervisor is the sole owner of system blocking-fault aggregation, first-fault snapshot, watchdog episode state, registered abort and registered system-stop request. AMI, Scheduler and SSW remain the sole owners of their local detection and `fault_active` recovery predicates.

```verilog
parameter integer C_FRAME_ID_WIDTH                    = 16;
parameter integer C_SAMPLE_INDEX_WIDTH                = 16;
parameter integer C_CONFIG_EPOCH_WIDTH                = 8;
parameter integer C_COEF_EPOCH_WIDTH                  = 8;
parameter integer C_DC_RECOVERY_EPOCH_WIDTH           = 8;
parameter integer C_CODE_EPOCH_WIDTH                  = 4;
parameter integer C_RUN_GENERATION_WIDTH              = 8;
parameter integer C_FAULT_CAUSE_WIDTH                 = 8;
parameter integer C_FAULT_SOURCE_WIDTH                = 4;
parameter integer C_FAULT_SUMMARY_WIDTH               = 16;
parameter integer C_ADC_DRAIN_WATCHDOG_CYCLES         = 5000;
parameter integer C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH  = 13;
```

~~Elaboration shall reject `C_ADC_DRAIN_WATCHDOG_CYCLES < 1` or `C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH < $clog2(C_ADC_DRAIN_WATCHDOG_CYCLES + 1)`.~~ V1.6 (F-014/F-024): the two watchdog parameters are **fixed product values** `C_ADC_DRAIN_WATCHDOG_CYCLES = 5000` and `C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH = 13` and shall not be overridden at integration. Verilog-2001 RTL performs no elaboration-time reject; legality (`CYCLES >= 1` and `COUNTER_WIDTH >= $clog2(CYCLES + 1)`) is instead checked at simulation start by reading the actually elaborated values hierarchically, in: the supervisor unit TB (`tb_ppg_system_fault_abort_supervisor.v`, TB-local check `WDPARM`), the control-top smoke TB (`tb_ppg_control_top.v`, `PARAM-WDOG`) and the chip-top TB (`tb_ppg_chip_digital_top.v`, `PARAM-WDOG`). The other width parameters are likewise fixed product values (C01, chip-top contract). `5000` cycles is a provisional one-400-Hz-frame system policy (`2.5 ms` at 2 MHz), not ADC/analog macro timing signoff.

## 2. Complete Supervisor Port Contract

Every local source has the same registered record. `valid` is exactly one 2 MHz cycle; `active` is a registered level. When `identity_valid=0`, every identity field is driven to zero. The source must hold cause and identity stable throughout `valid`.

| Input group | Width | Exact Top producer | Meaning |
| --- | ---: | --- | --- |
| `i_ami_fault_valid` / `active` / `cause` / `identity_valid` / `<FAULT_ID>` | `1/1/8/1/each field` | AMI `o_ami_fault_*` | AMI blocking record and unresolved state. |
| `i_scheduler_fault_valid` / `active` / `cause` / `identity_valid` / `<FAULT_ID>` | `1/1/8/1/each field` | Scheduler `o_scheduler_fault_*` | Scheduler blocking record and unresolved state. |
| `i_ssw_fault_valid` / `active` / `cause` / `identity_valid` / `<FAULT_ID>` | `1/1/8/1/each field` | SSW `o_ssw_fault_*` | SSW blocking record and unresolved state. |
| `i_stop_episode_active` | 1 | manager `o_stop_episode_active` through ACTIVE wrapper and Top `flag_stop_episode_active` | Accepted STOP, system-STOP or abort drain episode. |
| `i_adc_physical_idle` | 1 | Top `flag_adc_physical_idle` | Synchronized physical fact only; never completion. |
| `i_diag_clear_event` | 1 | Top `flag_diag_clear_event` | Sole registered system diagnostic-clear event. |
| `i_measurement_result_discard_event` | 1 | AMI `o_measurement_result_discard_event` | Registered one-cycle lifecycle observation. It is the sole input that sets the non-blocking result-discard summary. |
| ~~`i_rstn_2m`~~ `i_rstn` (V1.6, F-051: RTL port name) | 1 | Top reset boundary | Active-low system reset. |

`FAULT_ID` is the observable first-fault group defined by the closure matrix: frame ID, sample index, color, frame type, precision and `run_generation`. A local source may retain a larger `TXN_ID`, but it may not force unsupported epoch fields into the supervisor record.

| Output | Width | Consumer | Rule |
| --- | ---: | --- | --- |
| `o_system_fault_blocking` | 1 | Top -> ACTIVE wrapper -> manager | Registered active blocking state. The path is mandatory and prevents manager START acceptance while high. |
| `o_system_abort_event` | 1 | Top registered owner-abort merge -> AMI, Scheduler, SSW | Exactly-once registered one-cycle event per fault episode. Never manager STOP. |
| `o_system_stop_request_event` | 1 | Top stop merge | Exactly-once registered one-cycle event per fault episode. |
| `o_system_fault_discard_event` | 1 | AMI | Exactly-once registered one-cycle event per blocking-fault episode. It makes AMI select `DISCARD_SYSTEM_FAULT`; it is neither completion nor an owner-release acknowledgement. |
| `o_system_fault_cause_valid` / `cause` / `source` / `identity_valid` / `<FAULT_ID>` | `1/8/4/1/each field` | Top observation / CSR | Atomic first blocking-fault snapshot. |
| `o_system_fault_summary` | 16 | Top observation / CSR | Historical bitwise blocking-cause summary. |
| `o_result_discard_summary_sticky` | 1 | Top observation / CSR | Historical non-blocking lifecycle-discard summary. |

These are logical Top observability signals, not a requirement for package pads. A later CSR, scan or debug mapping may consume them without changing this contract.

## 3. Fixed Encoding

| Code | `cause` | `source` | `summary` bit | Severity |
| ---: | --- | ---: | ---: | --- |
| `8'h01` | AMI protected sample-index mismatch | `4'h1` AMI | 0 | blocking |
| `8'h02` | AMI unrecoverable owner/protocol error | `4'h1` AMI | 1 | blocking |
| `8'h03` | AMI unprovable controlled-recovery context | `4'h1` AMI | 2 | blocking |
| `8'h04` | Precision-window switch timeout or blocking precision-control protocol fault | `4'h1` AMI | 7 | blocking |
| `8'h05` | IDAC controller blocking fault | `4'h1` AMI | 8 | blocking |
| `8'h06` | V1.6. AMI same-slot consecutive ADC completion loss: the same RED/IR/calibration slot was voided `C_ADC_COMPLETION_LOST_LIMIT` (=2) times in a row (C10 §7.1a, lane `flag_owner_lost_fault_hold`) | `4'h1` AMI | 9 | blocking |
| `8'h07` | V1.6. AMI ADC long busy: the owner has been in flight for `2*C_ADC_COMPLETION_LOST_CYCLES` (=9000) cycles and the physical ADC is still not idle (C10 §7.1a, lane `flag_adc_busy_fault_hold`) | `4'h1` AMI | 10 | blocking |
| `8'h11` | Scheduler unrecoverable protocol error | `4'h2` Scheduler | 3 | blocking |
| `8'h21` | SSW identity/owner protocol error | `4'h3` SSW | 4 | blocking |
| `8'h22` | SSW analog-safe protocol error | `4'h3` SSW | 5 | blocking |
| `8'h31` | ADC physical-drain watchdog timeout | `4'h4` Supervisor | 6 | blocking |

`8'h00` / `4'h0` mean none. All other cause values, source values `4'h5`-`4'hF`, and summary bits ~~9-15~~ 11-15 (V1.6) are reserved and must be driven/retained as zero. Cause `8'h04` is emitted only when the registered PWI precision-fault record is active; cause `8'h05` is emitted only when the registered IDAC fault record is active. Both records enter the supervisor only through AMI's single fault-record output. Waveform launch timeout and owner-deadline timeout are Scheduler-local non-blocking diagnostics. Only `i_measurement_result_discard_event` sets `o_result_discard_summary_sticky`; it never claims a fault cause or summary bit. V1.6: this includes the AMI `COMPLETION_LOST` (`2'b11`) discard of a timeout void, which is non-blocking by itself; only the k-th same-slot void raises cause `8'h06`. Detection discard remains an AMI/PWI lifecycle event and is deliberately not a supervisor fault or result-summary source.

Cause `8'h22` (SSW analog-safe protocol error) is a reserved encoding slot only: SSW does not currently emit it (`o_ssw_fault_cause` only maps `8'h21`). See `PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` Section 7.9a (frozen 2026-09-05) for the closed applicability decision; this contract's table above is unchanged.

## 4. Snapshot, Events, Episode Rearm and Same-Cycle Rules

The first eligible blocking source captures cause, source and all identity fields atomically. Priority is watchdog, AMI identity/protocol, Scheduler, SSW; equal class ties use AMI, Scheduler, then SSW. Later faults set only their summary bit. A new fault wins over same-cycle clear.

```text
reset
> new blocking fault
> existing active fault hold
> legal diagnostic clear
```

An episode opens on a registered eligible blocking record when the prior
episode is closed. At that opening edge, the supervisor sets blocking and emits
exactly one `o_system_abort_event`, `o_system_stop_request_event` and
`o_system_fault_discard_event`. The abort fans only to transaction owners. The
Top alone registers the OR of external STOP, external abort-drain stop request
and `o_system_stop_request_event` into the manager STOP input; an abort is
never recoded as STOP. Repeated local fault, repeated STOP or repeated abort in
an open episode cannot create another event.

An episode closes, independently of diagnostic history, on the first 2 MHz
edge after all three local `fault_active` inputs are low and the watchdog is
recovered. Watchdog recovery is true when no timeout is latched, or after a
latched timeout when real `i_adc_physical_idle=1` has been sampled. Closing an
episode does not clear the first-fault snapshot, summary or discard sticky.
Therefore a later independent blocking record opens a new episode and emits one
new abort/stop/discard trio even when the previous first-fault snapshot has not
yet received `i_diag_clear_event`. That later record sets its summary bit but
never overwrites the retained first-fault cause/source/identity.

The fixed same-edge priority is `reset > eligible new blocking record > open
episode hold/recovery computation > episode close > legal diagnostic clear`.
Thus a new fault wins over simultaneous close or clear; clear is legal only
after recovery and does not suppress a following episode. `o_system_fault_discard_event`
is zero for an external abort that has no independently recorded blocking fault.

## 5. Recovery and Diagnostic Clear

| Condition | Required action |
| --- | --- |
| AMI active fault | It falls only after a matching normal completion or a proven original-ID, exactly-once `success=0` controlled release leaves no AMI blocking cause. V1.6: per the final AMI RTL (C10 §6.11, §15.2), AMI lanes `8'h01`/`8'h02`/`8'h03`/`8'h06`/`8'h07` also fall on START, on abort, and when the RUN has been ended by STOP and AMI has drained (`flag_run_context_drained`); a new lane set on the same edge wins over the STOP-drain fall. Lanes `8'h04`/`8'h05` follow their PWI/IDAC recovery predicates. |
| Scheduler active fault | It falls only after its documented safe cancellation/recovery predicate; ordinary deadline diagnostics never assert it. |
| SSW active fault | It falls only after its documented waveform/owner-safe recovery predicate. |
| Watchdog timeout | It remains active until real `i_adc_physical_idle=1` and the manager closes the drain episode, or until reset. |
| System active fault | `o_system_fault_blocking` falls on the next 2 MHz edge after all local active levels are low and watchdog recovery is true. |
| `i_diag_clear_event` while any cause is active | No action. It cannot release an owner, abort, injection request or pending result. |
| `i_diag_clear_event` after all recovery | Clear first-fault snapshot, summary and discard summary only. |
| START | Never clears historical snapshot. START is rejected while system blocking is high. |
| Reset | Clears all supervisor state and events. |
| V1.6: F-1 (accepted known exception) | Dual-optical IR completion loss in the same macro frame as a pending precision switch: the void (about macro tick 4810) is later than the precision commit point (tick 4760), the switch hold blocks the next NORMAL frame, the switch times out after 10000 cycles and AMI reports cause `8'h04`; the supervisor opens an episode, aborts and requests STOP. Recovery: after the drain, diagnostic clear, then COMMIT/START. This is the one case where a single completion loss escalates (C10 §7.1a, C23 §15). |
| V1.6: F-2 | If the k-th same-slot void lands at the end of a host-STOP drain, lane `8'h06` is held for one cycle only (the STOP-drain fall clears it); the cause-`8'h06` episode opens only after the manager has returned to CONFIG, and the supervisor STOP request then makes the manager record error `0x0C`. A diagnostic clear is required before the next START (C10 §7.1a). |

## 6. ADC Physical-Drain Watchdog

The watchdog starts only after `i_stop_episode_active=1` proves an accepted external STOP, registered system STOP request or registered abort drain. Normal RUN ADC busy never starts it. If physical idle is high, no episode is counted.

At the accepted drain edge the counter is zero. Each later sampled 2 MHz cycle with `i_adc_physical_idle=0` increments the counter. `i_adc_physical_idle=1` wins on every edge, clears the counter and terminates the episode without timeout. The 5000th consecutive non-idle sample emits one `8'h31` fault record; the timeout latch prevents retriggering during that episode. Repeated STOP does not restart counting.

Timeout prohibits new work through registered abort/stop handling, but never fabricates `CLK_DOUT`, RAW, completion, `success=0`, physical idle or `datapath_empty`. It waits for true idle or reset.

V1.6 (completion loss, C10 §7.1a). An AMI completion-loss timeout void is **not** fabrication: it is a separate, explicitly identified event (`o_adc_transaction_lost_event`, discard reason `COMPLETION_LOST`) decided only by AMI when the owner age has reached T-lost (4500 cycles), the physical ADC is idle and no completion is in the capture chain; it produces no `CLK_DOUT`, RAW, completion or success. Handling by phase:
- During RUN: a lost completion is voided by AMI and the owner is released; the k-th consecutive same-slot void raises cause `8'h06`. An owner whose ADC stays busy for 9000 cycles raises cause `8'h07`; this watchdog does not run in RUN.
- During a STOP/abort drain: the AMI owner age keeps counting, so an owner whose completion is lost is still voided once the ADC is idle, and the digital drain completes. If instead the ADC stays non-idle, this section's drain watchdog reports `8'h31` after 5000 non-idle samples (abort clears AMI lane `8'h07`, so the watchdog is the only long-busy monitor during an abort drain).
- No-deadlock guarantee: every in-flight owner ends in a matching completion, a controlled `success=0` release, an AMI void, or a blocking fault record (`8'h06`, `8'h07` or `8'h31`) that STOPs the system; none of these waits indefinitely without a record.

## 7. Required Evidence

| ID | Contract requirement | Evidence state |
| --- | --- | --- |
| SUP-01 | AMI mismatch captures one atomic snapshot and emits one abort/stop request. | `EVIDENCE_PENDING` |
| SUP-02 | Concurrent records use fixed priority; later records set summary only. | `EVIDENCE_PENDING` |
| SUP-03 | New fault wins over same-cycle clear. | `EVIDENCE_PENDING` |
| SUP-04 | Discard changes only discard summary. | `EVIDENCE_PENDING` |
| SUP-05 | External/system STOP merge is idempotent. | `EVIDENCE_PENDING` |
| SUP-06 | Watchdog boundary, idle priority and no-fabrication behavior are observed. | `EVIDENCE_PENDING` |
| SUP-07 | Clear cannot release active owner/cause; legal clear removes history. | `EVIDENCE_PENDING` |
| SUP-08 | Final Top proves mismatch to STOPPING and legal restart. | `EVIDENCE_PENDING` |
| SUP-09 | A blocking fault emits one fault-discard event; an external abort emits none unless a separate blocking record exists. | `EVIDENCE_PENDING` |
| SUP-10 | A single fault-discard event is retained as an AMI-local current-generation reason until terminal digital drain, so delayed discardable work remains `DISCARD_SYSTEM_FAULT` without a repeated supervisor pulse. V1.6: this is AMI behavior; the governing entry is C10 AMI-53 (the row is kept here so the ID is not reused). | `EVIDENCE_PENDING` |

V1.6 evidence pointer: the supervisor unit TB sub-labels `SUP03A`, `SUP06A`, `SUP09A` and `SUP10A` do not test the same-numbered rows above, and the TB banner "SUP-01 through SUP-10 PASS" also covers rows without a check. The mapping between TB checks and these IDs, and the current evidence state, are kept in the alias table (SUP rows) and matrix §13 (ID=SUP-01…SUP-10); SUP-05 and SUP-08 currently have only partial evidence (`verification_reports/ID_GOVERNANCE_AUDIT_FOLLOWUP_20261005.md` §2).
