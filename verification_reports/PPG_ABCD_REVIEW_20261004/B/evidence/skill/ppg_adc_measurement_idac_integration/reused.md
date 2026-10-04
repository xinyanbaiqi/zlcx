# Verilog deliverable gate

Root: `C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\snapshot\rtl\ppg_adc_measurement_idac_integration\ppg_adc_measurement_idac_integration.v`
Delivery ready: `False`
Summary: **2 error(s)**, **1 strict warning(s)**

| Severity | Code | Path | Line | Message |
|---|---|---|---:|---|
| warning | VG014 | `ppg_adc_measurement_idac_integration.v` |  | Output port `o_test_calibration_loss_inject_ready` has no explicit assign bridge detected; confirm direct output assignment is intentional. |
| error | VG061 | `ppg_adc_measurement_idac_integration.v` | 481 | Item `idac_test_saturation_inject_ready_o` must be placed in 输出信号, not `标志信号`. |
| error | VG066 | `ppg_adc_measurement_idac_integration.v` | 2361 | Comment for instance mapping `.o_test_saturation_inject_ready` repeats or closely reuses comment from port `o_test_saturation_inject_ready`; write entity-specific RTL intent. |
