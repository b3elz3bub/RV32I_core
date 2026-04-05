`include "params.vh"
module EX_MEM(
    input clk,
    input rst,
    input flush,

    // ── Data ──
    input [31:0] ex_alu_out,
    input [31:0] ex_rs2_data,       // raw store data (shifted in MEM)
    input [31:0] ex_pc_plus_4,
    input [31:0] ex_imm,
    input [4:0]  ex_rd,

    output reg [31:0] mem_alu_out,
    output reg [31:0] mem_rs2_data,
    output reg [31:0] mem_pc_plus_4,
    output reg [31:0] mem_imm,
    output reg [4:0]  mem_rd,

    // ── Control: used in MEM ──
    input        ex_memwrite_en,
    input [3:0]  ex_memstore_ctrl,
    input [2:0]  ex_memload_ctrl,

    output reg        mem_memwrite_en,
    output reg [3:0]  mem_memstore_ctrl,
    output reg [2:0]  mem_memload_ctrl,

    // ── Control: pass through to WB ──
    input        ex_regwrite_en,
    input [1:0]  ex_regwrite_ctrl,

    output reg        mem_regwrite_en,
    output reg [1:0]  mem_regwrite_ctrl
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            // Data
            mem_alu_out      <= 32'b0;
            mem_rs2_data     <= 32'b0;
            mem_pc_plus_4    <= 32'b0;
            mem_imm          <= 32'b0;
            mem_rd           <= 5'b0;
            // Control – MEM
            mem_memwrite_en  <= 1'b0;
            mem_memstore_ctrl <= 4'b0;
            mem_memload_ctrl <= 3'b0;
            // Control – WB
            mem_regwrite_en  <= 1'b0;
            mem_regwrite_ctrl <= 2'b0;
        end
        else begin
            // Data
            mem_alu_out      <= ex_alu_out;
            mem_rs2_data     <= ex_rs2_data;
            mem_pc_plus_4    <= ex_pc_plus_4;
            mem_imm          <= ex_imm;
            mem_rd           <= ex_rd;
            // Control – MEM
            mem_memwrite_en  <= ex_memwrite_en;
            mem_memstore_ctrl <= ex_memstore_ctrl;
            mem_memload_ctrl <= ex_memload_ctrl;
            // Control – WB
            mem_regwrite_en  <= ex_regwrite_en;
            mem_regwrite_ctrl <= ex_regwrite_ctrl;
        end
    end
endmodule