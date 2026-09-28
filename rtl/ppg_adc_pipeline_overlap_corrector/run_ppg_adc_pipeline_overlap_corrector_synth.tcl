# Resolve every source and report path relative to this feature directory.
set script_dir [file dirname [file normalize [info script]]]
set module_dir $script_dir
set report_dir $script_dir

# Read only the active synthesizable RTL for the overlap-corrector function.
read_verilog [file join $module_dir ppg_adc_pipeline_overlap_corrector.v]

# Run out-of-context synthesis with the same Artix-7 review target used by adjacent modules.
synth_design -top ppg_adc_pipeline_overlap_corrector -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Constrain the real 2 MHz input clock and keep asynchronous reset outside data timing.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
set_false_path -from [get_ports i_rstn]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != i_clk && NAME != i_rstn}]
set_input_delay -clock i_clk_2m 1.000 $data_inputs
set_output_delay -clock i_clk_2m 1.000 [all_outputs]

# Preserve utilization, DRC, timing completeness and maximum-delay evidence beside the RTL.
report_utilization -file [file join $report_dir ppg_adc_pipeline_overlap_corrector_synth_utilization.rpt]
report_drc -file [file join $report_dir ppg_adc_pipeline_overlap_corrector_synth_drc.rpt]
check_timing -verbose -file [file join $report_dir ppg_adc_pipeline_overlap_corrector_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $report_dir ppg_adc_pipeline_overlap_corrector_synth_timing_summary.rpt]
report_methodology -file [file join $report_dir ppg_adc_pipeline_overlap_corrector_synth_methodology.rpt]
exit
