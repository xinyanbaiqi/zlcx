# PPG Real RAW Generator Testbench Contract

> V1.7 fail-closed integration review, 2026-08-20: public joint/final-Top evidence obligations, explicit STOP discard and non-blocking deadline classification remain normative, but system closure is `NOT_CLOSED` until the matrix audit records zero defects. Runtime evidence is `EVIDENCE_PENDING`.
> V1.7 change record: replaces the obsolete mixed-version dependency list and removes the competing current `V1.3 frozen` status. It changes no scenario, timing, acceptance ID or verification verdict.

> Historical V1.3 frozen status (non-normative)
>
> Freeze date: 2026-08-17
>
> Scope: Scheduler + SSW + AMI joint-testbench behavioral sources and acceptance only
>
> This contract changes no synthesizable RTL, DUT port, analog-netlist timing window,
> scheduler ownership rule, SSW waveform rule, or AMI result-processing algorithm.
>
> V1.1 revision: freeze the 10-second physical-PPG regression duration and require a
> 64-bit `time`-typed simulation guard with margin; no Verilog source is changed by
> this contract revision.
>
> V1.2 revision: freeze independent-reset grouped PPG algorithm regressions. Each
> group must first re-establish the complete JNT baseline, then execute its own
> NORMAL-SAR9 configuration and real-RAW scenario; no Verilog source is changed by
> this contract revision.
>
> V1.3 revision: freeze fifteen functional verification groups and two global
> verification layers for the Scheduler + SSW + AMI joint testbench. The revision
> retains RAW-01 through RAW-13 and the five V1.2 PPG groups, adds ten explicit
> startup-calibration, tracking, recheck, mode-matrix, numerical, ownership,
> lifecycle, and robustness groups, and freezes the final formatter/lint/Vivado
> evidence gate. This contract revision changes no Verilog source or RTL port.
>
> V1.3 audit closure: add the direct Stage2-reconstruction, DC-recovery,
> dynamic-baseline, and peak/valley mathematical dependencies; freeze calibration
> absolute timing, complete characterization isolation, explicit IDAC/recheck failure
> behavior, invalid-sample robustness, public-interface-only backpressure, and 107
> stable acceptance IDs for the ten new groups. This closure changes no group count,
> RTL, DUT port, timing rule, algorithm, testbench source, or prior evidence status.
>
> V1.3 P1 audit correction: require every AMB_CAL and DCS_CAL conversion used by
> startup calibration or periodic recheck to traverse the real Q3-end, asynchronous
> CLK_DOUT/RAW, AMI capture, identity-match, and completion-sideband chain; separate
> per-group stable-ID closure from the final 107-ID aggregate closure. This correction
> changes no group count, acceptance ID, RTL, DUT port, or analog timing point.
>
> V1.3 P1 recheck-state correction: align successful and failed periodic-recheck
> recovery with PWI-05. Recheck accept clears temporary detection and precision-tail
> state but preserves the latest reliable peak anchor and active slope; successful
> recovery reuses those preserved values, while failure, protocol fault, or explicit
> reacquire invalidates the anchor and reloads the configured fixed slope. This
> correction changes no group count, acceptance ID, RTL port, or arithmetic rule.
>
> V1.3 stable-ID closure correction: bind every periodic-recheck AMB/DCS conversion
> to the real asynchronous ADC completion chain, extend fixed-current RED_ONLY and
> IR_ONLY cases with their 400-Hz and LED/LEDDAC-off requirements, and explicitly
> prohibit Q1/Q2/Q3, CLK_DOUT, owner, and completion activity in STATIC_BIAS. This
> correction changes no group count, acceptance ID, RTL port, or physical timing.
>
> V1.3 layered-backpressure correction: align OIB waveform, ADC-owner/AMI-start,
> and formal-result acceptance with the frozen Scheduler hard-real-time boundaries.
> A waveform context may wait only before its fixed handover point; an ADC owner may
> wait only before its owner deadline; a completed formal result remains a held
> ready/valid transaction. Crossing either hard deadline is an expected bounded-loss
> branch only when the required timeout, no-late-fire, no-sample-index-consumption,
> and no-fabricated-result checks all pass. This correction changes no group count,
> stable acceptance ID, RTL port, fixed handover point, Q3 location, or owner deadline.
>
> V1.3 controlled-fault-injection correction: freeze the end-to-end verification
> semantics required by LFA-08 and PRC-08. A separately versioned public
> verification boundary may inject only a wrong completion `sample_index` or an explicit
> invalid-sample qualification only when a protected test mode is enabled. The
> injected condition must traverse the production identity, fault, qualification,
> and recovery logic; direct force, hierarchical mutation, special RAW values, or
> reuse of calibration-valid controls is not evidence. This correction changes no
> group count or stable acceptance ID and does not itself implement an RTL port.
>
> V1.3 fault-injection interface-shape alignment: the separately versioned AMI
> V1.3.4, FIR V2.1, precision-window V1.2, and top V1.3.5 contracts now freeze the
> exact protected injection and sample-valid port names, one-shot valid/ready
> binding, production-default disable, and future final-top connection position.
> The joint-TB contract adopts those names without changing its 107 stable IDs.
> RTL, TB, final-top, and supervisor implementation evidence is `EVIDENCE_PENDING`; this predecessor-level interface freeze does not assert system `CONTRACT_CLOSED`. The matrix owns the only system closure verdict.
>
> V1.3 P1 fork-and-recovery correction: require transaction-local sample-valid
> snapshots for both AMI DC-result fork consumers, and require STOP or registered
> system abort after an injected identity mismatch to replay the buffered original
> identity exactly once as a `success=0` completion. This correction adds no stable
> ID and does not change Scheduler timing or treat missing RTL/TB evidence as PASS.

## 1. Purpose and Boundary

This contract defines both the deterministic PPG RAW source and the verification
scope that uses that source in the joint Scheduler, SSW, and AMI testbench. It
replaces only test stimulus and testbench checking behavior. It is not a chip RTL
block and must not be instantiated in a synthesizable implementation.

The generator shall produce one physiological PPG RAW sample for each accepted
`PHOTODIODE`-input NORMAL measurement waveform context of each color in each physical
frame:

```text
physical frame N
    RED NORMAL waveform context -> one RED RAW sample[N]
    IR  NORMAL waveform context -> one IR  RAW sample[N]
```

AMB_CAL and DCS_CAL are calibration transactions, not samples in the RED/IR
physiological PPG series. Their input values remain governed by the existing
calibration testbench model, but the V1.3 joint acceptance scope shall verify their
physical scheduling, code snapshot, result identity, and IDAC sequence interaction.

`EXTERNAL_TEST_CURRENT` is a characterization input source, not a physiological PPG
source. It shall use its independently configured fixed-current stimulus and must not
be silently replaced by this pulse, drift, notch, or noise model. `STATIC_BIAS` does
not use a RAW source and shall retain its frozen static-vector behavior. Both modes
remain inside the V1.3 joint-testbench acceptance matrix even though the physiological
RAW generator is inactive for them.

The generator is an input model only. It must not create, edit, or release any ADC
result owner, and it must not directly drive an AMI completion sideband.

## 2. Normative Dependencies

The timing, ownership, fixed-point arithmetic, qualification, and detection semantics
of this contract are subordinate to the following current active contracts:

1. C01 — `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.10.
2. C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.10.
3. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.9.
4. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.3.
5. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.5.
6. C06 — `ppg_system_integration/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.3.
7. C17 — `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` V2.3.
8. C16 — `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` V2.
9. C19 — `ppg_system_integration/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md` V2.5.
10. C18 — `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.0.
11. C23 — `ppg_system_integration/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md` V2.6.
12. C11 — `ppg_system_integration/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md` V1.
13. C14 — `ppg_system_integration/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md` V1.2.
14. C15 — `ppg_system_integration/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md` V1.
15. C20 — `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` V2.6.
16. C22 — `ppg_system_integration/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` V2.6.

`PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md`, prior versions, RTL,
testbench logs and delivery evidence are non-normative references. They cannot
define a DUT connection, acceptance result or contract-closure state.

If this contract conflicts with an owner, waveform-context, Q3, completion,
fixed-point arithmetic, rounding, saturation, qualified-sample, baseline, or
peak/valley rule in a dependency, the dependency takes precedence. The RAW model may
not resolve a conflict by moving a timing point, changing mathematics, or fabricating
a sample, event, or completion.

## 3. Required RAW Waveform Content

For each color, the generated RAW sequence shall be deterministic and reproducible
from its frozen model parameters and physical-frame index. It shall include all of
the following components:

| Component | Required behavior |
| --- | --- |
| Fast systolic rise | A comparatively short rising portion from the local low point to the primary peak. |
| Slow diastolic decay | A longer falling portion after the primary peak. |
| Dicrotic notch | A local downward notch after the primary peak followed by a bounded rebound. |
| Baseline drift | A low-rate change of the DC baseline across physical frames. |
| Deterministic noise | A bounded, repeatable fixed-amplitude sequence; `$random`, `$urandom`, simulator seed state, and wall-clock time are prohibited. |

The RED and IR series have independent state and may use different frozen DC offsets,
pulse amplitudes, and noise phases. Their physical frame identity remains the same.
The model may not infer a color from a fixed simulator time; it shall use the accepted
waveform/owner context color field.

The intended arithmetic form is:

```text
raw_unclamped(color, frame) =
    dc_offset(color)
  + pulse_shape(color, frame mod pulse_period_frames)
  + baseline_drift(color, frame)
  + deterministic_noise(color, frame)

raw(color, frame) = clamp(raw_unclamped, ADC_min(precision), ADC_max(precision))
```

`pulse_shape` shall exhibit the five required characteristics above. Clamping must be
explicit in the testbench model. Overflow, wraparound, X/Z propagation, or implicit
Verilog signedness conversion must not determine an ADC RAW value.

## 4. Parameterization and Reproducibility

The following are frozen as named testbench-model parameters, but their numerical
defaults are intentionally not frozen by this contract because no measured optical
target values have been supplied:

| Parameter class | Per-color requirement |
| --- | --- |
| DC offset | Independent RED and IR value. |
| Pulse period | Positive integral count of physical frames. |
| Systolic interval and amplitude | Defines the fast-rise section. |
| Diastolic interval and decay | Defines the slow-decay section. |
| Notch position, depth, and rebound | Defines the dicrotic feature. |
| Baseline-drift period and amplitude | Slow relative to the pulse waveform. |
| Noise amplitude and sequence table | Fixed, bounded, and deterministic. |
| ADC numeric range | Explicit per SAR9/SAR15 RAW representation. |

Once a joint-TB configuration selects those values, a rerun with identical waveform
contexts must generate bit-identical RAW values. Changes to these parameters require
a versioned testbench configuration record; they must not be made through an
unrecorded simulator seed.

SAR9 and SAR15 shall use the same underlying physiological sample identity for a
given color and frame. Any Stage1/Stage2 representation conversion shall follow the
existing AMI testbench interface and must be documented at implementation time. It
may change representation or quantization, but may not create a second pulse phase
or a second physical-frame identity.

## 5. Mandatory Causal Timing Chain

For each eligible `PHOTODIODE`-input NORMAL sample, the testbench shall observe and
preserve this causal order:

```text
accepted waveform context
    -> SSW waveform preparation and Q1/Q2/Q3 execution
    -> selected Q3 window has ended
    -> selected asynchronous CLK_DOUT edge carrying the generated RAW code
    -> AMI asynchronous capture, synchronizer, and RAW register
    -> AMI transaction-identity match
    -> AMI completion sideband
```

The generated RAW code becomes eligible for its `CLK_DOUT` transfer only after the
same color, precision, frame identity, and waveform context have completed Q1/Q2/Q3
and the selected Q3 window has ended. It may not be transferred at waveform-context
fire, ADC-owner commit, Q3 entry, or Q3 center.

The testbench shall model `CLK_DOUT` as asynchronous to the 2 MHz AMI clock. The
edge and associated RAW value must be presented to the existing AMI capture input
path; the testbench may not bypass AMI synchronization or directly assign an AMI
completion signal, RAW register, router result, or result-valid signal.

The delay from Q3 end to the `CLK_DOUT` edge may be configurable and deterministic,
but its authorization condition is the completed physical timing chain above, not a
fixed number of system-clock cycles after any `fire` event.

The following patterns are explicitly prohibited:

```text
transaction_start_fire -> repeat(N) -> CLK_DOUT/DONE
adc_owner_commit       -> fixed N clocks -> CLK_DOUT/DONE
Q3 end                 -> direct AMI completion sideband
macro tick             -> direct DONE without RAW capture
```

Only AMI may produce `o_adc_transaction_complete_event` and its associated success
and sample-index sideband. The RAW generator must never drive those signals.

The same physical completion chain is mandatory for every AMB_CAL, DCS_CAL RED, and
DCS_CAL IR conversion used by startup calibration or periodic recheck. The conversion
value may originate from the existing deterministic calibration stimulus model rather
than the physiological PPG generator, but each physical SAR9 conversion must still:

```text
accepted calibration waveform context and committed ADC owner
    -> dedicated AMB/DCS preparation and Q1/Q2/Q3 execution
    -> selected calibration Q3 window end
    -> asynchronous CLK_DOUT edge carrying the calibration RAW code
    -> AMI asynchronous capture and RAW latch
    -> AMI calibration-transaction identity match
    -> AMI completion sideband
```

None of the eight conversions for an evaluated calibration candidate may be satisfied
by directly injecting a calibration result, search evidence, AMI completion sideband,
or internal RAW/result state. A fixed delay from calibration waveform or owner fire is
also insufficient; only completion of the dedicated physical chain authorizes AMI to
produce the matching completion.

## 6. Identity Binding and Owner Semantics

Before scheduling a RAW transfer, the model shall retain a pending identity snapshot:

```text
frame_id
color_ir
precision_mode
frame_type
sample_index
waveform-context acceptance identity
ADC-owner commitment identity
```

The RAW transfer must use the identity of the committed ADC owner. A waveform context
alone is insufficient. This preserves the permitted behavior in which IR waveform
preparation begins at its fixed handover point while the RED ADC owner has not yet
been released.

For NORMAL RED and IR, the model must generate exactly one RAW transfer per committed
owner. It must not produce a duplicate transfer if valid is held, ready backpressures,
or a context is observed more than once in a waveform slot.

If the owner has not committed before its contractual deadline, the model must not
manufacture a RAW transfer to make the test pass. The scheduler/SSW fault and timeout
path remains responsible for that case.

## 7. STOP, Abort, Reset, and Fault Behavior

The RAW source must respect the existing lifecycle semantics without taking ownership
of them:

| Condition | Required RAW-source behavior |
| --- | --- |
| STOP | Do not create a new RAW transfer after a non-eligible owner is withdrawn; an already physical transfer remains subject to AMI's normal controlled-discard rule. |
| Abort after owner commit | The source may deliver the physically outstanding `CLK_DOUT`/RAW transfer only with the original owner identity; AMI must emit the matching `success=0` completion sideband that releases the old physical owner and discards data. |
| Reset | Clear all pending model identities and scheduled transfers. A pre-reset RAW transfer must not be reused to complete a post-reset owner. |
| Owner mismatch | Do not re-label, reuse, or inject the RAW value for a different owner. Let AMI's identity-mismatch diagnostic path operate. |
| Scheduler/SSW fault | Do not synthesize a completion merely to release the owner. |

The RAW source is not permitted to infer a new owner from `adc_idle`, a frame boundary,
or a currently visible color/precision signal. It must use its retained accepted
context and owner snapshot.

### 7.1 V1.4 public injection, discard and final-Top evidence

All new scenarios use public Top/AMI ports only. Test injection is driven by
the registered 2 MHz verification-control source and obeys held valid/payload
until public ready; no hierarchical `force`, internal ready override, synthetic
RAW or fabricated DONE is permitted. LFA-08 injects only a wrong
`sample_index`. Identity and invalid requests are never presented together.

The joint integration run shall prove AMI-local behavior:

```text
accepted request -> production matcher rejection -> AMI fault record
-> owner retained -> STOP or registered abort -> proven original-ID success=0
-> exactly-once owner release -> next legal transaction
```

It shall separately prove PRC-08 consumes an invalid-qualified transaction
without moving FIR, baseline, cross, peak/valley or precision state; RAW,
numeric payload, ID, epochs and normal sample index remain unchanged. For a
backpressured formal result, the run proves normal `valid && ready` wins over a
same-edge discard; otherwise it observes the one-cycle AMI measurement discard
record with stable branch ID. Detection discard is observed without ready and
PWI/FIR/detector empty may assert only in the next cycle.

The final-Top run shall prove AMI/Scheduler/SSW record wiring to the supervisor,
fixed snapshot codes, registered abort, registered system STOP request, manager
STOPPING, watchdog boundary/idle priority, diagnostic clear after recovery and
a legal fresh generation START. A current joint run and a current final-Top run
are both mandatory for LFA-08 closure. Expected waveform/owner timeout,
explicit result discard, watchdog timeout and unexpected protocol fault remain
separate aggregate classes; none may be silently treated as PASS.

## 8. Joint-Testbench Acceptance Matrix

### 8.1 Long-run Physical Time Scale

The real PPG RAW regression shall cover at least 10 seconds of post-START physical
measurement time. At the frozen 400 Hz physical-frame rate and 2 MHz system clock,
the minimum mandatory coverage is:

| Quantity | Frozen minimum | Derivation |
| --- | ---: | --- |
| Physical PPG duration | `10_000_000_000 ns` | 10 seconds |
| Physical macro frames | 4,000 | 400 frames/s x 10 s |
| 2 MHz system-clock cycles | 20,000,000 | 2,000,000 cycles/s x 10 s |
| RED physiological samples | 4,000 | one NORMAL RED sample per physical frame |
| IR physiological samples | 4,000 | one NORMAL IR sample per physical frame |

The following declaration requirements are normative for the future joint-TB update:

```verilog
localparam time C_PPG_MIN_DURATION_NS = 64'd10000000000;
localparam time C_SIM_TIMEOUT_NS       = 64'd12000000000;
```

`C_SIM_TIMEOUT_NS` must be declared as `time`, not as a 32-bit `integer`. A 10-second
value expressed at `timescale 1ns / 1ps` is `10_000_000_000 ns`, which exceeds the
maximum signed 32-bit integer value. The frozen 12-second guard provides a two-second
allowance for reset release, START, controlled drain, and terminal checks; it is a
watchdog limit, not part of the 10-second physiological observation window.

The 10-second measurement interval begins at the accepted measurement START event.
Timeout arithmetic and its stored start timestamp shall both use `time`-typed values,
for example `$time - reg_measurement_start_time`. The testbench must not truncate,
cast through a 32-bit `integer`, or infer elapsed physical time from a fixed test-task
iteration count.

The regression shall separately prove that at least 4,000 RED and 4,000 IR eligible
NORMAL physical-frame sample opportunities occur after START. A timeout merely
reaching 10 seconds is not evidence that the required waveform contexts, Q3 windows,
owner commits, and AMI completion path actually operated.

The future joint-TB implementation shall add a named RAW-generator acceptance group.
It must cover at least the following checks in addition to the existing JNT baseline:

| ID | Acceptance requirement |
| --- | --- |
| RAW-01 | RED and IR each produce one `PHOTODIODE`-input NORMAL RAW sample per accepted physical frame. |
| RAW-02 | A trace demonstrates a fast rise, slow decay, dicrotic notch/rebound, and baseline drift. |
| RAW-03 | The deterministic noise sequence has the configured fixed bound and is bit-identical on repeat simulation. |
| RAW-04 | The code is explicitly clamped at the selected SAR numeric bounds. |
| RAW-05 | No `CLK_DOUT` occurs before the selected Q3 window has ended. |
| RAW-06 | `CLK_DOUT` enters the real AMI async capture path; the testbench does not directly drive AMI completion outputs or internal result state. |
| RAW-07 | Completion occurs only after AMI capture and owner-identity matching, not after a fixed fire-relative clock count. |
| RAW-08 | IR waveform preparation can precede RED completion, while IR RAW transfer still waits for IR owner commit. |
| RAW-09 | SAR9/SAR15 conversion retains the same color/frame physiological sample identity. |
| RAW-10 | Abort permits only the matching old-owner `success=0` release path; reset prevents old RAW reuse. |
| RAW-11 | Missing owner commitment, owner timeout, or mismatch cannot be hidden by a generated DONE. |
| RAW-12 | A post-START run covers at least 10 seconds, 4,000 physical frames, and 20,000,000 2 MHz cycles without a 32-bit timeout overflow. |
| RAW-13 | The guard is a `time`-typed 12-second watchdog; it neither shortens the 10-second observation window nor substitutes for frame/sample coverage checks. |

The testbench must log the waveform context acceptance, Q3 completion, asynchronous
`CLK_DOUT` edge, AMI RAW capture, and AMI completion sideband with their bound
identities. A PASS result may not be based solely on the final count of result-valid
events.

## 9. Fifteen Independent Functional Verification Groups

V1.3 freezes fifteen functional groups. A group is a verification scenario class,
not a single assertion. Each group contains all numerical, timing, identity, state,
and negative checks required by its definition. The groups shall be separate
simulations or separate fully reset test phases. No group may inherit baseline,
FIR, peak/valley, precision, IDAC, RAW-generator, owner, or pending state from a
previous group.

### 9.1 Common Group Entry and Result Rule

Every group that exercises stateful Scheduler, SSW, or AMI behavior shall use this
high-level order:

```text
independent reset
    -> JNT-01 through JNT-09 baseline, all 52 sub-checks PASS
    -> configure the group-specific scenario
    -> run the contractual physical or static causal sequence
    -> execute the group-specific scoreboard
```

The JNT baseline is a prerequisite, not evidence that the functional group passed.
After the baseline, the group-specific configuration and START sequence shall begin
from contractually clean state; no JNT transaction, owner, pending update, detector
history, or RAW phase may leak into the group. A group fails if fewer than 52 JNT
sub-checks pass, even when its group-specific end condition appears satisfied.

### 9.2 Existing Five PPG Algorithm Groups

| No. | Group | Required stimulus and checks |
| ---: | --- | --- |
| 1 | `PPG-BASELINE-WARMUP` | Begin in NORMAL SAR9 and run enough real color samples to establish FIR and dynamic-baseline history. Confirm that insufficient history cannot qualify a cross, that only valid same-color recovered samples advance history, and that each eligible RED center sample advances the expected cycle-level baseline state. |
| 2 | `PPG-CROSS-SAR15` | Use the deterministic waveform to create a qualified upward baseline crossing after warmup. Check that the request comes from the real data path, waits for the contractual safe boundary, and commits SAR15 without changing waveform handover, Q3, color identity, sample order, or code epochs. |
| 3 | `PPG-PEAK-VALLEY-RETURN` | Starting from a committed SAR15 measurement, continue the same physical sequence through a qualified peak and valley. Check peak-before-valley ordering, bound center-sample identity, the contractual return request, and safe SAR15-to-SAR9 commit. |
| 4 | `PPG-FIR-TAIL-ISOLATION` | Exercise SAR15-to-SAR9 return with valid old SAR15 FIR history present. Confirm that the old precision tail cannot qualify a new SAR9 cross and that restored SAR9 samples rebuild only the permitted same-precision adjacency evidence. |
| 5 | `PPG-LONG-10-CYCLES` | Run at least 10 seconds, 4,000 macro frames, and ten complete configured pulse periods. Check repeated baseline generation, precision entry/return, RED/IR continuity, bounded RAW arithmetic, and absence of accumulated stale context or owner leakage. |

`PPG-LONG-10-CYCLES` may use any frozen deterministic pulse-period parameter that
fits at least ten complete periods in the mandatory 10-second window. The selected
period and resulting cycle count must be logged; the group must not claim ten cycles
merely because 10 seconds elapsed.

### 9.3 Ten Additional Joint Verification Groups

| No. | Group | Required stimulus and checks |
| ---: | --- | --- |
| 6 | `STARTUP-IDAC-CALIBRATION` | Execute START, the one-shot startup IDAC safe boundary, and the fixed AMB -> DC_R -> DC_IR startup search. Every calibration transaction uses local Q3=266; eight Q3 centers are separated by exactly 625 ticks; owner commits no later than local tick 248; and a candidate update after tick 385 affects only the next subframe. Use eight physical SAR9 conversions for every evaluated candidate code. Prove the dedicated AMB/DCS netlist waveforms, LED state, pre-warmup code latching, request/result identity, success, exhaustion, wrong-identity rejection, and that no first NORMAL owner or result is accepted before `startup_search_complete`. |
| 7 | `NORMAL-IDAC-SLOW-TRACKING` | Drive independent RED and IR high/low threshold evidence. Prove consecutive-confirmation counting, direction reversal, one-LSB pending updates, safe-boundary-only commit, update pulse and epoch behavior, min/max non-wrap, epoch wrap identity, wrong-snapshot rejection, and tracking-state retention across SAR9/SAR15 transitions. Only signed 12-bit calibrated Stage1 evidence may drive tracking; Stage2, reconstructed 15-bit, coarse/fine DC-recovered, and formal-output values may not drive it. |
| 8 | `PERIODIC-RECHECK-RECOVERY` | Count completed NORMAL macro frames, not color transactions, to the configured interval; wait for legal SAR15-to-SAR9 return and full ADC/fork/FIR/detector/IDAC drain; then execute AMB -> DC_R -> DC_IR. At accept, atomically invalidate both FIR histories, stale cross candidates, old extrema/direction state, and passive precision-tail context without clearing the latest reliable peak anchor or active slope. Cover changed and unchanged AMB paths, formal-output inhibition, successful retention and reuse of the reliable anchor/slope, two-color 21-sample re-warmup and new cross, failure-to-reacquire with anchor invalidation and fixed-slope reload, and proof that no old event can revive. |
| 9 | `NO-RECHECK-CROSS-CONTROL` | Set `amb_recheck_interval_frames=0` and run a complete PPG sequence. No recheck pending, accept, busy, done, failed, or recheck-driven history clear may occur; FIR, baseline, cross, SAR15 entry, peak/valley, and SAR9 return must still complete through the normal path. |
| 10 | `INPUT-LIGHT-STATIC-MATRIX` | Cover legal PHOTODIODE NORMAL dual-color operation, PHOTODIODE RED_ONLY fixed SAR9/SAR15 characterization, EXTERNAL_TEST_CURRENT BOTH/RED_ONLY/IR_ONLY fixed SAR9/SAR15 400-Hz intermittent operation, AMB_CAL, DCS_CAL RED/IR, and STATIC_BIAS. Check `EN_TEST`, LEDEN/LEDDAC, selected transactions, fixed precision, manual-code ownership, dedicated calibration waveforms, the exact static vector, atomic `S[4:0]` update, and no measurement or algorithm activity in STATIC_BIAS. Reject EXTERNAL_TEST_CURRENT OFF, characterization search/tracking/recheck, and invalid STATIC_BIAS source without waveform, owner, code-update, or sample-index side effects. Changes to input source, optical mode, or fixed precision during an accepted transaction may affect only a later legal RUN/snapshot. |
| 11 | `ADC-NUMERIC-CODE-SCOREBOARD` | Compare RAW to signed 12-bit Stage1 calibration, Stage1 to coarse DC-recovered output, and SAR15 Stage1+Stage2 reconstruction to coarse/fine DC-recovered outputs. Cover representative positive, negative, rounding, saturation, and endpoint cases, while binding every comparison to color, frame, sample, precision, code snapshot, and all relevant epochs. |
| 12 | `IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION` | Prove that each code is captured before preparation, live input changes cannot alter the current waveform, and only a safe boundary commits a new code. Compare all four 8-bit IDAC buses bit by bit, keep unselected precision buses at zero, isolate RED/IR code and epoch state, and prohibit update or epoch movement when committed code does not change. |
| 13 | `OWNER-IDENTITY-BACKPRESSURE` | Apply deterministic reproducible backpressure only through formal public waveform, ADC-owner, and AMI-result interfaces, and use legal public conditions to induce downstream stalls. Treat waveform handover and ADC-owner establishment as deadline-bounded channels, while treating the completed AMI formal result as a held ready/valid channel. Cover both recovery before the applicable hard boundary and the contracted timeout branch when the boundary is crossed. Prove no loss, duplication, reorder, payload change, half-commit, late fire, fabricated DONE/result, sample-index side effect, or combinational ready loop. Bind each accepted result to frame ID, sample index, color, frame type, precision, AMB/DC code and epochs, and configuration/coefficient/DC-recovery epochs. Direct force or hierarchical mutation of an internal fork is prohibited; exact per-branch fork stalls remain FFK/AMI unit evidence. |
| 14 | `LIFECYCLE-FAULT-ADC-ANOMALY` | Exercise STOP, abort, reset, and clean restart during startup search, NORMAL, SAR15, tracking pending, and periodic recheck. Cover early, duplicate, late, and wrong-identity `CLK_DOUT`/DONE behavior, including only a wrong `sample_index` injected through the protected public verification boundary and rejected by the production identity matcher. Cover owner deadline failure as a non-blocking historical diagnostic, abort-time matching `success=0` release with data discard, reset-time identity invalidation, fault isolation and top-level propagation, explicit recovery, and absence of stale-context recovery. |
| 15 | `PPG-ROBUSTNESS-CORNER-WAVEFORMS` | Use deterministic flat/no-pulse, low-amplitude, high-amplitude or saturated, strong-drift, bounded-noise, fast/slow pulse-period, weak/missing-notch, explicit invalid-sample, and calibration-qualification-loss profiles. The invalid-sample case shall use the protected public verification boundary, not a special RAW value or calibration-valid control. Saturated or unqualified samples may propagate only as their owner contract permits and may not create qualified FIR history, baseline, cross, peak, valley, or precision-control evidence. After an invalid sample, result identity and legal sample ordering remain intact and later legal samples rebuild only the permitted history. |

Backpressure and noise schedules shall be deterministic and recorded. `$random`,
`$urandom`, wall-clock seeds, and unrecorded simulator seed state are prohibited.

### 9.3.1 Layered Public-Interface Backpressure Semantics

The three public boundaries do not share one unlimited ready/valid policy. Their
acceptance behavior is frozen by the physical timing ownership of each channel.

#### Waveform-context handover

The waveform-context payload may be preloaded with `valid=1` before its fixed
contractual handover point. While `ready=0` before that point, `valid` and every
payload bit shall remain stable. The only legal successful transfer is the single
`valid && ready` fire at the fixed handover point: NORMAL RED at macro tick 0,
NORMAL IR at macro tick 160, or AMB_CAL/DCS_CAL at local tick 0.

If `ready` is still zero at that point, the current physical opportunity is lost.
The Scheduler shall assert the contracted launch-timeout diagnostic, cancel that
opportunity without a late waveform fire, and prohibit a Q3 sampling transaction,
asynchronous `CLK_DOUT`/RAW transfer, ADC owner, completion, or formal result for the
missed context. The missed opportunity shall not consume or skip `sample_index`.
Restoring `ready` after the fixed point cannot revive or move that context or Q3;
NORMAL continues with the next legal physical opportunity, while a held calibration
request retries only at a later legal local tick 0.

#### ADC-owner/AMI-start establishment

After a matching waveform context has been accepted, the ADC transaction-start
source may hold `valid=1` with the complete owner payload stable while AMI reports
`ready=0`, but only before that transaction's frozen owner deadline. The single
atomic owner establishment event is `valid && ready`; only this fire binds SSW and
AMI ownership and consumes exactly one `sample_index`. No half-commit is permitted.

If the owner deadline is reached without that fire, the pending owner opportunity
expires, the owner-deadline timeout shall assert, and the affected physical sampling
window shall be suppressed and safely completed. No owner shall be committed, no
`sample_index` shall be consumed or skipped, and no testbench source may fabricate
`CLK_DOUT`, DONE, completion, or a formal result to conceal the timeout. A later
`ready` cannot accept the expired payload; a retry requires a later legal waveform
opportunity under the Scheduler contract.

#### AMI formal-result transfer

Once AMI has produced a formal result, `valid=1 && ready=0` is ordinary result
backpressure rather than a waveform or owner timeout. Every numerical value,
qualification bit, diagnostic, code snapshot, epoch, and identity field shall remain
bit-stable until the single public `valid && ready` transfer. The transaction shall
not be duplicated, dropped, reordered, or cleared before that transfer. Contracted
reset or abort invalidation remains governed by the lifecycle rules and shall be
logged as a lifecycle discard, never reported as a successful result transfer.

For waveform and owner channels, every directed OIB run shall cover two separately
logged legal branches:

1. `ready` recovers before the applicable fixed handover point or owner deadline;
   the held payload transfers once and the normal transaction completes.
2. `ready` remains low across the applicable hard boundary; the matching timeout is
   expected, no late transfer or fabricated result occurs, no `sample_index` side
   effect occurs, and a later legal opportunity recovers without stale context.

An expected timeout is PASS evidence only when all branch-specific comparisons above
pass. A timeout message by itself, any unclassified protocol/SSW/AMI fault, or a
blanket waiver of timeout diagnostics is a failure or `NOT_CLOSED`, never PASS.

### 9.4 Stable Acceptance IDs for the Ten Added Groups

Every ID in this section is a mandatory signal comparison. A group PASS requires all
of its IDs to pass. A held valid, repeated clock level, final state alone, or printed
message is not an event count and cannot satisfy an ID.

#### 9.4.1 `STARTUP-IDAC-CALIBRATION`: SID-01 through SID-12

| ID | Acceptance requirement |
| --- | --- |
| SID-01 | START creates exactly one startup IDAC safe boundary after the required physical-idle qualifications; it creates no waveform, ADC owner, macro frame, result, or sample-index advance. |
| SID-02 | Automatic startup requests and accepted stages occur strictly in AMB, DC_R, DC_IR order; an enabled stage cannot be skipped or duplicated. |
| SID-03 | AMB_CAL, DCS_CAL RED, and DCS_CAL IR each use local Q3=266 without red/IR NORMAL-Q3 substitution. |
| SID-04 | Every evaluated candidate uses eight physical SAR9 subframes whose adjacent Q3 centers are exactly 625 ticks apart; every subframe completes only through its dedicated Q3 end, asynchronous `CLK_DOUT`/RAW transfer, AMI capture/latch, calibration-identity match, and AMI completion sideband, with no direct result or search-evidence injection. |
| SID-05 | Each calibration ADC owner commits no later than local tick 248; a missed deadline suppresses the affected conversion and cannot consume a sample index. |
| SID-06 | Candidate, confirmed AMB code, color, type, and epochs are captured before preparation; an update after tick 385 affects only the next subframe. |
| SID-07 | AMB_CAL follows its dedicated netlist waveform, keeps both LEDs and all DC buses inactive, and drives only the qualified SAR9 AMB candidate-code window. |
| SID-08 | DCS_CAL RED follows its dedicated netlist waveform and uses the confirmed AMB code plus the DC_R candidate without enabling an IR LED window. |
| SID-09 | DCS_CAL IR follows its dedicated netlist waveform and uses the confirmed AMB code plus the DC_IR candidate without enabling a RED LED window. |
| SID-10 | Exactly eight matching successful results contribute to each candidate evaluation; wrong type, color, sample index, code snapshot, or epoch is consumed only by its contractual reject path and cannot advance the search. |
| SID-11 | A double-saturated or otherwise ineligible sample cannot advance search evidence and must produce the specified protocol diagnostic; no replacement result may be fabricated. |
| SID-12 | Successful AMB/DC_R/DC_IR closure asserts startup complete before the first NORMAL owner; search exhaustion keeps the boundary code, asserts exhausted/fault, leaves startup complete low, and blocks NORMAL. |

#### 9.4.2 `NORMAL-IDAC-SLOW-TRACKING`: TRK-01 through TRK-10

| ID | Acceptance requirement |
| --- | --- |
| TRK-01 | Invalid tracking input or a changing payload while valid is low cannot change evidence, pending code, committed code, or epoch. |
| TRK-02 | In-window evidence clears the matching direction count; consecutive out-of-window evidence reaches pending only at the configured confirmation count. |
| TRK-03 | A high/low direction reversal clears the old count and starts the opposite count at one without producing two pending updates. |
| TRK-04 | RED and IR evidence, pending code, committed code, saturation state, and epoch remain independent under interleaved results. |
| TRK-05 | SAR9/SAR15 transitions preserve same-color evidence, pending code, committed code, and epoch; no precision transition itself produces an update. |
| TRK-06 | While pending waits for a safe boundary, formal PPG consumption continues, the pending payload remains stable, and later evidence cannot overwrite it. |
| TRK-07 | A safe boundary commits at most one signed one-LSB change, emits one update and one track-adjust event, clears the matching count, and increments only that color epoch. |
| TRK-08 | Continued evidence at min/max cannot wrap, emit a false update, or increment epoch; an actual update from epoch 4'hF wraps to zero with correct transaction identity. |
| TRK-09 | A missing calibration-applied qualification or mismatched code snapshot/epoch is consumed but cannot alter tracking evidence or pending state. |
| TRK-10 | Tracking comparisons use only signed 12-bit calibrated Stage1 evidence. Stage2, reconstructed 15-bit, coarse/fine DC-recovered, and formal-output values cannot drive or substitute for that evidence. |

> **2026-09-19 TRK-01 verification-method note (evidence type clarified, requirement unchanged)**:
> this property holds and is satisfied by the current RTL, but not through a dynamic test of the
> literal "payload changes while valid stays low" scenario — that scenario is not constructible on
> real hardware. `ppg_normal_transaction_fork.v`'s `payload_o` and `track_valid_o` registers are
> both written only under the identical `flag_input_transfer` clock-enable condition (two
> independent `always @(posedge i_clk)` blocks, same gating signal), so no event can change
> `payload_o` while `track_valid_o` stays low. A complementary static proof covers the consumer
> side: `ppg_idac_code_controller.v`'s `flag_track_sample_qualified` (`@satisfies: TRK-01, TRK-09`)
> is a pure AND-chain gated by `flag_track_transfer`, so it is structurally 0 whenever transfer is
> 0, independent of payload content. This is satisfaction by construction, not by an independent
> dynamic test — a deliberate choice confirmed by the user 2026-09-19 after evaluating whether to
> add a dedicated test-injection port to force the scenario (rejected: it would only exercise a
> combination that cannot occur on real hardware). **Fragility trigger**: if a future redesign ever
> decouples `payload_o` and `track_valid_o` from a shared clock-enable condition, this requirement's
> satisfaction must be re-verified with a real dynamic test at that time, because the structural
> guarantee this note relies on would no longer hold. Existing (weaker, but independently valid)
> dynamic coverage of the passive "no spontaneous change during silence" property is unaffected and
> retained; see `ppg_system_integration/WORKLINE_D_TRK01_ISE01_20260918.md` for the full
> investigation trail.

#### 9.4.3 `PERIODIC-RECHECK-RECOVERY`: RRC-01 through RRC-12

| ID | Acceptance requirement |
| --- | --- |
| RRC-01 | The interval counter advances once per completed NORMAL macro frame, not once per color or ADC result, and asserts pending at the configured frame count. |
| RRC-02 | Recheck pending during SAR15 cannot start calibration or alter a code; it waits for a real SAR15-to-SAR9 return event. |
| RRC-03 | Accept remains low until ADC, NORMAL fork, IDAC, FIR, detection fork, peak/valley, and held result ownership are all drained. |
| RRC-04 | Accept atomically invalidates both FIR histories, old cross candidates and cycle qualification, old extrema/direction state, and passive precision-tail context, but it must not clear or alter the latest reliable peak anchor or `o_slope_current_q16`; both values are snapshotted for the later success/failure comparison. |
| RRC-05 | The active sequence is exactly AMB, DC_R, DC_IR. Every accepted periodic-recheck calibration conversion completes only through its dedicated Q3 end, asynchronous `CLK_DOUT`/RAW transfer, AMI capture/latch, calibration-identity match, and AMI completion sideband; direct result/search-evidence injection and fixed fire-relative completion are prohibited. Calibration transactions cannot enter the formal PPG output or NORMAL tracking paths. |
| RRC-06 | An in-window unchanged AMB code preserves its code and epoch but still requires DC_R and DC_IR revalidation. |
| RRC-07 | An actual AMB, DC_R, or DC_IR change occurs only at its safe boundary, increments only its epoch, and is used by later waveform/result snapshots. |
| RRC-08 | From accept through successful or failed sequence termination, formal NORMAL output remains inhibited and no baseline, cross, peak, or valley event is accepted. |
| RRC-09 | After success, the latest reliable peak anchor and `o_slope_current_q16` equal their pre-accept snapshots and are reused for the resumed baseline; RED and IR independently require 21 new qualified NORMAL samples before FIR output qualification returns, and old samples or inserted zeros cannot count. |
| RRC-10 | After successful re-warmup, a new upward cross must be formed solely from new eligible history and may enter SAR15 through the normal safe-boundary path. |
| RRC-11 | A failed AMB/DC stage preserves the contractual boundary code, asserts failed/fault, invalidates the old baseline anchor, reloads the configured fixed slope, enters reacquire, and cannot reopen formal NORMAL through stale state; the same anchor invalidation and fixed-slope reload apply to a covering protocol fault or explicit reacquire request. |
| RRC-12 | STOP or abort clears pending/active recheck requests without a code update; an already committed physical owner follows the normal controlled-release rule. |

#### 9.4.4 `NO-RECHECK-CROSS-CONTROL`: NRE-01 through NRE-06

| ID | Acceptance requirement |
| --- | --- |
| NRE-01 | With interval zero, pending, accept, busy, done, and failed remain inactive for the entire RUN. |
| NRE-02 | No recheck-driven FIR-history clear, detector clear, output inhibition, or calibration request occurs. |
| NRE-03 | Both colors complete normal FIR warmup and retain uninterrupted qualified history. |
| NRE-04 | A real baseline crossing enters SAR15, and a qualified peak/valley sequence returns to SAR9 without any recheck event. |
| NRE-05 | The cross identity is bound to normal FIR/baseline evidence and cannot be temporally attributed to START, reset, or a hidden recheck clear. |
| NRE-06 | Long operation preserves owner/result order, code epochs, and result continuity while all recheck counters and events remain disabled. |

#### 9.4.5 `INPUT-LIGHT-STATIC-MATRIX`: ILM-01 through ILM-15

| ID | Acceptance requirement |
| --- | --- |
| ILM-01 | PHOTODIODE NORMAL dual-color operation keeps EN_TEST low and executes the contracted RED/IR LED, waveform, owner, and result sequence. |
| ILM-02 | PHOTODIODE RED_ONLY SAR9 characterization uses one RED transaction per 400-Hz frame, fixed SAR9, committed MANUAL AMB/DC_R codes, and no IR waveform or owner. |
| ILM-03 | PHOTODIODE RED_ONLY SAR15 characterization uses one RED transaction per 400-Hz frame, fixed SAR15, committed MANUAL AMB/DC_R codes, and no precision-window transition. |
| ILM-04 | EXTERNAL_TEST_CURRENT BOTH SAR9 uses 400-Hz intermittent RED/IR transactions with EN_TEST high, fixed SAR9, both LEDEN low, and no LEDDAC drive window. |
| ILM-05 | EXTERNAL_TEST_CURRENT BOTH SAR15 preserves the same 400-Hz intermittent sequence and LED-off rules with fixed SAR15. |
| ILM-06 | EXTERNAL_TEST_CURRENT RED_ONLY in fixed SAR9 and fixed SAR15 uses one RED transaction per 400-Hz intermittent frame with EN_TEST high, both LEDEN low, and no LEDDAC drive window; only RED waveform, owner, and result identities may occur, while IR remains inactive. |
| ILM-07 | EXTERNAL_TEST_CURRENT IR_ONLY in fixed SAR9 and fixed SAR15 uses one IR transaction per 400-Hz intermittent frame with EN_TEST high, both LEDEN low, and no LEDDAC drive window; only IR waveform, owner, and result identities may occur, while RED remains inactive. |
| ILM-08 | EXTERNAL_TEST_CURRENT OFF is rejected before waveform/owner launch and causes no code update, epoch change, frame/sample advance, or LED activity. |
| ILM-09 | Every non-STATIC_BIAS characterization measurement requires MANUAL IDAC; automatic startup search, NORMAL tracking, periodic recheck, and automatic precision switching remain inactive. |
| ILM-10 | After a transaction snapshot, changes to input source, optical mode, initial precision, or MANUAL code cannot alter its waveform or result identity; only a later legal RUN/snapshot may use them. |
| ILM-11 | AMB_CAL uses PHOTODIODE input semantics, EN_TEST low, the dedicated SAR9 waveform, both LEDs off, and no DC code window. |
| ILM-12 | DCS_CAL RED/IR each use the dedicated SAR9 waveform, confirmed AMB code and selected-color DC candidate, with no opposite-color LED window. |
| ILM-13 | Legal STATIC_BIAS establishes every frozen static-vector bit, advances no frame/sample index, and creates no Q1, Q2, Q3, `CLK_DOUT`, ADC owner, AMI completion sideband, ADC transaction, IDAC search/tracking/recheck, FIR transaction, or formal algorithm output. |
| ILM-14 | During legal STATIC_BIAS, all five `S[4:0]` bits update atomically on one 2-MHz edge; other static outputs remain unchanged and other modes drive S low as contracted. |
| ILM-15 | STATIC_BIAS with an invalid input source is rejected without static-vector entry, waveform, owner, result, code update, or counter side effect. |

#### 9.4.6 `ADC-NUMERIC-CODE-SCOREBOARD`: ADCN-01 through ADCN-10

| ID | Acceptance requirement |
| --- | --- |
| ADCN-01 | Representative Stage1 RAW encodings match the frozen per-physical-bit signed-Q16 calibration model and the public signed 12-bit calibrated output. |
| ADCN-02 | Negative results, positive results, and positive/negative half-LSB cases use the frozen symmetric rounding rule without early unsigned conversion. |
| ADCN-03 | Stage1 arithmetic outside the signed 12-bit range saturates to -2048 or +2047 with the matching exclusive saturation diagnostic. |
| ADCN-04 | A valid SAR9 transaction produces the frozen coarse DC-recovered signed value and no valid fine result. |
| ADCN-05 | A valid SAR15 transaction uses the bound Stage1 and Stage2 values in the frozen programmable reconstruction model; a nominal or raw Stage2 substitute is rejected. |
| ADCN-06 | SAR15 coarse and fine DC-recovered results match the frozen DC-recovery model, rounding, saturation, and calibration-valid rules. |
| ADCN-07 | Every numerical comparison binds frame, sample, color, type, precision, AMB/DC code, code epochs, config epoch, Stage1/Stage2 coefficient epochs, and DC-recovery epoch. |
| ADCN-08 | Output backpressure holds every numerical value, qualification, diagnostic, and identity bit stable until the public result transfer. |
| ADCN-09 | The signed 12-bit Stage1 value is never truncated to nine bits; the formal 9-bit-role result is checked at the public coarse DC-recovered interface. |
| ADCN-10 | Stage2, reconstructed, coarse/fine recovered, or formal-output values cannot enter the IDAC tracking comparator; only the same transaction's calibrated Stage1 evidence may do so. |

#### 9.4.7 `IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION`: ISE-01 through ISE-10

| ID | Acceptance requirement |
| --- | --- |
| ISE-01 | AMB/DC code, color, type, precision, and epochs are captured before the first preparation window of each waveform. |
| ISE-02 | Changing any live code after capture cannot change a current IDAC bus bit, enable, LED window, or result snapshot. |
| ISE-03 | The next legal waveform adopts a changed committed code only after its contractual safe-boundary update. |
| ISE-04 | SAR9 NORMAL/DCS drives only SAR9 AMB/DC buses bit by bit in their netlist windows; both SAR15 buses remain zero every tick. |
| ISE-05 | SAR15 NORMAL drives only SAR15 AMB/DC buses bit by bit in their netlist windows; both SAR9 buses remain zero every tick. |
| ISE-06 | AMB_CAL drives only the SAR9 AMB candidate bus; DCS_CAL drives qualified SAR9 AMB and selected DC buses; STATIC_BIAS drives all four buses to zero. |
| ISE-07 | At least two non-symmetric 8-bit patterns prove per-bit code gating rather than an all-high window or bus-level enable shortcut. |
| ISE-08 | RED and IR committed codes, pending values, updates, and epochs remain independent under interleaved transactions. |
| ISE-09 | A safe boundary with no numerical code change emits no update, track-adjust, or epoch increment. |
| ISE-10 | An actual update from epoch 4'hF wraps to zero exactly once and remains correctly bound to all later waveform and result snapshots. |

#### 9.4.8 `OWNER-IDENTITY-BACKPRESSURE`: OIB-01 through OIB-10

| ID | Acceptance requirement |
| --- | --- |
| OIB-01 | Public waveform-context backpressure covers both legal branches. If `ready` recovers by the fixed handover point, the complete stable payload fires exactly once at that point. If `ready` remains low across the point, the opportunity asserts launch timeout and is discarded with no late waveform fire, Q3 transaction, RAW/DONE, owner, result, or `sample_index` side effect; the next legal opportunity contains no stale context. |
| OIB-02 | Public ADC-owner/AMI-start backpressure covers both legal branches. Before the owner deadline, the complete stable transaction may wait and then establish SSW/AMI ownership atomically on one `valid && ready` fire that consumes one `sample_index`. Crossing the deadline asserts owner timeout with no half-commit, late fire, consumed/skipped `sample_index`, or fabricated DONE/result, and a later legal opportunity recovers cleanly. |
| OIB-03 | Public AMI formal-result backpressure holds every result value, qualification, diagnostic, code snapshot, epoch, and identity bit stable until exactly one `valid && ready` transfer. A same-edge normal transfer wins; otherwise accepted STOP, abort, or system fault causes exactly one public lifecycle discard with stable branch ID and never a successful transfer. Reset clears without a discard event. |
| OIB-04 | Legal public lifecycle and downstream conditions induce the waveform pre-handover/recovery and timeout branches, owner pre-deadline/recovery and timeout branches, and held-result branch without direct force, hierarchical write, source-`valid` suppression, or replacement of any internal ready signal. Every expected timeout is explicitly classified and checked; any other protocol, SSW, or AMI fault remains a failure. |
| OIB-05 | Across all induced stalls, each committed owner produces at most one completion and each successful NORMAL completion produces at most one formal result. |
| OIB-06 | Accepted transactions and results preserve order with no loss, duplication, recoloring, retyping, or precision relabeling. |
| OIB-07 | Completion/result identity matches frame, sample, color, type, precision, AMB/DC snapshots, code epochs, and all configuration/coefficient epochs. |
| OIB-08 | A matching `success=0` completion releases only the old physical owner and cannot produce a calibration, tracking, FIR, detector, or formal-output transfer. |
| OIB-09 | A transaction accepted before a legal direct-configuration change retains its old snapshot; only the next accepted transaction may use the new complete snapshot, with no mixed epoch set. |
| OIB-10 | Static ready/valid analysis and dynamic traces show no combinational ready loop; exact independent internal-fork branch stalls remain covered by FFK/AMI unit regression evidence. |

#### 9.4.9 `LIFECYCLE-FAULT-ADC-ANOMALY`: LFA-01 through LFA-12

| ID | Acceptance requirement |
| --- | --- |
| LFA-01 | STOP during startup search prevents new calibration owners, cancels uncommitted pending state, preserves committed codes/epochs, and reaches real idle without a fabricated completion. |
| LFA-02 | STOP during NORMAL or SAR15 prevents new owners. A committed physical owner waits for true completion/idle but is discard-pending from STOP acceptance: its matching real DONE emits exactly one original-identity `success=0` release and no formal data, IDAC, calibration or detector side effect. An untransferred held formal result produces one public `DISCARD_STOP` record within the documented digital lifecycle path; it does not wait indefinitely for ready. The same STOP must emit one generation-scoped detection discard whenever AMI fork or downstream PWI/FIR/detector state for the active generation remains; the test shall cover the case where AMI detection fork is already empty but downstream detection state is not. `identity_valid=0` in that scope-only flush requires every trigger identity field except mandatory target `run_generation`, and sample-valid, to be zero; all current-generation detection state must report empty no earlier than the following 2 MHz cycle. The complementary system-fault case injects the one-cycle supervisor fault-discard event before a retained branch becomes discardable and proves the later exactly-once record is still `DISCARD_SYSTEM_FAULT`, not STOP or abort. |
| LFA-03 | STOP during tracking pending or recheck cancels uncommitted updates/requests without changing committed codes or epochs. |
| LFA-04 | Abort after owner commit retains the minimum old identity; its matching real DONE emits one original-sample-index `success=0` completion and no formal data. |
| LFA-05 | Reset immediately invalidates all model and DUT owner identities; a pre-reset or post-reset old DONE cannot release or complete a new owner. |
| LFA-06 | An early `CLK_DOUT` before the selected Q3 end cannot produce a successful completion or advance formal data state. |
| LFA-07 | A duplicate DONE for an already released owner produces no second completion, result, update, or sample-index change. |
| LFA-08 | With protected test mode enabled, only a wrong completion `sample_index` may be injected at the public verification boundary. It traverses the production identity matcher, cannot release or replace the current owner, produces no formal result or algorithm/control side effect, and asserts the contracted mismatch/protocol diagnostic. The diagnostic propagates through the joint integration fault export and the final top-level fault/abort supervisor. When STOP or the registered system abort is applied after the original real DONE has been buffered, AMI re-presents the buffered original identity and emits exactly one original-`sample_index` `success=0` completion; the two recovery events are idempotent and cannot directly clear or double-release the owner. Reset may instead invalidate the digital owner. After legal diagnostic clear/restart, the next legal START/transaction completes without stale identity. Frame/color/type/precision injection is outside LFA-08. |
| LFA-09 | RED, IR, and calibration owner-deadline failures suppress the affected active sampling windows, do not consume sample index, and expose the correct non-blocking historical timeout diagnostic. They do not create a supervisor blocking record, abort, system STOP request, or first-fault snapshot. |
| LFA-10 | AMI and SSW faults independently block new Scheduler launches without a feedback combinational loop or false local clear. |
| LFA-11 | Diagnostic clear removes only historical sticky state; an active fault cause continues to block until its contractual recovery condition. |
| LFA-12 | A new START after legal recovery begins from sample index/frame start, search, detector, pending, and RAW-model state required by the owner contracts, with no stale event revival. |

#### 9.4.10 `PPG-ROBUSTNESS-CORNER-WAVEFORMS`: PRC-01 through PRC-10

| ID | Acceptance requirement |
| --- | --- |
| PRC-01 | A flat or no-pulse deterministic input produces no false upward cross, peak/valley pair, or precision transition. |
| PRC-02 | A below-threshold low-amplitude pulse remains in SAR9 or follows the contracted no-cross/reacquire policy without a fabricated fine window. |
| PRC-03 | A high-amplitude or clamped input asserts the correct saturation qualification and cannot use a saturated sample as baseline, cross, peak, or valley evidence. |
| PRC-04 | Strong bounded baseline drift follows the dynamic-baseline contract without arithmetic wrap, false direction reversal, or identity loss. |
| PRC-05 | Every deterministic noise schedule remains within its recorded bound and produces bit-identical results on repeat simulation. |
| PRC-06 | Fast and slow legal pulse periods satisfy configured peak/valley interval checks; out-of-range periods follow timeout/reacquire behavior without false acceptance. |
| PRC-07 | Weak or missing dicrotic-notch profiles either produce a fully qualified valley or the contracted timeout/reacquire path, never an unqualified SAR9 return. |
| PRC-08 | With protected test mode enabled, an explicit invalid-sample qualification injected at the public verification boundary remains bound to one real, identity-matched sample and cannot advance FIR history/count/full qualification, dynamic-baseline cycle evidence, peak/valley confirmation, or precision control. It is not represented by a low, zero, high, or saturated RAW code and does not reuse Stage1/Stage2/DC calibration-valid controls. Later legal samples preserve frame/sample/color order and rebuild only the history permitted by the FIR and detector contracts before any new qualified event. |
| PRC-09 | A calibration-qualification-loss sample is consumed according to the FIR/DC contracts but makes every covering detection window unqualified. |
| PRC-10 | After invalid or unqualified samples, later legal results preserve frame/sample/color order and rebuild only the permitted history before any new event. |

The ten added groups therefore contain 107 mandatory stable acceptance IDs:

```text
SID 12 + TRK 10 + RRC 12 + NRE 6 + ILM 15
       + ADCN 10 + ISE 10 + OIB 10 + LFA 12 + PRC 10 = 107
```

### 9.5 Numerical and Identity Evidence Boundary

The joint testbench shall connect and compare every relevant existing AMI public
observation, including calibrated Stage1 value, coarse/fine formal outputs, code and
epoch updates, search state, tracking state, and recheck state. It shall not add a
synthesizable observation/debug port solely to satisfy this testbench contract. The
   only exception is the controlled public fault-injection boundary defined below. Its
   exact ports and qualification propagation are frozen by AMI V1.3.4, FIR V2.1,
   precision-window V1.2, and top V1.3.5; RTL implementation shall not precede those
   owner contracts.

### 9.5.1 Protected Verification-Only Fault-Injection Boundary

The LFA-08 and PRC-08 injections are verification controls, not alternate production
data paths. The exact AMI V1.3.4 public control group is:

```text
parameter C_ENABLE_TEST_INJECTION = 0
i_test_inject_enable
i_test_identity_inject_valid
o_test_identity_inject_ready
i_test_identity_inject_sample_index[C_SAMPLE_INDEX_WIDTH-1:0]
i_test_invalid_sample_valid
o_test_invalid_sample_ready
o_result_sample_valid
```

The first request binds one explicit wrong completion `sample_index` to the current
unique ADC-result owner before the production completion-identity matcher. The second
binds an explicit invalid-sample qualification to the current unique NORMAL owner.
Both are held one-shot valid/ready requests. AMI passes `result_sample_valid` through
precision-window V1.2 to FIR V2.1 `i_sample_valid`; Router-to-overlap remains unchanged
because this qualification boundary is after identity acceptance and DC recovery.
Top V1.3.5 freezes the same public request/ready ports and their direct AMI connection.
Because the current Scheduler+SSW+AMI joint setup has no separate synthesizable joint
wrapper, `ppg_adc_measurement_idac_integration` is the temporary public integration
boundary and the joint TB shall drive only those AMI ports. A TB-only hierarchy or
force path is not an alternate wrapper. The future `ppg_control_top` shall expose and
directly connect the same group as frozen by top V1.3.5.

The boundary shall satisfy all of the following safety rules:

1. Reset disables and clears every latched injection request, payload, owner binding,
   and pending state. The top verification source drives its controls low during reset.
   Production mode keeps `C_ENABLE_TEST_INJECTION=0` and ties or qualifies the boundary
   inactive; an unenabled
   request has no waveform, owner, RAW, result, fault, algorithm, counter, or epoch
   side effect.
2. An injection request is accepted only on its documented public valid/ready fire and
   affects exactly the unique owner present on that fire. It cannot be enabled or
   retargeted halfway through an unrelated accepted transaction. Both injection valids
   asserted together shall produce neither ready nor side effect.
3. The identity injector may corrupt only the completion identity presented to the
   existing production identity comparison. It shall not overwrite the stored owner,
   force a mismatch sticky, release an owner directly, synthesize success/failure
   completion, or bypass the normal fault and recovery paths. The original real DONE,
   RAW, and owner identity remain buffered and unconsumed so that a later STOP or
   controlled abort may re-present that same real context with the original identity and the
   contracted `success=0` qualification; no second physical DONE may be fabricated.
4. A mismatched injected completion cannot release or replace the current owner and
   cannot produce a formal measurement result, IDAC update, FIR input, detector event,
   precision change, or `sample_index` advance. The mismatch/protocol diagnostic must
   reach the joint integration fault export. Final LFA-08 closure additionally
   requires current final-top evidence that the same diagnostic reaches the top-level
   fault/abort supervisor without a combinational feedback loop.
5. Fault clear alone cannot silently discard an unresolved physical owner. After an
   injected mismatch has buffered the real completion, STOP or controlled abort shall
   cause AMI to re-present the retained original identity and produce exactly one
   matching `success=0` completion sideband before Scheduler, SSW, and AMI ownership
   is released. STOP and abort are idempotent for that owner; neither event may clear
   it directly or produce a duplicate completion. Reset may instead invalidate the
   digital owner. After legal clear/restart, the next legal transaction must complete
   with no stale injected identity or fault context.
6. The invalid-sample injector may only clear the sample qualification of one real,
   successfully identity-matched transaction at the documented qualification boundary.
   It shall not modify RAW, calibrated Stage1/Stage2 values, owner identity,
   `sample_index`, code snapshots, epochs, or physical completion.
7. An injected invalid sample retains its transaction identity and ordering but is
   ineligible to advance FIR history count/full state, dynamic-baseline cycle evidence,
   peak/valley confirmation, cross qualification, or precision-control state. Any
   formal observation of that transaction shall explicitly retain invalid/unqualified
   status according to the owner-interface contract.
8. RAW value zero, a low or high RAW value, clamping, and saturation are valid numeric
   conditions unless independently marked invalid. Stage1/Stage2/DC
   calibration-valid inputs describe coefficient/result qualification and shall not
   be repurposed as the invalid-sample injection control.
9. Direct `force`, hierarchical state mutation, replacement of an internal valid or
   ready signal, direct sticky assertion, or unconditional scoreboard PASS cannot
   satisfy LFA-08 or PRC-08.
10. At AMI's DC-result fork, `result_sample_valid` is part of each branch's complete
    transaction payload. The measurement and detection branches shall each hold their
    own qualification snapshot until that branch transfers. A measurement transfer
    cannot clear or change the qualification later observed by a stalled detection
    branch, and a detection transfer cannot change a stalled formal-output branch.
    Current AMI unit evidence shall exercise both asymmetric-ready orders for valid
    and injected-invalid transactions; a shared mutable qualification register is not
    acceptable evidence even when the public formal-result branch alone is stable.

LFA-08 evidence remains `EVIDENCE_PENDING` until one current joint run proves injection through the
public boundary, production identity rejection, no result/owner leak, and clean
STOP/abort idempotent release, and one current final-top run proves registered
fault/abort propagation. PRC-08 remains
`EVIDENCE_PENDING` until one current joint or final-top run proves explicit invalid-sample
injection through the public qualification boundary and compares every prohibited
FIR/detector/precision state advance plus later legal-history recovery. Unit-only
evidence cannot substitute for either end-to-end acceptance ID.

Exact exhaustive arithmetic remains layered evidence:

1. The Stage1 unit scoreboard proves all 1,024 RAW encodings and signed 12-bit
   arithmetic. The joint testbench performs representative end-to-end comparisons.
2. The FIR unit scoreboard proves impulse, frequency, rounding, saturation, and
   exact filtered values. The joint testbench proves real-input history qualification,
   identity continuity, tail isolation, and downstream event causality.
3. The dynamic-baseline unit scoreboard proves exact per-cycle fixed-point baseline
   mathematics. The joint testbench proves eligible-sample counting, baseline-valid
   state, slope/event sequence, cross identity, and precision-control causality.
4. The peak/valley unit scoreboard proves exact extrema identities and boundary
   mathematics. The joint testbench proves event order, precision-window ownership,
   and the real return-to-SAR9 path.

`o_calibrated_s1_value` is a signed 12-bit calibrated Stage1 value, not an unsigned
9-bit bus. The nominal calibrated range may be -4 through 515. The scoreboard shall
not truncate it to nine bits before comparison. The 9-bit term identifies the Stage1
conversion role and nominal resolution; the formal post-recovery value is checked at
the existing AMI coarse-result interface.

### 9.6 Common Result Continuity and Summary

For every applicable group, result continuity means all of the following:

1. Each accepted AMI completion is bound to exactly one previously committed owner.
2. Within each color's accepted NORMAL result stream, `frame_id` ordering is
   monotonic and no identity is duplicated or relabeled across a precision transition.
3. A precision transition does not introduce a result from an old FIR tail, a stale
   RAW transfer, or an uncommitted waveform context.
4. RED and IR retain their own physical sample identities even while permitted analog
   pre-establishment overlaps are present.
5. A matching completion with `success=0` may release the old physical owner but may
   not enter calibration, tracking, FIR, baseline, peak/valley, or formal output paths.

Each group summary shall separately record:

```text
JNT baseline: 52 / 52 PASS
RAW acceptance: RAW-01 through RAW-13, applicable subset and result
functional group: group name and PASS or first failing bound identity
stable acceptance IDs: applicable SID/TRK/RRC/NRE/ILM/ADCN/ISE/OIB/LFA/PRC IDs,
                       passed count, required count, and first failing ID
numerical scoreboard: comparison count and first mismatch
protocol scoreboard: owner/result/update counts and first mismatch
```

Each added group may be reported as PASS only when every stable acceptance ID assigned
to that group is present in that group's independent-run log and has a real comparison
result. An ID belonging to another independently reset group is not a prerequisite for
the current group-level PASS. A missing, skipped, or unobservable assigned ID makes the
affected group `NOT_CLOSED`, not PASS.

The final V1.3 aggregate may be reported as PASS only when the ten independent group
logs collectively cover all 107 stable acceptance IDs with no failed or `NOT_CLOSED`
group. The aggregate report shall associate every group name and stable-ID range with
its independent reset/run identity, current-source log path, log timestamp, comparison
counts, and result; it shall not merge state or comparisons across runs. Internal fork
branch IDs supplied by FFK/AMI unit evidence shall be linked by log name and contract
version; they may not be replaced by an unconditional joint-TB message.

LFA-08 is a deliberate cross-layer exception to the single-log rule: its owning joint
run shall prove public injection, production identity rejection, retained owner, no
formal/algorithm side effect, and clean recovery, while a linked current final-top run
shall prove propagation through the system fault/abort supervisor. Both logs and their
contract versions are required for the one LFA-08 PASS result. PRC-08 shall be closed
by a current joint or final-top public-injection run; a FIR or AMI unit log may support
diagnosis but cannot replace that end-to-end comparison. These evidence links do not
add stable IDs or permit state to be borrowed across independently reset runs.

## 10. Two Global Verification Layers

### 10.1 Independent-Run Layer

The five core PPG groups and every added stateful group shall execute after an
independent reset and a complete 52-check JNT baseline. Mode-matrix subcases that
cannot legally share one RUN shall use separate reset/START phases. No result may be
carried from one phase to satisfy another phase's end condition.

### 10.2 RAW Physical-Timing Layer

RAW-01 through RAW-13 remain mandatory for every applicable physiological run. In
particular, each transfer shall preserve waveform context -> preparation -> Q1/Q2/Q3
-> Q3 end -> asynchronous `CLK_DOUT`/RAW -> AMI capture -> identity match -> completion
sideband causality. A fixed fire-relative DONE model is prohibited. The long-run group
shall prove at least 10 seconds, 4,000 macro frames, and 20,000,000 cycles at 2 MHz
without timeout-width overflow.

## 11. Delivery Gate, Non-Changes, and Evidence Status

This V1.3 revision is contract-only. It changes no RTL, testbench, port, timing,
algorithm, or prior simulation log. The subsequent implementation may modify the
joint testbench and explicitly associated test-only documentation. Any required
synthesizable port or behavior change requires a separately approved owner-contract
revision before RTL is edited. AMI V1.3.4, FIR V2.1, precision-window V1.2, and top
V1.3.5 now provide that interface-shape approval; this testbench contract alone still
does not authorize a differently named port or any behavior outside those owner
contracts.

Before V1.3 implementation is claimed complete, it must demonstrate that it preserves:

1. Scheduler fixed waveform handover, Q3 locations, owner deadlines, and sample-index
   consumption only on real owner fire.
2. SSW overlap whitelist, netlist-derived analog waveform behavior, code-window
   snapshot semantics, and unselected-precision bus isolation.
3. AMI asynchronous capture, RAW latch, complete identity match, matching
   `success=0` release, reset invalidation, and previously verified algorithms.
4. Existing production-mode synthesizable behavior and every RTL port except a
   separately approved, protected, default-disabled verification injection boundary.

The final evidence sequence is mandatory:

```text
strict formatter-AST deliverable gate, including the testbench
    -> independent static lint
    -> Vivado xvlog
    -> Vivado xelab
    -> all fifteen grouped xsim regressions
    -> all applicable RAW-01 through RAW-13 comparisons
    -> each added group's complete assigned stable-ID range in its independent log
    -> linked joint/final-top LFA-08 evidence and joint-or-top PRC-08 evidence
    -> aggregate manifest covering all 107 stable IDs for groups 6 through 15
    -> final aggregate PASS with current-source log timestamps
```

Strict delivery requires zero errors and zero strict warnings. A previous log, a
partial group PASS, a watchdog expiry, or an unconditional PASS print is not closure
evidence. Synthesis is not required for a testbench-only revision when synthesizable
RTL is unchanged; if implementation discovers an RTL change, all affected unit and
joint regressions plus OOC synthesis shall be rerun.

SPI shadow/COMMIT/1024-bit joint ACTIVE V4/V5 integration, the final `ppg_control_top`, and the
system fault/abort supervisor are implementation scopes owned by their respective
contracts, not exclusions from this verification contract. This contract requires the
public final-Top scenarios and linked evidence for every acceptance ID that names them,
especially LFA-08 and TOP-21 through TOP-24. The joint run and final-Top run have
complementary obligations; neither may declare the other out of scope or substitute a
historical log for current evidence.

No formatter, lint, compilation, simulation, or synthesis result is claimed by this
contract-only revision.
