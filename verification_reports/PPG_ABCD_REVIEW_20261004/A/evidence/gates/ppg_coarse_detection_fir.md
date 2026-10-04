# Verilog deliverable gate

Root: `C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\snapshot\rtl\ppg_coarse_detection_fir\ppg_coarse_detection_fir.v`
Delivery ready: `False`
Summary: **3 error(s)**, **0 strict warning(s)**

| Severity | Code | Path | Line | Message |
|---|---|---|---:|---|
| error | VG052 | `ppg_coarse_detection_fir.v` | 312 | Output bridge assign `o_test_calibration_loss_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG061 | `ppg_coarse_detection_fir.v` | 312 | Item `o_test_calibration_loss_inject_ready` must be placed in 输出信号连线, not `其他信号连线`. |
| error | VG061 | `ppg_coarse_detection_fir.v` | 465 | Item `always@(posedge i_clk or negedge i_rstn)` must be placed in 主要任务处理区域, not `输出信号处理区域`. |
