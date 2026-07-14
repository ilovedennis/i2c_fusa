// prim_fifo_sync_cnt.sv
module prim_fifo_sync_cnt #(
  parameter int unsigned Depth = 4,
  parameter bit Secure         = 1'b0,
  parameter bit NeverClears    = 1'b0,
  // Derived width parameters
  localparam int unsigned AddrW = prim_util_pkg::vbits(Depth),
  localparam int unsigned DepthW = prim_util_pkg::vbits(Depth + 1)
) (
  input                  clk_i,
  input                  rst_ni,
  input                  clr_i,
  input                  incr_wptr_i,
  input                  incr_rptr_i,
  output logic [AddrW-1:0] wptr_o,
  output logic [AddrW-1:0] rptr_o,
  output logic           full_o,
  output logic           empty_o,
  output logic [DepthW-1:0] depth_o,
  output logic           err_o
);

  logic [AddrW-1:0] wptr_q, rptr_q;
  logic [DepthW-1:0] depth_q;

  assign wptr_o  = wptr_q;
  assign rptr_o  = rptr_q;
  assign full_o  = (depth_q == Depth[DepthW-1:0]);
  assign empty_o = (depth_q == '0);
  assign depth_o = depth_q;
  assign err_o   = 1'b0;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wptr_q  <= '0;
      rptr_q  <= '0;
      depth_q <= '0;
    end else if (clr_i && !NeverClears) begin
      wptr_q  <= '0;
      rptr_q  <= '0;
      depth_q <= '0;
    end else begin
      logic do_write;
      logic do_read;

      do_write = incr_wptr_i && !full_o;
      do_read  = incr_rptr_i && !empty_o;

      if (do_write && do_read) begin
        wptr_q <= (wptr_q == Depth[AddrW-1:0] - 1'b1) ? '0 : wptr_q + 1'b1;
        rptr_q <= (rptr_q == Depth[AddrW-1:0] - 1'b1) ? '0 : rptr_q + 1'b1;
      end else if (do_write) begin
        wptr_q  <= (wptr_q == Depth[AddrW-1:0] - 1'b1) ? '0 : wptr_q + 1'b1;
        depth_q <= depth_q + 1'b1;
      end else if (do_read) begin
        rptr_q  <= (rptr_q == Depth[AddrW-1:0] - 1'b1) ? '0 : rptr_q + 1'b1;
        depth_q <= depth_q - 1'b1;
      end
    end
  end

endmodule
