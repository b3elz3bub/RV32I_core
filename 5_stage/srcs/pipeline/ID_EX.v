`include "params.vh"
module ID_EX(
    input clk,
    input rst,
    input flush,
    input stall,

    input [31:0] id_a, id_b, id_imm,
    input [31:0] id_pc, id_pc_plus_4,

    output reg [31:0] ex_a, ex_b, ex_imm,
    output reg [31:0] ex_pc, ex_pc_plus_4
);
   always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_a         <= 32'b0;
            ex_b         <= 32'b0;
            ex_imm       <= 32'b0;
            ex_pc        <= 32'b0;
            ex_pc_plus_4 <= 32'b0;
        end 
        else if (flush) begin
            ex_a         <= 32'b0;
            ex_b         <= 32'b0;
            ex_imm       <= 32'b0;
            ex_pc        <= 32'b0;
            ex_pc_plus_4 <= 32'b0;
        end 
        else if (!stall) begin
            ex_a         <= id_a;
            ex_b         <= id_b;
            ex_imm       <= id_imm;
            ex_pc        <= id_pc;
            ex_pc_plus_4 <= id_pc_plus_4;
        end
    end
endmodule