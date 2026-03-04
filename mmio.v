module system_bus(
    input clk,
    input [3:0] byte_en,
    input [31:0] addr,
    input [31:0] write_data,
    input write_en,
    input read_en,
    output reg [31:0] read_data,

    output reg [7:0] leds,
    input [7:0] switches
);

    wire io_en;
    assign io_en = (addr<32'h00001000)? 1'b0:1'b1;
    wire [31:0] ram_read_data;

    dmem ram_inst(
        .clk(clk),
        .addr(addr),
        .write_data(write_data),
        .write_en(write_en && !io_en),
        .read_en(read_en),
        .byte_en(byte_en),
        .read_data(ram_read_data)
    );

    always @(*) begin
        if (!io_en) begin
            read_data = ram_read_data;
        end else if (io_en && addr[3:0] == 4'h0) begin
            read_data = {24'b0, leds};
        end else if (io_en && addr[3:0] == 4'h4) begin
            read_data = {24'b0, switches};
        end else begin
            read_data = 32'h0;
        end
    end
    always @(posedge clk) begin
        if (io_en && addr[3:0] == 4'h0) begin
            leds <= write_data[7:0];
        end
    end
endmodule