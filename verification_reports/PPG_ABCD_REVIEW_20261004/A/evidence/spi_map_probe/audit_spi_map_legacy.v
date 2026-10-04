`timescale 1ns/1ps
module audit_spi_map;
reg clk=0,sclk=0,rstn=1,cs=1,sdi=0,mr_event=0,dd_event=0;
reg [7:0] error_code=8'h31;
always #250 clk=~clk;
ppg_spi_register_file dut (
.i_clk(clk),
.i_rstn(rstn),
.i_source_clk(sclk),
.i_source_rstn(rstn),
.i_spi_cs_n(cs),
.i_spi_sdi(sdi),
.i_source_config_update_ready('h1),
.i_source_characterization_update_ready('h1),
.i_lifecycle_state('h2),
.i_start_ready('h1),
.i_commit_ack_sticky('h1),
.i_error_sticky('h0),
.i_last_error_code(error_code),
.i_schema_version('h32),
.i_config_epoch('h33),
.i_coef_epoch('h34),
.i_stage2_coef_epoch('h35),
.i_dc_recovery_coef_epoch('h36),
.i_scheduler_idle('h0),
.i_scheduler_launch_timeout_sticky('h1),
.i_scheduler_owner_deadline_timeout_sticky('h0),
.i_scheduler_completion_mismatch_sticky('h1),
.i_scheduler_protocol_error_sticky('h0),
.i_ami_datapath_empty('h1),
.i_ami_idac_idle('h0),
.i_active_precision_mode('h1),
.i_ami_integration_protocol_error_sticky('h0),
.i_ssw_wrapper_idle('h1),
.i_ssw_switch_protocol_error_sticky('h0),
.i_ssw_transaction_mismatch_sticky('h1),
.i_ssw_owner_deadline_timeout_sticky('h0),
.i_ssw_calibration_timeout_sticky('h1),
.i_characterization_control_valid('h0),
.i_characterization_protocol_error_sticky('h1),
.i_system_fault_blocking('h1),
.i_system_fault_cause_valid('h0),
.i_system_fault_identity_valid('h1),
.i_system_fault_color_ir('h1),
.i_system_fault_frame_type('h2),
.i_system_fault_precision('h1),
.i_result_discard_summary_sticky('h1),
.i_system_fault_cause('h4b),
.i_system_fault_source('hc),
.i_system_fault_frame_id('h7e6d),
.i_system_fault_sample_index('h908f),
.i_system_fault_run_generation('h91),
.i_system_fault_summary('hb3a2),
.i_measurement_result_discard_event(mr_event),
.i_measurement_result_discard_reason('h2),
.i_measurement_result_discard_identity_valid('h1),
.i_measurement_result_discard_sample_valid('h1),
.i_measurement_result_discard_frame_id('h1234),
.i_measurement_result_discard_sample_index('h5678),
.i_measurement_result_discard_color_ir('h1),
.i_measurement_result_discard_frame_type('h1),
.i_measurement_result_discard_precision('h1),
.i_measurement_result_discard_run_generation('h3a),
.i_detection_discard_event(dd_event),
.i_detection_discard_reason('h1),
.i_detection_discard_identity_valid('h1),
.i_detection_discard_sample_valid('h0),
.i_detection_discard_frame_id('hbbaa),
.i_detection_discard_sample_index('hddcc),
.i_detection_discard_color_ir('h0),
.i_detection_discard_frame_type('h3),
.i_detection_discard_precision('h0),
.i_detection_discard_config_epoch('h5c),
.i_detection_discard_coef_epoch('h6d),
.i_detection_discard_dc_recovery_epoch('h7e),
.i_detection_discard_amb_code_epoch('h8),
.i_detection_discard_dc_code_epoch('h9),
.i_detection_discard_run_generation('h4b));
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
 sdi=tx[bitn]; got[bitn]=dut.o_spi_sdo; #125 sclk=1; #125 sclk=0;
end end endtask
task header;input rd;input [15:0] addr;
begin cs=0;#125;byte_io({rd,7'd0},discard);byte_io(addr[15:8],discard);byte_io(addr[7:0],discard);
 if(rd)begin byte_io(0,discard);byte_io(0,discard);end
end endtask
task close_frame;begin #125 cs=1; #500;end endtask
initial begin
 #1 rstn=0;#1000 rstn=1;
 @(negedge clk);mr_event=1;dd_event=1;@(negedge clk);mr_event=0;dd_event=0;
 expected[0]=8'h0E;
 expected[1]=8'h31;
 expected[2]=8'h32;
 expected[3]=8'h33;
 expected[4]=8'h34;
 expected[5]=8'h35;
 expected[6]=8'h36;
 expected[7]=8'hAA;
 expected[8]=8'h2A;
 expected[9]=8'h0B;
 expected[10]=8'hED;
 expected[11]=8'h4B;
 expected[12]=8'h0C;
 expected[13]=8'h6D;
 expected[14]=8'h7E;
 expected[15]=8'h8F;
 expected[16]=8'h90;
 expected[17]=8'h91;
 expected[18]=8'hA2;
 expected[19]=8'hB3;
 expected[20]=8'h7D;
 expected[21]=8'h34;
 expected[22]=8'h12;
 expected[23]=8'h78;
 expected[24]=8'h56;
 expected[25]=8'h3A;
 expected[26]=8'h01;
 expected[27]=8'hCB;
 expected[28]=8'hAA;
 expected[29]=8'hBB;
 expected[30]=8'hCC;
 expected[31]=8'hDD;
 expected[32]=8'h5C;
 expected[33]=8'h6D;
 expected[34]=8'h7E;
 expected[35]=8'h98;
 expected[36]=8'h4B;
 expected[37]=8'h00;

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
