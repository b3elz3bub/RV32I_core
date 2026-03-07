module alu(
    input [31:0] a,b,
    input [3:0] alu_ctrl,
    // top 3 bits funct3, lsb from funct7[5] for (srl,sra) and (add,sub)
    output reg [31:0] rslt,
    output zero_flag,
    output lt_u  // 1 when a < b (unsigned), valid when alu_ctrl is SUB (for BLTU/BGEU)
);
    wire do_sub = (alu_ctrl[3:1] == 3'b000 && alu_ctrl[0] == 1'b1);
    wire [32:0] sub_sum = {1'b0, a} + {1'b0, ~b} + 33'd1;

    assign zero_flag = (rslt == 32'b0);
    assign lt_u = do_sub ? ~sub_sum[32] : 1'b0;  // borrow when a < b unsigned

    always @(*) begin
        case (alu_ctrl[3:1])
            3'b000: rslt = (alu_ctrl[0])? a - b : a + b;                             //(ADD,SUB)
            3'b001: rslt = a << b[4:0];                                              // SLL
            3'b010: rslt = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;                // SLT
            3'b011: rslt = (a < b) ? 32'b1 : 32'b0;                                  // SLTU
            3'b100: rslt = a ^ b;                                                    // XOR
            3'b101: rslt = (alu_ctrl[0] == 1) ? $signed(a) >>> b[4:0] : a >> b[4:0]; //(SRL,SRA)
            3'b110: rslt = a | b;                                                    // OR
            3'b111: rslt = a & b;                                                    // AND
        endcase
    end
endmodule