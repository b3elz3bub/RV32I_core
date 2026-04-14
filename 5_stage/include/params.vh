`ifndef PARAMS_VH
`define PARAMS_VH

`define RESET_VECTOR 32'b0;
`define RV32_NOP 32'h13

`define PC_SEL_PLUS4    2'b00
`define PC_SEL_BRANCH   2'b01
`define PC_SEL_JALR     2'b10

`endif