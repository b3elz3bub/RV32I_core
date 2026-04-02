module datapath(
    input clk,
    input rst,
    input [1:0] regwrite_ctrl,
    input regwrite_en,
    input memwrite_en,
    input [2:0] memload_ctrl,
    input [3:0] memstore_ctrl,
    input [3:0] alu_ctrl,
    input auipc_ctrl,
    input bsel_ctrl,
    input branch_en,
    input [2:0] branchcond_ctrl,
    input jal_ctrl,
    input jalr_ctrl,
    output [31:0] instr,
    
    input uart_load,
    input [31:0] uart_data,
    input [31:0] imem_addr,

    output [7:0] leds,
    input [7:0] switches
);
    wire[31:0] inst;
    wire[31:0] pc_out;
    reg [31:0] pc_next;
    wire[31:0] branch_target;
    wire[31:0] pc_plus_4;

    reg [31:0] write_data;
    wire [31:0] a, b, rs2, rs1;
    wire [31:0] imm;

    wire zero_flag;
    wire [31:0] alu_out;

    wire [31:0] mem_data;
    wire [31:0] processed_mem_data;
    reg  [31:0] store_data;
    wire [3:0] byte_en;
    pc pc_inst(
        .clk(clk),
        .rst(rst),
        .pc_next(pc_next),
        .pc_out(pc_out)
    );
    immgen immgen_inst(
        .inst(inst),
        .imm(imm)
    );
    wire alu_lt_u;
    alu alu_inst(
        .a(a),
        .b(b),
        .alu_ctrl(alu_ctrl),
        .rslt(alu_out),
        .zero_flag(zero_flag),
        .lt_u(alu_lt_u)
    );
    regfile regfile_inst(
        .clk(clk),
        .write_en(regwrite_en),
        .rs1(inst[19:15]),
        .rs2(inst[24:20]),
        .write_reg(inst[11:7]),
        .write_data(write_data),
        .a(rs1),
        .b(rs2)
    );

    assign byte_en = (memstore_ctrl == 4'b0001) ? (4'b0001 << alu_out[1:0]) :
                     (memstore_ctrl == 4'b0011) ? (4'b0011 << {alu_out[1], 1'b0}) :
                     memstore_ctrl;

    always @(*) begin
        case (memstore_ctrl)
            4'b0001: store_data = rs2 << {alu_out[1:0], 3'b000};   // SB
            4'b0011: store_data = rs2 << {alu_out[1],   4'b0000};  // SH (aligned: addr[0] assumed 0)
            default: store_data = rs2;                             // SW
        endcase
    end

    system_bus system_bus_inst(
        .clk(clk),
        .byte_en(byte_en),
        .addr(alu_out),
        .write_data(store_data),
        .write_en(memwrite_en),
        .read_data(mem_data),
        .leds(leds),
        .switches(switches)
    );
    loadext loadext_inst(
        .mem_data(mem_data),
        .memload_ctrl(memload_ctrl),
        .byte_addr(alu_out[1:0]),
        .processed_mem_data(processed_mem_data)
    );
    imem imem_inst(
        .clk(clk),
        .pc(pc_out),
        .inst(inst),

        .load(uart_load),
        .addr(imem_addr),
        .data(uart_data)

    );
    assign instr = inst;

    assign pc_plus_4 = pc_out + 4;
    assign branch_target = pc_out + imm;

    // PC update logic
    wire [1:0] pc_sel;
    assign pc_sel[1] = jalr_ctrl;
    assign pc_sel[0] = jal_ctrl | (branch_en & branch_cond);

    reg branch_cond;
    always @(*) begin
        case (branchcond_ctrl)
            3'b000: branch_cond =  zero_flag;
            3'b001: branch_cond = ~zero_flag;
            3'b100: branch_cond =  alu_out[0];
            3'b101: branch_cond = ~alu_out[0];
            3'b110: branch_cond =  alu_lt_u;
            3'b111: branch_cond = ~alu_lt_u;
            default: branch_cond = 1'b0;
        endcase
    end

    wire [31:0] jalr_target;
    assign jalr_target = {alu_out[31:1], 1'b0};
    always @(*) begin
        case (pc_sel)
            2'b00: pc_next = pc_plus_4;
            2'b01: pc_next = branch_target;
            2'b10: pc_next = jalr_target;
            default: pc_next = pc_plus_4;
        endcase
    end
    
    // ALU Source Mux
    assign a = (auipc_ctrl) ? pc_out : rs1;
    assign b = (bsel_ctrl) ? imm : rs2;

    // Register Writeback Mux
    always @(*) begin
        case(regwrite_ctrl)
            2'b00: write_data = alu_out;              // Standard ALU (ADD, SUB, etc.)
            2'b01: write_data = processed_mem_data;   // Loads (LW)
            2'b10: write_data = pc_plus_4;            // Jumps (JAL, JALR)
            2'b11: write_data = imm;                  // LUI (Load Upper Immediate)
            default: write_data = alu_out;
        endcase
    end

endmodule