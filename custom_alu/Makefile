##############################################################################
# Makefile for custom_alu CROC integration
# Usage:
#   make compile    - Compile SV with Verilator
#   make sim        - Run testbench simulation
#   make synth      - Run Yosys synthesis
#   make pnr        - Run OpenROAD place-and-route
#   make all        - Run everything
#   make clean      - Remove generated files
##############################################################################

# Tool paths (update if needed)
VERILATOR  ?= verilator
YOSYS      ?= yosys
OPENROAD   ?= openroad

RTL_FILES  = rtl/custom_alu.sv rtl/custom_alu_apb_wrapper.sv
TB_FILE    = tb/tb_custom_alu_apb.sv
TOP_TB     = tb_custom_alu_apb

.PHONY: all compile sim synth pnr clean

all: compile sim synth

# ---- Compilation with Verilator ----
compile:
	@echo "=== Compiling with Verilator ==="
	mkdir -p build
	$(VERILATOR) --lint-only --sv --top-module custom_alu_apb_wrapper $(RTL_FILES)
	@echo "Lint OK"

# ---- Simulation ----
sim: compile
	@echo "=== Running simulation ==="
	mkdir -p build/sim
	$(VERILATOR) --binary --sv --trace --Mdir build/sim \
	    --top-module $(TOP_TB) $(RTL_FILES) $(TB_FILE) \
	    -CFLAGS "-std=c++17"
	./build/sim/V$(TOP_TB)
	@echo "VCD dumped to tb_custom_alu_apb.vcd"

# ---- Synthesis with Yosys ----
synth:
	@echo "=== Running Yosys synthesis ==="
	mkdir -p synth/synth_out
	cd synth && $(YOSYS) synth_custom_alu.ys | tee synth_out/yosys.log

# ---- Place and Route with OpenROAD ----
pnr: synth
	@echo "=== Running OpenROAD PnR ==="
	cp synth/custom_alu.sdc synth/synth_out/custom_alu.sdc
	cd synth && $(OPENROAD) -exit openroad_flow.tcl | tee synth_out/openroad.log

clean:
	rm -rf build/ synth/synth_out/ *.vcd *.log obj_dir/
