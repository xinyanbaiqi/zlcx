# PPG System Fault / Abort Supervisor Interface Contract

> Version: V1.5, 2026-08-20.
> Status: normative supervisor source; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. RTL, final-Top and TB evidence are `EVIDENCE_PENDING`.
> V1.5 change record: freezes episode close/rearm independently of first-fault history and makes the fail-closed matrix, rather than this header, the sole closure verdict.
> Clock domain: one registered 2 MHz system domain. Reset asserts asynchronously and releases synchronously at the owning Top boundary.
> Boundary: the supervisor aggregates registered blocking fault records. It neither creates ADC completion nor releases an ADC owner, changes Scheduler timing, drives `ready`, or forms a combinational feedback path.

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C01 | `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` | V1.10 | Sole direct Top parent, external-abort registration and registered-event fanout boundary. |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.9 | Sole manager STOPPING lifecycle consumer via Top/wrapper forwarding. |
| C03 | `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V1.6 | Sole manager parent and `i_system_fault_blocking`/stop-episode forwarding boundary. |
| C08 | `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` | V1.11 | Scheduler registered fault-record source and stop-drain consumer. |
| C09 | `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | V1.9 | SSW registered fault-record source and stop-drain consumer. |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.3 | AMI registered fault-record source, discard owner and drain predicate source. |
| C17 | `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` | V2.3 | IDAC blocking fault is promoted only through AMI's record path. |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.1 | PWI/precision blocking fault is promoted only through AMI's record path. |

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

Elaboration shall reject `C_ADC_DRAIN_WATCHDOG_CYCLES < 1` or `C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH < $clog2(C_ADC_DRAIN_WATCHDOG_CYCLES + 1)`. `5000` cycles is a provisional one-400-Hz-frame system policy (`2.5 ms` at 2 MHz), not ADC/analog macro timing signoff.

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
| `i_rstn_2m` | 1 | Top reset boundary | Active-low system reset. |

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
| `8'h11` | Scheduler unrecoverable protocol error | `4'h2` Scheduler | 3 | blocking |
| `8'h21` | SSW identity/owner protocol error | `4'h3` SSW | 4 | blocking |
| `8'h22` | SSW analog-safe protocol error | `4'h3` SSW | 5 | blocking |
| `8'h31` | ADC physical-drain watchdog timeout | `4'h4` Supervisor | 6 | blocking |

`8'h00` / `4'h0` mean none. All other cause values, source values `4'h5`-`4'hF`, and summary bits 9-15 are reserved and must be driven/retained as zero. Cause `8'h04` is emitted only when the registered PWI precision-fault record is active; cause `8'h05` is emitted only when the registered IDAC fault record is active. Both records enter the supervisor only through AMI's single fault-record output. Waveform launch timeout and owner-deadline timeout are Scheduler-local non-blocking diagnostics. Only `i_measurement_result_discard_event` sets `o_result_discard_summary_sticky`; it never claims a fault cause or summary bit. Detection discard remains an AMI/PWI lifecycle event and is deliberately not a supervisor fault or result-summary source.

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
| AMI active fault | It falls only after a matching normal completion or a proven original-ID, exactly-once `success=0` controlled release leaves no AMI blocking cause. |
| Scheduler active fault | It falls only after its documented safe cancellation/recovery predicate; ordinary deadline diagnostics never assert it. |
| SSW active fault | It falls only after its documented waveform/owner-safe recovery predicate. |
| Watchdog timeout | It remains active until real `i_adc_physical_idle=1` and the manager closes the drain episode, or until reset. |
| System active fault | `o_system_fault_blocking` falls on the next 2 MHz edge after all local active levels are low and watchdog recovery is true. |
| `i_diag_clear_event` while any cause is active | No action. It cannot release an owner, abort, injection request or pending result. |
| `i_diag_clear_event` after all recovery | Clear first-fault snapshot, summary and discard summary only. |
| START | Never clears historical snapshot. START is rejected while system blocking is high. |
| Reset | Clears all supervisor state and events. |

## 6. ADC Physical-Drain Watchdog

The watchdog starts only after `i_stop_episode_active=1` proves an accepted external STOP, registered system STOP request or registered abort drain. Normal RUN ADC busy never starts it. If physical idle is high, no episode is counted.

At the accepted drain edge the counter is zero. Each later sampled 2 MHz cycle with `i_adc_physical_idle=0` increments the counter. `i_adc_physical_idle=1` wins on every edge, clears the counter and terminates the episode without timeout. The 5000th consecutive non-idle sample emits one `8'h31` fault record; the timeout latch prevents retriggering during that episode. Repeated STOP does not restart counting.

Timeout prohibits new work through registered abort/stop handling, but never fabricates `CLK_DOUT`, RAW, completion, `success=0`, physical idle or `datapath_empty`. It waits for true idle or reset.

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
| SUP-10 | A single fault-discard event is retained as an AMI-local current-generation reason until terminal digital drain, so delayed discardable work remains `DISCARD_SYSTEM_FAULT` without a repeated supervisor pulse. | `EVIDENCE_PENDING` |
