# Resolve dependency and report paths from the characterization CDC directory.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

# Read the contract-mandated reusable request/acknowledge bridge and its wrapper.
read_verilog [file join $repo_dir ppg_config_cdc_bridge ppg_config_cdc_bridge.v]
read_verilog [file join $script_dir ppg_characterization_control_cdc.v]

# Run out-of-context synthesis using the repository's established Artix-7 target.
synth_design -top ppg_characterization_control_cdc -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Constrain the two independent CDC domains at the 2 MHz review rate.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
create_clock -name i_source_clk_review -period 500.000 [get_ports i_source_clk]
set_clock_groups -asynchronous -group [get_clocks i_clk_2m] -group [get_clocks i_source_clk_review]
set_false_path -from [get_ports i_rstn]
set_false_path -from [get_ports i_source_rstn]

# Apply I/O delays only to each clock domain's synchronous control interface.
set source_inputs [get_ports {i_source_update_valid i_source_static_characterization_enable i_source_test_mux_ctrl[*]}]
set source_outputs [get_ports o_source_update_ready]
set system_inputs [get_ports {i_run_enable i_diag_clear_event}]
set system_outputs [get_ports {o_static_characterization_enable o_test_mux_ctrl[*] o_control_valid o_control_update_event o_control_reject_event o_protocol_error_sticky}]
set_input_delay -clock i_source_clk_review -max 1.000 $source_inputs
set_input_delay -clock i_source_clk_review -min 0.000 $source_inputs
set_output_delay -clock i_source_clk_review -max 1.000 $source_outputs
set_output_delay -clock i_source_clk_review -min 0.000 $source_outputs
set_input_delay -clock i_clk_2m -max 1.000 $system_inputs
set_input_delay -clock i_clk_2m -min 0.000 $system_inputs
set_output_delay -clock i_clk_2m -max 1.000 $system_outputs
set_output_delay -clock i_clk_2m -min 0.000 $system_outputs

# Emit resource, structural and timing evidence for the CDC wrapper review.
report_utilization -file [file join $script_dir ppg_characterization_control_cdc_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_characterization_control_cdc_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_characterization_control_cdc_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $script_dir ppg_characterization_control_cdc_synth_timing_summary.rpt]

# Print hard structural counts into the Vivado log for the acceptance record.
puts "CCC_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "CCC_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
exit
