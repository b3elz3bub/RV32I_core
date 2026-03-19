module uart_rx #(
    parameter CLKS_PER_BIT = 87
)(
    input            clk,
    input            rx_pin,
    output reg [7:0] rx_byte,
    output reg       rx_valid
);

    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state = IDLE;
    
    reg [15:0] clock_count = 0;
    reg [2:0]  bit_index = 0;
    
    always @(posedge clk) begin
        // Default
        rx_valid <= 1'b0;
        
        case (state)
            IDLE: begin
                clock_count <= 0;
                bit_index <= 0;
                if (rx_pin == 1'b0) state <= START; // Start bit detected
            end
            
            START: begin
                if (clock_count == (CLKS_PER_BIT/2)) begin
                    if (rx_pin == 1'b0) begin
                        clock_count <= 0;
                        state <= DATA;
                    end else state <= IDLE;
                end else clock_count <= clock_count + 1;
            end
            
            DATA: begin
                if (clock_count == CLKS_PER_BIT - 1) begin
                    clock_count <= 0;
                    rx_byte[bit_index] <= rx_pin;
                    if (bit_index < 7) bit_index <= bit_index + 1;
                    else state <= STOP;
                end else clock_count <= clock_count + 1;
            end
            
            STOP: begin
                if (clock_count == CLKS_PER_BIT - 1) begin
                    rx_valid <= 1'b1;
                    state <= IDLE;
                end else clock_count <= clock_count + 1;
            end
            
            default: state <= IDLE;
        endcase
    end
endmodule