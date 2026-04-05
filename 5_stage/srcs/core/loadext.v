module loadext(
    input [31:0] mem_data,
    input [2:0] memload_ctrl,
    input [1:0] byte_addr,
    output reg [31:0] processed_mem_data
);

    always @(*) begin
        case(memload_ctrl) // From Control Unit (funct3)
            3'b000: // LB (Byte Signed)
                case(byte_addr[1:0])
                    2'b00: processed_mem_data = {{24{mem_data[7]}},  mem_data[7:0]};
                    2'b01: processed_mem_data = {{24{mem_data[15]}}, mem_data[15:8]};
                    2'b10: processed_mem_data = {{24{mem_data[23]}}, mem_data[23:16]};
                    2'b11: processed_mem_data = {{24{mem_data[31]}}, mem_data[31:24]};
                endcase
            3'b100: // LBU (Byte Unsigned)
                case(byte_addr[1:0])
                    2'b00: processed_mem_data = {24'b0, mem_data[7:0]};
                    2'b01: processed_mem_data = {24'b0, mem_data[15:8]};
                    2'b10: processed_mem_data = {24'b0, mem_data[23:16]};
                    2'b11: processed_mem_data = {24'b0, mem_data[31:24]};
                endcase
            3'b001: // LH (Half-word Signed)
                processed_mem_data = (byte_addr[1]) ? {{16{mem_data[31]}}, mem_data[31:16]} : {{16{mem_data[15]}}, mem_data[15:0]};
            3'b101: // LHU (Half-word Unsigned)
                processed_mem_data = (byte_addr[1]) ? {16'b0, mem_data[31:16]} : {16'b0, mem_data[15:0]};
            default: processed_mem_data = mem_data; // LW
        endcase
    end
endmodule