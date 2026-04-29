`timescale 1ns / 1ps

module tb_trap_flush();

    // System signals
    reg clk;
    reg rst;

    // DMA loader signals
    reg dma_load;
    reg [31:0] dma_data;
    reg [31:0] dma_addr;

    // Dummy IO wires
    wire [31:0] uart_addr;
    wire [31:0] uart_write_data;
    wire uart_write_en;
    wire uart_read_en;
    reg  [31:0] uart_read_data = 0;
    wire [7:0] leds;
    reg  [7:0] switches = 0;

    // Instantiate the Datapath (DUT)
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
        .switches(switches)
    );

    // Clock generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // DMA Bootloader Task
    task load_inst(input [31:0] addr, input [31:0] inst);
        begin
            @(posedge clk);
            dma_load = 1;
            dma_addr = addr;
            dma_data = inst;
        end
    endtask

    initial begin
        // 1. Assert Reset
        rst = 1;
        dma_load = 0;
        #20;
        rst = 0;

        // 2. Load the test program via DMA backdoor
        
        //Main Program
        // 0x00: li x2, 0x20      (Set trap handler address)
        load_inst(32'h00, 32'h02000113); 
        // 0x04: csrrw x0, mtvec, x2 (Write to mtvec)
        load_inst(32'h04, 32'h30511073); 
        // 0x08: li x3, 1         (x3 = 1)
        load_inst(32'h08, 32'h00100193); 
        // 0x0C: ecall            (TRIGGER TRAP! Pipeline should flush EX_MEM)
        load_inst(32'h0C, 32'h00000073); 
        // 0x10: addi x3, x3, 2    (This should NOT execute until after mret!)
        load_inst(32'h10, 32'h00218193); 
        
        //TRAP HANDLER (at 0x20) 
        // 0x20: li x4, 10         (x4 = 10, proves we entered handler)
        load_inst(32'h20, 32'h00a00213); 
        // 0x24: mret              (Return from trap)
        load_inst(32'h24, 32'h30200073); 

        // Turn off DMA and let CPU run
        @(posedge clk);
        dma_load = 0;

        // Let it run for 30 cycles to watch the trap occur
        #300;
        $finish;
    end

endmodule
