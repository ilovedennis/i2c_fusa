// i2c_target_bfm.sv - Simple I2C Target BFM (Address 7'h50)
logic target_sda_oe;
logic target_sda_o;
assign sda = target_sda_oe ? target_sda_o : 1'bz;

// Synchronous SCL/SDA edge detectors to avoid simulator races
logic scl_q, sda_q;
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    scl_q <= 1'b1;
    sda_q <= 1'b1;
  end else begin
    scl_q <= cio_scl_i;
    sda_q <= cio_sda_i;
  end
end

wire start_cond  = scl_q && sda_q && !cio_sda_i;
wire stop_cond   = scl_q && !sda_q && cio_sda_i;
wire scl_posedge = !scl_q && cio_scl_i;
wire scl_negedge = scl_q && !cio_scl_i;

// Target State Machine
typedef enum int {
  IDLE,
  ADDR_RX,
  ACK_ADDR,
  DATA_RX_START,
  DATA_RX,
  ACK_DATA_RX,
  DATA_TX_START,
  DATA_TX,
  ACK_DATA_TX
} target_state_e;

target_state_e target_state;
logic [3:0] bit_cnt;
logic [7:0] addr_shreg;
logic [7:0] data_shreg;
logic rw_bit;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    target_state  <= IDLE;
    bit_cnt       <= 0;
    target_sda_oe <= 0;
    target_sda_o  <= 0;
    addr_shreg    <= 0;
    data_shreg    <= 0;
    rw_bit        <= 0;
  end else begin
    if (start_cond) begin
      target_state  <= ADDR_RX;
      bit_cnt       <= 0;
      target_sda_oe <= 0;
    end else if (stop_cond) begin
      target_state  <= IDLE;
      target_sda_oe <= 0;
    end else begin
      case (target_state)
        IDLE: begin
          target_sda_oe <= 0;
        end

        ADDR_RX: begin
          if (scl_posedge) begin
            addr_shreg <= {addr_shreg[6:0], cio_sda_i};
            bit_cnt    <= bit_cnt + 1'b1;
            if (bit_cnt == 7) begin
              target_state <= ACK_ADDR;
            end
          end
        end

        ACK_ADDR: begin
          if (scl_negedge) begin
            rw_bit <= addr_shreg[0];
            if (addr_shreg[7:1] == 7'h50) begin
              target_sda_oe <= 1; // Pull down SDA to ACK
              target_sda_o  <= 0;
              if (addr_shreg[0]) begin
                target_state <= DATA_TX_START;
              end else begin
                target_state <= DATA_RX_START;
              end
            end else begin
              target_state <= IDLE;
            end
            bit_cnt <= 0;
          end
        end

        DATA_RX_START: begin
          if (scl_negedge) begin
            target_sda_oe <= 0; // Release ACK (let SCL pull-up)
            target_state  <= DATA_RX;
            bit_cnt       <= 0;
          end
        end

        DATA_TX_START: begin
          if (scl_negedge) begin
            // Drive 8'hA5 bit 7 immediately. Since bit 7 of 8'hA5 is 1, we release SDA.
            target_sda_oe <= 0; 
            target_sda_o  <= 0;
            data_shreg    <= {7'h25, 1'b0}; // Remaining bits of 8'hA5
            bit_cnt       <= 1;
            target_state  <= DATA_TX;
          end
        end

        DATA_RX: begin
          if (scl_negedge) begin
            target_sda_oe <= 0; // Release SDA
          end
          if (scl_posedge) begin
            data_shreg <= {data_shreg[6:0], cio_sda_i};
            bit_cnt    <= bit_cnt + 1'b1;
            if (bit_cnt == 7) begin
              target_state <= ACK_DATA_RX;
            end
          end
        end

        ACK_DATA_RX: begin
          if (scl_negedge) begin
            target_sda_oe <= 1; // Pull down SDA to ACK
            target_sda_o  <= 0;
            target_state  <= DATA_RX;
            bit_cnt       <= 0;
          end
        end

        DATA_TX: begin
          if (scl_negedge) begin
            // Drive data_shreg[7]. If 1, release (0). If 0, pull down (1).
            target_sda_oe <= !data_shreg[7];
            target_sda_o  <= 0;
            data_shreg    <= {data_shreg[6:0], 1'b0};
            bit_cnt       <= bit_cnt + 1'b1;
            if (bit_cnt == 7) begin
              target_state <= ACK_DATA_TX;
            end
          end
        end

        ACK_DATA_TX: begin
          if (scl_negedge) begin
            target_sda_oe <= 0; // Release SDA to let Host ACK/NACK
          end
          if (scl_posedge) begin
            target_state <= IDLE;
            bit_cnt      <= 0;
          end
        end
      endcase
    end
  end
end

// Display target output out of always_ff to avoid simulation warning
always @(posedge clk) begin
  if (rst_n && target_state == ACK_ADDR && scl_negedge) begin
    $display("[BFM TARGET] Address received = 8'h%h (rw=%b)", addr_shreg, addr_shreg[0]);
  end
  if (rst_n && target_state == ACK_DATA_RX && scl_negedge) begin
    $display("[BFM TARGET] Received data byte = 8'h%h", data_shreg);
  end
  if (rst_n && u_dut.u_i2c.i2c_core.rx_fifo_wvalid) begin
    $display("[DEBUG CORE] Writing to RX FIFO, data = 8'h%h", u_dut.u_i2c.i2c_core.rx_fifo_wdata);
  end
end
