## RV32I Core Repository

This repository contains two RV32I CPU implementations in Verilog:

- `5_stage/` - the main active design: a 5-stage pipelined core with CSR/interrupt support.
- `single_cycle/` - an earlier single-cycle implementation for baseline bring-up and reference.

The development focus is currently on making the `5_stage` design robust for **FreeRTOS bring-up**.

## Current Project Status

- **Primary target:** Stable FreeRTOS execution on the `5_stage` core.
- **Optimization status:** Pipeline/performance optimizations are **pending** and are intentionally secondary right now.
- **Validation approach:** RTL simulation + architectural compliance programs generated from RISC-V test ELFs.
- **Important testbench caveat:** `./run_all.sh` is currently not plug-and-play in this branch because the expected `tohost` / `tohost_valid` completion signaling path used by the arch test flow has been removed from the active integration. See "Arch test flow status" below.

## Repository Layout

- `5_stage/`
  - `srcs/core/` - datapath, control, ALU, register file, immediate generator.
  - `srcs/pipeline/` - IF/ID, ID/EX, EX/MEM, MEM/WB, forwarding, hazard logic.
  - `srcs/csr/` - machine-mode CSR file and exception/interrupt control.
  - `srcs/memory/` - instruction memory, data memory, system bus/MMIO.
  - `srcs/peripherals/` - timer, UART peripheral, UART DMA loader.
  - `srcs/top/top.v` - ZedBoard-oriented FPGA top-level integration.
  - `srcs/tb/tb_arch.v` - architecture-test simulation testbench.
  - `build.sh` - C + startup assembly -> `software/program.mem`.
  - `run_all.sh` - batch-run architectural `.mem` tests in simulation.
- `single_cycle/`
  - Legacy single-cycle RV32I flow and Vivado scripts.
- `riscv-arch-test/`
  - External architectural test source tree used to generate test ELFs.

## 5-Stage Core Capabilities

The `5_stage` core is a pipelined RV32I machine intended for software-oriented bring-up (interrupts, traps, runtime support), not just bare instruction execution.

### ISA and Control

- RV32I integer instruction execution (ALU, branch/jump, load/store, immediates).
- Pipeline hazard management via forwarding and hazard units.
- Trap-aware PC selection including normal flow, branch/jump, trap entry, and return.

### CSR / Trap / Interrupt Features

- Machine CSRs include:
  - `mstatus`, `mie`, `mtvec`, `mscratch`, `mepc`, `mcause`, `mip`
  - cycle/instret counters (`mcycle*`, `minstret*`, and aliases)
- Exception/trap handling path for software-visible machine mode behavior.
- Support for return-from-trap (`mret`) flow.

### Beginner-friendly datapath walkthrough

If you are new to CPU pipelines, this section explains the `5_stage/srcs/core/datapath.v` behavior in plain language.

The core uses the classic 5 stages:

1. **IF (Instruction Fetch)** - fetch instruction from IMEM using current PC.
2. **ID (Instruction Decode)** - decode opcode, read register file, generate immediate.
3. **EX (Execute)** - run ALU operation, resolve branch/jump, evaluate trap/interrupt redirects.
4. **MEM (Memory Access)** - perform load/store and MMIO access.
5. **WB (Write Back)** - write ALU/load/CSR result back into register file.

Pipeline helper logic:

- **Forwarding unit** reduces stalls by feeding recent results directly into EX operands.
- **Hazard unit** inserts stall/bubble when forwarding cannot safely solve dependency timing.
- **Pipeline flush** clears wrong-path instructions after control-flow redirects.

### Machine mode and CSR behavior (beginner view)

This core currently centers around **machine mode (M-mode)** control using `csr_file.v`.

Think of CSRs as "CPU control registers":

- `mstatus` - global interrupt enable bits and machine-state control.
- `mie` - enables specific interrupt classes (timer interrupt bit used here).
- `mip` - pending interrupt status (timer pending reflected here).
- `mtvec` - trap/interrupt entry address (where CPU jumps on trap).
- `mepc` - return address saved on trap entry.
- `mcause` - reason for trap/interrupt.
- counters (`mcycle`, `minstret`, etc.) - cycle and retired-instruction counters.

Trap/interrupt flow in simple terms:

1. CPU executes normally.
2. If trap/interrupt condition is taken, datapath selects `mtvec` as next PC.
3. CSR logic saves current PC to `mepc` and reason to `mcause`.
4. Interrupt-enable state in `mstatus` is updated (MIE/MPIE behavior).
5. On `mret`, CPU restores interrupt-enable state and jumps back to `mepc`.

Important priority idea (from datapath PC select logic):

- trap/interrupt redirect has highest priority,
- then `mret`,
- then `jalr`,
- then taken branch / `jal`,
- otherwise next sequential instruction.

This keeps control flow deterministic and easy to reason about.

### No branch prediction: what it means here

This design currently does **not** implement branch prediction.

Beginner explanation:

- The CPU does **not guess** whether a branch will be taken.
- Branch condition is resolved in EX stage.
- When branch/jump decision is made, pipeline flushes wrong-path work.

Practical effect:

- Control-flow instructions (taken branches/jumps/traps) cost extra cycles compared to an aggressively predicted design.
- Simpler logic and easier debug correctness now, at the cost of throughput.
- This is aligned with current priorities (functional stability + FreeRTOS bring-up before optimization).

### PC update flow (step-by-step)

The PC is updated by a mux in IF stage, driven by a select generated in EX stage.

Possible next-PC sources:

- `PC + 4` (default sequential flow)
- branch target (`ex_pc + imm`) for taken branch / `jal`
- `jalr` target (`{alu_out[31:1], 1'b0}`)
- `mtvec` on trap/interrupt entry
- `mepc` on `mret`
- fence-related redirect path used in this implementation

When a non-sequential source is selected, `pipeline_flush` is asserted so stale fetched/decode instructions are discarded.

In short: **PC redirection is explicit, prioritized, and correctness-first rather than prediction-first**.

### Memory System and MMIO

From `5_stage/srcs/memory/mmio.v` and `5_stage/include/params.vh`:

- Instruction memory region: `0x0000_0000` - `0x0000_FFFF`
- Data memory region: `0x0004_0000` - `0x0004_FFFF`
- MMIO:
  - LEDs: `0x8000_0000`
  - Switches: `0x8000_0004`
  - UART data: `0x8000_1000`
  - UART status: `0x8000_1004`
  - Timer block: `0x8000_2000` - `0x8000_200C`

### Peripheral Integration

- **Timer peripheral** with `mtime/mtimecmp` style registers and IRQ output.
- **UART peripheral** for memory-mapped access.
- **UART DMA loader path** to load instruction data while CPU is held/reset (controlled in top-level design).

## Where Test `.mem` Files Come From

The architectural test memory files under `5_stage/software/arch_tests_elfs/` are generated from **ELF binaries built from the `riscv-arch-tests` repository**.

In short:

1. RISC-V architectural tests are built to `.elf`.
2. ELF images are converted to Verilog-style hex/memory files.
3. Those `.mem` files are passed to simulation (`+HEX_FILE=...`) and loaded by `tb_arch.v`.

These `.mem` files are included mainly as:

- **Proof of prior compliance generation flow**
- **A reference dataset for others to verify their own builds**
- **A compatibility check target while rebuilding the test harness**

They should not be interpreted as a guaranteed turnkey regression suite for the current top-level wiring state.

## Arch test linker script details (why generation differs)

Custom arch-test core config path:

- `riscv-arch-test/config/cores/b3elz3bub/RV32I_core`

The linker script at `riscv-arch-test/config/cores/b3elz3bub/RV32I_core/link.ld` is tailored to this core memory map and testbench assumptions:

- `.text*` starts at `0x00000000` (IMEM region).
- `.data/.bss/.rodata` are moved to `0x00040000` (DMEM base for this design).
- `.tohost` is forced to `0x00070000` so pass/fail signaling is isolated from normal DMEM sections.

This differs from many default/reference arch-test layouts where data and `tohost` placement assumptions are tied to other memory maps or platforms.  
Associated macro definitions in `riscv-arch-test/config/cores/b3elz3bub/RV32I_core/rvmodel_macros.h` explicitly match this setup (`RVMODEL_TOHOST_ADDR 0x00070000` and HTIF-style halt writes).

## Usage Procedures

## 1) Run 5-stage architectural tests (simulation)

From repository root:

```bash
cd 5_stage
./run_all.sh
```

### Arch test flow status

`run_all.sh` compiles and runs the suite, but **pass/fail auto-detection depends on `tohost`/`tohost_valid` signals**.  
Because those completion test signals have been removed from the active top-level integration path, this script is currently a historical/diagnostic artifact rather than a guaranteed CI-grade regression command.

What this does:

- Compiles RTL with `iverilog` using `fileset.txt`.
- Runs each `.mem` in `software/arch_tests_elfs/` with `vvp`.
- Marks pass/fail based on `tb_arch.v` `tohost` completion status.

To make it fully operational again, re-introduce and plumb:

- `tohost` signal write monitor (memory-mapped or symbol-based observation path)
- `tohost_valid` pulse/flag generation
- testbench connection from DUT to pass/fail monitor logic

Manual single-test run (useful for debug):

```bash
cd 5_stage
iverilog -c fileset.txt -o sim.vvp
vvp sim.vvp +HEX_FILE="./software/arch_tests_elfs/<test_name>.mem"
```

## 2) Build a standalone software image (`program.mem`)

`5_stage/build.sh` compiles a C source together with startup assembly and emits `software/program.mem`.

```bash
cd 5_stage
./build.sh ./software/blinky.c
```

Toolchain expected by script:

- `riscv64-unknown-elf-gcc`
- `riscv64-unknown-elf-objcopy`
- `od`, `awk` (standard host tools)

## 3) Build FPGA bitstream (ZedBoard flow)

The top-level hardware integration is `5_stage/srcs/top/top.v`.  
Vivado TCL flow script: `5_stage/scripts/test.tcl`.

Typical batch invocation:

```bash
cd 5_stage
vivado -mode batch -source ./scripts/test.tcl
```

Output artifact:

- `5_stage/build_out/zedboard_riscv.bit`

## 4) UART/DMA program loading mode (hardware)

In `5_stage/srcs/top/top.v`, switch bit `sw[7]` is used as a mode select:

- DMA/load mode for UART-based instruction loading.
- CPU held/reset appropriately during loader activity.

This is useful for iterative bring-up without rebuilding memory images into bitstreams each cycle.

### Detailed DMA upload protocol (IMEM programming)

Implementation reference: `5_stage/srcs/peripherals/uart_dma.v`.

High-level behavior:

1. Set `sw[7] = 1` to enter DMA mode.
2. CPU is held in reset while DMA loader accepts UART RX bytes.
3. The first 4 received bytes are interpreted as a 32-bit **start IMEM address**.
4. Every next 4 bytes are interpreted as one 32-bit instruction/data word.
5. Each assembled word triggers one-cycle `imem_load` pulse.
6. Internal address auto-increments by `+4` after every committed word.
7. Set `sw[7] = 0` to exit DMA mode and restart normal CPU execution.

Framing and byte order details:

- Start address is captured once per DMA session (until mode is toggled off/on).
- DMA parser is byte-stream based; no explicit packet delimiter is used.
- Words are assembled in shift-register order as `{prev[23:0], rx_byte}`.
- Practically, transmit bytes in **MSB-first order per 32-bit word** (same for start address and payload words).

Minimal host-side transmit sequence:

1. Send 4 bytes: target start address (example `0x00000000`).
2. Send program body as 4-byte words, contiguous, MSB-first.
3. Keep UART stream continuous and clean (avoid extra bytes).
4. After all bytes are sent and committed, leave DMA mode to run.

Operational cautions:

- Any stray byte during DMA mode shifts framing and can corrupt all subsequent writes.
- If framing is lost, toggle DMA mode off then on to reset DMA parser state.
- Ensure the binary stream is word-aligned (multiple of 4 bytes after start address).
- Keep addresses inside valid IMEM range for your synthesis configuration.

## single_cycle (secondary/reference core)

`single_cycle/` is retained as a simpler core and flow reference.  
It is useful for quick checks, educational comparison, or validating assumptions against a less complex microarchitecture.

Basic usage:

```bash
cd single_cycle
./build.sh ./software/blinky.c
```

Vivado script to generate Bitstream exists at `5_stage/scripts/test.tcl`.

## Future Additions

Planned work (priority-ordered by project direction):

- Complete FreeRTOS boot/runtime stabilization on `5_stage`.
- Add and harden context-switch/interrupt stress testing.
- Improve performance via pending pipeline/timing optimizations.
- Improve automation for ELF -> `.mem` generation and test ingestion.
- Add clearer software examples and board-side bring-up guides.

## Notes

- This repository can contain generated files, logs, and test artifacts from active hardware development.
- If results differ across environments, re-check toolchain versions and simulation/Vivado versions first.