module system_bus(
    input clk,
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
    input [31:0] uart_read_data
);

    // 1. Explicit Address Map (Matches your C code)
    wire is_ram    = (addr < 32'h00001000);
    wire is_led    = (addr == 32'h00001000);
    wire is_switch = (addr == 32'h00002000); 
    wire is_uart   = (addr == 32'h00003000) || (addr == 32'h00003004);

    wire [31:0] ram_read_data;

    assign uart_addr = addr;
    assign uart_write_data = write_data;
    assign uart_write_en = write_en && is_uart;
    assign uart_read_en = read_en && is_uart;

    // 2. Data Memory Instance
    dmem ram_inst(
        .clk(clk),
        .addr(addr),
        .write_data(write_data),
        .write_en(write_en && is_ram), // Only write if address is in RAM range
        .byte_en(byte_en),
        .read_data(ram_read_data)
    );

    // 3. The Read Multiplexer
    always @(*) begin
        if (is_ram) begin
            read_data = ram_read_data;
        end else if (is_led) begin
            read_data = {24'b0, leds};     // Read back LED state
        end else if (is_switch) begin
            read_data = {24'b0, switches}; // Read physical switches
        end else if (is_uart) begin
            read_data = uart_read_data;
        end else begin
            read_data = 32'h0;             // Default/Safe fallback
        end
    end

    // 4. The Write Demultiplexer
    always @(posedge clk) begin
        if (write_en && is_led) begin
            leds <= write_data[7:0];
        end
    end
endmodule