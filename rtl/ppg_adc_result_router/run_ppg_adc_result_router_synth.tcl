set script_dir [file dirname [file normalize [info script]]]
set module_dir $script_dir
set report_dir $script_dir
read_verilog [file join $module_dir ppg_adc_result_router.v]
synth_design -top ppg_adc_result_router -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none
create_clock -name virtual_clk_2m -period 500.000
set_input_delay -clock virtual_clk_2m 1.000 [all_inputs]
set_output_delay -clock virtual_clk_2m 1.000 [all_outputs]
report_utilization -file [file join $report_dir ppg_adc_result_router_synth_utilization.rpt]
report_drc -file [file join $report_dir ppg_adc_result_router_synth_drc.rpt]
check_timing -verbose -file [file join $report_dir ppg_adc_result_router_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $report_dir ppg_adc_result_router_synth_timing_summary.rpt]
exit
