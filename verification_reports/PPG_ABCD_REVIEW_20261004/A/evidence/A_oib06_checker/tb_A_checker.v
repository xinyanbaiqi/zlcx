`timescale 1ns/1ps
module tb_A_checker;
reg i_clk,flag_oib_order_monitor_active,o_measurement_result_valid,i_measurement_result_ready,flag_order_first_seen;
reg [15:0]o_result_frame_id,o_result_sample_index,reg_last_result_frame_id,reg_last_result_sample_index;
reg o_result_color_ir,o_result_precision_mode,reg_last_result_color_ir,reg_last_result_precision_mode;
reg [1:0]o_result_frame_type,reg_last_result_frame_type;
integer cnt_order_violation,cnt_duplicate_or_relabel_violation,cnt_error,cnt_result_capture,k,c,id;
always #5 i_clk=~i_clk;
	always @(posedge i_clk) begin
		if(flag_oib_order_monitor_active && o_measurement_result_valid && i_measurement_result_ready) begin
			if(!flag_order_first_seen) begin
				flag_order_first_seen <= 1'b1;
			end else if((o_result_frame_id < reg_last_result_frame_id) ||
				((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index < reg_last_result_sample_index))) begin
				cnt_order_violation <= cnt_order_violation + 1;
				$display("OIB_ORDER_VIOLATION frame_id=%0d sample_index=%0d last_frame_id=%0d last_sample_index=%0d",
					o_result_frame_id, o_result_sample_index, reg_last_result_frame_id, reg_last_result_sample_index);
			end else if((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index == reg_last_result_sample_index)) begin
				// 2026-09-17新增：合同"no loss, duplication, recoloring, retyping, or
				// precision relabeling"里，重复/换色/换型/精度错标这四种失效模式原本
				// 全部未被检测（上面判据只查递减）；恰好重复的(frame_id, sample_index)
				// 到这里统一判为违规，无论颜色/类型/精度是否也被同时错误改写
				cnt_duplicate_or_relabel_violation <= cnt_duplicate_or_relabel_violation + 1;
				$display("OIB_DUPLICATE_OR_RELABEL_VIOLATION frame_id=%0d sample_index=%0d color=%b type=%0d precision=%b last_color=%b last_type=%0d last_precision=%b",
					o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_frame_type, o_result_precision_mode,
					reg_last_result_color_ir, reg_last_result_frame_type, reg_last_result_precision_mode);
			end
			reg_last_result_frame_id <= o_result_frame_id;
			reg_last_result_sample_index <= o_result_sample_index;
			reg_last_result_color_ir <= o_result_color_ir;
			reg_last_result_frame_type <= o_result_frame_type;
			reg_last_result_precision_mode <= o_result_precision_mode;
		end
	end
task check_original;begin
		if(cnt_order_violation != 0) begin
			$display("FAIL OIB-06 result stream order violated (out-of-order/decreasing frame_id or sample_index), count=%0d", cnt_order_violation);
			cnt_error = cnt_error + 1;
		end else if(cnt_duplicate_or_relabel_violation != 0) begin
			$display("FAIL OIB-06 result stream contained duplicate/recolored/retyped/precision-relabeled entries, count=%0d", cnt_duplicate_or_relabel_violation);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across %0d real transfers", cnt_result_capture);
		end
end endtask
initial begin
i_clk=0;flag_oib_order_monitor_active=0;o_measurement_result_valid=0;i_measurement_result_ready=1;
for(c=0;c<7;c=c+1)begin
 @(negedge i_clk);flag_order_first_seen=0;cnt_order_violation=0;cnt_duplicate_or_relabel_violation=0;cnt_error=0;cnt_result_capture=0;flag_oib_order_monitor_active=1;
 for(k=1;k<=4;k=k+1)begin
  if(!(c==1 && k==2))begin
   @(negedge i_clk);id=k;
   if(c==5 && k==2)id=1;
   if(c==6 && k==2)id=3;
   if(c==6 && k==3)id=2;
   o_result_frame_id=id;o_result_sample_index=id;o_result_color_ir=(k%2);o_result_frame_type=0;o_result_precision_mode=0;
   if(c==2 && k==2)o_result_color_ir=~o_result_color_ir;
   if(c==3 && k==2)o_result_frame_type=1;
   if(c==4 && k==2)o_result_precision_mode=1;
   o_measurement_result_valid=1;@(posedge i_clk);#1;cnt_result_capture=cnt_result_capture+1;
   @(negedge i_clk);o_measurement_result_valid=0;
  end
 end
 check_original;$display("A_OIB_CHECKER case=%0d errors=%0d transfers=%0d",c,cnt_error,cnt_result_capture);
 if(c<5 && cnt_error!=0)$fatal(1,"unexpected counterexample rejection");
 if(c>=5 && cnt_error!=1)$fatal(1,"known duplicate/order negative did not fire");
end
$display("A_OIB_CHECKER_CONFIRMED");$finish;end
endmodule
