// --- Opcodes ---
`define OP_LUI    7'b0110111
`define OP_AUIPC  7'b0010111
`define OP_JAL    7'b1101111
`define OP_JALR   7'b1100111
`define OP_BRANCH 7'b1100011
`define OP_LOAD   7'b0000011
`define OP_STORE  7'b0100011
`define OP_ARITH  7'b0110011 // R-type
`define OP_IMM    7'b0010011 // I-type Arithmetic

// --- ALU Control (alu_ctrl[3:1]) ---
`define ALU_ADD   3'b000
`define ALU_SLL   3'b001
`define ALU_SLT   3'b010
`define ALU_SLTU  3'b011
`define ALU_XOR   3'b100
`define ALU_SR    3'b101
`define ALU_OR    3'b110
`define ALU_AND   3'b111

// --- Memory Mapping ---
`define LED_ADDR  32'h0000_1000
`define SW_ADDR   32'h0000_1004