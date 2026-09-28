# Resolve sources and reports relative to the coarse detection FIR directory.
set script_dir [file dirname [file normalize [info script]]]

# Read only the synthesizable FIR RTL.
read_verilog [file join $script_dir ppg_coarse_detection_fir.v]

# Run out-of-context synthesis using the established Artix-7 review target.
synth_design -top ppg_coarse_detection_fir -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Apply the real 2 MHz processing-domain timing assumptions.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
set_false_path -from [get_ports i_rstn]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != i_clk && NAME != i_rstn}]
set_input_delay -clock i_clk_2m -max 1.000 $data_inputs
set_input_delay -clock i_clk_2m -min 0.000 $data_inputs
set_output_delay -clock i_clk_2m -max 1.000 [all_outputs]
set_output_delay -clock i_clk_2m -min 0.000 [all_outputs]

# Emit structural and timing evidence for synthesis review.
report_utilization -file [file join $script_dir ppg_coarse_detection_fir_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_coarse_detection_fir_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_coarse_detection_fir_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $script_dir ppg_coarse_detection_fir_synth_timing_summary.rpt]
report_methodology -file [file join $script_dir ppg_coarse_detection_fir_synth_methodology.rpt]

# Record critical structural counts explicitly in the batch log.
puts "COARSE_FIR_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "COARSE_FIR_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
exit
