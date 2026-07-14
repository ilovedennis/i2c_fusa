// i2c_apb.sv - APB wrapped OpenTitan I2C top (now directly connected)
module i2c_apb (
  input clk_i,
  input rst_ni,

  // APB interface
  input  [31:0] paddr_i,
  input         psel_i,
  input         penable_i,
  input         pwrite_i,
  input  [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,

  // I2C interface
  input                     cio_scl_i,
  output logic              cio_scl_o,
  output logic              cio_scl_en_o,
  input                     cio_sda_i,
  output logic              cio_sda_o,
  output logic              cio_sda_en_o,

  // Interrupts
  output logic              intr_fmt_threshold_o,
  output logic              intr_rx_threshold_o,
  output logic              intr_acq_threshold_o,
  output logic              intr_rx_overflow_o,
  output logic              intr_controller_halt_o,
  output logic              intr_scl_interference_o,
  output logic              intr_sda_interference_o,
  output logic              intr_stretch_timeout_o,
  output logic              intr_sda_unstable_o,
  output logic              intr_cmd_complete_o,
  output logic              intr_tx_stretch_o,
  output logic              intr_tx_threshold_o,
  output logic              intr_acq_stretch_o,
  output logic              intr_unexp_stop_o,
  output logic              intr_host_timeout_o
);

  prim_ram_1p_pkg::ram_1p_cfg_t ram_cfg;
  prim_ram_1p_pkg::ram_1p_cfg_rsp_t ram_cfg_rsp;

  assign ram_cfg = '0;

  // Declare explicit signals to bypass iverilog port expression limitations
  logic [6:0] paddr_i2c;
  assign paddr_i2c = paddr_i[6:0];

  top_racl_pkg::racl_policy_vec_t racl_policies;

  i2c u_i2c (
    .clk_i,
    .rst_ni,
    .ram_cfg_i(ram_cfg),
    .ram_cfg_rsp_o(ram_cfg_rsp),
    
    // Connect APB directly
    .paddr_i(paddr_i2c),
    .psel_i,
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .prdata_o,
    .pready_o,
    .pslverr_o,

    .alert_rx_i('0),
    .alert_tx_o(),
    .racl_policies_i(racl_policies),
    .racl_error_o(),

    .cio_scl_i,
    .cio_scl_o,
    .cio_scl_en_o,
    .cio_sda_i,
    .cio_sda_o,
    .cio_sda_en_o,

    .lsio_trigger_o(),

    .intr_fmt_threshold_o,
    .intr_rx_threshold_o,
    .intr_acq_threshold_o,
    .intr_rx_overflow_o,
    .intr_controller_halt_o,
    .intr_scl_interference_o,
    .intr_sda_interference_o,
    .intr_stretch_timeout_o,
    .intr_sda_unstable_o,
    .intr_cmd_complete_o,
    .intr_tx_stretch_o,
    .intr_tx_threshold_o,
    .intr_acq_stretch_o,
    .intr_unexp_stop_o,
    .intr_host_timeout_o
  );

endmodule
