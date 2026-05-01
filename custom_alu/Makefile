VERILATOR  ?= verilator
YOSYS      ?= yosys
OPENROAD   ?= openroad

RTL_FILES  = rtl/custom_alu.sv rtl/custom_alu_apb_wrapper.sv
TB_FILE    = rtl/tb/tb_custom_alu_apb.sv
TOP_TB     = tb_custom_alu_apb
LIB_FILE   = /home/gokul/croc/ihp13/pdk/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

.PHONY: all compile sim synth pnr clean

all: sim

compile:
	@echo "=== Compiling with Verilator ==="
	mkdir -p build
	$(VERILATOR) --lint-only --sv --top-module custom_alu_apb_wrapper $(RTL_FILES)
	@echo "Lint OK"

sim:
	@echo "=== Running simulation ==="
	mkdir -p build/sim
	$(VERILATOR) --binary --sv --trace -Wno-WIDTHEXPAND --Mdir build/sim --top-module $(TOP_TB) $(RTL_FILES) $(TB_FILE) -CFLAGS "-std=c++17"
	@echo "=== Executing testbench ==="
	./build/sim/V$(TOP_TB)

synth:
	@echo "=== Running Yosys synthesis ==="
	mkdir -p synth/synth_out
	cd synth && $(YOSYS) synth_custom_alu.ys | tee synth_out/yosys.log

pnr: synth
	@echo "=== Running OpenROAD Place and Route ==="
	mkdir -p synth/synth_out
	cp synth/custom_alu.sdc synth/synth_out/custom_alu.sdc
	cd synth && $(OPENROAD) -exit openroad_flow.tcl | tee synth_out/openroad.log
	@echo "=== PnR complete. Outputs in synth/synth_out/ ==="

clean:
	rm -rf build/ synth/synth_out/ *.vcd *.log obj_dir/
