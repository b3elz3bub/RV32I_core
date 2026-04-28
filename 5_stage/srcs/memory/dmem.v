module dmem(
    input clk,
    input [31:0] addr,
    input [31:0] write_data,
    input write_en,
    input [3:0] byte_en,
    output [31:0] read_data
);
    // Expanded to 16,384 entries per bank (64 KB total)
    reg [7:0] mem0[0:16383];
    reg [7:0] mem1[0:16383];
    reg [7:0] mem2[0:16383];
    reg [7:0] mem3[0:16383];

    // Synchronous write
    always @(posedge clk) begin
        if (write_en) begin
            // Address bits [15:2] provide the 14-bit index required for 16384 entries
            if (byte_en[0]) mem0[addr[15:2]] <= write_data[7:0];
            if (byte_en[1]) mem1[addr[15:2]] <= write_data[15:8];
            if (byte_en[2]) mem2[addr[15:2]] <= write_data[23:16];
            if (byte_en[3]) mem3[addr[15:2]] <= write_data[31:24];
        end
    end

    // Asynchronous read — data available in the same cycle the address is presented.
    assign read_data = {mem3[addr[15:2]], mem2[addr[15:2]], mem1[addr[15:2]], mem0[addr[15:2]]};

endmodule