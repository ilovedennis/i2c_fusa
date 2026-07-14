// prim_flop_2sync.sv
module prim_flop_2sync #(
  parameter int Width = 1,
  parameter logic [Width-1:0] ResetValue = '0
) (
  input clk_i,
  input rst_ni,
  input [Width-1:0] d_i,
  output logic [Width-1:0] q_o
);
  logic [Width-1:0] sync_reg_0;
  logic [Width-1:0] sync_reg_1;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync_reg_0 <= ResetValue;
      sync_reg_1 <= ResetValue;
    end else begin
      sync_reg_0 <= d_i;
      sync_reg_1 <= sync_reg_0;
    end
  end

  assign q_o = sync_reg_1;
endmodule
