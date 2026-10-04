`timescale 1ns/1ps
module audit_prc10;
reg clk=0,rstn=0,valid=0,last_valid=0;
reg [15:0] sample_index=0,last_index;
integer violations=0;
always #5 clk=~clk;
always @(posedge clk)begin
 if(!rstn)last_valid<=0;
 else if(valid)begin
  if(last_valid)if((sample_index-last_index)=={16{1'b0}})violations=violations+1;
  last_index<=sample_index;last_valid<=1;
 end
end
task send(input [15:0] value);
begin @(negedge clk);sample_index=value;valid=1;@(posedge clk);#1;@(negedge clk);valid=0;end
endtask
task reset;
begin @(negedge clk);rstn=0;@(posedge clk);#1;@(negedge clk);rstn=1;violations=0;end
endtask
initial begin
 reset;send(0);send(1);send(2);$display("A ordered 0,1,2: original_order_check_violations=%0d",violations);if(violations!=0)$fatal(1,"A_FAIL");
 reset;send(1);send(0);send(2);$display("B reordered 1,0,2: original_order_check_violations=%0d",violations);if(violations!=0)$fatal(1,"B_FAIL");
 reset;send(1);send(1);send(2);$display("C duplicate 1,1,2: original_order_check_violations=%0d",violations);if(violations!=1)$fatal(1,"C_NEGATIVE_FAIL");
 $display("AUDIT_PRC10_CHECKER_CONFIRMED");$finish;
end
endmodule
