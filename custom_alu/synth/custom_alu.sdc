# =============================================================================
# Synopsys Design Constraints (SDC) for custom_alu_apb_wrapper
# File: synth/custom_alu.sdc
# =============================================================================

# 100 MHz clock (10 ns period)
create_clock -name clk -period 10.0 [get_ports clk_i]

# Input/output delays (assume 40% of clock period)
set_input_delay  -clock clk  4.0 [all_inputs]
set_output_delay -clock clk  4.0 [all_outputs]

# False paths for reset (asynchronous)
set_false_path -from [get_ports rst_ni]

# Driving cell and load (Nangate45 example)
# set_driving_cell -lib_cell BUF_X2 [all_inputs]
# set_load 0.01 [all_outputs]

# Max transition / fanout
set_max_fanout 20 [current_design]
