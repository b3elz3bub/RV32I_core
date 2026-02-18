module immgen(
    input [31:0] inst,
    input [2:0] imm_sel,
    output reg [31:0] imm
);
    always @(*) begin
        case (imm_sel)
            3'b000: imm = { {20{inst[31]}}, inst[31:20] };                            // I-type
            3'b001: imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };                // S-type
            3'b010: imm = { {20{inst[31]}},inst[7], inst[30:25], inst[11:8], 1'b0 };  // B-type
            3'b011: imm = { {12{inst[31]}}, inst[19:12],inst[20],inst[30:21],1'b0 };  // J-type
            3'b100: imm = { {12{inst[31]}}, inst[31:12] };                            // U-type
            default: imm = 32'b0;
        endcase
    end
endmodule