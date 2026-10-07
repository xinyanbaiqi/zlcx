#!/bin/bash
D=/d/PPG/verilog/ppg_regression_runs/05a31cf_20261006
date > $D/ctrl19_start.txt
(cd $D/rtl/ppg_control_top && bash run_xsim_regression.sh > $D/ctrl19_driver.log 2>&1; echo "driver_rc=$?" >> $D/ctrl19_driver.log; date > $D/ctrl19_end.txt) &
(cd $D && bash rtl/ppg_chip_digital_top/run_xsim_regression.sh > $D/chip_driver.log 2>&1; echo "chip_rc=$?" >> $D/chip_driver.log; bash tools/run_unit_tb_regression.sh -g all -o D:/PPG/verilog/ppg_regression_runs/05a31cf_20261006_unit > $D/unit_driver.log 2>&1; echo "unit_rc=$?" >> $D/unit_driver.log; date > $D/chipunit_end.txt) &
wait
echo ALL_DONE >> $D/ctrl19_driver.log
