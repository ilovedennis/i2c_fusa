// prim_fifo_sync.sv
module prim_fifo_sync #(
  parameter int unsigned Width       = 16,
  parameter bit Pass                 = 1'b1,
  parameter int unsigned Depth       = 4,
  parameter bit OutputReg            = 1'b0, // Unused in simple behavioral model
  // Derived parameter for port width
  localparam int unsigned DepthW     = prim_util_pkg::vbits(Depth + 1)
) (
  input                  clk_i,
  input                  rst_ni,
  input                  clr_i,
  input                  wvalid_i,
  output logic           wready_o,
  input  [Width-1:0]     wdata_i,
  output logic           rvalid_o,
  input                  rready_i,
  output logic [Width-1:0] rdata_o,
  output logic [DepthW-1:0] depth_o,
  output logic           full_o,
  output logic           err_o
);

  assign err_o = 1'b0;

  // If Depth is 0, it acts as a simple pass-through wire
  if (Depth == 0) begin : gen_depth0
    assign wready_o = rready_i;
    assign rvalid_o = wvalid_i;
    assign rdata_o  = wdata_i;
    assign depth_o  = '0;
    assign full_o   = '0;
  end else begin : gen_fifo
    logic [Width-1:0] storage [Depth];
    logic [DepthW-1:0] wptr_q, rptr_q;
    logic [DepthW-1:0] count_q;
    logic full, empty;

    assign full  = (count_q == Depth[DepthW-1:0]);
    assign empty = (count_q == '0);

    // Write ready
    assign wready_o = !full;
    assign full_o   = full;

    // Pass-through logic (Bypass)
    // If Pass is enabled, FIFO is empty, and there is a write request, 
    // the write data can directly propagate to the output.
    // Pointer width for addressing (vbits(Depth))
    localparam int unsigned AddrW = prim_util_pkg::vbits(Depth);
    logic [AddrW-1:0] wptr_addr, rptr_addr;
    assign wptr_addr = wptr_q[AddrW-1:0];
    assign rptr_addr = rptr_q[AddrW-1:0];

    // Pass-through logic (Bypass)
    // If Pass is enabled, FIFO is empty, there is a write request, and a read request
    // is active, the write data can directly propagate to the output.
    logic pass_active;
    assign pass_active = Pass && empty && wvalid_i && rready_i;

    assign rvalid_o = !empty || (Pass && wvalid_i);
    assign rdata_o  = pass_active ? wdata_i : storage[rptr_addr];
    assign depth_o  = count_q;

    logic do_write;
    logic do_read;
    assign do_write = wvalid_i && wready_o && !pass_active;
    assign do_read  = rready_i && rvalid_o && !pass_active;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        wptr_q  <= '0;
        rptr_q  <= '0;
        count_q <= '0;
      end else if (clr_i) begin
        wptr_q  <= '0;
        rptr_q  <= '0;
        count_q <= '0;
      end else begin
        if (do_write && do_read) begin
          storage[wptr_addr] <= wdata_i;
          wptr_q <= (wptr_addr == Depth - 1) ? '0 : wptr_q + 1'b1;
          rptr_q <= (rptr_addr == Depth - 1) ? '0 : rptr_q + 1'b1;
        end else if (do_write) begin
          storage[wptr_addr] <= wdata_i;
          wptr_q <= (wptr_addr == Depth - 1) ? '0 : wptr_q + 1'b1;
          count_q <= count_q + 1'b1;
        end else if (do_read) begin
          rptr_q <= (rptr_addr == Depth - 1) ? '0 : rptr_q + 1'b1;
          count_q <= count_q - 1'b1;
        end
      end
    end

    always @(posedge clk_i) begin
      if (rst_ni) begin
        if (do_write && do_read) begin
          $display("[FIFO R/W] %m: wdata=8'h%h, rdata_before=8'h%h, wptr=%0d, rptr=%0d, count=%0d", 
                   wdata_i, storage[rptr_addr], wptr_addr, rptr_addr, count_q);
        end else if (do_write) begin
          $display("[FIFO WRITE] %m: wdata=8'h%h, wptr=%0d, count=%0d -> %0d", 
                   wdata_i, wptr_addr, count_q, count_q + 1'b1);
        end else if (do_read) begin
          $display("[FIFO READ] %m: rdata=8'h%h, rptr=%0d, count=%0d -> %0d", 
                   storage[rptr_addr], rptr_addr, count_q, count_q - 1'b1);
        end
      end
    end
  end

endmodule
