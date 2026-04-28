#!/bin/bash

# Define directories based on your actual file structure
# (Adjust the path if you are running this from outside the riscv-arch-test folder)
SRC_DIR="/home/beelzebub/Documents/workspaces/RV32I_core/riscv-arch-test/work/RV32I_core/elfs/rv32i/I"
DEST_DIR="/home/beelzebub/Documents/workspaces/RV32I_core/5_stage/software/arch_tests_elfs"

# Ensure the destination directory exists
mkdir -p "$DEST_DIR"

echo "Extracting hex files from $SRC_DIR..."

# Loop through every .elf file in the source directory
for elf_file in "$SRC_DIR"/*.elf; do
    # Strip the path and the .elf extension to get just the base name
    base_name=$(basename "$elf_file" .elf)
    
    # Define the output hex file path
    hex_file="$DEST_DIR/${base_name}.hex"
    
    # Run objcopy to convert and output directly to the destination
    riscv-none-elf-objcopy -O verilog "$elf_file" "$hex_file"
    
    echo " -> Created ${base_name}.hex"
done

echo "Done! All hex files moved to $DEST_DIR."