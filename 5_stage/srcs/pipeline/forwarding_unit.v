// Forwarding Unit — resolves data hazards by selecting the most recent value
// of a source register from the pipeline, bypassing the register file.
//
// Priority: MEM (1 cycle ago) > WB (2 cycles ago) > register file (no hazard)
//
// Special case: loads in MEM cannot be forwarded (data not ready yet).
// That case is handled by the hazard unit (stall + forward from WB next cycle).

module forwarding_unit(
    // Source register addresses from EX stage
    input [4:0] ex_rs1_addr,
    input [4:0] ex_rs2_addr,

    // MEM stage destination (EX/MEM register outputs)
    input [4:0]  mem_rd,
    input        mem_regwrite_en,
    input [1:0]  mem_regwrite_ctrl,

    // WB stage destination (MEM/WB register outputs)
    input [4:0]  wb_rd,
    input        wb_regwrite_en,

    // Forwarding select for ALU operand A and B
    //   2'b00 = no forwarding (use register file value from ID/EX)
    //   2'b01 = forward from WB  stage (wb_write_data)
    //   2'b10 = forward from MEM stage (mem_forward_data)
    output reg [1:0] forward_a_sel,
    output reg [1:0] forward_b_sel
);

    // --- Forward A (rs1) ---
    always @(*) begin
        if (mem_regwrite_en && mem_rd != 5'b0 && mem_rd == ex_rs1_addr
            && mem_regwrite_ctrl != 2'b01)  // not a load (loads can't forward from MEM)
            forward_a_sel = 2'b10;          // forward from MEM
        else if (wb_regwrite_en && wb_rd != 5'b0 && wb_rd == ex_rs1_addr)
            forward_a_sel = 2'b01;          // forward from WB
        else
            forward_a_sel = 2'b00;          // no forwarding
    end

    // --- Forward B (rs2) ---
    always @(*) begin
        if (mem_regwrite_en && mem_rd != 5'b0 && mem_rd == ex_rs2_addr
            && mem_regwrite_ctrl != 2'b01)
            forward_b_sel = 2'b10;
        else if (wb_regwrite_en && wb_rd != 5'b0 && wb_rd == ex_rs2_addr)
            forward_b_sel = 2'b01;
        else
            forward_b_sel = 2'b00;
    end

endmodule
