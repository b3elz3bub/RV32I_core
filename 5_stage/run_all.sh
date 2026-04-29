#!/bin/bash

echo "Compiling Verilog RTL..."
# Assuming you run this script from the folder containing fileset.txt
iverilog -c fileset.txt -o sim.vvp

if [ $? -ne 0 ]; then
    echo "Compilation failed! Fix your Verilog errors."
    exit 1
fi

PASSED=0
FAILED=0

# Use the absolute path here. This makes the script bulletproof.
SOFTWARE_DIR="./software/arch_tests_elfs"

echo "------------------------------------------------"
echo " Running RISC-V RV32I Compliance Suite"
echo "------------------------------------------------"

# Loop through every mem file in the absolute directory
for mem_file in "$SOFTWARE_DIR"/*.mem; do
    
    test_name=$(basename "$mem_file" .mem)
    
    # mem_file now contains the FULL absolute path.
    # Verilog's $readmemh will never fail to find it.
    output=$(vvp sim.vvp +HEX_FILE="$mem_file")
    
    if echo "$output" | grep -q "SUCCESS"; then
        echo -e "[\033[32mPASS\033[0m] $test_name"
        ((PASSED++))
    else
        echo -e "[\033[31mFAIL\033[0m] $test_name"
        ((FAILED++))
    fi
done

echo "------------------------------------------------"
echo " SUMMARY: $PASSED Passed, $FAILED Failed"
echo "------------------------------------------------"