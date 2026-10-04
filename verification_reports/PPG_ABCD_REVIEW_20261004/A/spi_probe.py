from pathlib import Path
import json,subprocess,shlex
B=Path(__file__).resolve().parent; S=B/'snapshot'; D=B/'evidence/spi_map_probe'; D.mkdir(exist_ok=True)
ast=json.loads((B/'evidence/gates/ppg_spi_register_file.json').read_text(encoding='utf-8'))['quality_gate']['ast_report']['files'][0]['modules'][0]
signal={'i_clk':'clk','i_rstn':'rstn','i_source_clk':'sclk','i_source_rstn':'rstn','i_spi_cs_n':'cs','i_spi_sdi':'sdi','i_last_error_code':'error_code','i_measurement_result_discard_event':'mr_event','i_detection_discard_event':'dd_event'}
values={'i_lifecycle_state':2,'i_start_ready':1,'i_commit_ack_sticky':1,'i_error_sticky':0,'i_schema_version':0x32,'i_config_epoch':0x33,'i_coef_epoch':0x34,'i_stage2_coef_epoch':0x35,'i_dc_recovery_coef_epoch':0x36,
'i_active_precision_mode':1,'i_ami_idac_idle':0,'i_ami_datapath_empty':1,'i_scheduler_protocol_error_sticky':0,'i_scheduler_completion_mismatch_sticky':1,'i_scheduler_owner_deadline_timeout_sticky':0,'i_scheduler_launch_timeout_sticky':1,'i_scheduler_idle':0,
'i_ssw_calibration_timeout_sticky':1,'i_ssw_owner_deadline_timeout_sticky':0,'i_ssw_transaction_mismatch_sticky':1,'i_ssw_switch_protocol_error_sticky':0,'i_ssw_wrapper_idle':1,'i_ami_integration_protocol_error_sticky':0,
'i_source_config_update_ready':1,'i_source_characterization_update_ready':1,'i_characterization_control_valid':0,'i_characterization_protocol_error_sticky':1,
'i_result_discard_summary_sticky':1,'i_system_fault_precision':1,'i_system_fault_frame_type':2,'i_system_fault_color_ir':1,'i_system_fault_identity_valid':1,'i_system_fault_cause_valid':0,'i_system_fault_blocking':1,
'i_system_fault_cause':0x4B,'i_system_fault_source':0xC,'i_system_fault_frame_id':0x7E6D,'i_system_fault_sample_index':0x908F,'i_system_fault_run_generation':0x91,'i_system_fault_summary':0xB3A2,
'i_measurement_result_discard_reason':2,'i_measurement_result_discard_identity_valid':1,'i_measurement_result_discard_sample_valid':1,'i_measurement_result_discard_color_ir':1,'i_measurement_result_discard_frame_type':1,'i_measurement_result_discard_precision':1,'i_measurement_result_discard_frame_id':0x1234,'i_measurement_result_discard_sample_index':0x5678,'i_measurement_result_discard_run_generation':0x3A,
'i_detection_discard_reason':1,'i_detection_discard_identity_valid':1,'i_detection_discard_sample_valid':0,'i_detection_discard_color_ir':0,'i_detection_discard_frame_type':3,'i_detection_discard_precision':0,'i_detection_discard_frame_id':0xBBAA,'i_detection_discard_sample_index':0xDDCC,'i_detection_discard_config_epoch':0x5C,'i_detection_discard_coef_epoch':0x6D,'i_detection_discard_dc_recovery_epoch':0x7E,'i_detection_discard_amb_code_epoch':8,'i_detection_discard_dc_code_epoch':9,'i_detection_discard_run_generation':0x4B}
con=[]
for p in ast['ports']:
    if p['direction']!='input': continue
    name=p['name']; assert name in signal or name in values,name
    con.append('.'+name+'('+signal.get(name,"'h"+format(values.get(name,0),'x'))+')')
expected=[0x0E,0x31,0x32,0x33,0x34,0x35,0x36,0xAA,0x2A,0x0B,0xED,0x4B,0x0C,0x6D,0x7E,0x8F,0x90,0x91,0xA2,0xB3,0x7D,0x34,0x12,0x78,0x56,0x3A,0x01,0xCB,0xAA,0xBB,0xCC,0xDD,0x5C,0x6D,0x7E,0x98,0x4B,0x00]
body='''`timescale 1ns/1ps
module audit_spi_map;
reg clk=0,sclk=0,rstn=1,cs=1,sdi=0,mr_event=0,dd_event=0;
reg [7:0] error_code=8'h31;
always #250 clk=~clk;
ppg_spi_register_file dut (
'''+',\n'.join(con)+''');
reg [7:0] expected[0:37];
reg [7:0] rx,discard;
integer n,checks=0,start_count=0,stop_count=0,clear_count=0,abort_count=0,commit_count=0;
always @(posedge clk) begin
 if(dut.o_start_event) start_count=start_count+1;
 if(dut.o_stop_event) stop_count=stop_count+1;
 if(dut.o_diag_clear_event) clear_count=clear_count+1;
 if(dut.o_control_abort_event) abort_count=abort_count+1;
end
always @(posedge sclk) if(dut.o_source_config_update_event) commit_count=commit_count+1;
task byte_io; input [7:0] tx; output [7:0] got; integer bitn;
begin for(bitn=7;bitn>=0;bitn=bitn-1)begin
 sdi=tx[bitn]; #125 sclk=1; #1 got[bitn]=dut.o_spi_sdo; #124 sclk=0; #1;
end end endtask
task header;input rd;input [15:0] addr;
begin cs=0;#125;byte_io({rd,7'd0},discard);byte_io(addr[15:8],discard);byte_io(addr[7:0],discard);
 if(rd)begin byte_io(0,discard);byte_io(0,discard);end
end endtask
task close_frame;begin #125 cs=1; #500;end endtask
initial begin
 #1 rstn=0;#1000 rstn=1;
 @(negedge clk);mr_event=1;dd_event=1;@(negedge clk);mr_event=0;dd_event=0;
'''+''.join(f" expected[{i}]=8'h{x:02X};\n" for i,x in enumerate(expected))+'''
 header(1,16'h0100);
 for(n=0;n<38;n=n+1)begin
   byte_io(0,rx);
   if(rx !== expected[n]) $fatal(1,"SPI_MAP_FAIL addr=%h got=%h expected=%h",16'h0100+n,rx,expected[n]);
   checks=checks+1;
   if(n==3) error_code=8'hE7;
 end
 close_frame;
 header(1,16'h0101);byte_io(0,rx);if(rx!==8'hE7)$fatal(1,"SPI_REFRESH_FAIL got=%h",rx);close_frame;
 header(0,0);for(n=0;n<128;n=n+1) byte_io((n*13)^8'hA5,discard);close_frame;
 header(1,0);for(n=0;n<128;n=n+1)begin byte_io(0,rx);if(rx!==(((n*13)^8'hA5)&8'hFF))$fatal(1,"SPI_SHADOW_FAIL addr=%h",n);end close_frame;
 header(0,16'h0080);byte_io(8'hFF,discard);byte_io(8'hFF,discard);byte_io(8'hFF,discard);close_frame;
 header(1,16'h0080);byte_io(0,rx);if(rx!==8'h3F)$fatal(1,"SPI_CHAR_FAIL");byte_io(0,rx);if(rx!==7)$fatal(1,"SPI_DBG_FAIL");byte_io(0,rx);if(rx!==0)$fatal(1,"SPI_RESERVED_FAIL");close_frame;
 header(0,16'h0090);byte_io(8'h3F,discard);close_frame;#3000;
 if(start_count!==1||stop_count!==1||clear_count!==1||abort_count!==1||commit_count!==1)$fatal(1,"SPI_CMD_FAIL %d %d %d %d %d",start_count,stop_count,clear_count,abort_count,commit_count);
 header(1,16'h0090);byte_io(0,rx);if(rx!==0)$fatal(1,"SPI_COMMAND_READ_FAIL");close_frame;
 $display("SPI_MAP_PROBE_PASS diagnostic_bytes=%0d shadow_bytes=128 atomic_freeze=1 refresh=1 reserved=1 multi_command=1",checks);
 $finish;
end
initial begin #1000000;$fatal(1,"SPI_PROBE_TIMEOUT");end
endmodule
'''
(D/'audit_spi_map.v').write_bytes(body.encode());(D/'audit_spi_map_negative.v').write_bytes(body.replace("expected[0]=8'h0E;","expected[0]=8'h0F;").encode())
legacy=body.replace('sdi=tx[bitn]; #125 sclk=1; #1 got[bitn]=dut.o_spi_sdo; #124 sclk=0; #1;', 'sdi=tx[bitn]; got[bitn]=dut.o_spi_sdo; #125 sclk=1; #125 sclk=0;')
(D/'audit_spi_map_legacy.v').write_bytes(legacy.encode())
# Hypothesis control only: mutate an OUTSIDE-REPOSITORY leaf copy so loading uses
# the just-completed byte boundary at the physical falling edge.
rtl=S/'rtl/ppg_spi_register_file/ppg_spi_register_file.v'
mutant=rtl.read_text(encoding='utf-8')
old="assign flag_load_read_byte = (flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b1)) || (flag_byte_boundary && (state_current == ST_DATA) && flag_cmd_is_read);"
assert mutant.count(old)==1
mutant=mutant.replace(old,"assign flag_load_read_byte = (cnt_bit_in_byte == 3'd0) && (state_current == ST_DATA) && flag_cmd_is_read;")
old="assign dec_read_load_addr = (state_current == ST_DATA) ? (reg_byte_addr + 16'd1) : reg_byte_addr;"
assert mutant.count(old)==1
mutant=mutant.replace(old,'assign dec_read_load_addr = reg_byte_addr;')
(D/'hypothesis_ppg_spi_register_file.v').write_bytes(mutant.encode())
def lin(p):return '/mnt/c/'+p.resolve().as_posix()[3:]
lib=B/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'; iv=B/'toolchain/icarus11/usr/bin/iverilog'; vp=B/'toolchain/icarus11/usr/bin/vvp'
for name,src,rtlfile in [('physical','audit_spi_map.v',rtl),('legacy','audit_spi_map_legacy.v',rtl),('hypothesis','audit_spi_map.v',D/'hypothesis_ppg_spi_register_file.v'),('hypothesis_negative','audit_spi_map_negative.v',D/'hypothesis_ppg_spi_register_file.v')]:
    source=D/src; sim=D/(name+'.vvp')
    args=[lin(iv),'-B',lin(lib),'-g2012','-Wall','-s','audit_spi_map','-o',lin(sim),lin(source),lin(rtlfile),lin(S/'rtl/ppg_pulse_cdc_sync/ppg_pulse_cdc_sync.v')]
    rc=subprocess.run(['wsl.exe','-d','Debian','--']+args,capture_output=True);(D/(name+'.compile.log')).write_bytes(rc.stdout+rc.stderr)
    run=subprocess.run(['wsl.exe','-d','Debian','--',lin(vp),'-M',lin(lib),lin(sim)],capture_output=True);(D/(name+'.run.log')).write_bytes(run.stdout+run.stderr)
    print(name,'compile',rc.returncode,'run',run.returncode,run.stdout.decode('utf-8',errors='replace'))
