# Resolve wrapper sources and reports relative to this script.
set script_dir [file dirname [file normalize [info script]]]

# Read only the synthesizable safe-selection wrapper.
read_verilog [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper.v]

# Run out-of-context synthesis using the established Artix-7 review target.
synth_design -top ppg_sar9_sar15_safe_selection_wrapper -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Apply the 2 MHz processing-clock timing assumption.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
set_false_path -from [get_ports i_rstn]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != i_clk && NAME != i_rstn}]
set_input_delay -clock i_clk_2m -max 1.000 $data_inputs
set_input_delay -clock i_clk_2m -min 0.000 $data_inputs
set_output_delay -clock i_clk_2m -max 1.000 [all_outputs]
set_output_delay -clock i_clk_2m -min 0.000 [all_outputs]

# Emit structural and timing evidence for review.
report_utilization -file [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper_synth_timing_summary.rpt]
report_methodology -file [file join $script_dir ppg_sar9_sar15_safe_selection_wrapper_synth_methodology.rpt]

# Record latch and Blackbox counts directly in the batch log.
puts "SSW_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "SSW_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
exit
