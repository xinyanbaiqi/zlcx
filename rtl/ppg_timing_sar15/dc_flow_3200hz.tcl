# =============================================================================
# Design:      ppg_timing_sar15_3200hz
# File:        dc_flow.tcl
# Purpose:     Strict first-pass Design Compiler synthesis flow
# Location:    <synthesis>/scripts/dc_flow.tcl
# Invocation:
#   dc_shell -64bit -f scripts/dc_flow.tcl
# =============================================================================

set FLOW_FILE [file normalize [info script]]
set FLOW_DIR  [file dirname $FLOW_FILE]

if {![info exists DC_SETUP_FILE]} {
	set DC_SETUP_FILE [file join $FLOW_DIR dc_setup.tcl]
}

if {![file exists $DC_SETUP_FILE]} {
	error "Required setup file not found: $DC_SETUP_FILE"
}

source -echo -verbose $DC_SETUP_FILE

foreach required_var {
	DESIGN_NAME
	vlgfiles
	target_library
	link_library
	SYN_PATH
	CONSTRAINT_FILE
	RESULTS_DIR
	REPORTS_DIR
} {
	if {![info exists $required_var]} {
		error "dc_setup.tcl did not define required variable: $required_var"
	}
}

if {$DESIGN_NAME ne "ppg_timing_sar15_3200hz"} {
	error "This flow requires ppg_timing_sar15_3200hz, but DESIGN_NAME is $DESIGN_NAME"
}

if {[llength $vlgfiles] != 2} {
	error "Expected exactly two RTL sources: SAR15 core and 3200 Hz wrapper"
}

if {[llength $target_library] == 0} {
	error "The target_library list is empty"
}

if {[llength $link_library] == 0} {
	error "The link_library list is empty"
}

file mkdir $RESULTS_DIR
file mkdir $REPORTS_DIR

# Resolve and validate the ordered core-plus-wrapper RTL source list.
set RTL_FILES {}
foreach rtl_file $vlgfiles {
	set resolved_rtl $rtl_file
	if {![file exists $resolved_rtl]} {
		set resolved_rtl [file join $SYN_PATH $rtl_file]
	}
	if {![file exists $resolved_rtl]} {
		error "RTL source file not found: $rtl_file"
	}
	lappend RTL_FILES [file normalize $resolved_rtl]
}

if {![file exists $CONSTRAINT_FILE]} {
	error "Constraint file not found: $CONSTRAINT_FILE"
}
set CONSTRAINT_FILE [file normalize $CONSTRAINT_FILE]

set_app_var sh_enable_page_mode false
set_app_var sh_continue_on_error false

if {![info exists DC_MAX_CORES]} {
	set DC_MAX_CORES 4
}
set_host_options -max_cores $DC_MAX_CORES

set_svf [file join $RESULTS_DIR ${DESIGN_NAME}.svf]

# -----------------------------------------------------------------------------
# Read, elaborate, link, and validate the RTL hierarchy
# -----------------------------------------------------------------------------

analyze -format verilog $RTL_FILES
elaborate $DESIGN_NAME
current_design $DESIGN_NAME
link
uniquify

check_design > [file join $REPORTS_DIR check_design_elaborated.rpt]

write -format ddc -hierarchy \
	-output [file join $RESULTS_DIR ${DESIGN_NAME}_elaborated.ddc]

# -----------------------------------------------------------------------------
# Read timing and electrical constraints
# -----------------------------------------------------------------------------

source -echo -verbose $CONSTRAINT_FILE

if {[sizeof_collection [get_ports -quiet i_clk]] != 1} {
	error "Expected primary clock port i_clk was not found"
}

if {[sizeof_collection [get_ports -quiet i_rstn]] != 1} {
	error "Expected reset port i_rstn was not found"
}

if {[sizeof_collection [get_ports -quiet o_clk_2m]] != 1} {
	error "Expected forwarded-clock port o_clk_2m was not found"
}

if {[sizeof_collection [get_ports -quiet o_frame_start_3200hz]] != 1} {
	error "Expected 3200 Hz frame-start port was not found"
}

if {[sizeof_collection [get_clocks -quiet CLK_2M]] != 1} {
	error "Constraint file did not create exactly one CLK_2M clock"
}

if {![info exists CRITICAL_RANGE]} {
	set CRITICAL_RANGE 3.0
}
set_critical_range $CRITICAL_RANGE [current_design]

# Keep functional high-fanout controls visible to optimization and reporting.
set_fix_multiple_port_nets -all -buffer_constants

# -----------------------------------------------------------------------------
# Synthesis
# -----------------------------------------------------------------------------

set_app_var compile_seqmap_identify_shift_registers false
set_app_var timing_enable_multiple_clocks_per_reg true
set_app_var compile_seqmap_propagate_high_effort false
set_app_var compile_seqmap_propagate_constants true
set_app_var compile_auto_ungroup_count_leaf_cells true
set_app_var compile_auto_ungroup_area_num_cells 10

set_structure -boolean true -boolean_effort high
set_max_area 0

compile_ultra \
	-no_seq_output_inversion \
	-no_autoungroup \
	-no_boundary_optimization

# -----------------------------------------------------------------------------
# Reports
# -----------------------------------------------------------------------------

check_design > [file join $REPORTS_DIR check_design_postcompile.rpt]
check_timing > [file join $REPORTS_DIR check_timing_postcompile.rpt]
report_units > [file join $REPORTS_DIR report_units.rpt]
report_clock > [file join $REPORTS_DIR report_clock.rpt]
report_design > [file join $REPORTS_DIR report_design.rpt]
report_qor > [file join $REPORTS_DIR report_qor.rpt]
report_area > [file join $REPORTS_DIR report_area.rpt]
report_area -hierarchy > [file join $REPORTS_DIR report_area_hierarchy.rpt]
report_power > [file join $REPORTS_DIR report_power.rpt]
report_reference > [file join $REPORTS_DIR report_reference.rpt]
report_port -verbose > [file join $REPORTS_DIR report_port.rpt]
report_cell > [file join $REPORTS_DIR report_cell.rpt]
report_net > [file join $REPORTS_DIR report_net.rpt]
report_constraint -all_violators -verbose > \
	[file join $REPORTS_DIR report_violators.rpt]

report_timing \
	-delay_type max \
	-max_paths 10 \
	-nworst 10 \
	-input_pins \
	-nets \
	-capacitance \
	-transition_time \
	> [file join $REPORTS_DIR timing_setup.rpt]

report_timing \
	-delay_type min \
	-max_paths 10 \
	-nworst 10 \
	-input_pins \
	-nets \
	-capacitance \
	-transition_time \
	> [file join $REPORTS_DIR timing_hold.rpt]

# -----------------------------------------------------------------------------
# Output netlist, pre-layout SDF, and resolved SDC
# -----------------------------------------------------------------------------

change_names -rules verilog -hierarchy

write -format verilog -hierarchy \
	-output [file join $RESULTS_DIR ${DESIGN_NAME}_syn.v]

write -format ddc -hierarchy \
	-output [file join $RESULTS_DIR ${DESIGN_NAME}_syn.ddc]

# This SDF is a synthesis estimate. Innovus must generate the post-route SDF
# after clock-tree synthesis, routing, and parasitic extraction.
write_sdf [file join $RESULTS_DIR ${DESIGN_NAME}_presynth.sdf]

write_sdc -version 1.4 \
	[file join $RESULTS_DIR ${DESIGN_NAME}_syn.sdc]

set_svf -off
exit
