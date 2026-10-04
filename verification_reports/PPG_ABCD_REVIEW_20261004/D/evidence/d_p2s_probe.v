`timescale 1ns/1ps
module d_p2s_probe;
reg clk=0, rstn=1, valid=0;
reg [160:0] payload=0;
wire ready, frame, serial_data;
reg [160:0] expected[0:31];
integer written=0, received=0, bit_number=160, backpressure_cycles=0, packets=0;
integer index, guard;
reg previous_frame=0;
reg needs_gap=0;
always #5 clk=~clk;
ppg_p2s_packer dut(.i_clk(clk),.i_rstn(rstn),.i_result_valid(valid),.o_result_ready(ready),
 .i_frame_id(payload[160:145]),.i_sample_index(payload[144:129]),.i_color_ir(payload[128]),
 .i_frame_type(payload[127:126]),.i_result_precision_mode(payload[125]),
 .i_coarse_ppg_value(payload[124:101]),.i_coarse_valid(payload[100]),.i_coarse_recovery_calibrated(payload[99]),
 .i_fine_ppg_value(payload[98:75]),.i_fine_valid(payload[74]),.i_fine_recovery_calibrated(payload[73]),
 .i_amb_code_snapshot(payload[72:65]),.i_dc_code_snapshot(payload[64:57]),
 .i_amb_code_epoch(payload[56:53]),.i_dc_code_epoch(payload[52:49]),
 .i_calibrated_s1_value(payload[48:37]),.i_programmable_15_code(payload[36:22]),
 .i_programmable_15_valid(payload[21]),.i_s1_calibration_applied(payload[20]),
 .i_stage1_raw(payload[19:10]),.i_stage2_raw(payload[9:0]),.o_p2s_data(serial_data),.o_p2s_frame(frame));
// 在合同定义的上升沿采样已经稳定的MSB-first位；只在frame有效期间比较数据。
always @(posedge clk) begin
 if(rstn) begin
  if(frame !== 1'b0 && frame !== 1'b1) $fatal(1,"P2S_FRAME_X");
  if(needs_gap && frame!==0) $fatal(1,"P2S_NO_FRAME_GAP");
  needs_gap=0;
  if(frame) begin
   if(received>=written) $fatal(1,"P2S_UNEXPECTED_PACKET");
   if(serial_data !== expected[received][bit_number])
    $fatal(1,"P2S_BIT_FAIL packet=%0d bit=%0d",received,bit_number);
   if(bit_number==0) begin received=received+1; packets=packets+1; bit_number=160; needs_gap=1; end
   else bit_number=bit_number-1;
  end else if(previous_frame && bit_number!=160) $fatal(1,"P2S_SHORT_PACKET");
  previous_frame=frame;
  if(valid && ready) begin
   expected[written]=payload;
   if($test$plusargs("NEGATIVE")) expected[written][160]=~payload[160];
   written=written+1;
  end
  if(valid && !ready) backpressure_cycles=backpressure_cycles+1;
 end
end
task send;
input [160:0] value;
begin
 @(negedge clk); payload=value; valid=1;
 guard=0;
 @(posedge clk); #1;
 // written由边沿监视器记录；valid与数据在真正握手前保持。
 while(written<=index && guard<2000) begin @(posedge clk); #1; guard=guard+1; end
 if(guard>=2000) $fatal(1,"P2S_INPUT_TIMEOUT");
 @(negedge clk); valid=0;
end
endtask
initial begin
 #1 rstn=0; #2;
 if(frame!==0 || ready!==1) $fatal(1,"P2S_RESET_FAIL");
 rstn=1;
 for(index=0;index<6;index=index+1) send({1'b1,32'h76543210 ^ index,32'h89abcdef+index,32'h55aa55aa^index,32'h01234567+index,32'hf0e1d2c3^index});
 guard=0;
 while(received<6 && guard<2000) begin @(posedge clk); #1; guard=guard+1; end
 if(received!=6 || backpressure_cycles==0) $fatal(1,"P2S_COVERAGE_FAIL");
 // 第二批发送中途共同复位：当前位流和缓存撤销，复位之后不接受旧包。
 index=written; send({161{1'b1}});
 repeat(20) @(negedge clk);
 rstn=0; #1; valid=0; written=0; received=0; bit_number=160; previous_frame=0; needs_gap=0;
 #1; if(frame!==0 || ready!==1) $fatal(1,"P2S_RESET_INFLIGHT_FAIL");
 @(negedge clk); rstn=1;
 repeat(4) @(negedge clk);
 index=0; send(161'h0123456789abcdef0123456789abcdef0123456789);
 guard=0;
 while(received<1 && guard<300) begin @(posedge clk); #1; guard=guard+1; end
 if(received!=1) $fatal(1,"P2S_RESTART_FAIL");
 repeat(10) @(negedge clk);
 if(frame!==0 || received!=1) $fatal(1,"P2S_LATE_PACKET");
 $display("D_P2S_PASS complete_packets=%0d backpressure_cycles=%0d",packets,backpressure_cycles); $finish;
end
initial begin #100000; $fatal(1,"P2S_TIMEOUT"); end
endmodule
