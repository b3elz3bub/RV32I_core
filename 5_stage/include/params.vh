`ifndef PARAMS_VH
`define PARAMS_VH

`define RESET_VECTOR 32'b0
`define RV32_NOP 32'h00000013

// PC source select (expanded for trap/mret)
`define PC_SEL_PLUS4    3'b000
`define PC_SEL_BRANCH   3'b001
`define PC_SEL_JALR     3'b010
`define PC_SEL_MTVEC    3'b011   // trap/interrupt entry
`define PC_SEL_MEPC     3'b100   // mret return

// Memory map — Peripherals at 0x8000_xxxx
`define ADDR_LED        32'h80000000
`define ADDR_SW         32'h80000004
`define ADDR_UART_DATA  32'h80001000
`define ADDR_UART_STAT  32'h80001004
`define ADDR_TIMER_BASE 32'h80002000  // mtime_lo/hi, mtimecmp_lo/hi

// CSR addresses
`define CSR_MSTATUS  12'h300
`define CSR_MIE      12'h304
`define CSR_MTVEC    12'h305
`define CSR_MSCRATCH 12'h340
`define CSR_MEPC     12'h341
`define CSR_MCAUSE   12'h342
`define CSR_MIP      12'h344

// Performance counters (M-mode + User-mode aliases)
`define CSR_MCYCLE    12'hB00
`define CSR_MCYCLEH   12'hB80
`define CSR_MINSTRET  12'hB02
`define CSR_MINSTRETH 12'hB82
`define CSR_CYCLE     12'hC00
`define CSR_CYCLEH    12'hC80
`define CSR_INSTRET   12'hC02
`define CSR_INSTRETH  12'hC82

`endif
