// prim_assert.sv - dummy macros for iverilog
`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

`define ASSERT(name, prop, clk=1'b0, rst=1'b0)
`define ASSERT_KNOWN(name, sig, clk=1'b0, rst=1'b0)
`define ASSERT_NEVER_KNOWN(name, sig, clk=1'b0, rst=1'b0)
`define ASSERT_INIT(name, prop)
`define ASSERT_FINAL(name, prop)
`define ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(name, path, sig)
`define ASSERT_STATIC_IN_PACKAGE(name, prop) localparam int name``_static_assert = 1;
`define ASSUME(name, prop, clk=1'b0, rst=1'b0)
`define ASSUME_I(name, prop)
`define ASSERT_PULSE(name, sig, clk=1'b0, rst=1'b0)

`endif


