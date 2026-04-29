`include "params.vh"
module datapath(
    input clk,
    input rst,

    // DMA loader
    input dma_load,
    input [31:0] dma_data,
    input [31:0] dma_addr,

    // UART MMIO peripheral bridge
    output [31:0] uart_addr,
    output [31:0] uart_write_data,
    output uart_write_en,
    output uart_read_en,
    input [31:0] uart_read_data,

    //To Host
    output [31:0] tohost,
    output        tohost_valid,

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
    reg  [31:0] if_pc_aligned;
    wire [31:0] if_pc_aligned_plus_4; 

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
    wire        id_mret_en;

    // --- CSR WIRES (ID) ---
    wire        id_csr_we, id_csr_imm_sel, id_wb_is_csr;
    wire [1:0]  id_csr_op;
    wire [11:0] id_csr_addr = id_inst[31:20];

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

    // --- CSR WIRES (EX) ---
    wire        ex_csr_we, ex_csr_imm_sel, ex_wb_is_csr;
    wire [1:0]  ex_csr_op;
    wire [11:0] ex_csr_addr;
    wire        ex_mret_en;

    // --- EX (ALU + branch resolution) ---
    wire [31:0] alu_out;
    wire        zero_flag, alu_lt_u, alu_lt_s;
    reg  [31:0] alu_a, alu_b;
    wire [31:0] ex_forward_rs1, ex_forward_rs2;
    wire [31:0] branch_target, jalr_target;
    wire [2:0]  pc_sel;
    reg         branch_cond;
    
    (* max_fanout = 32 *) wire pipeline_flush;

    // --- EX/MEM outputs ---
    wire [31:0] mem_alu_out, mem_rs2_data, mem_pc_plus_4, mem_imm;
    wire [4:0]  mem_rd;
    wire        mem_memwrite_en;
    wire [3:0]  mem_memstore_ctrl;
    wire [2:0]  mem_memload_ctrl;
    wire        mem_regwrite_en;
    wire [1:0]  mem_regwrite_ctrl;

    // --- CSR WIRES (MEM) ---
    wire        mem_wb_is_csr;
    wire [31:0] mem_csr_rdata;

    // --- MEM (memory access + load/store shifting) ---
    wire [31:0] mem_data, processed_mem_data;
    reg  [31:0] store_data;
    wire [3:0]  byte_en;
    wire [31:0] mem_forward_data;
    wire        mem_read_en;

    // --- MEM/WB outputs ---
    wire [31:0] wb_alu_out, wb_mem_data, wb_pc_plus_4, wb_imm;
    wire [4:0]  wb_rd;
    wire        wb_regwrite_en;
    wire [1:0]  wb_regwrite_ctrl;

    // --- CSR WIRES (WB) ---
    wire        wb_wb_is_csr;
    wire [31:0] wb_csr_rdata;

    // --- WB ---
    reg  [31:0] wb_write_data;

    // --- Hazard / Forwarding ---
    wire        pc_stall, if_id_stall, id_ex_bubble;
    wire [1:0]  forward_a_sel, forward_b_sel;

    // --- Interrupt / Trap wires ---
    wire        take_interrupt;     // from CSR: global & timer enabled & pending
    wire [31:0] mtvec_out, mepc_out;
    wire        bus_timer_irq;      // from system_bus

    // =========================================================================
    //  PARALLEL VALID & TRAP PIPELINE
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
            if (pipeline_flush) id_valid <= 1'b0;
            else if (!if_id_stall) id_valid <= if_valid;

            if (pipeline_flush || id_ex_bubble) begin
                ex_valid   <= 1'b0;
                ex_trap_en <= 1'b0;
            end else begin
                ex_valid   <= id_valid;
                ex_trap_en <= id_trap_en;
            end

            mem_valid <= ex_valid;
            wb_valid  <= mem_valid;
        end
    end

    // =========================================================================
    //  INTERRUPT INJECTION LOGIC
    // =========================================================================
    // Guard: don't inject an interrupt if EX already has a control-flow change
    // (branch/jal/jalr/ecall/mret) — those take priority. This avoids a
    // combinational loop through pipeline_flush → csr_trap_en → interrupt_inject.
    wire ex_has_cf_change = ex_trap_en | ex_mret_en | ex_jal_ctrl | ex_jalr_ctrl | ex_branch_en;
    
    wire interrupt_inject = take_interrupt & ex_valid & ~ex_has_cf_change;

    // Unified trap signal to CSR file — covers both ecall and hardware interrupt
    wire csr_trap_en    = ex_trap_en | interrupt_inject;
    wire [31:0] csr_trap_pc    = ex_pc;  // PC of instruction in EX stage
    wire [31:0] csr_trap_cause = ex_trap_en ? 32'd11 :      // ecall from M-mode
                                 {1'b1, 31'd7};              // machine timer interrupt (async, code 7)

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

    wire [31:0] imem_pc_in = pc_stall ? if_pc_aligned : if_pc;

    imem imem_inst(
        .clk(clk),
        .pc(imem_pc_in),
        .inst(if_inst),
        .load(dma_load),
        .addr(dma_addr),
        .data(dma_data)
    );

    // PC mux — expanded for trap entry (mtvec) and mret (mepc)
    always @(*) begin
        case (pc_sel)
            `PC_SEL_PLUS4:  pc_next = if_pc_plus_4;
            `PC_SEL_BRANCH: pc_next = branch_target;
            `PC_SEL_JALR:   pc_next = jalr_target;
            `PC_SEL_MTVEC:  pc_next = mtvec_out;       // trap/interrupt entry
            `PC_SEL_MEPC:   pc_next = mepc_out;         // mret return
            default:        pc_next = if_pc_plus_4;
        endcase
    end

    // =========================================================================
    //  IF/ID Pipeline Register
    // =========================================================================
    always @(posedge clk) begin
        if (rst) if_pc_aligned <= 0;
        else if (!pc_stall) if_pc_aligned <= if_pc;
    end

    assign if_pc_plus_4 = if_pc + 4;
    assign if_pc_aligned_plus_4 = if_pc_aligned + 4;
    reg pipeline_flush_d1;
    always @(posedge clk) begin
        if (rst) pipeline_flush_d1 <= 1'b0;
        else     pipeline_flush_d1 <= pipeline_flush;
    end

    IF_ID if_id_reg(
        .clk(clk),
        .rst(rst),
        .flush(pipeline_flush || pipeline_flush_d1),
        .stall(if_id_stall),
        .if_inst(if_inst),
        .if_pc(if_pc_aligned),
        .if_pc_plus_4(if_pc_aligned_plus_4),
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
        .trap_en(id_trap_en),
        .mret_en(id_mret_en),

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
        .flush(pipeline_flush || pipeline_flush_d1 || id_ex_bubble),
        .stall(1'b0),
        .id_rs1_data(id_rs1_data), .id_rs2_data(id_rs2_data), .id_imm(id_imm),
        .id_pc(id_pc), .id_pc_plus_4(id_pc_plus_4), .id_rd(id_rd),
        .id_rs1_addr(id_rs1_addr), .id_rs2_addr(id_rs2_addr),
        
        .ex_rs1_data(ex_rs1_data), .ex_rs2_data(ex_rs2_data), .ex_imm(ex_imm),
        .ex_pc(ex_pc), .ex_pc_plus_4(ex_pc_plus_4), .ex_rd(ex_rd),
        .ex_rs1_addr(ex_rs1_addr), .ex_rs2_addr(ex_rs2_addr),

        .id_alu_ctrl(id_alu_ctrl), .id_auipc_ctrl(id_auipc_ctrl), .id_bsel_ctrl(id_bsel_ctrl),
        .id_branch_en(id_branch_en), .id_branchcond_ctrl(id_branchcond_ctrl),
        .id_jal_ctrl(id_jal_ctrl), .id_jalr_ctrl(id_jalr_ctrl),
        
        .ex_alu_ctrl(ex_alu_ctrl), .ex_auipc_ctrl(ex_auipc_ctrl), .ex_bsel_ctrl(ex_bsel_ctrl),
        .ex_branch_en(ex_branch_en), .ex_branchcond_ctrl(ex_branchcond_ctrl),
        .ex_jal_ctrl(ex_jal_ctrl), .ex_jalr_ctrl(ex_jalr_ctrl),

        .id_memwrite_en(id_memwrite_en), .id_memstore_ctrl(id_memstore_ctrl), .id_memload_ctrl(id_memload_ctrl),
        .ex_memwrite_en(ex_memwrite_en), .ex_memstore_ctrl(ex_memstore_ctrl), .ex_memload_ctrl(ex_memload_ctrl),

        .id_regwrite_en(id_regwrite_en), .id_regwrite_ctrl(id_regwrite_ctrl),
        .ex_regwrite_en(ex_regwrite_en), .ex_regwrite_ctrl(ex_regwrite_ctrl),

        .id_csr_we(id_csr_we), .id_csr_op(id_csr_op), .id_csr_imm_sel(id_csr_imm_sel), 
        .id_wb_is_csr(id_wb_is_csr), .id_csr_addr(id_csr_addr),
        
        .ex_csr_we(ex_csr_we), .ex_csr_op(ex_csr_op), .ex_csr_imm_sel(ex_csr_imm_sel), 
        .ex_wb_is_csr(ex_wb_is_csr), .ex_csr_addr(ex_csr_addr),

        .id_mret_en(id_mret_en),
        .ex_mret_en(ex_mret_en)
    );

    // =========================================================================
    //  EX — Execute (ALU + Branch + Trap/Interrupt Resolution)
    // =========================================================================

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

    assign mem_forward_data = (mem_wb_is_csr) ? mem_csr_rdata :
                              (mem_regwrite_ctrl == 2'b10) ? mem_pc_plus_4 :
                              (mem_regwrite_ctrl == 2'b11) ? mem_imm :
                              mem_alu_out;

    assign ex_forward_rs1 = (forward_a_sel == 2'b10) ? mem_forward_data :
                            (forward_a_sel == 2'b01) ? wb_write_data :
                            ex_rs1_data;

    assign ex_forward_rs2 = (forward_b_sel == 2'b10) ? mem_forward_data :
                            (forward_b_sel == 2'b01) ? wb_write_data :
                            ex_rs2_data;

    always @(*) begin
        alu_a = (ex_auipc_ctrl) ? ex_pc : ex_forward_rs1;
        alu_b = (ex_bsel_ctrl)  ? ex_imm : ex_forward_rs2;
    end

    alu alu_inst(
        .a(alu_a),
        .b(alu_b),
        .alu_ctrl(ex_alu_ctrl),
        .rslt(alu_out),
        .zero_flag(zero_flag),
        .lt_u(alu_lt_u),
        .lt_s(alu_lt_s)
    );

    assign branch_target = ex_pc + ex_imm;
    assign jalr_target   = {alu_out[31:1], 1'b0};

    // --- Fast Branch Comparator ---
    wire branch_eq   = (ex_forward_rs1 == ex_forward_rs2);
    wire branch_lt_s = ($signed(ex_forward_rs1) < $signed(ex_forward_rs2));
    wire branch_lt_u = (ex_forward_rs1 < ex_forward_rs2);

    always @(*) begin
        case (ex_branchcond_ctrl)
            3'b000:  branch_cond =  branch_eq;       
            3'b001:  branch_cond = ~branch_eq;       
            3'b100:  branch_cond =  branch_lt_s;     
            3'b101:  branch_cond = ~branch_lt_s;     
            3'b110:  branch_cond =  branch_lt_u;     
            3'b111:  branch_cond = ~branch_lt_u;     
            default: branch_cond = 1'b0;
        endcase
    end

    // --- PC Select (expanded to 3 bits) ---
    // Priority: interrupt/trap > mret > jalr > branch/jal > PC+4
    wire branch_taken = ex_branch_en & branch_cond;

    assign pc_sel = (csr_trap_en)   ? `PC_SEL_MTVEC  :   // trap/interrupt → mtvec
                    (ex_mret_en)    ? `PC_SEL_MEPC   :   // mret → mepc
                    (ex_jalr_ctrl)  ? `PC_SEL_JALR   :   // JALR
                    (ex_jal_ctrl | branch_taken) ? `PC_SEL_BRANCH :  // JAL / taken branch
                    `PC_SEL_PLUS4;                        // default

    assign pipeline_flush = (pc_sel != `PC_SEL_PLUS4);

    // --- CSR Unit ---
    wire [31:0] csr_zimm = {27'b0, ex_rs1_addr}; 
    wire [31:0] csr_wdata = ex_csr_imm_sel ? csr_zimm : ex_forward_rs1;
    wire [31:0] ex_csr_rdata;

    // Suppress CSR software write if we are also taking an interrupt/trap this cycle
    wire csr_we_effective = ex_csr_we & ~csr_trap_en & ~interrupt_inject;

    csr_file my_csr_unit (
        .clk(clk),
        .rst(rst),
        .csr_addr(ex_csr_addr),
        .wdata(csr_wdata),
        .csr_op(ex_csr_op),
        .csr_we(csr_we_effective),
        .rdata(ex_csr_rdata),
        .inst_retire(wb_valid),

        // Trap interface
        .trap_en(csr_trap_en),
        .trap_pc(csr_trap_pc),
        .trap_cause(csr_trap_cause),

        // MRET interface
        .mret_en(ex_mret_en),

        // External interrupt
        .timer_irq(bus_timer_irq),

        // Outputs
        .take_interrupt(take_interrupt),
        .mtvec_out(mtvec_out),
        .mepc_out(mepc_out)
    );

    // =========================================================================
    //  EX/MEM Pipeline Register
    // =========================================================================

    EX_MEM ex_mem_reg(
        .clk(clk),
        .rst(rst),
        .flush(csr_trap_en),
        .ex_alu_out(alu_out), .ex_rs2_data(ex_forward_rs2), .ex_pc_plus_4(ex_pc_plus_4),
        .ex_imm(ex_imm), .ex_rd(ex_rd),

        .mem_alu_out(mem_alu_out), .mem_rs2_data(mem_rs2_data), .mem_pc_plus_4(mem_pc_plus_4),
        .mem_imm(mem_imm), .mem_rd(mem_rd),

        .ex_memwrite_en(ex_memwrite_en), .ex_memstore_ctrl(ex_memstore_ctrl), .ex_memload_ctrl(ex_memload_ctrl),
        .mem_memwrite_en(mem_memwrite_en), .mem_memstore_ctrl(mem_memstore_ctrl), .mem_memload_ctrl(mem_memload_ctrl),

        .ex_regwrite_en(ex_regwrite_en), .ex_regwrite_ctrl(ex_regwrite_ctrl),
        .mem_regwrite_en(mem_regwrite_en), .mem_regwrite_ctrl(mem_regwrite_ctrl),

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
            4'b0001: store_data = mem_rs2_data << {mem_alu_out[1:0], 3'b000};
            4'b0011: store_data = mem_rs2_data << {mem_alu_out[1],   4'b0000};
            default: store_data = mem_rs2_data;
        endcase
    end

    assign mem_read_en = mem_valid && (mem_regwrite_ctrl == 2'b01);

    system_bus system_bus_inst(
        .clk(clk),
        .rst(rst),
        .byte_en(byte_en),
        .addr(mem_alu_out),
        .write_data(store_data),
        .write_en(mem_memwrite_en),
        .read_en(mem_read_en),
        .read_data(mem_data),
        .leds(leds),
        .switches(switches),
        .uart_addr(uart_addr),
        .uart_write_data(uart_write_data),
        .uart_write_en(uart_write_en),
        .uart_read_en(uart_read_en),
        .uart_read_data(uart_read_data),
        .timer_irq(bus_timer_irq),
        .tohost(tohost),
        .tohost_valid(tohost_valid)
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
        .mem_alu_out(mem_alu_out), .mem_mem_data(processed_mem_data),
        .mem_pc_plus_4(mem_pc_plus_4), .mem_imm(mem_imm), .mem_rd(mem_rd),

        .wb_alu_out(wb_alu_out), .wb_mem_data(wb_mem_data),
        .wb_pc_plus_4(wb_pc_plus_4), .wb_imm(wb_imm), .wb_rd(wb_rd),

        .mem_regwrite_en(mem_regwrite_en), .mem_regwrite_ctrl(mem_regwrite_ctrl),
        .wb_regwrite_en(wb_regwrite_en), .wb_regwrite_ctrl(wb_regwrite_ctrl),

        .mem_wb_is_csr(mem_wb_is_csr), .mem_csr_rdata(mem_csr_rdata),
        .wb_wb_is_csr(wb_wb_is_csr), .wb_csr_rdata(wb_csr_rdata)
    );

    // =========================================================================
    //  WB — Writeback
    // =========================================================================

    always @(*) begin
        if (wb_wb_is_csr) begin
            wb_write_data = wb_csr_rdata;
        end else begin
            case (wb_regwrite_ctrl)
                2'b00:   wb_write_data = wb_alu_out;       
                2'b01:   wb_write_data = wb_mem_data;       
                2'b10:   wb_write_data = wb_pc_plus_4;      
                2'b11:   wb_write_data = wb_imm;            
                default: wb_write_data = wb_alu_out;
            endcase
        end
    end

endmodule
