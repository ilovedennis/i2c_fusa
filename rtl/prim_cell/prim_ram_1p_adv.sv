// prim_ram_1p_adv.sv
module prim_ram_1p_adv #(
  parameter int Depth = 512,
  parameter int Width = 32,
  parameter int DataBitsPerMask = 8,
  parameter bit EnableInputPipeline = 1'b0,
  parameter bit EnableOutputPipeline = 1'b0,
  parameter bit EnableECC = 1'b0,
  parameter bit EnableParity = 1'b0,
  localparam int Aw = prim_util_pkg::vbits(Depth)
) (
  input clk_i,
  input rst_ni,
  input req_i,
  input write_i,
  input [Aw-1:0] addr_i,
  input [Width-1:0] wdata_i,
  input [Width-1:0] wmask_i,
  output logic [Width-1:0] rdata_o,
  output logic rvalid_o,
  output logic [1:0] rerror_o,
  input prim_ram_1p_pkg::ram_1p_cfg_t cfg_i,
  output prim_ram_1p_pkg::ram_1p_cfg_rsp_t cfg_rsp_o,
  output logic alert_o
);

  logic [Width-1:0] mem [Depth];
  logic [Width-1:0] rdata_q;
  logic rvalid_q;

  assign rdata_o = rdata_q;
  assign rvalid_o = rvalid_q;
  assign rerror_o = 2'b00;
  assign cfg_rsp_o = '0;
  assign alert_o = 1'b0;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_q  <= '0;
      rvalid_q <= 1'b0;
    end else begin
      rvalid_q <= req_i && !write_i;
      if (req_i) begin
        if (write_i) begin
          for (int i = 0; i < Width; i++) begin
            if (wmask_i[i]) begin
              mem[addr_i][i] <= wdata_i[i];
            end
          end
        end else begin
          rdata_q <= mem[addr_i];
        end
      end
    end
  end

endmodule
