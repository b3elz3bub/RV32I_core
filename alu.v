module alu(
    input [31:0] a,b,
    input [3:0] alu_ctrl, 
    //top 3 bits funct 3 and lsb that is in funct 7[5] for (srl,sra) and (add,sub)
    output reg [31:0] rslt,
    output zero_flag
);  

    assign zero_flag = (rslt == 32'b0);

    always @(*) begin
        case (alu_ctrl[3:1])
            3'b000: rslt = (alu_ctrl[0] == 1) ? a - b : a + b;                      //(ADD,SUB)
            3'b001: rslt = a << b[4:0];                                             // SLL
            3'b010: rslt = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;               // SLT
            3'b011: rslt = (a < b) ? 32'b1 : 32'b0;                                 // SLTU
            3'b100: rslt = a ^ b;                                                   // XOR
            3'b101: rslt = (alu_ctrl[0] == 1) ? $signed(a) >>> b[4:0] : a >> b[4:0];//(SRL,SRA)
            3'b110: rslt = a | b;                                                   // OR
            3'b111: rslt = a & b;                                                   // AND
        endcase
    end
endmodule;