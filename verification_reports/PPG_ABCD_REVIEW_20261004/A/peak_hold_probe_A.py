from pathlib import Path
from native_probe import run
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence/peak_hold_A';E.mkdir(exist_ok=True)
source=B.parent.parent/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/peak_public_vectors/tb_C_peak_return_hold.v'
tb=source.read_text(encoding='utf-8')
orig=E/'audit_peak_hold.v';orig.write_text(tb,encoding='utf-8')
control=E/'audit_peak_return_consumed.v'
control.write_text(tb.replace('consume_valley;','consume_valley; consume_return_request;',1).replace('o_return_frame_id!==16\'d10)\n            $fatal','o_return_frame_id!==16\'d21)\n            $fatal'),encoding='utf-8')
negative=E/'audit_peak_wrong_initial.v'
negative.write_text(tb.replace("o_return_frame_id!==16'd10) $fatal(1,\"initial return\");","o_return_frame_id!==16'd11) $fatal(1,\"initial return wrong expected negative\");",1),encoding='utf-8')
rtl=S/'rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v'
for name,file in [('peak_hold_actual',orig),('peak_hold_consumed_control',control),('peak_hold_wrong_expected_negative',negative)]:
    run(name,[rtl,file],'tb_ppg_peak_valley_window_detector',60)
