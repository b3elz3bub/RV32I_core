module datapath(
    input clk,
    input rst,

    // UART loader
    input uart_load,
    input [31:0] uart_data,
    input [31:0] imem_addr,

    // IO
    output [7:0] leds,
    input  [7:0] switches
);

    // =========================================================================
    //  WIRES & REGS organised by pipeline stage
    // =========================================================================

    // --- IF ---
    wire [31:0] if_pc, if_pc_plus_4, if_inst;
    reg  [31:0] pc_next;

    // --- IF/ID outputs ---
    wire [31:0] id_inst, id_pc, id_pc_plus_4;

    // --- ID (decode + regfile read) ---
    wire [31:0] id_rs1_data, id_rs2_data, id_imm;
    wire [4:0]  id_rs1_addr, id_rs2_addr, id_rd;

    // Control signals from control unit (ID stage)
    wire [3:0]  id_alu_ctrl;
    wire        id_auipc_ctrl, id_bsel_ctrl;
    wire        id_branch_en, id_jal_ctrl, id_jalr_ctrl;
    wire [2:0]  id_branchcond_ctrl;
    wire        id_memwrite_en;
    wire [3:0]  id_memstore_ctrl;
    wire [2:0]  id_memload_ctrl;
    wire        id_regwrite_en;
    wire [1:0]  id_regwrite_ctrl;
    wire        id_trap_en;

    // --- NEW CSR WIRES (ID) ---
    wire        id_csr_we, id_csr_imm_sel, id_wb_is_csr;
    wire [1:0]  id_csr_op;
    wire [11:0] id_csr_addr = id_inst[31:20]; // Extract 12-bit address

    // --- ID/EX outputs ---
    wire [31:0] ex_rs1_data, ex_rs2_data, ex_imm, ex_pc, ex_pc_plus_4;
    wire [4:0]  ex_rd, ex_rs1_addr, ex_rs2_addr;
    wire [3:0]  ex_alu_ctrl;
    wire        ex_auipc_ctrl, ex_bsel_ctrl;
    wire        ex_branch_en, ex_jal_ctrl, ex_jalr_ctrl;
    wire [2:0]  ex_branchcond_ctrl;
    wire        ex_memwrite_en;
    wire [3:0]  ex_memstore_ctrl;
    wire [2:0]  ex_memload_ctrl;
    wire        ex_regwrite_en;
    wire [1:0]  ex_regwrite_ctrl;

    // --- NEW CSR WIRES (EX) ---
    wire        ex_csr_we, ex_csr_imm_sel, ex_wb_is_csr;
    wire [1:0]  ex_csr_op;
    wire [11:0] ex_csr_addr;

    // --- EX (ALU + branch resolution) ---
    wire [31:0] alu_out;
    wire        zero_flag, alu_lt_u;
    reg  [31:0] alu_a, alu_b;         // after forwarding + input muxes
    wire [31:0] ex_forward_rs1, ex_forward_rs2;  // after forwarding, before input mux
    wire [31:0] branch_target, jalr_target;
    wire [1:0]  pc_sel;
    reg         branch_cond;
    wire        pipeline_flush;

    // --- EX/MEM outputs ---
    wire [31:0] mem_alu_out, mem_rs2_data, mem_pc_plus_4, mem_imm;
    wire [4:0]  mem_rd;
    wire        mem_memwrite_en;
    wire [3:0]  mem_memstore_ctrl;
    wire [2:0]  mem_memload_ctrl;
    wire        mem_regwrite_en;
    wire [1:0]  mem_regwrite_ctrl;

    // --- NEW CSR WIRES (MEM) ---
    wire        mem_wb_is_csr;
    wire [31:0] mem_csr_rdata;

    // --- MEM (memory access + load/store shifting) ---
    wire [31:0] mem_data, processed_mem_data;
    reg  [31:0] store_data;
    wire [3:0]  byte_en;
    wire [31:0] mem_forward_data;  // forwarding value from MEM stage

    // --- MEM/WB outputs ---
    wire [31:0] wb_alu_out, wb_mem_data, wb_pc_plus_4, wb_imm;
    wire [4:0]  wb_rd;
    wire        wb_regwrite_en;
    wire [1:0]  wb_regwrite_ctrl;

    // --- NEW CSR WIRES (WB) ---
    wire        wb_wb_is_csr;
    wire [31:0] wb_csr_rdata;

    // --- WB ---
    reg  [31:0] wb_write_data;

    // --- Hazard / Forwarding ---
    wire        pc_stall, if_id_stall, id_ex_bubble;
    wire [1:0]  forward_a_sel, forward_b_sel;

    // =========================================================================
    //  PARALLEL VALID & TRAP PIPELINE
    //  (Tracks valid instructions and traps without altering your existing modules)
    // =========================================================================
    wire if_valid = 1'b1; 
    reg  id_valid, ex_valid, mem_valid, wb_valid;
    reg  ex_trap_en;

    always @(posedge clk) begin
        if (rst) begin
            id_valid   <= 1'b0;
            ex_valid   <= 1'b0;
            mem_valid  <= 1'b0;
            wb_valid   <= 1'b0;
            ex_trap_en <= 1'b0;
        end else begin
            // IF/ID logic
            if (pipeline_flush) id_valid <= 1'b0;
            else if (!if_id_stall) id_valid <= if_valid;

            // ID/EX logic
            if (pipeline_flush || id_ex_bubble) begin
                ex_valid   <= 1'b0;
                ex_trap_en <= 1'b0;
            end else begin
                ex_valid   <= id_valid;
                ex_trap_en <= id_trap_en;
            end

            // EX/MEM logic
            mem_valid <= ex_valid;

            // MEM/WB logic
            wb_valid <= mem_valid;
        end
    end

    // =========================================================================
    //  IF — Instruction Fetch
    // =========================================================================

    pc pc_inst(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_next(pc_next),
        .pc_out(if_pc)
    );

    assign if_pc_plus_4 = if_pc + 4;

    imem imem_inst(
        .clk(clk),
        .pc(if_pc),
        .inst(if_inst),
        .load(uart_load),
        .addr(imem_addr),
        .data(uart_data)
    );

    always @(*) begin
        case (pc_sel)
            2'b00:   pc_next = if_pc_plus_4;     // default: not-taken prediction
            2'b01:   pc_next = branch_target;    // taken branch (from EX)
            2'b10:   pc_next = jalr_target;      // JALR (from EX)
            default: pc_next = if_pc_plus_4;
        endcase
    end

    // =========================================================================
    //  IF/ID Pipeline Register
    // =========================================================================

    IF_ID if_id_reg(
        .clk(clk),
        .rst(rst),
        .flush(pipeline_flush),
        .stall(if_id_stall),
        .if_inst(if_inst),
        .if_pc(if_pc),
        .if_pc_plus_4(if_pc_plus_4),
        .id_inst(id_inst),
        .id_pc(id_pc),
        .id_pc_plus_4(id_pc_plus_4)
    );

    // =========================================================================
    //  ID — Instruction Decode + Register Read
    // =========================================================================

    assign id_rs1_addr = id_inst[19:15];
    assign id_rs2_addr = id_inst[24:20];
    assign id_rd       = id_inst[11:7];

    control control_inst(
        .inst(id_inst),
        .regwrite_ctrl(id_regwrite_ctrl),
        .regwrite_en(id_regwrite_en),
        .memwrite_en(id_memwrite_en),
        .memload_ctrl(id_memload_ctrl),
        .memstore_ctrl(id_memstore_ctrl),
        .alu_ctrl(id_alu_ctrl),
        .auipc_ctrl(id_auipc_ctrl),
        .bsel_ctrl(id_bsel_ctrl),
        .branch_en(id_branch_en),
        .branchcond_ctrl(id_branchcond_ctrl),
        .jal_ctrl(id_jal_ctrl),
        .jalr_ctrl(id_jalr_ctrl),
        .trap_en(id_trap_en), // Connected Trap Enable

        // --- NEW CSR PORTS ---
        .csr_we(id_csr_we),
        .csr_op(id_csr_op),
        .csr_imm_sel(id_csr_imm_sel),
        .wb_is_csr(id_wb_is_csr)
    );

    regfile regfile_inst(
        .clk(clk),
        .write_en(wb_regwrite_en),
        .rs1(id_rs1_addr),
        .rs2(id_rs2_addr),
        .write_reg(wb_rd),
        .write_data(wb_write_data),
        .a(id_rs1_data),
        .b(id_rs2_data)
    );

    immgen immgen_inst(
        .inst(id_inst),
        .imm(id_imm)
    );

    // =========================================================================
    //  Hazard Detection Unit
    // =========================================================================

    hazard_unit hazard_inst(
        .ex_regwrite_en(ex_regwrite_en),
        .ex_regwrite_ctrl(ex_regwrite_ctrl),
        .ex_rd(ex_rd),
        .id_rs1_addr(id_rs1_addr),
        .id_rs2_addr(id_rs2_addr),
        .pipeline_flush(pipeline_flush),
        .pc_stall(pc_stall),
        .if_id_stall(if_id_stall),
        .id_ex_bubble(id_ex_bubble)
    );

    // =========================================================================
    //  ID/EX Pipeline Register
    // =========================================================================

    ID_EX id_ex_reg(
        .clk(clk),
        .rst(rst),
        .flush(pipeline_flush || id_ex_bubble),
        .stall(1'b0),

        // Data
        .id_rs1_data(id_rs1_data),
        .id_rs2_data(id_rs2_data),
        .id_imm(id_imm),
        .id_pc(id_pc),
        .id_pc_plus_4(id_pc_plus_4),
        .id_rd(id_rd),
        .id_rs1_addr(id_rs1_addr),
        .id_rs2_addr(id_rs2_addr),

        .ex_rs1_data(ex_rs1_data),
        .ex_rs2_data(ex_rs2_data),
        .ex_imm(ex_imm),
        .ex_pc(ex_pc),
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_rd(ex_rd),
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),

        // Control – EX
        .id_alu_ctrl(id_alu_ctrl),
        .id_auipc_ctrl(id_auipc_ctrl),
        .id_bsel_ctrl(id_bsel_ctrl),
        .id_branch_en(id_branch_en),
        .id_branchcond_ctrl(id_branchcond_ctrl),
        .id_jal_ctrl(id_jal_ctrl),
        .id_jalr_ctrl(id_jalr_ctrl),

        .ex_alu_ctrl(ex_alu_ctrl),
        .ex_auipc_ctrl(ex_auipc_ctrl),
        .ex_bsel_ctrl(ex_bsel_ctrl),
        .ex_branch_en(ex_branch_en),
        .ex_branchcond_ctrl(ex_branchcond_ctrl),
        .ex_jal_ctrl(ex_jal_ctrl),
        .ex_jalr_ctrl(ex_jalr_ctrl),

        // Control – MEM pass-through
        .id_memwrite_en(id_memwrite_en),
        .id_memstore_ctrl(id_memstore_ctrl),
        .id_memload_ctrl(id_memload_ctrl),

        .ex_memwrite_en(ex_memwrite_en),
        .ex_memstore_ctrl(ex_memstore_ctrl),
        .ex_memload_ctrl(ex_memload_ctrl),

        // Control – WB pass-through
        .id_regwrite_en(id_regwrite_en),
        .id_regwrite_ctrl(id_regwrite_ctrl),

        .ex_regwrite_en(ex_regwrite_en),
        .ex_regwrite_ctrl(ex_regwrite_ctrl),

        // --- NEW CSR PORTS ---
        .id_csr_we(id_csr_we), .id_csr_op(id_csr_op), .id_csr_imm_sel(id_csr_imm_sel), 
        .id_wb_is_csr(id_wb_is_csr), .id_csr_addr(id_csr_addr),
        
        .ex_csr_we(ex_csr_we), .ex_csr_op(ex_csr_op), .ex_csr_imm_sel(ex_csr_imm_sel), 
        .ex_wb_is_csr(ex_wb_is_csr), .ex_csr_addr(ex_csr_addr)
        
    );

    // =========================================================================
    //  EX — Execute (ALU + Branch Resolution)
    // =========================================================================

    // --- Forwarding Unit ---
    forwarding_unit fwd_inst(
        .ex_rs1_addr(ex_rs1_addr),
        .ex_rs2_addr(ex_rs2_addr),
        .mem_rd(mem_rd),
        .mem_regwrite_en(mem_regwrite_en),
        .mem_regwrite_ctrl(mem_regwrite_ctrl),
        .wb_rd(wb_rd),
        .wb_regwrite_en(wb_regwrite_en),
        .forward_a_sel(forward_a_sel),
        .forward_b_sel(forward_b_sel)
    );

    // MEM stage forwarding value
    assign mem_forward_data = (mem_wb_is_csr) ? mem_csr_rdata :
                              (mem_regwrite_ctrl == 2'b10) ? mem_pc_plus_4 :
                              (mem_regwrite_ctrl == 2'b11) ? mem_imm :
                              mem_alu_out;

    // --- Forwarding muxes ---
    assign ex_forward_rs1 = (forward_a_sel == 2'b10) ? mem_forward_data :
                            (forward_a_sel == 2'b01) ? wb_write_data :
                            ex_rs1_data;

    assign ex_forward_rs2 = (forward_b_sel == 2'b10) ? mem_forward_data :
                            (forward_b_sel == 2'b01) ? wb_write_data :
                            ex_rs2_data;

    // --- ALU input muxes (after forwarding) ---
    always @(*) begin
        alu_a = (ex_auipc_ctrl) ? ex_pc : ex_forward_rs1;
        alu_b = (ex_bsel_ctrl)  ? ex_imm : ex_forward_rs2;
    end

    // --- ALU ---
    alu alu_inst(
        .a(alu_a),
        .b(alu_b),
        .alu_ctrl(ex_alu_ctrl),
        .rslt(alu_out),
        .zero_flag(zero_flag),
        .lt_u(alu_lt_u)
    );

    // --- Branch target computation ---
    assign branch_target = ex_pc + ex_imm;
    assign jalr_target   = {alu_out[31:1], 1'b0};

    // =========================================================================
    //  CSR Execute Logic (UPDATED)
    // =========================================================================
    wire [31:0] csr_zimm = {27'b0, ex_rs1_addr}; 
    wire [31:0] csr_wdata = ex_csr_imm_sel ? csr_zimm : ex_forward_rs1;
    wire [31:0] ex_csr_rdata;

    csr_file my_csr_unit (
        .clk(clk),
        .rst(rst),
        .csr_addr(ex_csr_addr),
        .wdata(csr_wdata),
        .csr_op(ex_csr_op),
        .csr_we(ex_csr_we),
        .rdata(ex_csr_rdata),
        
        // Use the newly created WB valid bit for instret tracking
        .inst_retire(wb_valid),
        
        // Connect the parallel pipelined hardware trap signals
        .trap_en(ex_trap_en),
        .trap_pc(ex_pc),
        .trap_cause(32'd11) // Hardcoded ECALL Exception Cause
    );

    // --- Branch condition evaluation ---
    always @(*) begin
        case (ex_branchcond_ctrl)
            3'b000:  branch_cond =  zero_flag;       // BEQ
            3'b001:  branch_cond = ~zero_flag;       // BNE
            3'b100:  branch_cond =  alu_out[0];      // BLT  (SLT result)
            3'b101:  branch_cond = ~alu_out[0];      // BGE  (SLT result inverted)
            3'b110:  branch_cond =  alu_lt_u;        // BLTU
            3'b111:  branch_cond = ~alu_lt_u;        // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    // --- PC select ---
    assign pc_sel[1] = ex_jalr_ctrl;
    assign pc_sel[0] = ex_jal_ctrl | (ex_branch_en & branch_cond);

    // --- Pipeline flush ---
    assign pipeline_flush = (pc_sel != 2'b00);

    // =========================================================================
    //  EX/MEM Pipeline Register
    // =========================================================================

    EX_MEM ex_mem_reg(
        .clk(clk),
        .rst(rst),
        .flush(1'b0),   // no flush needed for MEM in this design

        // Data
        .ex_alu_out(alu_out),
        .ex_rs2_data(ex_forward_rs2),
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_imm(ex_imm),
        .ex_rd(ex_rd),

        .mem_alu_out(mem_alu_out),
        .mem_rs2_data(mem_rs2_data),
        .mem_pc_plus_4(mem_pc_plus_4),
        .mem_imm(mem_imm),
        .mem_rd(mem_rd),

        // Control – MEM
        .ex_memwrite_en(ex_memwrite_en),
        .ex_memstore_ctrl(ex_memstore_ctrl),
        .ex_memload_ctrl(ex_memload_ctrl),

        .mem_memwrite_en(mem_memwrite_en),
        .mem_memstore_ctrl(mem_memstore_ctrl),
        .mem_memload_ctrl(mem_memload_ctrl),

        // Control – WB pass-through
        .ex_regwrite_en(ex_regwrite_en),
        .ex_regwrite_ctrl(ex_regwrite_ctrl),

        .mem_regwrite_en(mem_regwrite_en),
        .mem_regwrite_ctrl(mem_regwrite_ctrl),

        // --- NEW CSR PORTS ---
        .ex_wb_is_csr(ex_wb_is_csr), .ex_csr_rdata(ex_csr_rdata),
        .mem_wb_is_csr(mem_wb_is_csr), .mem_csr_rdata(mem_csr_rdata)
    );

    // =========================================================================
    //  MEM — Memory Access
    // =========================================================================

    assign byte_en = (mem_memstore_ctrl == 4'b0001) ? (4'b0001 << mem_alu_out[1:0]) :
                     (mem_memstore_ctrl == 4'b0011) ? (4'b0011 << {mem_alu_out[1], 1'b0}) :
                     mem_memstore_ctrl;

    always @(*) begin
        case (mem_memstore_ctrl)
            4'b0001: store_data = mem_rs2_data << {mem_alu_out[1:0], 3'b000};   // SB
            4'b0011: store_data = mem_rs2_data << {mem_alu_out[1],   4'b0000};  // SH
            default: store_data = mem_rs2_data;                                  // SW
        endcase
    end

    system_bus system_bus_inst(
        .clk(clk),
        .byte_en(byte_en),
        .addr(mem_alu_out),
        .write_data(store_data),
        .write_en(mem_memwrite_en),
        .read_data(mem_data),
        .leds(leds),
        .switches(switches)
    );

    loadext loadext_inst(
        .mem_data(mem_data),
        .memload_ctrl(mem_memload_ctrl),
        .byte_addr(mem_alu_out[1:0]),
        .processed_mem_data(processed_mem_data)
    );

    // =========================================================================
    //  MEM/WB Pipeline Register
    // =========================================================================

    MEM_WB mem_wb_reg(
        .clk(clk),
        .rst(rst),

        // Data
        .mem_alu_out(mem_alu_out),
        .mem_mem_data(processed_mem_data),
        .mem_pc_plus_4(mem_pc_plus_4),
        .mem_imm(mem_imm),
        .mem_rd(mem_rd),

        .wb_alu_out(wb_alu_out),
        .wb_mem_data(wb_mem_data),
        .wb_pc_plus_4(wb_pc_plus_4),
        .wb_imm(wb_imm),
        .wb_rd(wb_rd),

        // Control
        .mem_regwrite_en(mem_regwrite_en),
        .mem_regwrite_ctrl(mem_regwrite_ctrl),

        .wb_regwrite_en(wb_regwrite_en),
        .wb_regwrite_ctrl(wb_regwrite_ctrl),

        // --- NEW CSR PORTS ---
        .mem_wb_is_csr(mem_wb_is_csr), .mem_csr_rdata(mem_csr_rdata),
        .wb_wb_is_csr(wb_wb_is_csr), .wb_csr_rdata(wb_csr_rdata)
    );

    // =========================================================================
    //  WB — Writeback
    // =========================================================================

    always @(*) begin
        if (wb_wb_is_csr) begin
            wb_write_data = wb_csr_rdata;       // OVERRIDE FOR CSR INSTRUCTIONS
        end else begin
            case (wb_regwrite_ctrl)
                2'b00:   wb_write_data = wb_alu_out;       // R-type / I-type ALU result
                2'b01:   wb_write_data = wb_mem_data;       // Load data
                2'b10:   wb_write_data = wb_pc_plus_4;      // JAL / JALR return address
                2'b11:   wb_write_data = wb_imm;            // LUI
                default: wb_write_data = wb_alu_out;
            endcase
        end
    end

endmodule