module leaf(input a); endmodule
module port_bad; leaf x(.NO_SUCH_PORT(1'b0)); endmodule
