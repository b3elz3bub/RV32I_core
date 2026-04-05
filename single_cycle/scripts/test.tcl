# --- Configuration & Cleanup ---
set output_dir "./build_out"
file delete -force $output_dir
file mkdir $output_dir
file mkdir $output_dir/ip ;# FIX: Explicitly create the IP directory first

# Set the target FPGA part for the ZedBoard
set_part xc7z020clg484-1

read_verilog [glob ./srcs/core/*.v]
read_verilog [glob ./srcs/memory/*.v]
read_verilog [glob ./srcs/top/*.v]

# --- 2. Read Constraints ---
read_xdc ./constraints/zedboard.xdc

# --- 3. In-Memory IP Generation ---
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0 -dir $output_dir/ip
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {290.478} \
  CONFIG.CLKOUT1_PHASE_ERROR {133.882} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {15.625} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {78.125} \
  CONFIG.MMCM_DIVCLK_DIVIDE {2} \
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