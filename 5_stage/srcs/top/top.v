module top(
    input clk_100m,     // From ZedBoard Oscillator
    input rst_btn,      // Physical button
    input [7:0] sw,     // Physical switches
    input uart_rx_pin,
    input uart_dma_toggle,
    output uart_tx_pin,
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
    wire [31:0] uart_addr;
    wire [31:0] uart_write_data;
    wire        uart_write_en;
    wire        uart_read_en;
    wire [31:0] uart_read_data;
    wire [7:0]  uart_dma_rx_byte;
    wire        uart_dma_rx_valid;
    wire        uart_imem_load;
    wire [31:0] uart_imem_addr;
    wire [31:0] uart_imem_data;
    wire        uart_addr_captured;

    uart_peripheral uart_io (
        .clk(cpu_clk),
        .rst(~locked || rst_btn),
        .bus_enable(~uart_dma_toggle),
        .bus_addr(uart_addr),
        .bus_write_data(uart_write_data),
        .bus_write_en(uart_write_en),
        .bus_read_en(uart_read_en),
        .bus_read_data(uart_read_data),
        .rx_pin(uart_rx_pin),
        .tx_pin(uart_tx_pin),
        .dma_rx_byte(uart_dma_rx_byte),
        .dma_rx_valid(uart_dma_rx_valid)
    );

    uart_dma uart_loader (
        .clk(cpu_clk),
        .rst(~locked || rst_btn),
        .toggle(uart_dma_toggle),
        .rx_byte(uart_dma_rx_byte),
        .rx_valid(uart_dma_rx_valid),
        .imem_load(uart_imem_load),
        .imem_addr(uart_imem_addr),
        .imem_data(uart_imem_data),
        .addr_captured(uart_addr_captured)
    );

    // 2. Pipelined CPU Core
    //    timer_irq is generated inside system_bus (which is inside the datapath)
    //    and fed back into the CSR file — all internal wiring.
    datapath cpu_core (
        .clk(cpu_clk),
        .rst(~locked || rst_btn || uart_dma_toggle),
        .leds(cpu_led_out),
        .switches(sw),
        .dma_load(uart_imem_load),
        .dma_data(uart_imem_data),
        .dma_addr(uart_imem_addr),
        .uart_addr(uart_addr),
        .uart_write_data(uart_write_data),
        .uart_write_en(uart_write_en),
        .uart_read_en(uart_read_en),
        .uart_read_data(uart_read_data)
    );

    // 3. LED Mapping — identical to single-cycle top
    reg [23:0] heartbeat_cnt;

    assign ld[0] = locked;               // Status: PLL Locked
    assign ld[7] = heartbeat_cnt[23];    // Status: CPU Clocking
    assign ld[6:1] = cpu_led_out[6:1];   // Software: Bits 1-4

    always @(posedge cpu_clk) begin
        if (rst_btn) heartbeat_cnt <= 0;
        else heartbeat_cnt <= heartbeat_cnt + 1;
    end
endmodule
