module uart_peripheral #(
    parameter CLKS_PER_BIT = 87,
    parameter UART_DATA_ADDR   = 32'h00003000,
    parameter UART_STATUS_ADDR = 32'h00003004
)(
    input clk,
    input rst,
    input bus_enable,
    input [31:0] bus_addr,
    input [31:0] bus_write_data,
    input bus_write_en,
    input bus_read_en,
    output reg [31:0] bus_read_data,

    input rx_pin,
    output tx_pin,

    output [7:0] dma_rx_byte,
    output dma_rx_valid
);
    wire [7:0] rx_byte_raw;
    wire       rx_valid_raw;
    reg  [7:0] rx_data_reg;
    reg        rx_ready;

    reg        tx_en;
    reg  [7:0] tx_byte;
    wire       tx_busy;

    wire is_uart_data   = (bus_addr == UART_DATA_ADDR);
    wire is_uart_status = (bus_addr == UART_STATUS_ADDR);

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_rx_inst (
        .clk(clk),
        .rx_pin(rx_pin),
        .rx_byte(rx_byte_raw),
        .rx_valid(rx_valid_raw)
    );

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_tx_inst (
        .clk(clk),
        .tx_en(tx_en),
        .tx_byte(tx_byte),
        .tx_pin(tx_pin),
        .tx_busy(tx_busy)
    );

    assign dma_rx_byte = rx_byte_raw;
    assign dma_rx_valid = rx_valid_raw;

    always @(*) begin
        tx_en = 1'b0;
        tx_byte = bus_write_data[7:0];

        if (bus_enable && bus_write_en && is_uart_data && !tx_busy) begin
            tx_en = 1'b1;
        end
    end

    always @(*) begin
        if (bus_enable && is_uart_data) begin
            bus_read_data = {24'b0, rx_data_reg};
        end else if (bus_enable && is_uart_status) begin
            bus_read_data = {30'b0, tx_busy, rx_ready};
        end else begin
            bus_read_data = 32'h00000000;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            rx_data_reg <= 8'd0;
            rx_ready <= 1'b0;
        end else begin
            if (rx_valid_raw) begin
                rx_data_reg <= rx_byte_raw;
                rx_ready <= 1'b1;
            end

            if (bus_enable && bus_read_en && is_uart_data) begin
                rx_ready <= 1'b0;
            end
        end
    end
endmodule
