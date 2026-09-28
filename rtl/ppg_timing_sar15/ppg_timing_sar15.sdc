# =============================================================================
# Design:      ppg_timing_sar15
# File:        ppg_timing_sar15.sdc
# Purpose:     First-pass block-level synthesis and place-and-route constraints
# Clock:       2 MHz digital master clock, 500 ns period
# Notes:
#   1. Time and capacitance units are inherited from the loaded timing library.
#      Run report_units after loading the libraries to confirm them.
#   2. Interface budgets and loads are first-pass assumptions for standalone
#      SAR15 synthesis and initial P&R. Replace them with extracted values.
#   3. Only i_clk is a digital CTS clock. Q1/Q2/Q3 and other CLK-named outputs
#      are synchronous analog-control data outputs.
# =============================================================================

# -----------------------------------------------------------------------------
# Centralized block-level assumptions
# -----------------------------------------------------------------------------

set C_CLK_PERIOD                 500.0

set C_CLK_JITTER                  0.2
set C_SETUP_MARGIN                0.3
set C_HOLD_MARGIN                 0.3
set C_CLK_TRANSITION              0.2
set C_CLK_LATENCY                 0.0

set C_INPUT_DELAY_MAX            20.0
set C_INPUT_DELAY_MIN             0.0

# Q2/Q3, LED, TIA, IREF, SAR15 Q1, and precision-select edges use the
# short initial register-to-output implementation budget.
set C_CRITICAL_CONTROL_PATH_MAX   5.0

# LEDDAC/IDAC code buses and test-MUX controls settle before sampling windows.
set C_CODE_PATH_MAX              20.0
set C_TEST_PATH_MAX              20.0

# Maximum permitted input-clock to forwarded analog-clock output delay.
set C_FORWARD_CLK_MAX_DELAY       2.0

# Initial capacitive loads in the timing-library capacitance unit.
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

# -----------------------------------------------------------------------------
# Configuration and mode-control inputs
# -----------------------------------------------------------------------------

# All inputs except the primary clock and asynchronous reset are modeled as
# CLK_2M-domain configuration signals driven by upstream registers.
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

# This exception is limited to initial standalone synthesis. Final chip-level
# signoff must synchronize reset deassertion or check recovery/removal.
set_false_path -from [get_ports i_rstn]

# -----------------------------------------------------------------------------
# Forwarded 2 MHz analog clock
# -----------------------------------------------------------------------------

create_generated_clock \
	-name ANA_CLK_2M \
	-source [get_ports i_clk] \
	-divide_by 1 \
	[get_ports o_clk_2m]

set_load \
	$C_FORWARD_CLK_OUTPUT_LOAD \
	[get_ports o_clk_2m]

set_max_delay \
	$C_FORWARD_CLK_MAX_DELAY \
	-from [get_ports i_clk] \
	-to [get_ports o_clk_2m]

# -----------------------------------------------------------------------------
# Synchronous analog-control outputs
# -----------------------------------------------------------------------------

# Critical SAR15 sampling and analog-control edges. Static-characterization
# overrides remain included because they also drive analog receiver inputs.
set C_CRITICAL_CONTROL_OUTPUTS [get_ports {
	o_frame_start_400hz
	o_en_tia_low
	o_leden1_low
	o_leden2_low
	o_clk_buf_low
	o_clk_iref_idac_low
	o_clk_15q1_low
	o_clk_aferst_low
	o_clk_iref_idac_sar9_low
	o_clk_iref_idac_sar15_low
	o_clk_q2_low
	o_clk_q3_low
	o_clk_tiaen_low
	o_en_15sar_low
	o_en_sar9_amb_low
	o_en_sar9_dc_low
	o_en_sar15_amb_low
	o_en_sar15_dc_low
	o_en_sar15_iref
}]

set C_CODE_OUTPUTS [get_ports {o_leddac* o_idac_*}]
set C_TEST_OUTPUTS [get_ports {o_en_test o_s_in*}]

# These outputs are constants in normal SAR15 operation.
set C_FIXED_OUTPUTS [get_ports {
	o_clk_9q1_low
	o_en_sar9_iref
}]

set_load $C_CRITICAL_CONTROL_LOAD $C_CRITICAL_CONTROL_OUTPUTS
set_load $C_CODE_OUTPUT_LOAD      $C_CODE_OUTPUTS
set_load $C_TEST_OUTPUT_LOAD      $C_TEST_OUTPUTS
set_load $C_FIXED_OUTPUT_LOAD     $C_FIXED_OUTPUTS

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
# End of ppg_timing_sar15.sdc
# =============================================================================
