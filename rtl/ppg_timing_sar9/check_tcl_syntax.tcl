set script_dir [file dirname [file normalize [info script]]]
set files_to_check [list \
	[file join $script_dir dc_setup.tcl] \
	[file join $script_dir dc_flow.tcl] \
	[file join $script_dir .. constraints ppg_timing_sar9_3200hz.sdc]]

set error_count 0
foreach file_name $files_to_check {
	set file_handle [open $file_name r]
	set file_text [read $file_handle]
	close $file_handle
	if {![info complete $file_text]} {
		puts "INCOMPLETE_TCL: $file_name"
		incr error_count
	} else {
		puts "COMPLETE_TCL: $file_name"
	}
}

exit $error_count
