// tb.sv - Simple APB wrapped OpenTitan I2C testbench
`timescale 1ns/1ps

module tb;

  logic clk;
  logic rst_n;

  // APB interface
  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  // I2C interface
  wire scl;
  wire sda;

  logic cio_scl_i;
  logic cio_scl_o;
  logic cio_scl_en_o;
  logic cio_sda_i;
  logic cio_sda_o;
  logic cio_sda_en_o;

  // Connect tri-state for I2C open-drain
  assign scl = cio_scl_en_o ? cio_scl_o : 1'bz;
  assign sda = cio_sda_en_o ? cio_sda_o : 1'bz;

  // Robustly resolve high-impedance (Z) and unknown (X) states to logic high (1'b1)
  assign cio_scl_i = (scl === 1'b0) ? 1'b0 : 1'b1;
  assign cio_sda_i = (sda === 1'b0) ? 1'b0 : 1'b1;

  // Pull-ups for I2C lines
  pullup(scl);
  pullup(sda);

  // Include Target BFM
  `include "task/i2c_target_bfm.sv"

  // Clock generation (100MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Instantiate DUT
  i2c_apb u_dut (
    .clk_i(clk),
    .rst_ni(rst_n),

    .paddr_i(paddr),
    .psel_i(psel),
    .penable_i(penable),
    .pwrite_i(pwrite),
    .pwdata_i(pwdata),
    .prdata_o(prdata),
    .pready_o(pready),
    .pslverr_o(pslverr),

    .cio_scl_i,
    .cio_scl_o,
    .cio_scl_en_o,
    .cio_sda_i,
    .cio_sda_o,
    .cio_sda_en_o,

    .intr_fmt_threshold_o(),
    .intr_rx_threshold_o(),
    .intr_acq_threshold_o(),
    .intr_rx_overflow_o(),
    .intr_controller_halt_o(),
    .intr_scl_interference_o(),
    .intr_sda_interference_o(),
    .intr_stretch_timeout_o(),
    .intr_sda_unstable_o(),
    .intr_cmd_complete_o(),
    .intr_tx_stretch_o(),
    .intr_tx_threshold_o(),
    .intr_acq_stretch_o(),
    .intr_unexp_stop_o(),
    .intr_host_timeout_o()
  );

  // APB Read/Write Tasks
  `include "task/apb_tasks.sv"

  logic [31:0] rdata;

  initial begin
    `include "tc/test_pattern.sv"
  end

endmodule
