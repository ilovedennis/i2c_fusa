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

  // Simple I2C Target BFM (Address 7'h50)
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
  task apb_write(input [31:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      paddr   = addr;
      pwrite  = 1;
      pwdata  = data;
      psel    = 1;
      @(posedge clk);
      penable = 1;
      forever begin
        @(posedge clk);
        if (pready) break;
      end
      psel    = 0;
      penable = 0;
      pwrite  = 0;
    end
  endtask

  task apb_read(input [31:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      paddr   = addr;
      pwrite  = 0;
      psel    = 1;
      @(posedge clk);
      penable = 1;
      forever begin
        @(posedge clk);
        if (pready) begin
          data = prdata;
          break;
        end
      end
      psel    = 0;
      penable = 0;
    end
  endtask

  logic [31:0] rdata;

  initial begin
    // Setup VCD dumping
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);

    // Initialize inputs
    rst_n   = 0;
    psel    = 0;
    penable = 0;
    pwrite  = 0;
    paddr   = 0;
    pwdata  = 0;

    // Reset sequence
    #100;
    @(posedge clk);
    rst_n = 1;
    
    // Wait for CDC sync of scl/sda inputs
    repeat (10) @(posedge clk);
    #50;

    $display("=== Starting I2C APB Testbench ===");

    // Test 1: Read STATUS Register (Offset 0x14)
    apb_read(32'h14, rdata);
    $display("[STATUS READ] Default value = 32'h%h (expected: 32'h33c)", rdata);

    // Test 2: Write timing parameter TIMING0 (Offset 0x3c)
    apb_write(32'h3c, 32'h00280028); // thigh=40, tlow=40
    apb_read(32'h3c, rdata);
    $display("[TIMING0 R/W] TIMING0 readback = 32'h%h (expected: 32'h00280028)", rdata);

    // Test 3: Enable host (CTRL.enablehost = 1, Offset 0x10)
    apb_write(32'h10, 32'h00000001);
    apb_read(32'h10, rdata);
    $display("[CTRL R/W] CTRL readback = 32'h%h (expected: 32'h00000001)", rdata);

    // Test 4: Configure remaining timing registers
    apb_write(32'h40, 32'h00050005); // TIMING1: t_r=5, t_f=5
    apb_write(32'h44, 32'h00140014); // TIMING2: tsu_sta=20, thd_sta=20
    apb_write(32'h48, 32'h00140005); // TIMING3: tsu_sto=20, tsu_dat=5
    apb_write(32'h4c, 32'h00050005); // TIMING4: thd_dat=5, t_buf=5

    apb_write(32'h20, 32'h00000000); // FIFO_CTRL (No reset, threshold 0)

    // Test 5: Queue I2C Write transaction (Address 7'h50, Data 8'h33)
    // FDATA Offset 0x1c
    $display("[HOST WRITE] Queue Address 7'h50 (write)");
    apb_write(32'h1c, 32'h1a0); 

    $display("[HOST WRITE] Queue Data Byte 8'h33");
    apb_write(32'h1c, 32'h233); 

    // Wait for FMT FIFO to empty and STATUS.hostidle = 1
    #2000;
    forever begin
      apb_read(32'h14, rdata);
      if (rdata[3]) break; // Host idle (bit 3)
      #100;
    end
    $display("[HOST WRITE] Write transaction completed!");
    #2000;

    // Clear any controller events (NACK etc.) to prevent halt
    apb_write(32'h78, 32'h00000001); // CONTROLLER_EVENTS Offset 0x78

    // Test 6: Queue I2C Read transaction (Address 7'h50, Read 1 Byte)
    $display("[HOST READ] Queue Address 7'h50 (read)");
    apb_write(32'h1c, 32'h1a1); 

    $display("[HOST READ] Queue Read 1 byte and STOP");
    apb_write(32'h1c, 32'h601); 

    // Wait for transaction completion
    #2000;
    forever begin
      apb_read(32'h14, rdata);
      if (rdata[3]) break; // Host idle (bit 3)
      #100;
    end

    apb_read(32'h14, rdata);
    $display("[STATUS AT READ] STATUS = 32'h%h", rdata);
    $display("[DEBUG] Controller State = %0d", u_dut.u_i2c.i2c_core.u_i2c_controller_fsm.state_q);
    apb_read(32'h78, rdata); // CONTROLLER_EVENTS
    $display("[DEBUG] CONTROLLER_EVENTS = 32'h%h", rdata);
    apb_read(32'h7c, rdata); // HOST_EVENTS
    $display("[DEBUG] HOST_EVENTS = 32'h%h", rdata);
    // Read the received byte from RX FIFO (RDATA Offset 0x18)
    apb_read(32'h18, rdata);
    $display("[HOST READ] Read data from RX FIFO = 8'h%h (expected: 8'ha5)", rdata[7:0]);

    #500;
    $display("=== Testbench Finished ===");
    $finish;
  end

endmodule
