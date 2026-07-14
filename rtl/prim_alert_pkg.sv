// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package prim_alert_pkg;

  typedef struct packed {
    logic alert_p;
    logic alert_n;
  } alert_tx_t;

  typedef struct packed {
    logic ping_p;
    logic ping_n;
    logic ack_p;
    logic ack_n;
  } alert_rx_t;

  parameter alert_tx_t ALERT_TX_DEFAULT = '{1'b0, 1'b1};

  parameter alert_rx_t ALERT_RX_DEFAULT = '{1'b0, 1'b1, 1'b0, 1'b1};


endpackage : prim_alert_pkg
