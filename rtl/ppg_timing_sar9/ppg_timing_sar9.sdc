# =============================================================================
# Design:      ppg_timing_sar9
# File:        ppg_timing_sar9.sdc
# Purpose:     First-pass block-level synthesis and place-and-route constraints
# Clock:       2 MHz digital master clock, 500 ns period
# Notes:
#   1. Time and capacitance units are inherited from the loaded timing library.
#      Run report_units after loading the libraries to confirm them.
#   2. The interface delays and output loads below are first-pass assumptions
#      for DC and initial P&R. Replace them with values derived from the final
#      upstream registers, level shifters, analog input capacitances, and route.
#   3. Only i_clk is a digital CTS clock. The Q1/Q2/Q3 and other CLK-named
#      outputs are synchronous analog-control data outputs.
# =============================================================================

# -----------------------------------------------------------------------------
# Centralized block-level assumptions
# -----------------------------------------------------------------------------

# Primary 2 MHz clock period in the library time unit, normally ns.
set C_CLK_PERIOD                 500.0

# Pre-CTS ideal-clock assumptions.
set C_CLK_JITTER                  0.2
set C_SETUP_MARGIN                0.3
set C_HOLD_MARGIN                 0.3
set C_CLK_TRANSITION              0.2
set C_CLK_LATENCY                 0.0

# Interface timing budgets for configuration inputs and analog-control outputs.
set C_INPUT_DELAY_MAX            20.0
set C_INPUT_DELAY_MIN             0.0

# Critical timing outputs include Q1/Q2/Q3, LED enables, TIA/AFE controls,
# IREF controls, and SAR enables. The 5 ns value is an initial implementation
# budget for the short analog-control edge paths, not a final signoff number.
set C_CRITICAL_CONTROL_PATH_MAX   5.0

# LEDDAC/IDAC buses and test-MUX outputs settle before the sampling windows, so
# they use a looser first-pass path budget.
set C_CODE_PATH_MAX              20.0
set C_TEST_PATH_MAX              20.0

# Maximum permitted input-clock to forwarded-clock output delay.
# Replace this value with the analog clock-alignment requirement.
set C_FORWARD_CLK_MAX_DELAY       2.0

# Initial capacitive load assumptions in the timing-library capacitance unit.
# Use separate values because the forwarded clock, control edges, code buses,
# and test outputs drive different analog receivers.
set C_CRITICAL_CONTROL_LOAD       0.05
set C_CODE_OUTPUT_LOAD            0.10
set C_TEST_OUTPUT_LOAD            0.05
set C_FIXED_OUTPUT_LOAD           0.05
set C_FORWARD_CLK_OUTPUT_LOAD     0.05
set C_CONFIG_INPUT_TRANSITION     1.0

# Initial electrical design-rule limits. Confirm against the selected PDK.
set C_MAX_FANOUT                 16
set C_DATA_MAX_TRANSITION         2.0

# -----------------------------------------------------------------------------
# Primary clock
# -----------------------------------------------------------------------------

create_clock \
	-name CLK_2M \
	-period $C_CLK_PERIOD \
	-waveform {0.0 250.0} \
	[get_ports i_clk]

set_clock_uncertainty \
	-setup [expr {$C_CLK_JITTER + $C_SETUP_MARGIN}] \
	[get_clocks CLK_2M]

set_clock_uncertainty \
	-hold [expr {$C_CLK_JITTER + $C_HOLD_MARGIN}] \
	[get_clocks CLK_2M]

set_clock_transition \
	-max $C_CLK_TRANSITION \
	[get_clocks CLK_2M]

set_clock_latency \
	$C_CLK_LATENCY \
	[get_clocks CLK_2M]

# The clock is ideal during synthesis and pre-CTS optimization. Innovus should
# switch to a propagated clock after CTS instead of retaining this ideal model.

# -----------------------------------------------------------------------------
# Configuration and mode-control inputs
# -----------------------------------------------------------------------------

# Every input except the primary clock and asynchronous reset is treated as a
# synchronous configuration input driven by an upstream CLK_2M-domain register.
set C_CONFIG_INPUTS [remove_from_collection \
	[all_inputs] \
	[get_ports {i_clk i_rstn}]]

set_input_transition \
	$C_CONFIG_INPUT_TRANSITION \
	$C_CONFIG_INPUTS

set_input_delay \
	-max $C_INPUT_DELAY_MAX \
	-clock CLK_2M \
	$C_CONFIG_INPUTS

set_input_delay \
	-min $C_INPUT_DELAY_MIN \
	-clock CLK_2M \
	$C_CONFIG_INPUTS

# -----------------------------------------------------------------------------
# Asynchronous reset
# -----------------------------------------------------------------------------

# This exception is suitable for the initial standalone block flow. The final
# chip-level flow must either synchronize reset deassertion or explicitly check
# recovery and removal at every receiving register.
set_false_path -from [get_ports i_rstn]

# -----------------------------------------------------------------------------
# Forwarded 2 MHz analog clock
# -----------------------------------------------------------------------------

# o_clk_2m is logically assigned from i_clk. Defining it as a divide-by-one
# generated clock preserves its clock identity for downstream integration.
create_generated_clock \
	-name ANA_CLK_2M \
	-source [get_ports i_clk] \
	-divide_by 1 \
	[get_ports o_clk_2m]

set_load \
	$C_FORWARD_CLK_OUTPUT_LOAD \
	[get_ports o_clk_2m]

# Constrain the physical clock-forwarding path separately from ordinary data
# outputs. This budget must eventually include the selected clock buffer and
# any required voltage-domain level shifter.
set_max_delay \
	$C_FORWARD_CLK_MAX_DELAY \
	-from [get_ports i_clk] \
	-to [get_ports o_clk_2m]

# -----------------------------------------------------------------------------
# Synchronous analog-control outputs
# -----------------------------------------------------------------------------

# Critical control edges used by the analog sampling sequence.
set C_CRITICAL_CONTROL_OUTPUTS [get_ports {
	o_frame_start_400hz
	o_en_tia_low
	o_leden1_low
	o_leden2_low
	o_clk_buf_low
	o_clk_iref_idac_low
	o_clk_9q1_low
	o_clk_aferst_low
	o_clk_iref_idac_sar9_low
	o_clk_iref_idac_sar15_low
	o_clk_q2_low
	o_clk_q3_low
	o_clk_tiaen_low
	o_en_sar9_amb_low
	o_en_sar9_dc_low
	o_en_sar9_iref
	o_en_sar15_amb_low
	o_en_sar15_dc_low
}]

# LEDDAC and IDAC buses are allowed a longer output path because their codes
# are established before the Q2/Q3 sampling windows.
set C_CODE_OUTPUTS [get_ports {o_leddac* o_idac_*}]

# Test-MUX and frontend-test outputs are frame-latched but are not part of the
# shortest Q2/Q3 analog edge relationship.
set C_TEST_OUTPUTS [get_ports {o_en_test o_s_in*}]

# These outputs are constants in normal SAR9 operation. They still receive a
# load model, but do not need a dynamic register-to-output timing budget.
set C_FIXED_OUTPUTS [get_ports {
	o_clk_15q1_low
	o_en_15sar_low
	o_en_sar15_iref
}]

set_load $C_CRITICAL_CONTROL_LOAD $C_CRITICAL_CONTROL_OUTPUTS
set_load $C_CODE_OUTPUT_LOAD      $C_CODE_OUTPUTS
set_load $C_TEST_OUTPUT_LOAD      $C_TEST_OUTPUTS
set_load $C_FIXED_OUTPUT_LOAD     $C_FIXED_OUTPUTS

# Bound the paths separately so the critical sampling controls are not hidden
# by a single loose all-output constraint.
set_max_delay \
	$C_CRITICAL_CONTROL_PATH_MAX \
	-from [all_registers] \
	-to $C_CRITICAL_CONTROL_OUTPUTS

set_max_delay \
	$C_CODE_PATH_MAX \
	-from [all_registers] \
	-to $C_CODE_OUTPUTS

set_max_delay \
	$C_TEST_PATH_MAX \
	-from [all_registers] \
	-to $C_TEST_OUTPUTS

# -----------------------------------------------------------------------------
# Electrical design rules
# -----------------------------------------------------------------------------

set_max_fanout \
	$C_MAX_FANOUT \
	[current_design]

set_max_transition \
	$C_DATA_MAX_TRANSITION \
	[current_design]

# =============================================================================
# End of ppg_timing_sar9.sdc
# =============================================================================
