`include "params.vh"
// System Bus / MMIO Controller
//
// Memory Map:
//   0x0000_0000 – 0x0000_1FFF  RAM (8 KB, LUTRAM, async read)
//   0x8000_0000                LEDs [7:0]   (R/W, 1 byte)
//   0x8000_0004                Switches [7:0] (R, 1 byte)
//   0x8000_1000                UART data    (R/W)
//   0x8000_1004                UART status  (R)
//   0x8000_2000 – 0x8000_200C  Timer (mtime_lo/hi, mtimecmp_lo/hi)

module system_bus(
    input clk,
    input rst,
    input [3:0] byte_en,
    input [31:0] addr,
    input [31:0] write_data,
    input write_en,
    input read_en,
    output reg [31:0] read_data,

    output reg [7:0] leds,
    input [7:0] switches,

    output [31:0] uart_addr,
    output [31:0] uart_write_data,
    output uart_write_en,
    output uart_read_en,
    input [31:0] uart_read_data,

    output reg [31:0] tohost,
    output reg        tohost_valid,
    // Timer interrupt output (directly from timer peripheral)
    output timer_irq
);

   // ── Address Decode ──
    // Shift the RAM decode up to 0x4000. 8KB space: 0x4000 -> 0x5FFF
    wire is_ram    = (addr >= 32'h00040000 && addr < 32'h00050000); 
    
    wire is_led    = (addr == `ADDR_LED);                   
    wire is_switch = (addr == `ADDR_SW);                    
    wire is_uart   = (addr == `ADDR_UART_DATA) || (addr == `ADDR_UART_STAT);
    wire is_timer  = (addr[31:4] == 28'h8000200);           
    
    // 2. Move tohost to match Linker/Macro/Sail (0x50000)
    wire is_tohost = (addr == 32'h00070000);

    
    wire [31:0] ram_read_data;
    wire [31:0] timer_read_data;

    // ── UART bridge (directly forwarded) ──
    assign uart_addr = addr;
    assign uart_write_data = write_data;
    assign uart_write_en = write_en && is_uart;
    assign uart_read_en = read_en && is_uart;

    // ── Data Memory ──
    dmem ram_inst(
        .clk(clk),
        // Subtract the new base address so BRAM receives a 0-indexed address
        .addr(addr - 32'h00040000), 
        .write_data(write_data),
        .write_en(write_en && is_ram),
        .byte_en(byte_en),
        .read_data(ram_read_data)
    );

    // ── Timer Peripheral ──
    timer timer_inst(
        .clk(clk),
        .rst(rst),
        .addr(addr[3:0]),
        .write_data(write_data),
        .write_en(write_en && is_timer),
        .read_data(timer_read_data),
        .timer_irq(timer_irq)
    );

    // ── Read Multiplexer ──
    always @(*) begin
        if (is_ram)
            read_data = ram_read_data;
        else if (is_led)
            read_data = {24'b0, leds};
        else if (is_switch)
            read_data = {24'b0, switches};
        else if (is_uart)
            read_data = uart_read_data;
        else if (is_timer)
            read_data = timer_read_data;
        else
            read_data = 32'h0;
    end

    // ── LED Write ──
    always @(posedge clk) begin
        if (rst)
            leds <= 8'b0;
        else if (write_en && is_led)
            leds <= write_data[7:0];
    end
    // Inside system_bus.v
    always @(posedge clk) begin
        if (rst) begin
            tohost_valid <= 0;
        end else if (write_en && is_tohost && write_data != 32'h0) begin
            tohost_valid <= 1;
            tohost <= write_data;
        end
    end
endmodule