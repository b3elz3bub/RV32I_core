## RV32I_core

A Verilog RV32I CPU core

1. `single_cycle/` - synthesizable single-cycle design intended to be built for the ZedBoard (Vivado flow).

---

## Top module (single_cycle)

The FPGA top module is:

- `single_cycle/srcs/top/singlecycle_top.v` (module name: `top`)

Key blocks:

- `single_cycle/srcs/core/`: `control.v`, `datapath.v`, `alu.v`, `regfile.v`, `immgen.v`, `pc.v`
- `single_cycle/srcs/memory/`: `imem.v`, `dmem.v`, `mmio.v`

---

## Memory map (single_cycle)

From `single_cycle/srcs/memory/mmio.v` and `dmem.v`:

- RAM: `addr < 0x0000_1000` (word-addressed internally via `addr[11:2]`)
- LEDs: `addr == 0x0000_1000` (writes update `leds`, reads return LED state)
- Switches: `addr == 0x0000_2000` (reads return `switches`)

---

## RV32I coverage (high level)

Implemented (in the core/control logic):

- Integer ALU: `ADD/SUB`, `SLL`, `SLT/SLTU`, `XOR`, `SRL/SRA`, `OR`, `AND`
- Immediate ALU: `ADDI`, `SLTI/SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI/SRAI`
- Loads: `LB`, `LH`, `LW`, `LBU`, `LHU`
- Stores: `SB`, `SH`, `SW`
- Branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- Jumps: `JAL`, `JALR`
- `LUI`, `AUIPC`

Not fully implemented / explicitly excluded during bringing-up:

- CSR instructions (e.g. CSRRW/CSRRS/CSRRC)
- `fence`
- `ecall` / `ebreak` handling may exist as `trap_en` in `single_cycle`, but wiring/behavior depends on the rest of the design.

Note on stores:

- `SB` is handled via byte lanes selected by `addr[1:0]`.
- `SH` is implemented with the assumption that the address is halfword-aligned (the code comments indicate `addr[0]` is assumed 0). The memory system is byte-lane based but uses a single-word write interface.

---

## Build flow for FPGA (single_cycle)

### 1) Build `program.mem`

`single_cycle/build.sh` compiles a C program for RV32I, then converts the `.bin` into `software/program.mem` which `imem.v` preloads.

Example:

```bash
cd ./RV32I_core/single_cycle
./build.sh ./software/blinky.c
```

### 2) Build Vivado project/bitstream

The Vivado TCL script is:

- `single_cycle/scripts/test.tcl`

It runs:

- Verilog source import
- Clock wizard IP generation (or reuse, depending on the script)
- Synthesis, implementation, and writes `build_out/zedboard_riscv.bit`

Typical usage is to run the script inside Vivado (batch mode is also possible if you configure Vivado properly).
Ensure that you change directory to ./single_cycle before running the TCL scripts.

---

## Current WIP:
- UART bootloader
- 5 stage pipelined design
- CSR and TRAP related stuff