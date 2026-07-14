# i2c_fusa Simulation Makefile
IVERILOG     ?= iverilog
VVP          ?= vvp
GTKWAVE      ?= gtkwave
VERILATOR    ?= verilator

# Questa Simulator
VLIB         ?= vlib
VLOG         ?= vlog
VSIM         ?= vsim

# Default testcase
tc           ?= tc_i2c_basic

TOP          := tb
OUT_FILE     := sim.vvp
VCD_FILE     := tb.vcd
FLIST        := flist.f

VFLAGS := \
  -g2012 \
  -Wall \
  -Wno-timescale \
  -Wno-portbind \
  -I../rtl \
  -I../rtl/prim_cell \
  -DIVERILOG

.PHONY: all
all: $(OUT_FILE)

.PHONY: prepare
prepare:
	@if [ ! -f tc/$(tc).sv ]; then \
	  echo "[ERROR] Testcase tc/$(tc).sv not found!"; \
	  exit 1; \
	fi
	cp tc/$(tc).sv tc/test_pattern.sv

$(OUT_FILE): prepare $(FLIST) tb.sv
	$(IVERILOG) $(VFLAGS) -s $(TOP) -o $@ -f $(FLIST) tb.sv

.PHONY: run
run: $(OUT_FILE)
	$(VVP) $(OUT_FILE)

.PHONY: questa
questa: prepare
	$(VLIB) work
	$(VLOG) -sv -I../rtl -I../rtl/prim_cell -f $(FLIST) tb.sv
	$(VSIM) -c -do "run -all; quit" $(TOP)

.PHONY: wave
wave: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE) &

.PHONY: lint
lint: prepare
	$(VERILATOR) --lint-only -sv --top-module i2c_apb -I../rtl -I../rtl/prim_cell -Wno-fatal -f $(FLIST)

.PHONY: clean
clean:
	rm -f $(OUT_FILE) $(VCD_FILE) tc/test_pattern.sv
	rm -rf work transcript vsim.wlf

.PHONY: help
help:
	@echo "Usage: make [target] [tc=testcase_name]"
	@echo "Example: make run tc=tc_i2c_write"
	@echo ""
	@echo "Targets:"
	@echo "  all       Compile simulation for iverilog"
	@echo "  run       Run simulation using iverilog/vvp"
	@echo "  questa    Run simulation using Questa Sim"
	@echo "  wave      Open GTKWave to view waveform"
	@echo "  lint      Lint check using Verilator"
	@echo "  clean     Remove compilation and simulation artifacts"
	@echo "  help      Show this help message"
