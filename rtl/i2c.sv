// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Description: I2C top level wrapper file

`include "prim_assert.sv"

module i2c #(
  parameter logic [i2c_reg_pkg::NumAlerts-1:0] AlertAsyncOn              = {i2c_reg_pkg::NumAlerts{1'b1}},
  // Number of cycles a differential skew is tolerated on the alert signal
  parameter int unsigned                       AlertSkewCycles           = 1,
  parameter int unsigned                       InputDelayCycles          = 0,
  parameter bit                                EnableRacl                = 1'b0,
  parameter bit                                RaclErrorRsp              = EnableRacl
) (
  input                                    clk_i,
  input                                    rst_ni,
  input  prim_ram_1p_pkg::ram_1p_cfg_t     ram_cfg_i,
  output prim_ram_1p_pkg::ram_1p_cfg_rsp_t ram_cfg_rsp_o,

  // APB Interface
  input  [6:0]          paddr_i,
  input                 psel_i,
  input                 penable_i,
  input                 pwrite_i,
  input  [31:0]         pwdata_i,
  output logic [31:0]   prdata_o,
  output logic          pready_o,
  output logic          pslverr_o,

  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,

  // RACL interface
  input  top_racl_pkg::racl_policy_vec_t racl_policies_i,
  output top_racl_pkg::racl_error_log_t  racl_error_o,

  // Generic IO
  input                     cio_scl_i,
  output logic              cio_scl_o,
  output logic              cio_scl_en_o,
  input                     cio_sda_i,
  output logic              cio_sda_o,
  output logic              cio_sda_en_o,

  output logic              lsio_trigger_o,

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

  import i2c_reg_pkg::*;

  logic [3:0] RaclPolicySelVec[i2c_reg_pkg::NumRegs];

  i2c_reg2hw_t reg2hw;
  i2c_hw2reg_t hw2reg;

  logic [i2c_reg_pkg::NumAlerts-1:0] alert_test, alerts;

  i2c_reg_top #(
    .EnableRacl(EnableRacl),
    .RaclErrorRsp(RaclErrorRsp)
  ) u_reg (
    .clk_i,
    .rst_ni,
    .paddr_i,
    .psel_i,
    .penable_i,
    .pwrite_i,
    .pwdata_i,
    .prdata_o,
    .pready_o,
    .pslverr_o,
    .reg2hw,
    .hw2reg,
    .racl_policies_i,
    .racl_error_o,
    // SEC_CM: BUS.INTEGRITY
    .intg_err_o(alerts[0])
  );

  assign alert_test = {
    reg2hw.alert_test.q &
    reg2hw.alert_test.qe
  };

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(AlertAsyncOn[i]),
      .SkewCycles(AlertSkewCycles),
      .IsFatal(1'b1)
    ) u_prim_alert_sender (
      .clk_i,
      .rst_ni,
      .alert_test_i  ( alert_test[i] ),
      .alert_req_i   ( alerts[0]     ),
      .alert_ack_o   (               ),
      .alert_state_o (               ),
      .alert_rx_i    ( alert_rx_i[i] ),
      .alert_tx_o    ( alert_tx_o[i] )
    );
  end

  logic scl_int;
  logic sda_int;

  i2c_core #(
    .InputDelayCycles(InputDelayCycles)
  ) i2c_core (
    .clk_i,
    .rst_ni,
    .ram_cfg_i,
    .ram_cfg_rsp_o,

    .reg2hw,
    .hw2reg,

    .scl_i(cio_scl_i),
    .scl_o(scl_int),
    .sda_i(cio_sda_i),
    .sda_o(sda_int),

    .lsio_trigger_o,

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

  // For I2C, in standard, fast and fast-plus modes, outputs simulated as open-drain outputs.
  // Asserting scl or sda high should be equivalent to a tri-state output.
  // The output, when enabled, should only assert low.

  assign cio_scl_o = 1'b0;
  assign cio_sda_o = 1'b0;

  assign cio_scl_en_o = ~scl_int;
  assign cio_sda_en_o = ~sda_int;

  `ASSERT_KNOWN(TlDValidKnownO_A, tl_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_o.a_ready)
  `ASSERT_KNOWN(AlertKnownO_A, alert_tx_o)
  `ASSERT_KNOWN(CioSclKnownO_A, cio_scl_o)
  `ASSERT_KNOWN(CioSclEnKnownO_A, cio_scl_en_o)
  `ASSERT_KNOWN(CioSdaKnownO_A, cio_sda_o)
  `ASSERT_KNOWN(CioSdaEnKnownO_A, cio_sda_en_o)
  `ASSERT_KNOWN(IntrFmtWtmkKnownO_A, intr_fmt_threshold_o)
  `ASSERT_KNOWN(IntrRxWtmkKnownO_A, intr_rx_threshold_o)
  `ASSERT_KNOWN(IntrAcqWtmkKnownO_A, intr_acq_threshold_o)
  `ASSERT_KNOWN(IntrRxOflwKnownO_A, intr_rx_overflow_o)
  `ASSERT_KNOWN(IntrControllerHaltKnownO_A, intr_controller_halt_o)
  `ASSERT_KNOWN(IntrSclInterfKnownO_A, intr_scl_interference_o)
  `ASSERT_KNOWN(IntrSdaInterfKnownO_A, intr_sda_interference_o)
  `ASSERT_KNOWN(IntrStretchTimeoutKnownO_A, intr_stretch_timeout_o)
  `ASSERT_KNOWN(IntrSdaUnstableKnownO_A, intr_sda_unstable_o)
  `ASSERT_KNOWN(IntrCommandCompleteKnownO_A, intr_cmd_complete_o)
  `ASSERT_KNOWN(IntrTxStretchKnownO_A, intr_tx_stretch_o)
  `ASSERT_KNOWN(IntrTxWtmkKnownO_A, intr_tx_threshold_o)
  `ASSERT_KNOWN(IntrAcqStretchKnownO_A, intr_acq_stretch_o)
  `ASSERT_KNOWN(IntrUnexpStopKnownO_A, intr_unexp_stop_o)
  `ASSERT_KNOWN(IntrHostTimeoutKnownO_A, intr_host_timeout_o)
  `ASSERT_KNOWN(LsioTriggerKnown_A, lsio_trigger_o)
  `ASSERT_KNOWN(RaclErrorValidKnown_A, racl_error_o.valid)

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(RegWeOnehotCheck_A, u_reg, alert_tx_o[0])
endmodule
