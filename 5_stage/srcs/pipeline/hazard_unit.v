// Hazard Detection Unit — detects load-use data hazards
//
// A load-use hazard occurs when:
//   - The instruction in EX is a LOAD (regwrite_ctrl == 2'b01)
//   - The instruction in ID reads a register that the load will write
//
// Resolution: stall IF and IF/ID (hold), flush ID/EX (insert bubble).
// After the stall, the load data is in WB and can be forwarded to EX.
//
// If a branch flush is happening simultaneously, the stall is suppressed
// because the dependent instruction in ID is being flushed anyway.

module hazard_unit(
    // Load in EX? (from ID/EX register outputs)
    input        ex_regwrite_en,
    input [1:0]  ex_regwrite_ctrl,
    input [4:0]  ex_rd,

    // Source registers of instruction in ID (from IF/ID register)
    input [4:0]  id_rs1_addr,
    input [4:0]  id_rs2_addr,

    // Branch flush from EX (overrides stall)
    input        pipeline_flush,

    // Outputs
    output       pc_stall,       // hold PC
    output       if_id_stall,    // hold IF/ID register
    output       id_ex_bubble    // flush ID/EX (insert NOP)
);

    wire load_use_hazard = ex_regwrite_en
                         && (ex_regwrite_ctrl == 2'b01)  // instruction in EX is a load
                         && (ex_rd != 5'b0)
                         && ((ex_rd == id_rs1_addr) || (ex_rd == id_rs2_addr));

    // Stall only if there's a real hazard and no flush overriding it
    wire stall = load_use_hazard && !pipeline_flush;

    assign pc_stall    = stall;
    assign if_id_stall = stall;
    assign id_ex_bubble = stall;  // id_ex_flush is stall OR pipeline_flush (done externally)

endmodule
