# Read your files
read_verilog ./rtl/regfile.v

# Elaborate the design (this builds the RTL schematic in memory)
synth_design -top regfile -rtl

# Open the GUI only to show the schematic you just built
start_gui
show_schematic [get_cells]