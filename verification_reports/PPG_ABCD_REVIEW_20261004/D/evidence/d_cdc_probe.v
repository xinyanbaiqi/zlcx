`timescale 1ns/1ps
// D组数字协议专项：比例/相位/释放偏斜；没有物理亚稳态模型。
module d_cdc_probe;
integer source_half=7, dest_half=5, phase=1, skew=9;
reg source_clk=0, dest_clk=0, source_rstn=1, dest_rstn=1;
reg request=0, source_enable=0, run_enable=0, clear=0, pulse=0;
reg [4:0] source_mux=0;
wire ready, enable, valid, update, reject, sticky, pulse_out, reset_out;
wire [4:0] mux;
integer updates=0, rejects=0, pulses=0, checks=0;
reg previous_update=0, previous_reject=0;
reg [6:0] last_control=0;
integer prior_updates, prior_rejects, prior_pulses, index;
reg [5:0] wanted;

initial begin
    if($value$plusargs("SOURCE_HALF=%d",source_half)) begin end
    if($value$plusargs("DEST_HALF=%d",dest_half)) begin end
    if($value$plusargs("PHASE=%d",phase)) begin end
    if($value$plusargs("SKEW=%d",skew)) begin end
end
initial begin #1; forever #(source_half) source_clk=~source_clk; end
initial begin #(phase+1); forever #(dest_half) dest_clk=~dest_clk; end

ppg_characterization_control_cdc dut(
    .i_source_clk(source_clk), .i_source_rstn(source_rstn),
    .i_source_update_valid(request), .i_source_static_characterization_enable(source_enable),
    .i_source_test_mux_ctrl(source_mux), .i_clk(dest_clk), .i_rstn(dest_rstn),
    .i_run_enable(run_enable), .i_diag_clear_event(clear),
    .o_source_update_ready(ready), .o_static_characterization_enable(enable),
    .o_test_mux_ctrl(mux), .o_control_valid(valid), .o_control_update_event(update),
    .o_control_reject_event(reject), .o_protocol_error_sticky(sticky));
ppg_pulse_cdc_sync pulse_dut(
    .i_source_clk(source_clk), .i_source_rstn(source_rstn), .i_source_pulse(pulse),
    .i_dest_clk(dest_clk), .i_dest_rstn(dest_rstn), .o_dest_pulse(pulse_out));
ppg_reset_sync reset_dut(.i_clk(dest_clk), .i_async_rstn(dest_rstn), .o_rstn(reset_out));

// 有效目标窗口检查确定值、事务计数、单拍事件和提交原子性。
always @(negedge dest_rstn) begin
    updates=0; rejects=0; pulses=0;
    previous_update=0; previous_reject=0; last_control=0;
end
always @(posedge dest_clk) begin
    #0.1;
    if(!dest_rstn) begin
        updates=0; rejects=0; pulses=0;
        previous_update=0; previous_reject=0; last_control=0;
    end else begin
        if((^{enable,mux,valid,update,reject,sticky,pulse_out}) === 1'bx)
            $fatal(1,"CDC_PROBE_X");
        if(update && reject) $fatal(1,"CDC_EVENT_COLLISION");
        if((update && previous_update)||(reject && previous_reject)) $fatal(1,"CDC_NOT_ONE_CYCLE");
        if(({enable,mux,valid} !== last_control) && !update) $fatal(1,"CDC_NONATOMIC_CHANGE");
        if(update) updates=updates+1;
        if(reject) rejects=rejects+1;
        if(pulse_out) pulses=pulses+1;
        previous_update=update; previous_reject=reject;
        last_control={enable,mux,valid};
    end
end

task check;
input condition;
begin
    if(condition !== 1'b1) $fatal(1,"CDC_CHECK_FAIL check=%0d time=%0t",checks,$time);
    checks=checks+1;
end
endtask

// 请求只在负沿准备，并在真正源握手之后撤销；结果由持续监视器计数，避免漏采快目标事件。
task launch;
input [5:0] value;
integer guard;
begin
    @(negedge source_clk); request=0;
    @(posedge source_clk); #0.2;
    guard=0;
    while(ready !== 1'b1 && guard<100) begin @(posedge source_clk); #0.2; guard=guard+1; end
    check(ready===1'b1);
    @(negedge source_clk); {source_enable,source_mux}=value; request=1; pulse=1;
    @(posedge source_clk); #0.2; check(ready===1'b0);
    @(negedge source_clk); request=0; pulse=0;
end
endtask

task settle;
integer guard;
begin
    guard=0;
    while((updates+rejects)==(prior_updates+prior_rejects) && guard<100) begin
        @(posedge dest_clk); #0.3; guard=guard+1;
    end
    check((updates+rejects)==(prior_updates+prior_rejects+1));
    repeat(8) begin @(posedge dest_clk); #0.3; end
end
endtask

task transaction;
input [5:0] value;
input should_accept;
begin
    prior_updates=updates; prior_rejects=rejects; prior_pulses=pulses;
    launch(value); settle;
    check(updates==prior_updates+should_accept);
    check(rejects==prior_rejects+!should_accept);
    if(should_accept) begin check({enable,mux}===value); check(valid===1'b1); wanted=value; end
    else begin check({enable,mux}===wanted); check(sticky===1'b1); end
    check(pulses==prior_pulses+1);
end
endtask

initial begin
    #1; source_rstn=0; dest_rstn=0;
    #3; check({enable,mux,valid,update,reject,sticky}===10'b0);
    check(reset_out===1'b0);
    source_rstn=1; #(skew); dest_rstn=1;
    @(posedge dest_clk); #0.3; check(reset_out===1'b0);
    @(posedge dest_clk); #0.3; check(reset_out===1'b1);
    repeat(6) @(posedge dest_clk); #0.3; check(updates==0 && rejects==0 && pulses==0);
    transaction(6'b110101,1);
    transaction(6'b110101,1);
    // 覆盖全部64种载荷位组合，RUN外合法提交。
    for(index=0;index<64;index=index+1) transaction(index[5:0],1);
    run_enable=1; transaction(6'b100011,1); transaction(6'b001100,0);
    // 单独比较软件清除，不依赖后续错误再次置位。
    @(negedge dest_clk); clear=1;
    @(posedge dest_clk); #0.3; check(sticky===1'b0); check({enable,mux}===wanted);
    @(negedge dest_clk); clear=0;
    transaction(6'b010001,0);
    run_enable=0; transaction(6'b001001,1);
    run_enable=1; transaction(6'b111000,0);
    run_enable=0;
    // 保持valid跨应答返回仍只接受一次；未请求shadow变化不能旁路。
    @(negedge source_clk); request=0;
    repeat(8) @(posedge source_clk);
    @(negedge source_clk); prior_updates=updates; prior_rejects=rejects;
    {source_enable,source_mux}=6'b101010; request=1;
    repeat(40) @(posedge source_clk); #0.3;
    check(updates==prior_updates+1 && rejects==prior_rejects); check(ready===1'b0);
    @(negedge source_clk); request=0; {source_enable,source_mux}=6'b010101;
    repeat(10) @(posedge dest_clk); #0.3; check({enable,mux}===6'b101010);
    // 在途请求共同断言复位、目标先释放；源valid同时撤销，旧事务不得迟到。
    prior_updates=updates; prior_rejects=rejects;
    launch(6'b011111); #0.1; source_rstn=0; dest_rstn=0; request=0; pulse=0;
    #2; check({enable,mux,valid,update,reject,sticky}===10'b0);
    dest_rstn=1; #(skew); source_rstn=1;
    repeat(15) @(posedge dest_clk); #0.3;
    check(updates==0 && rejects==0 && pulses==0 && valid===1'b0);
    transaction(6'b000101,1);
    $display("D_CDC_PASS source_half=%0d dest_half=%0d phase=%0d skew=%0d checks=%0d",source_half,dest_half,phase,skew,checks);
    $finish;
end
initial begin #2000000; $fatal(1,"D_CDC_TIMEOUT"); end
endmodule
