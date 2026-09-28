# Resolve source and report paths from the precision controller directory.
set script_dir [file dirname [file normalize [info script]]]

# Read only the synthesizable precision window controller RTL.
read_verilog [file join $script_dir ppg_precision_window_controller.v]

# Run out-of-context synthesis on the established Artix-7 review target.
synth_design -top ppg_precision_window_controller -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Constrain the real 2 MHz control clock and synchronous interface timing.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
set_false_path -from [get_ports i_rstn]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != i_clk && NAME != i_rstn}]
set_input_delay -clock i_clk_2m -max 1.000 $data_inputs
set_input_delay -clock i_clk_2m -min 0.000 $data_inputs
set_output_delay -clock i_clk_2m -max 1.000 [all_outputs]
set_output_delay -clock i_clk_2m -min 0.000 [all_outputs]

# Emit utilization, DRC, timing and methodology evidence for review.
report_utilization -file [file join $script_dir ppg_precision_window_controller_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_precision_window_controller_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_precision_window_controller_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $script_dir ppg_precision_window_controller_synth_timing_summary.rpt]
report_methodology -file [file join $script_dir ppg_precision_window_controller_synth_methodology.rpt]

# Record structural closure counts directly in the batch log.
puts "PRECISION_WINDOW_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "PRECISION_WINDOW_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
exit
