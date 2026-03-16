#!/bin/bash
# RISC-V build script: .c + start.s -> program.mem

set -e

# ── Config ────────────────────────────────────────────────
ASM="./software/start.s"
OUT_DIR="./software"
TMPDIR="$(mktemp -d /tmp/riscv_build_XXXXXX)"
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
ELF="$TMPDIR/${BASENAME}.elf"
BIN="$TMPDIR/${BASENAME}.bin"
MEM="$OUT_DIR/program.mem"

echo "[ 1/4 ] Compiling:  $C_FILE + $ASM"
riscv64-unknown-elf-gcc \
    -march=rv32i -mabi=ilp32 \
    -static -nostdlib \
    -Ttext 0x0 \
    "$ASM" "$C_FILE" \
    -o "$ELF"

echo "[ 2/4 ] Objcopy:    $ELF -> $BIN"
riscv64-unknown-elf-objcopy -O binary "$ELF" "$BIN"

echo "[ 3/4 ] Generating: $MEM"
od -v -t x4 "$BIN" | awk '{for(i=2;i<=NF;i++) print $i}' > "$MEM"

echo "[ 4/4 ] Cleaning up tmp: $TMPDIR"
rm -rf "$TMPDIR"

echo ""
echo "Done! Output: $MEM"