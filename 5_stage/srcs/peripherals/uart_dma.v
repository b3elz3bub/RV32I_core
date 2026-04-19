module uart_dma(
    input clk,
    input rst,
    input toggle,   // 1 -> accept UART data and write IMEM
    input [7:0] rx_byte,
    input rx_valid,
    output reg imem_load,
    output reg [31:0] imem_addr,
    output reg [31:0] imem_data,
    output reg addr_captured
);
    reg [1:0]  addr_byte_count;
    reg [1:0]  data_byte_count;
    reg [31:0] addr_shift_reg;
    reg [31:0] data_shift_reg;
    reg [31:0] next_imem_addr;
    reg        write_pending;

    always @(posedge clk) begin
        imem_load <= 1'b0;

        if (rst) begin
            imem_load <= 1'b0;
            imem_addr <= 32'd0;
            imem_data <= 32'd0;
            addr_captured <= 1'b0;
            addr_byte_count <= 2'd0;
            data_byte_count <= 2'd0;
            addr_shift_reg <= 32'd0;
            data_shift_reg <= 32'd0;
            next_imem_addr <= 32'd0;
            write_pending <= 1'b0;
        end else if (!toggle) begin
            // Reset framing outside DMA mode so the next session begins
            // with a fresh 32-bit start address.
            imem_addr <= 32'd0;
            imem_data <= 32'd0;
            addr_captured <= 1'b0;
            addr_byte_count <= 2'd0;
            data_byte_count <= 2'd0;
            addr_shift_reg <= 32'd0;
            data_shift_reg <= 32'd0;
            next_imem_addr <= 32'd0;
            write_pending <= 1'b0;
        end else begin
            if (write_pending) begin
                imem_load <= 1'b1;
                write_pending <= 1'b0;
            end

            if (rx_valid) begin
                if (!addr_captured) begin
                    addr_shift_reg <= {addr_shift_reg[23:0], rx_byte};

                    if (addr_byte_count == 2'd3) begin
                        next_imem_addr <= {addr_shift_reg[23:0], rx_byte};
                        addr_captured <= 1'b1;
                        addr_byte_count <= 2'd0;
                    end else begin
                        addr_byte_count <= addr_byte_count + 2'd1;
                    end
                end else begin
                    data_shift_reg <= {data_shift_reg[23:0], rx_byte};

                    if (data_byte_count == 2'd3) begin
                        imem_addr <= next_imem_addr;
                        imem_data <= {data_shift_reg[23:0], rx_byte};
                        next_imem_addr <= next_imem_addr + 32'd4;
                        write_pending <= 1'b1;
                        data_byte_count <= 2'd0;
                    end else begin
                        data_byte_count <= data_byte_count + 2'd1;
                    end
                end
            end
        end
    end
endmodule
