# =============================================================================
# Design:      ppg_timing_sar15_3200hz
# File:        dc_setup.tcl
# Purpose:     Design Compiler setup for the 3200 Hz SAR15 simulation controller
# Location:    <synthesis>/scripts/dc_setup.tcl
# =============================================================================

# Resolve every project path from this script. The expected server structure is:
#   ppg_timing_sar15_3200hz/
#     ppg_timing_sar15.v
#     ppg_timing_sar15_3200hz.v
#     synthesis/scripts/dc_setup.tcl
#     synthesis/constraints/ppg_timing_sar15_3200hz.sdc
set SETUP_FILE [file normalize [info script]]
set SCRIPT_DIR [file dirname $SETUP_FILE]
set SYN_PATH   [file normalize [file join $SCRIPT_DIR ..]]

set RTL_PATH         [file normalize [file join $SYN_PATH ..]]
set CONSTRAINTS_PATH [file join $SYN_PATH constraints]
set WORK_PATH        [file join $SYN_PATH WORK]
set REPORTS_DIR      [file join $SYN_PATH reports]
set RESULTS_DIR      [file join $SYN_PATH results]

# Current slow synthesis corner: SS, 1.62 V, 150 C.
set LIB_PATH [file normalize \
	"/cad/DONGBU/DONGBU1824/DBH_STD_1824HP18BA_HDSVT1P8V_ISO_14Q1_V02/LIBERTY"]
set TARGET_LIBRARY_FILE \
	"1824HP18BA_HDSVT1P8V_ISO_SS_1P62V_150C.db"

set DESIGN_NAME ppg_timing_sar15_3200hz

# The wrapper is the synthesis top, but its parameterized SAR15 core must be
# analyzed first so Design Compiler can elaborate the complete hierarchy.
set CORE_RTL_FILE    [file join $RTL_PATH ppg_timing_sar15.v]
set TOP_RTL_FILE     [file join $RTL_PATH ${DESIGN_NAME}.v]
set CONSTRAINT_FILE  [file join $CONSTRAINTS_PATH ${DESIGN_NAME}.sdc]

set target_library [list $TARGET_LIBRARY_FILE]
set link_library   [concat [list *] $target_library]

set DC_MAX_CORES 4
set CRITICAL_RANGE 3.0

file mkdir $WORK_PATH
file mkdir $REPORTS_DIR
file mkdir $RESULTS_DIR

define_design_lib work -path $WORK_PATH

# Preserve dependency order: core RTL first, then the 3200 Hz top wrapper.
set vlgfiles [list $CORE_RTL_FILE $TOP_RTL_FILE]
set_app_var search_path [list $SYN_PATH $RTL_PATH $CONSTRAINTS_PATH $LIB_PATH]
set_app_var target_library $target_library
set_app_var link_library $link_library

# Stop before analyze when any required process or design input is missing.
if {![file isdirectory $LIB_PATH]} {
	error "Library directory not found: $LIB_PATH"
}

set TARGET_LIBRARY_PATH [file join $LIB_PATH $TARGET_LIBRARY_FILE]
if {![file exists $TARGET_LIBRARY_PATH]} {
	error "Target library file not found: $TARGET_LIBRARY_PATH"
}

if {![file exists $CORE_RTL_FILE]} {
	error "SAR15 core RTL file not found: $CORE_RTL_FILE"
}

if {![file exists $TOP_RTL_FILE]} {
	error "SAR15 3200 Hz wrapper RTL file not found: $TOP_RTL_FILE"
}

if {![file exists $CONSTRAINT_FILE]} {
	error "Constraint file not found: $CONSTRAINT_FILE"
}

# Add the exact fast/minimum library only after its PDK filename and operating
# condition have been confirmed for hold and multi-corner analysis.
# set min_library_file "<fast_corner_library>.db"
# set min_operating_condition "<fast_corner_condition>"
# set max_operating_condition "<slow_corner_condition>"
