`timescale 1ns / 1ps

module tb_datapath();

    // =========================================================================
    //  Signals
    // =========================================================================

    reg clk;
    reg rst;

    // Tie off UART loader inputs to zero
    wire        uart_load = 1'b0;
    wire [31:0] uart_data = 32'b0;
    wire [31:0] imem_addr = 32'b0;

    // Tie off UART MMIO read
    wire [31:0] uart_read_data = 32'b0;

    // IO
    reg [7:0]   switches;
    wire [7:0]  leds;

    // Outputs from DUT
    wire [31:0] uart_addr;
    wire [31:0] uart_write_data;
    wire        uart_write_en;
    wire        uart_read_en;

    // =========================================================================
    //  Device Under Test (DUT)
    // =========================================================================

    datapath dut (
        .clk(clk),
        .rst(rst),
        .uart_load(uart_load),
        .uart_data(uart_data),
        .imem_addr(imem_addr),
        .uart_addr(uart_addr),
        .uart_write_data(uart_write_data),
        .uart_write_en(uart_write_en),
        .uart_read_en(uart_read_en),
        .uart_read_data(uart_read_data),
        .leds(leds),
        .switches(switches)
    );

    // =========================================================================
    //  Clock Generation
    // =========================================================================
    
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    //  Stimulus & Execution
    // =========================================================================

    initial begin
        // 1. Setup VCD dumping
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_datapath);

        // 2. Initialize
        switches = 8'hFF;
        
        // 3. Assert Reset
        rst = 1'b1;
        repeat(3) @(posedge clk);
        
        // 4. Release Reset - CPU starts fetching from PC = 0
        @(posedge clk);
        rst = 1'b0;

        // 5. Let it run for 100 clock cycles (adjust as needed for your program)
        repeat(3000) @(posedge clk);

        $display("[%0t] Simulation complete.", $time);
        $finish;
    end

    // =========================================================================
    //  MMIO Bus Monitor
    // =========================================================================
    always @(posedge clk) begin
        if (uart_write_en) begin
            $display("[%0t] MMIO WRITE: Addr = %h, Data = %h", $time, uart_addr, uart_write_data);
        end
    end

endmodule