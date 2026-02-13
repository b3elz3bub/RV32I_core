# === User parameters ===
# Change these to match your setup
set part_name  "xc7a35tcpg236-1"  ;# <-- replace with your FPGA part
set top_name   "regfile"          ;# <-- replace if your top module name is different
set src_file   "regfile.v"        ;# <-- path to your regfile source

# === Script ===
# Create a fresh in-memory project
create_project -in_memory -part $part_name tmp_proj
read_verilog -v $src_file
synth_design -top $top_name -rtl -name rtl_1

# Start GUI and open elaborated design
start_gui
open_elaborated_design

