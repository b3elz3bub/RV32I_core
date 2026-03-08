module top(
    input clk_100m,     // From ZedBoard Oscillator
    input rst_btn,      // Physical button
    input [7:0] sw,     // Physical switches
    output [7:0] ld     // Physical LEDs
);
    wire cpu_clk;
    wire locked;

    // 1. Clock Wizard IP (100MHz -> 10MHz)
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100m),
        .clk_out1(cpu_clk),
        .reset(rst_btn),
        .locked(locked)
    );

    wire [31:0] inst;
    wire [1:0] regwrite_ctrl;
    wire regwrite_en;
    wire memwrite_en;
    wire [2:0] memload_ctrl;
    wire [3:0] memstore_ctrl;
    wire [3:0] alu_ctrl;
    wire auipc_ctrl;
    wire bsel_ctrl;
    wire branch_en;
    wire [2:0] branchcond_ctrl;
    wire jal_ctrl;
    wire jalr_ctrl;

    datapath cpu_core (
        .clk(cpu_clk),
        .rst(~locked || rst_btn),
        .leds(ld),
        .switches(sw),
        .instr(inst),
        .regwrite_ctrl(regwrite_ctrl),
        .regwrite_en(regwrite_en),
        .memwrite_en(memwrite_en),
        .memload_ctrl(memload_ctrl),
        .memstore_ctrl(memstore_ctrl),
        .alu_ctrl(alu_ctrl),
        .auipc_ctrl(auipc_ctrl),
        .bsel_ctrl(bsel_ctrl),
        .branch_en(branch_en),
        .branchcond_ctrl(branchcond_ctrl),
        .jal_ctrl(jal_ctrl),
        .jalr_ctrl(jalr_ctrl),
        .uart_load(),
        .uart_data(),
        .imem_addr()
    );

    control cpu_ctrl (
        .inst(inst),
        .regwrite_ctrl(regwrite_ctrl),
        .regwrite_en(regwrite_en),
        .memwrite_en(memwrite_en),
        .memload_ctrl(memload_ctrl),
        .memstore_ctrl(memstore_ctrl),
        .alu_ctrl(alu_ctrl),
        .auipc_ctrl(auipc_ctrl),
        .bsel_ctrl(bsel_ctrl),
        .branch_en(branch_en),
        .branchcond_ctrl(branchcond_ctrl),
        .jal_ctrl(jal_ctrl),
        .jalr_ctrl(jalr_ctrl)
    );

    assign ld[0]=locked;
    reg [23:0] heartbeat_cnt;
    always @(posedge cpu_clk) begin
        if (rst_btn) heartbeat_cnt <= 0;
        else heartbeat_cnt <= heartbeat_cnt+1;
    end
    
    assign ld[7] = heartbeat_cnt[23];
endmodule