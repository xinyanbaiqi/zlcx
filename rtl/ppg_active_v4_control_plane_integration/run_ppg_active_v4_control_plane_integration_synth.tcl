# Resolve all source and report paths relative to this wrapper directory.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]

# Read the wrapper and its three synthesizable control-plane dependencies.
read_verilog [file join $repo_dir ppg_config_cdc_bridge ppg_config_cdc_bridge.v]
read_verilog [file join $repo_dir ppg_system_config_manager ppg_system_config_manager.v]
read_verilog [file join $repo_dir ppg_system_active_config_unpack ppg_system_active_config_unpack.v]
read_verilog [file join $script_dir ppg_active_v4_control_plane_integration.v]

# Run out-of-context synthesis against the established Artix-7 review target.
synth_design -top ppg_active_v4_control_plane_integration -part xc7a35tcpg236-1 -mode out_of_context -flatten_hierarchy none

# Apply the 2 MHz control-clock timing assumption used by the wrapper contract.
# The source configuration rate is not frozen by this contract; use the same
# 2 MHz review assumption and declare the two independently reset domains async.
create_clock -name i_clk_2m -period 500.000 [get_ports i_clk]
create_clock -name i_source_clk_review -period 500.000 [get_ports i_source_clk]
set_clock_groups -asynchronous -group [get_clocks i_clk_2m] -group [get_clocks i_source_clk_review]
set_false_path -from [get_ports i_rstn]
set_false_path -from [get_ports i_source_rstn]

# Constrain each side of the CDC relative to its owning clock domain.
set source_inputs [get_ports {i_source_config_snapshot* i_source_config_update_event}]
set system_inputs [get_ports -filter {DIRECTION == IN && NAME !~ i_source_* && NAME != i_clk && NAME != i_rstn}]
set source_outputs [get_ports o_config_transport_busy]
set system_outputs [get_ports -filter {DIRECTION == OUT && NAME != o_config_transport_busy}]
set_input_delay -clock i_source_clk_review -max 1.000 $source_inputs
set_input_delay -clock i_source_clk_review -min 0.000 $source_inputs
set_input_delay -clock i_clk_2m -max 1.000 $system_inputs
set_input_delay -clock i_clk_2m -min 0.000 $system_inputs
set_output_delay -clock i_source_clk_review -max 1.000 $source_outputs
set_output_delay -clock i_source_clk_review -min 0.000 $source_outputs
set_output_delay -clock i_clk_2m -max 1.000 $system_outputs
set_output_delay -clock i_clk_2m -min 0.000 $system_outputs

# Emit structural and timing reports required for wrapper acceptance.
report_utilization -file [file join $script_dir ppg_active_v4_control_plane_integration_synth_utilization.rpt]
report_drc -file [file join $script_dir ppg_active_v4_control_plane_integration_synth_drc.rpt]
check_timing -verbose -file [file join $script_dir ppg_active_v4_control_plane_integration_synth_check_timing.rpt]
report_timing_summary -delay_type max -max_paths 10 -file [file join $script_dir ppg_active_v4_control_plane_integration_synth_timing_summary.rpt]
report_methodology -file [file join $script_dir ppg_active_v4_control_plane_integration_synth_methodology.rpt]

# Log hard structural acceptance counts for the final evidence record.
puts "AV4C_LATCH_COUNT=[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]"
puts "AV4C_BLACKBOX_COUNT=[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]"
exit
