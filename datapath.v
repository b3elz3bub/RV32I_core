module datapath(
    input clk,
    input rst,
    input [31:0] inst,
    input write_en,
    input [3:0] alu_ctrl,
    
    input uart_load,
    input [31:0] uart_data,
    input [31:0] imem_addr

    output reg [7:0] leds,
    input [7:0] switches
);
    wire[31:0] write_data;
    wire[31:0] a,b;
    reg [31:0] imm;

    wire zero_flag;
    wire[31:0] alu_out;
    
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
    .write_en(write_en),
    .rs1(inst[19:15]),
    .rs2(inst[24:20]),
    .write_reg(inst[11:7]),
    .write_data(write_data),
    .a(a),
    .b(b)
);
system_bus system_bus_inst(
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .write_data(write_data),
    .write_en(write_en),
    .read_data(read_data),
    .leds(leds),
    .switches(switches)
);
imem imem_inst(
    .addr(pc_out),
    .inst(inst),

    .load(uart_load),
    .addr(imem_addr),
    .data(uart_data)

);
pc_add pc_add_inst(
    .pc_in(pc_out),
    .pc_out(pc_next)
);
pc_add4 pc_add4_inst(
    .pc_in(pc_out),
    .pc_out(pc_next)
);

endmodule