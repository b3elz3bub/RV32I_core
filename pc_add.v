module pc_add (
    input  [31:0] pc,
    input  [31:0] bit_extended_imm,
    output [31:0] branch_target
);
    assign branch_target = pc + bit_extended_imm;
endmodule