# --- 1. Load Sources and Headers ---
read_verilog [glob ./srcs/**/*.v]

# --- 2. Load the Pre-compiled Clock IP ---
# This saves time by using the IP generated during your build script
read_ip ./build_out/ip/clk_wiz_0/clk_wiz_0.xci

# --- 3. Load Constraints ---
read_xdc ./constraints/zedboard.xdc

# --- 4. Synthesize the Design ---
# We must synthesize to generate the schematic and timing paths
synth_design -top top -part xc7z020clg484-1

# --- 5. Launch the Graphical Interface ---
start_gui

# --- 6. Generate the Timing Report ---
# This automatically runs the timing analysis and opens the window for your screenshot
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -name timing_1