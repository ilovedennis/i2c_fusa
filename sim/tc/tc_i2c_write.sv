// tc_i2c_write.sv - Verify I2C Controller Host Write operation
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

$display("=== [TESTCASE] Starting tc_i2c_write ===");

// Configure I2C Timing & Control Registers
apb_write(32'h3c, 32'h00280028); // TIMING0: thigh=40, tlow=40
apb_write(32'h40, 32'h00050005); // TIMING1: t_r=5, t_f=5
apb_write(32'h44, 32'h00140014); // TIMING2: tsu_sta=20, thd_sta=20
apb_write(32'h48, 32'h00140005); // TIMING3: tsu_sto=20, tsu_dat=5
apb_write(32'h4c, 32'h00050005); // TIMING4: thd_dat=5, t_buf=5
apb_write(32'h20, 32'h00000000); // FIFO_CTRL
apb_write(32'h10, 32'h00000001); // CTRL.enablehost = 1

// Queue I2C Write transaction (Address 7'h50, Data 8'h33)
// FDATA Offset 0x1c
$display("[HOST WRITE] Queue Address 7'h50 (write)");
apb_write(32'h1c, 32'h1a0); // START + Address 7'h50 (write: 0)

$display("[HOST WRITE] Queue Data Byte 8'h33");
apb_write(32'h1c, 32'h233); // STOP + Data 8'h33

// Wait for FMT FIFO to empty and STATUS.hostidle = 1
#2000;
forever begin
  apb_read(32'h14, rdata);
  if (rdata[3]) break; // Host idle (bit 3)
  #100;
end
$display("[HOST WRITE] Write transaction completed!");

#500;
$display("=== [TESTCASE] tc_i2c_write Finished ===");
$finish;
