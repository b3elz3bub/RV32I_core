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

    wire [7:0] cpu_led_out;

    // 2. Pipelined CPU Core
    //    Control unit is now INSIDE the datapath (decoded in ID stage,
    //    control signals pipelined through ID/EX, EX/MEM, MEM/WB).
    datapath cpu_core (
        .clk(cpu_clk),
        .rst(~locked || rst_btn),
        .leds(cpu_led_out),
        .switches(sw),
        .uart_load(1'b0),
        .uart_data(32'd0),
        .imem_addr(32'd0)
    );

    // 3. LED Mapping — identical to single-cycle top
    reg [23:0] heartbeat_cnt;

    assign ld[0] = locked;               // Status: PLL Locked
    assign ld[7] = heartbeat_cnt[23];    // Status: CPU Clocking
    assign ld[6:1] = cpu_led_out[6:1];   // Software: Bits 1-6

    always @(posedge cpu_clk) begin
        if (rst_btn) heartbeat_cnt <= 0;
        else heartbeat_cnt <= heartbeat_cnt + 1;
    end
endmodule
