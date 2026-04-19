`include "params.vh"
module ID_EX(
    input clk,
    input rst,
    input flush,     // Flush has priority over stall
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

    // ── Control: EX ──
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

    // ── Control: MEM ──
    input        id_memwrite_en,
    input [3:0]  id_memstore_ctrl,
    input [2:0]  id_memload_ctrl,

    output reg        ex_memwrite_en,
    output reg [3:0]  ex_memstore_ctrl,
    output reg [2:0]  ex_memload_ctrl,

    // ── Control: WB ──
    input        id_regwrite_en,
    input [1:0]  id_regwrite_ctrl,

    output reg        ex_regwrite_en,
    output reg [1:0]  ex_regwrite_ctrl,

    // ── CSR PORTS ──
    input        id_csr_we,
    input [1:0]  id_csr_op,
    input        id_csr_imm_sel,
    input        id_wb_is_csr,
    input [11:0] id_csr_addr,

    output reg        ex_csr_we,
    output reg [1:0]  ex_csr_op,
    output reg        ex_csr_imm_sel,
    output reg        ex_wb_is_csr,
    output reg [11:0] ex_csr_addr
);

    always @(posedge clk) begin
        if (rst) begin
            ex_rs1_data <= 0; ex_rs2_data <= 0; ex_imm <= 0;
            ex_pc <= 0; ex_pc_plus_4 <= 0; ex_rd <= 0;
            ex_rs1_addr <= 0; ex_rs2_addr <= 0;

            ex_alu_ctrl <= 0; ex_auipc_ctrl <= 0; ex_bsel_ctrl <= 0;
            ex_branch_en <= 0; ex_branchcond_ctrl <= 0; ex_jal_ctrl <= 0; ex_jalr_ctrl <= 0;

            ex_memwrite_en <= 0; ex_memstore_ctrl <= 0; ex_memload_ctrl <= 0;
            ex_regwrite_en <= 0; ex_regwrite_ctrl <= 0;

            ex_csr_we <= 0; ex_csr_op <= 0; ex_csr_imm_sel <= 0;
            ex_wb_is_csr <= 0; ex_csr_addr <= 0;

        end else if (flush) begin
            ex_regwrite_en <= 1'b0;
            ex_memwrite_en <= 1'b0;
            ex_branch_en   <= 1'b0;
            ex_jal_ctrl    <= 1'b0;
            ex_jalr_ctrl   <= 1'b0;
            ex_csr_we      <= 1'b0;

            ex_rs1_data  <= id_rs1_data;
            ex_rs2_data  <= id_rs2_data;
            ex_imm       <= id_imm;
            ex_pc        <= id_pc;
            ex_pc_plus_4 <= id_pc_plus_4;
            ex_rd        <= id_rd;
            ex_rs1_addr  <= id_rs1_addr;
            ex_rs2_addr  <= id_rs2_addr;
            
            ex_alu_ctrl        <= id_alu_ctrl;
            ex_auipc_ctrl      <= id_auipc_ctrl;
            ex_bsel_ctrl       <= id_bsel_ctrl;
            ex_branchcond_ctrl <= id_branchcond_ctrl;
            ex_memstore_ctrl   <= id_memstore_ctrl;
            ex_memload_ctrl    <= id_memload_ctrl;
            ex_regwrite_ctrl   <= id_regwrite_ctrl;
            
            ex_csr_op      <= id_csr_op;
            ex_csr_imm_sel <= id_csr_imm_sel; 
            ex_wb_is_csr   <= id_wb_is_csr;
            ex_csr_addr    <= id_csr_addr;

        end else if (!stall) begin
            // Normal operation: Pass all data and control through
            ex_rs1_data  <= id_rs1_data;
            ex_rs2_data  <= id_rs2_data;
            ex_imm       <= id_imm;
            ex_pc        <= id_pc;
            ex_pc_plus_4 <= id_pc_plus_4;
            ex_rd        <= id_rd;
            ex_rs1_addr  <= id_rs1_addr;
            ex_rs2_addr  <= id_rs2_addr;

            ex_alu_ctrl        <= id_alu_ctrl;
            ex_auipc_ctrl      <= id_auipc_ctrl;
            ex_bsel_ctrl       <= id_bsel_ctrl;
            ex_branch_en       <= id_branch_en;
            ex_branchcond_ctrl <= id_branchcond_ctrl;
            ex_jal_ctrl        <= id_jal_ctrl;
            ex_jalr_ctrl       <= id_jalr_ctrl;

            ex_memwrite_en   <= id_memwrite_en;
            ex_memstore_ctrl <= id_memstore_ctrl;
            ex_memload_ctrl  <= id_memload_ctrl;
            
            ex_regwrite_en   <= id_regwrite_en;
            ex_regwrite_ctrl <= id_regwrite_ctrl;

            ex_csr_we      <= id_csr_we;
            ex_csr_op      <= id_csr_op;
            ex_csr_imm_sel <= id_csr_imm_sel;
            ex_wb_is_csr   <= id_wb_is_csr;
            ex_csr_addr    <= id_csr_addr;
        end
        // Implicit else: if (stall), hold current state (all registers maintain current values)
    end
endmodule