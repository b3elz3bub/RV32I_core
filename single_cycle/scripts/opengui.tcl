# --- 1. Load Sources and Headers ---
read_verilog [glob ./srcs/*/*.v]

# --- 2. Load the Pre-compiled Clock IP ---
# This saves time by using the IP generated during your build script
read_ip ./build_out/ip/clk_wiz_0/clk_wiz_0.xci

# --- 5. Launch the Graphical Interface ---
start_gui

synth_design -rtl -top top