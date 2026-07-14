// tc_i2c_read.sv - Verify I2C Controller Host Read operation and RX FIFO RDATA
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

$display("=== [TESTCASE] Starting tc_i2c_read ===");

// Configure I2C Timing & Control Registers
apb_write(32'h3c, 32'h00280028); // TIMING0: thigh=40, tlow=40
apb_write(32'h40, 32'h00050005); // TIMING1: t_r=5, t_f=5
apb_write(32'h44, 32'h00140014); // TIMING2: tsu_sta=20, thd_sta=20
apb_write(32'h48, 32'h00140005); // TIMING3: tsu_sto=20, tsu_dat=5
apb_write(32'h4c, 32'h00050005); // TIMING4: thd_dat=5, t_buf=5
apb_write(32'h20, 32'h00000000); // FIFO_CTRL
apb_write(32'h10, 32'h00000001); // CTRL.enablehost = 1

// Clear any controller events (NACK etc.) to prevent halt
apb_write(32'h78, 32'h00000001); // CONTROLLER_EVENTS Offset 0x78

// Queue I2C Read transaction (Address 7'h50, Read 1 Byte)
$display("[HOST READ] Queue Address 7'h50 (read)");
apb_write(32'h1c, 32'h1a1); // START + Address 7'h50 (read: 1)

$display("[HOST READ] Queue Read 1 byte and STOP");
apb_write(32'h1c, 32'h601); // STOP + Read 1 byte

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

// Read the received byte from RX FIFO (RDATA Offset 0x18)
apb_read(32'h18, rdata);
$display("[HOST READ] Read data from RX FIFO = 8'h%h (expected: 8'ha5)", rdata[7:0]);
if (rdata[7:0] != 8'ha5) begin
  $display("[ERROR] RX FIFO readback mismatch!");
  $finish;
end

$display("[STATUS] Read transaction successfully verified!");

#500;
$display("=== [TESTCASE] tc_i2c_read Finished ===");
$finish;
