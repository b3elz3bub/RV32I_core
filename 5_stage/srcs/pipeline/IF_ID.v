`include "params.vh"
module IF_ID (
    input wire        clk,
    input wire        rst,
    input wire        flush,
    input wire        stall,
    input wire [31:0] if_inst,
    input wire [31:0] if_pc,
    input wire [31:0] if_pc_plus_4,
    
    output reg [31:0] id_inst,
    output reg [31:0] id_pc,
    output reg [31:0] id_pc_plus_4
);

    always @(posedge clk) begin
        if (rst) begin
            id_inst      <= `RV32_NOP;
            id_pc        <= 32'b0;
            id_pc_plus_4 <= 32'b0;
        end 
        else if (flush) begin
            id_inst      <= `RV32_NOP;
            id_pc        <= 32'b0;
            id_pc_plus_4 <= 32'b0;
        end 
        else if (!stall) begin
            id_inst      <= if_inst;
            id_pc        <= if_pc;
            id_pc_plus_4 <= if_pc_plus_4;
        end
    end

endmodule
