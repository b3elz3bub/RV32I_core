module datapath(
    input clk,
    input rst,
    input [31:0] inst,
    input regwrite_ctrl,
    input memwrite_ctrl,
    input [3:0] alu_ctrl,
    input bsel_ctrl,
    input reginp_ctrl,
    input branch_ctrl,
    input memread_ctrl,
    
    input uart_load,
    input [31:0] uart_data,
    input [31:0] imem_addr

    output reg [7:0] leds,
    input [7:0] switches
);

    wire[31:0] pc_next, pc_out;
    wire[31:0] branch_target;
    wire[31:0] pc_plus_4;

    wire[31:0] write_data;
    wire[31:0] a,b,rs2;
    wire[31:0] imm;

    wire zero_flag;
    wire[31:0] alu_out;

    wire[31:0] mem_data;

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
    alu alu_inst(
        .a(a),
        .b(b),
        .alu_ctrl(alu_ctrl),
        .rslt(alu_out),
        .zero_flag(zero_flag)
    );
    regfile regfile_inst(
        .clk(clk),
        .write_en(regwrite_ctrl),
        .rs1(inst[19:15]),
        .rs2(inst[24:20]),
        .write_reg(inst[11:7]),
        .write_data(write_data),
        .a(a),
        .b(rs2)
    );
    system_bus system_bus_inst(
        .clk(clk),
        .rst(rst),
        .addr(alu_out),
        .write_data(write_data),
        .write_en(memwrite_ctrl),
        .read_data(mem_data),
        .leds(leds),
        .switches(switches)
    );
    imem imem_inst(
        .pc(pc_out),
        .inst(inst),

        .load(uart_load),
        .addr(imem_addr),
        .data(uart_data)

    );

    assign pc_plus_4 = pc_out + 4;
    assign branch_target = pc_out + imm;

    always @(*) begin
        // PC Mux
        assign pc_next = (branch_ctrl && zero_flag) ? branch_target : pc_plus_4;

        // ALU B-Source Mux
        assign b = (bsel_ctrl) ? imm : rs2;

        // Writeback Mux
        assign write_data = (reginp_ctrl) ? mem_data : alu_out;
    end
endmodule