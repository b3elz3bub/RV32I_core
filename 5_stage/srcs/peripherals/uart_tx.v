module uart_tx #(
    parameter CLKS_PER_BIT = 87
)(
    input       clk,
    input       tx_en,
    input [7:0] tx_byte,
    output reg  tx_pin = 1'b1,
    output reg  tx_busy = 1'b0
);

    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] state = IDLE;
    
    reg [15:0] clock_count = 0;
    reg [2:0]  bit_index = 0;
    reg [7:0]  data_reg = 0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                tx_pin <= 1'b1;
                tx_busy <= 1'b0;
                clock_count <= 0;
                bit_index <= 0;
                
                if (tx_en) begin
                    data_reg <= tx_byte;
                    tx_busy <= 1'b1;
                    state <= START;
                end
            end
            
            START: begin
                tx_pin <= 1'b0; // Send Start Bit
                if (clock_count == CLKS_PER_BIT - 1) begin
                    clock_count <= 0;
                    state <= DATA;
                end else clock_count <= clock_count + 1;
            end
            
            DATA: begin
                tx_pin <= data_reg[bit_index];
                if (clock_count == CLKS_PER_BIT - 1) begin
                    clock_count <= 0;
                    if (bit_index < 7) bit_index <= bit_index + 1;
                    else state <= STOP;
                end else clock_count <= clock_count + 1;
            end
            
            STOP: begin
                tx_pin <= 1'b1; // Send Stop Bit
                if (clock_count == CLKS_PER_BIT - 1) begin
                    state <= IDLE;
                end else clock_count <= clock_count + 1;
            end
            
            default: state <= IDLE;
        endcase
    end
endmodule