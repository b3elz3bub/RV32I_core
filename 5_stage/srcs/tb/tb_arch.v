`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst;
    
    // DMA loader signals (tie to 0 if not using them actively right now)
    reg         dma_load = 0;
    reg  [31:0] dma_data = 0;
    reg  [31:0] dma_addr = 0;

    // Core outputs
    wire [7:0]  leds;
    wire [31:0] uart_addr;
    wire [31:0] uart_write_data;
    wire        uart_write_en;
    wire        uart_read_en;
    reg  [31:0] uart_read_data = 0;

    // HTIF outputs
    wire [31:0] tohost;
    wire        tohost_valid;

    // Instantiate your Top-Level Core
    datapath dut (
        .clk(clk),
        .rst(rst),
        .dma_load(dma_load),
        .dma_data(dma_data),
        .dma_addr(dma_addr),
        .uart_addr(uart_addr),
        .uart_write_data(uart_write_data),
        .uart_write_en(uart_write_en),
        .uart_read_en(uart_read_en),
        .uart_read_data(uart_read_data),
        .leds(leds),
        .switches(8'h00),
        .tohost(tohost),
        .tohost_valid(tohost_valid)
    );

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Simulation Sequence
    reg [255:0] hex_file_path; // String to hold the file path

    initial begin
        // 1. Grab the hex file path from the command prompt
        if (!$value$plusargs("HEX_FILE=%s", hex_file_path)) begin
            $display("ERROR: No hex file provided! Use +HEX_FILE=<path>");
            $finish;
        end
        
        $display("==================================================");
        $display(" Loading test: %s", hex_file_path);
        $display("==================================================");

        // 2. Load the specific hex file into memory
        $readmemh(hex_file_path, dut.imem_inst.mem);
        
        // 3. Apply Reset
        rst = 1;
        #20;
        rst = 0;

        // 4. Timeout safeguard
        #500000; 
        $display("TIMEOUT: Simulation took too long!");
        $finish;
    end

    // Monitor `tohost` to check for test completion
    always @(posedge clk) begin
        if (tohost_valid) begin
            if (tohost == 32'h1) begin
                $display("\n[SUCCESS] Test Passed! (tohost = 1)");
            end else begin
                $display("\n[FAILED] Test Failed! Error Code: %0d", tohost >> 1);
            end
            $finish;
        end
    end

endmodule