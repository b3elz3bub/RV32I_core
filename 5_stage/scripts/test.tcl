# --- Configuration & Cleanup ---
set output_dir "./build_out"
file delete -force $output_dir
file mkdir $output_dir
file mkdir $output_dir/ip ;# FIX: Explicitly create the IP directory first

# Set the target FPGA part for the ZedBoard
set_part xc7z020clg484-1

# --- 1. Read Design Sources ---
read_verilog ./include/params.vh
set_property is_global_include true [get_files ./include/params.vh]

read_verilog [glob ./srcs/core/*.v]
read_verilog [glob ./srcs/pipeline/*.v]  
read_verilog [glob ./srcs/memory/*.v]
read_verilog [glob ./srcs/top/*.v]

read_verilog [glob ./srcs/core/*.v]
read_verilog [glob ./srcs/memory/*.v]
read_verilog [glob ./srcs/top/*.v]

# --- 2. Read Constraints ---
read_xdc ./constraints/zedboard.xdc

# --- 3. In-Memory IP Generation ---
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $output_dir/ip

# Explicitly define the 100MHz input and 300MHz output
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {100.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {300.000} \
] [get_ips clk_wiz_0]

# Synthesize the IP Out-Of-Context
generate_target {synthesis} [get_ips clk_wiz_0]
synth_ip [get_ips clk_wiz_0]

# --- 4. Top-Level Synthesis ---
synth_design -top top -part xc7z020clg484-1

# --- 5. Implementation & Bitstream ---
opt_design
place_design
route_design
write_bitstream -force $output_dir/zedboard_riscv.bit

puts "Build complete. Bitstream is located at: $output_dir/zedboard_riscv.bit"
