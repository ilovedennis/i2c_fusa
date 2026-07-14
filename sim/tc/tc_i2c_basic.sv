// tc_i2c_basic.sv - Basic APB I2C controller read/write testcase
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
