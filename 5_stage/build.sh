#!/bin/bash
# RISC-V build script for Windows/Git Bash: .c + start.s -> program.mem

set -e

# ── Config ────────────────────────────────────────────────
ASM="./software/start.s"
OUT_DIR="./software"
# ──────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 <path/to/program.c>"
    echo "Output: ./software/program.mem"
    exit 1
}

[ $# -lt 1 ] && usage
C_FILE="$1"

[ ! -f "$C_FILE" ]  && { echo "Error: C file '$C_FILE' not found."; exit 1; }
[ ! -f "$ASM" ]     && { echo "Error: Assembly file '$ASM' not found."; exit 1; }

BASENAME=$(basename "$C_FILE" .c)
ELF="${BASENAME}_temp.elf"
BIN="${BASENAME}_temp.bin"
MEM="$OUT_DIR/program.mem"

echo "[ 1/4 ] Compiling:  $C_FILE + $ASM"
# Updated to xPack compiler name: riscv-none-elf-gcc
# Updated Compilation Line inside your script
riscv-none-elf-gcc \
    -march=rv32i -mabi=ilp32 \
    -static -nostdlib \
    -O2 \
    -Ttext 0x0 \
    "$ASM" "$C_FILE" \
    -o "$ELF"

echo "[ 2/4 ] Objcopy:    $ELF -> $BIN"
# Updated to xPack objcopy
riscv-none-elf-objcopy -O binary "$ELF" "$BIN"

echo "[ 3/4 ] Generating: $MEM"
# od and awk extract the raw 32-bit hex values for Vivado
od -v -t x4 "$BIN" | awk '{for(i=2;i<=NF;i++) print $i}' > "$MEM"

echo "[ 4/4 ] Cleaning up temporary files..."
rm -f "$ELF" "$BIN"

echo ""
echo "Done! Output: $MEM"
