module alu(
    input [31:0] a, b,
    input [3:0] alu_ctrl,
    output reg [31:0] rslt,
    output zero_flag,
    output lt_u, // Fast Unsigned Less Than
    output lt_s  // Fast Signed Less Than
);

    // These evaluate instantly, bypassing the 'rslt' multiplexer and adder!
    assign zero_flag = (a == b); 
    assign lt_u      = (a < b);
    assign lt_s      = ($signed(a) < $signed(b));
    // ────────────────────────────────────────────────────────────────

    always @(*) begin
        case (alu_ctrl[3:1])
            3'b000: rslt = (alu_ctrl[0]) ? a - b : a + b;                        // (ADD,SUB)
            3'b001: rslt = a << b[4:0];                                          // SLL
            3'b010: rslt = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;            // SLT
            3'b011: rslt = (a < b) ? 32'b1 : 32'b0;                              // SLTU
            3'b100: rslt = a ^ b;                                                // XOR
            3'b101: begin
                if (alu_ctrl[0]) // Arithmetic Shift Right (SRA, SRAI)
                    rslt = $signed(a) >>> b[4:0];
                else             // Logical Shift Right (SRL, SRLI)
                    rslt = a >> b[4:0];
            end // (SRL,SRA)
            3'b110: rslt = a | b;                                                // OR
            3'b111: rslt = a & b;                                                // AND
        endcase
    end
endmodule
