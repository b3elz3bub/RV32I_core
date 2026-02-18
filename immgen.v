module immgen(
    input [31:0] inst,
    output reg [31:0] imm
);
    always @(*) begin
        case (inst[6:2])
            5'b00000, 5'b00011, 5'b00100, 5'b11001, 5'b11100 : 
                imm = { {20{inst[31]}}, inst[31:20] };                             // I-type
            5'b01000: 
                imm = { {20{inst[31]}}, inst[31:25], inst[11:7] };                 // S-type
            5'b11000: 
                imm = { {20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0 };  // B-type
            5'b11011:
                imm = { {12{inst[31]}}, inst[19:12], inst[20], inst[30:21],1'b0 }; // J-type
            5'b00101, 5'b01101:
                imm = { inst[31:12], 12{1'b0} };                                   // U-type
            default: imm = 32'bx;
        endcase
    end
endmodule