# --- Build Script for RISC-V Core ---

# 1. Setup Project in Memory
create_project -in_memory -part xc7z020clg484-1

# 2. Include all Sources
# Assuming your directory structure: /src/core, /src/memory, /src/top
add_files [glob ./src/core/*.v]
add_files [glob ./src/memory/*.v]
add_files [glob ./src/top/*.v]
add_files ./include/defines.vh
add_files -fileset constrs_1 ./constraints/zedboard.xdc

# Set Global Include for the header
set_property is_global_include true [get_files ./include/defines.vh]

# 3. Run "Linter" (Synthesis Check)
# This will catch syntax errors, multi-driven nets, and port mismatches
synth_design -top top -part xc7z020clg484-1 -lint

# 4. Full Synthesis and Implementation
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check for Synthesis Errors
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed! Check the log."
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# 5. Report Timing and Utilization
open_run impl_1
report_timing_summary -file timing_summary.txt
report_utilization -file utilization_report.txt

puts "Build Complete. Bitstream generated in the .runs directory."