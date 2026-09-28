# Resolve all sources and reports relative to the integration feature directory.
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

# Read the integration wrapper and every synthesizable implementation dependency.
read_verilog [file join $root_dir ppg_adc_async_stage_capture ppg_adc_async_stage_capture.v]
read_verilog [file join $root_dir ppg_adc_s1_redundancy_corrector ppg_adc_s1_redundancy_corrector.v]
read_verilog [file join $root_dir ppg_adc_s1_programmable_calibrator ppg_adc_s1_programmable_calibrator.v]
read_verilog [file join $root_dir ppg_adc_result_router ppg_adc_result_router.v]
read_verilog [file join $root_dir ppg_normal_transaction_fork ppg_normal_transaction_fork.v]
read_verilog [file join $root_dir ppg_adc_pipeline_overlap_corrector ppg_adc_pipeline_overlap_corrector.v]
read_verilog [file join $root_dir ppg_adc_programmable_reconstructor ppg_adc_programmable_reconstructor.v]
read_verilog [file join $root_dir ppg_adc_dc_recovery ppg_adc_dc_recovery.v]
read_verilog [file join $root_dir ppg_idac_code_controller ppg_idac_code_controller.v]
read_verilog [file join $root_dir ppg_coarse_detection_fir ppg_coarse_detection_fir.v]
read_verilog [file join $root_dir ppg_dynamic_baseline_cross_detector ppg_dynamic_baseline_cross_detector.v]
read_verilog [file join $root_dir ppg_peak_valley_window_detector ppg_peak_valley_window_detector.v]
read_verilog [file join $root_dir ppg_precision_window_controller ppg_precision_window_controller.v]
read_verilog [file join $root_dir ppg_amb_recheck_scheduler ppg_amb_recheck_scheduler.v]
read_verilog [file join $root_dir ppg_precision_window_integration ppg_precision_window_integration.v]
read_verilog [file join $script_dir ppg_adc_measurement_idac_integration.v]

# Use the established Artix-7 OOC target and preserve hierarchy for review.
synth_design -top ppg_adc_measurement_idac_integration -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Apply the real 2 MHz processing-domain timing assumptions.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
set_false_path -from [get_ports i_rstn]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != i_clk && NAME != i_rstn}]
set_input_delay -clock i_clk_2m -max 1.000 $data_inputs
set_input_delay -clock i_clk_2m -min 0.000 $data_inputs
set_output_delay -clock i_clk_2m -max 1.000 [all_outputs]
set_output_delay -clock i_clk_2m -min 0.000 [all_outputs]

# Emit structural and timing evidence for integration review.
report_utilization -file [file join $script_dir ppg_adc_measurement_idac_integration_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_adc_measurement_idac_integration_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_adc_measurement_idac_integration_synth_check_timing.rpt]
report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose -max_paths 10 -file [file join $script_dir ppg_adc_measurement_idac_integration_synth_timing_summary.rpt]
report_methodology -file [file join $script_dir ppg_adc_measurement_idac_integration_synth_methodology.rpt]
write_checkpoint -force [file join $script_dir ppg_adc_measurement_idac_integration_post_synth.dcp]

# Record latch and black-box counts explicitly in the batch log.
puts "AMI_SYNTH_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "AMI_SYNTH_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
puts "AMI_SYNTH_CELL_COUNT=[llength [get_cells -hier]]"
puts "AMI_SYNTH_COMPLETE=1"
exit
