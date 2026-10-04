`timescale 1ns/1ps
module audit_pr06_formula;
reg signed [31:0] offset;
wire signed [37:0] acc = 38'sd3533837 + $signed({offset,1'b0});
wire [38:0] mag = acc[37] ? -$signed({acc[37],acc}) : {acc[37],acc};
wire signed [38:0] rounded = acc[37] ? -$signed((mag+39'd65536)>>17) : $signed((mag+39'd65536)>>17);
initial begin
offset=32768;#1;$display("PR06_POS_OFFSET acc=%0d rounded=%0d",acc,rounded);
if(acc!==38'sd3599373 || rounded!==39'sd27)$fatal(1,"PR06_POS_WRONG");
offset=-32768;#1;$display("PR06_NEG_OFFSET acc=%0d rounded=%0d",acc,rounded);
if(acc!==38'sd3468301 || rounded!==39'sd26)$fatal(1,"PR06_NEG_WRONG");
offset=-1734151;#1;if(acc!==38'sd65535 || rounded!==39'sd0)$fatal(1,"NEAR_POS_BELOW");
offset=-1734150;#1;if(acc!==38'sd65537 || rounded!==39'sd1)$fatal(1,"NEAR_POS_ABOVE");
offset=-1799686;#1;if(acc!==-38'sd65535 || rounded!==39'sd0)$fatal(1,"NEAR_NEG_BELOW");
offset=-1799687;#1;if(acc!==-38'sd65537 || rounded!==-39'sd1)$fatal(1,"NEAR_NEG_ABOVE");
$display("PR06_FORMULA_PASS six_vectors");$finish;
end
endmodule
