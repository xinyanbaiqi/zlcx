# =============================================================================
# Design:      ppg_timing_sar15
# File:        dc_setup.tcl
# Purpose:     Design Compiler setup for the standalone SAR15 timing controller
# Location:    <synthesis>/scripts/dc_setup.tcl
# =============================================================================

set SETUP_FILE [file normalize [info script]]
set SCRIPT_DIR [file dirname $SETUP_FILE]
set SYN_PATH   [file normalize [file join $SCRIPT_DIR ..]]

set RTL_PATH         [file normalize [file join $SYN_PATH ..]]
set CONSTRAINTS_PATH [file join $SYN_PATH constraints]
set WORK_PATH        [file join $SYN_PATH WORK]
set REPORTS_DIR      [file join $SYN_PATH reports]
set RESULTS_DIR      [file join $SYN_PATH results]

# Current SS, 1.62 V, 150 C synthesis corner.
set LIB_PATH [file normalize \
	"/cad/DONGBU/DONGBU1824/DBH_STD_1824HP18BA_HDSVT1P8V_ISO_14Q1_V02/LIBERTY"]
set TARGET_LIBRARY_FILE \
	"1824HP18BA_HDSVT1P8V_ISO_SS_1P62V_150C.db"

set DESIGN_NAME ppg_timing_sar15

set RTL_FILE        [file join $RTL_PATH ${DESIGN_NAME}.v]
set CONSTRAINT_FILE [file join $CONSTRAINTS_PATH ${DESIGN_NAME}.sdc]

set target_library [list $TARGET_LIBRARY_FILE]
set link_library   [concat [list *] $target_library]

set DC_MAX_CORES 4
set CRITICAL_RANGE 3.0

file mkdir $WORK_PATH
file mkdir $REPORTS_DIR
file mkdir $RESULTS_DIR

define_design_lib work -path $WORK_PATH

set vlgfiles [list $RTL_FILE]
set_app_var search_path [list $SYN_PATH $RTL_PATH $CONSTRAINTS_PATH $LIB_PATH]
set_app_var target_library $target_library
set_app_var link_library $link_library

if {![file isdirectory $LIB_PATH]} {
	error "Library directory not found: $LIB_PATH"
}

set TARGET_LIBRARY_PATH [file join $LIB_PATH $TARGET_LIBRARY_FILE]
if {![file exists $TARGET_LIBRARY_PATH]} {
	error "Target library file not found: $TARGET_LIBRARY_PATH"
}

if {![file exists $RTL_FILE]} {
	error "RTL file not found: $RTL_FILE"
}

if {![file exists $CONSTRAINT_FILE]} {
	error "Constraint file not found: $CONSTRAINT_FILE"
}

# Optional multi-corner configuration. Do not uncomment until the exact PDK
# fast-corner library and operating-condition names are confirmed.
# set min_library_file "<fast_corner_library>.db"
# set min_operating_condition "<fast_corner_condition>"
# set max_operating_condition "<slow_corner_condition>"
