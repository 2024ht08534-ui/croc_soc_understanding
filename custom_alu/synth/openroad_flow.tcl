##############################################################################
# OpenROAD Flow Script for custom_alu
# File: synth/openroad_flow.tcl
# PDK: IHP SG13G2 130nm
# Usage: openroad -exit openroad_flow.tcl
##############################################################################

# ---- PDK Paths ----
set PDK_ROOT   "/home/gokul/croc/ihp13/pdk/ihp-sg13g2"
set LIB_FILE   "$PDK_ROOT/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"
set TECH_LEF   "$PDK_ROOT/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef"
set CELL_LEF   "$PDK_ROOT/libs.ref/sg13g2_stdcell/lef/sg13g2_stdcell.lef"

# ---- Design ----
set DESIGN_NAME  "custom_alu_apb_wrapper"
set NETLIST      "./synth_out/custom_alu_netlist.v"
set SDC_FILE     "./synth_out/custom_alu.sdc"

# ---- Floorplan ----
set CORE_UTIL    0.25
set ASPECT_RATIO 1.0

##############################################################################
# Step 1: Read libraries and design
##############################################################################
puts "=== Step 1: Reading libraries ==="
read_lef  $TECH_LEF
read_lef  $CELL_LEF
read_lib  $LIB_FILE
read_verilog $NETLIST
link_design $DESIGN_NAME
read_sdc    $SDC_FILE

##############################################################################
# Step 2: Floorplanning
##############################################################################
puts "=== Step 2: Floorplan ==="
initialize_floorplan \
    -utilization $CORE_UTIL \
    -aspect_ratio $ASPECT_RATIO \
    -core_space 2.0 \
    -site CoreSite

make_tracks

add_global_connection -net VDD -pin_pattern "VDD" -power
add_global_connection -net VSS -pin_pattern "VSS" -ground
global_connect

place_pins -random \
    -hor_layers Metal3 \
    -ver_layers Metal2

##############################################################################
# Step 3: Power Distribution Network (PDN)
##############################################################################
puts "=== Step 3: PDN ==="
pdngen

##############################################################################
# Step 4: Global Placement
##############################################################################
puts "=== Step 4: Global Placement ==="
global_placement -skip_initial_place
estimate_parasitics -placement

##############################################################################
# Step 5: Detailed Placement
##############################################################################
puts "=== Step 5: Detailed Placement ==="
detailed_placement
optimize_mirroring
check_placement -verbose

##############################################################################
# Step 6: CTS
##############################################################################
puts "=== Step 6: CTS ==="
clock_tree_synthesis \
    -root_buf sg13g2_buf_8 \
    -buf_list {sg13g2_buf_16 sg13g2_buf_8 sg13g2_buf_4 sg13g2_buf_2}

set_propagated_clock [all_clocks]

# Re-legalize after CTS buffer insertion
detailed_placement
optimize_mirroring

##############################################################################
# Step 7: Global Routing
##############################################################################
puts "=== Step 7: Global Routing ==="
set_wire_rc -clock -layer Metal3
set_wire_rc -signal -layer Metal3
estimate_parasitics -placement

global_route \
    -congestion_iterations 30 \
    -verbose



##############################################################################
# Step 8: Detailed Routing
##############################################################################
puts "=== Step 8: Detailed Routing ==="

# Fix tie nets misclassified as power/ground nets by ABC
set db [ord::get_db]
set block [[$db getChip] getBlock]
foreach net_name {"one_" "zero_"} {
    set net [$block findNet $net_name]
    if {$net != ""} {
        puts "Fixing signal type for net: $net_name"
        $net setSigType SIGNAL
    }
}

detailed_route \
    -output_drc  ./synth_out/drc.rpt \
    -verbose 1

##############################################################################
# Step 9: Reports and Outputs
##############################################################################
puts "=== Step 9: Reports ==="
report_checks -path_delay min_max -format full_clock_expanded
report_tns
report_wns
report_design_area
report_power

write_def     ./synth_out/${DESIGN_NAME}_final.def
write_verilog ./synth_out/${DESIGN_NAME}_final_netlist.v

puts "\n=== OpenROAD flow complete ==="
puts "Outputs in ./synth_out/"
