module dmem(
    input clk,
    input [31:0] addr,
    input [31:0] write_data,
    input write_en,
    input read_en,
    input [3:0] byte_en,
    output [31:0] read_data
);
    reg [7:0] mem0[0:1023];
    reg [7:0] mem1[0:1023];
    reg [7:0] mem2[0:1023];
    reg [7:0] mem3[0:1023];
    assign read_data = {mem3[addr[11:2]], mem2[addr[11:2]], mem1[addr[11:2]], mem0[addr[11:2]]};
    always @(posedge clk) begin
        if (write_en) begin
            if (byte_en[0]) begin
                mem0[addr[11:2]] <= write_data[7:0];
            end
            if (byte_en[1]) begin
                mem1[addr[11:2]] <= write_data[15:8];
            end
            if (byte_en[2]) begin
                mem2[addr[11:2]] <= write_data[23:16];
            end
            if (byte_en[3]) begin
                mem3[addr[11:2]] <= write_data[31:24];
            end
        end
    end
endmodule