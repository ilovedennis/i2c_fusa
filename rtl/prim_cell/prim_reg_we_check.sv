// prim_reg_we_check.sv (Mock for iverilog simulation)
module prim_reg_we_check #(
  parameter int unsigned OneHotWidth  = 32
) (
  input                          clk_i,
  input                          rst_ni,
  input  logic [OneHotWidth-1:0] oh_i,
  input                          en_i,
  output logic                   err_o
);
  assign err_o = 1'b0;
endmodule
