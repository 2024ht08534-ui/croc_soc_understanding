##############################################################################
# OpenROAD Flow Script for custom_alu
# File: synth/openroad_flow.tcl
# Usage: openroad -exit openroad_flow.tcl
# Assumes: Nangate45 or sky130 PDK is available
##############################################################################

# ---- User Configuration (edit these paths) ----
set DESIGN_NAME    "custom_alu_apb_wrapper"
set NETLIST        "./synth_out/custom_alu_netlist.v"
set SDC_FILE       "./synth_out/custom_alu.sdc"

# Nangate45 example paths - update to match your PDK installation
set LIB_FILE       "/path/to/nangate45/NangateOpenCellLibrary_typical.lib"
set LEF_FILE       "/path/to/nangate45/NangateOpenCellLibrary.macro.lef"
set TECH_LEF       "/path/to/nangate45/NangateOpenCellLibrary.tech.lef"

# Floorplan parameters
set CORE_UTIL      0.40    ;# 40% utilization target
set ASPECT_RATIO   1.0     ;# Square floorplan

##############################################################################
# Step 1: Read libraries and design
##############################################################################
read_lef  $TECH_LEF
read_lef  $LEF_FILE
read_lib  $LIB_FILE
read_verilog $NETLIST
link_design $DESIGN_NAME
read_sdc    $SDC_FILE

##############################################################################
# Step 2: Floorplanning
##############################################################################
initialize_floorplan \
    -utilization $CORE_UTIL \
    -aspect_ratio $ASPECT_RATIO \
    -core_space 2.0

# Add power/ground rings
add_global_connection -net VDD -pin_pattern "VDD" -power
add_global_connection -net VSS -pin_pattern "VSS" -ground

# Insert I/O pins
place_pins -random -hor_layers metal3 -ver_layers metal4

##############################################################################
# Step 3: Power Distribution Network (PDN)
##############################################################################
pdngen

##############################################################################
# Step 4: Global Placement
##############################################################################
global_placement -skip_initial_place

estimate_parasitics -placement
report_checks -path_delay min_max -fields {slew cap input_pins nets}

##############################################################################
# Step 5: Detailed Placement
##############################################################################
detailed_placement
optimize_mirroring

check_placement -verbose

##############################################################################
# Step 6: CTS (Clock Tree Synthesis)
##############################################################################
clock_tree_synthesis \
    -root_buf BUF_X4 \
    -buf_list {BUF_X2 BUF_X4 BUF_X8}

repair_clock_inverters

##############################################################################
# Step 7: Global Routing
##############################################################################
estimate_parasitics -placement
repair_timing -skip_pin_swap

set_propagated_clock [all_clocks]
global_route \
    -guide_file ./synth_out/route_guide.txt \
    -congestion_iterations 30

##############################################################################
# Step 8: Detailed Routing
##############################################################################
detailed_route \
    -output_drc ./synth_out/drc.rpt \
    -output_maze ./synth_out/maze.rpt \
    -verbose 1

##############################################################################
# Step 9: Finishing & Reports
##############################################################################
write_def ./synth_out/${DESIGN_NAME}_final.def
write_gds ./synth_out/${DESIGN_NAME}_final.gds
write_verilog ./synth_out/${DESIGN_NAME}_final_netlist.v

report_checks -path_delay min_max -format full_clock_expanded
report_tns
report_wns
report_design_area
report_power

puts "\nOpenROAD flow complete!"
puts "Outputs in ./synth_out/"
