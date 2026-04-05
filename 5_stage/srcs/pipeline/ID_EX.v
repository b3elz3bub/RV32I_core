`include "params.vh"
module ID_EX(
    input clk,
    input rst,
    input flush,
    input stall,

    // ── Data ──
    input [31:0] id_rs1_data, id_rs2_data, id_imm,
    input [31:0] id_pc, id_pc_plus_4,
    input [4:0]  id_rd,
    input [4:0]  id_rs1_addr, id_rs2_addr,

    output reg [31:0] ex_rs1_data, ex_rs2_data, ex_imm,
    output reg [31:0] ex_pc, ex_pc_plus_4,
    output reg [4:0]  ex_rd,
    output reg [4:0]  ex_rs1_addr, ex_rs2_addr,

    // ── Control: used in EX ──
    input [3:0]  id_alu_ctrl,
    input        id_auipc_ctrl,
    input        id_bsel_ctrl,
    input        id_branch_en,
    input [2:0]  id_branchcond_ctrl,
    input        id_jal_ctrl,
    input        id_jalr_ctrl,

    output reg [3:0]  ex_alu_ctrl,
    output reg        ex_auipc_ctrl,
    output reg        ex_bsel_ctrl,
    output reg        ex_branch_en,
    output reg [2:0]  ex_branchcond_ctrl,
    output reg        ex_jal_ctrl,
    output reg        ex_jalr_ctrl,

    // ── Control: pass through to MEM ──
    input        id_memwrite_en,
    input [3:0]  id_memstore_ctrl,
    input [2:0]  id_memload_ctrl,

    output reg        ex_memwrite_en,
    output reg [3:0]  ex_memstore_ctrl,
    output reg [2:0]  ex_memload_ctrl,

    // ── Control: pass through to WB ──
    input        id_regwrite_en,
    input [1:0]  id_regwrite_ctrl,

    output reg        ex_regwrite_en,
    output reg [1:0]  ex_regwrite_ctrl
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            // Data
            ex_rs1_data      <= 32'b0;
            ex_rs2_data      <= 32'b0;
            ex_imm           <= 32'b0;
            ex_pc            <= 32'b0;
            ex_pc_plus_4     <= 32'b0;
            ex_rd            <= 5'b0;
            ex_rs1_addr      <= 5'b0;
            ex_rs2_addr      <= 5'b0;
            // Control – EX
            ex_alu_ctrl      <= 4'b0;
            ex_auipc_ctrl    <= 1'b0;
            ex_bsel_ctrl     <= 1'b0;
            ex_branch_en     <= 1'b0;
            ex_branchcond_ctrl <= 3'b0;
            ex_jal_ctrl      <= 1'b0;
            ex_jalr_ctrl     <= 1'b0;
            // Control – MEM
            ex_memwrite_en   <= 1'b0;
            ex_memstore_ctrl <= 4'b0;
            ex_memload_ctrl  <= 3'b0;
            // Control – WB
            ex_regwrite_en   <= 1'b0;
            ex_regwrite_ctrl <= 2'b0;
        end
        else if (!stall) begin
            // Data
            ex_rs1_data      <= id_rs1_data;
            ex_rs2_data      <= id_rs2_data;
            ex_imm           <= id_imm;
            ex_pc            <= id_pc;
            ex_pc_plus_4     <= id_pc_plus_4;
            ex_rd            <= id_rd;
            ex_rs1_addr      <= id_rs1_addr;
            ex_rs2_addr      <= id_rs2_addr;
            // Control – EX
            ex_alu_ctrl      <= id_alu_ctrl;
            ex_auipc_ctrl    <= id_auipc_ctrl;
            ex_bsel_ctrl     <= id_bsel_ctrl;
            ex_branch_en     <= id_branch_en;
            ex_branchcond_ctrl <= id_branchcond_ctrl;
            ex_jal_ctrl      <= id_jal_ctrl;
            ex_jalr_ctrl     <= id_jalr_ctrl;
            // Control – MEM
            ex_memwrite_en   <= id_memwrite_en;
            ex_memstore_ctrl <= id_memstore_ctrl;
            ex_memload_ctrl  <= id_memload_ctrl;
            // Control – WB
            ex_regwrite_en   <= id_regwrite_en;
            ex_regwrite_ctrl <= id_regwrite_ctrl;
        end
    end
endmodule