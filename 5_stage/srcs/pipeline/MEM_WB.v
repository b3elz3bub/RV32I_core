`include "params.vh"
module MEM_WB(
    input clk,
    input rst,

    // ── Data ──
    input [31:0] mem_alu_out,
    input [31:0] mem_mem_data,       // processed load data (after loadext)
    input [31:0] mem_pc_plus_4,
    input [31:0] mem_imm,
    input [4:0]  mem_rd,

    output reg [31:0] wb_alu_out,
    output reg [31:0] wb_mem_data,
    output reg [31:0] wb_pc_plus_4,
    output reg [31:0] wb_imm,
    output reg [4:0]  wb_rd,

    // ── Control: used in WB ──
    input        mem_regwrite_en,
    input [1:0]  mem_regwrite_ctrl,

    output reg        wb_regwrite_en,
    output reg [1:0]  wb_regwrite_ctrl
);
    always @(posedge clk) begin
        if (rst) begin
            // Data
            wb_alu_out       <= 32'b0;
            wb_mem_data      <= 32'b0;
            wb_pc_plus_4     <= 32'b0;
            wb_imm           <= 32'b0;
            wb_rd            <= 5'b0;
            // Control
            wb_regwrite_en   <= 1'b0;
            wb_regwrite_ctrl <= 2'b0;
        end
        else begin
            // Data
            wb_alu_out       <= mem_alu_out;
            wb_mem_data      <= mem_mem_data;
            wb_pc_plus_4     <= mem_pc_plus_4;
            wb_imm           <= mem_imm;
            wb_rd            <= mem_rd;
            // Control
            wb_regwrite_en   <= mem_regwrite_en;
            wb_regwrite_ctrl <= mem_regwrite_ctrl;
        end
    end
endmodule
