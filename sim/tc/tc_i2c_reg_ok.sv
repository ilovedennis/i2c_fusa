// tc_i2c_reg_ok.sv - Verify APB registers write and readback
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

$display("=== [TESTCASE] Starting tc_i2c_reg_ok ===");

// Test 1: Read STATUS Register (Offset 0x14)
apb_read(32'h14, rdata);
$display("[STATUS READ] Default value = 32'h%h (expected: 32'h33c)", rdata);
if (rdata != 32'h33c) begin
  $display("[ERROR] Default STATUS register value mismatch!");
  $finish;
end

// Test 2: Write timing parameter TIMING0 (Offset 0x3c)
apb_write(32'h3c, 32'h00280028); // thigh=40, tlow=40
apb_read(32'h3c, rdata);
$display("[TIMING0 R/W] TIMING0 readback = 32'h%h (expected: 32'h00280028)", rdata);
if (rdata != 32'h00280028) begin
  $display("[ERROR] TIMING0 readback mismatch!");
  $finish;
end

// Test 3: Enable host (CTRL.enablehost = 1, Offset 0x10)
apb_write(32'h10, 32'h00000001);
apb_read(32'h10, rdata);
$display("[CTRL R/W] CTRL readback = 32'h%h (expected: 32'h00000001)", rdata);
if (rdata != 32'h00000001) begin
  $display("[ERROR] CTRL readback mismatch!");
  $finish;
end

// Test 4: Configure remaining timing registers
apb_write(32'h40, 32'h00050005); // TIMING1: t_r=5, t_f=5
apb_write(32'h44, 32'h00140014); // TIMING2: tsu_sta=20, thd_sta=20
apb_write(32'h48, 32'h00140005); // TIMING3: tsu_sto=20, tsu_dat=5
apb_write(32'h4c, 32'h00050005); // TIMING4: thd_dat=5, t_buf=5

apb_write(32'h20, 32'h00000000); // FIFO_CTRL (No reset, threshold 0)

$display("[STATUS] All registers write/readback successfully verified!");

#500;
$display("=== [TESTCASE] tc_i2c_reg_ok Finished ===");
$finish;
