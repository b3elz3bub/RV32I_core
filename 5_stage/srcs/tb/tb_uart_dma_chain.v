`timescale 1ns / 1ps

module tb_uart_dma_chain();

    //SYstem Signals
    reg clk;
    reg rst;
    reg toggle;
    
    //Wires connecting the modules
    wire serial_line;       // The physical wire between Laptop (TX) and FPGA (RX)
    wire [7:0] rx_byte;     // From RX to DMA
    wire rx_valid;          // From RX to DMA
    
    //DMA outputs
    wire imem_load;
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire addr_captured;

    //Laptop as Tx
    reg tx_en;
    reg [7:0] tx_byte;
    wire tx_busy;
    
    uart_tx #(.CLKS_PER_BIT(87)) laptop_tx (
        .clk(clk),
        .tx_en(tx_en),
        .tx_byte(tx_byte),
        .tx_pin(serial_line),
        .tx_busy(tx_busy)
    );

    //FPGA RX Module
    uart_rx #(.CLKS_PER_BIT(87)) fpga_rx (
        .clk(clk),
        .rx_pin(serial_line),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );

    //DMA Module
    uart_dma fpga_dma (
        .clk(clk),
        .rst(rst),
        .toggle(toggle),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),
        .imem_load(imem_load),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .addr_captured(addr_captured)
    );

    //Clock Generation 
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    //Task to Send a Serial Byte
    // This tells the "laptop" to start sending and waits until it finishes
    task send_serial_byte;
        input [7:0] data;
        begin
            @(posedge clk);
            tx_byte = data;
            tx_en = 1'b1;
            @(posedge clk);
            tx_en = 1'b0;
            
            // Wait for the TX module to finish sending all 10 bits
            @(negedge tx_busy); 
            
            // Give a tiny gap between bytes like a real PC would
            repeat(100) @(posedge clk);
        end
    endtask

    //Main Test Sequence
    initial begin
        // 1. Initialize
        rst = 1;
        toggle = 0;
        tx_en = 0;
        tx_byte = 0;
        #100;
        
        rst = 0;
        #100;

        // 2. Enter DMA Mode
        @(posedge clk);
        toggle = 1;
        #100;

        // 3. Send Base Address: 0x00000000
        $display("[%0t] Sending Base Address...", $time);
        send_serial_byte(8'h00);
        send_serial_byte(8'h00);
        send_serial_byte(8'h00);
        send_serial_byte(8'h00);
      
        // 4. Send First Data Word: 0xDEADBEEF
        $display("[%0t] Sending Data Word 1...", $time);
        send_serial_byte(8'hDE);
        send_serial_byte(8'hAD);
        send_serial_byte(8'hBE);
        send_serial_byte(8'hEF);

        // 5. Send Second Data Word: 0xCAFEBABE
        $display("[%0t] Sending Data Word 2...", $time);
        send_serial_byte(8'hCA);
        send_serial_byte(8'hFE);
        send_serial_byte(8'hBA);
        send_serial_byte(8'hBE);

        // 6. Wait and Observe
        // Give the RX module time to finish the final stop bit
        repeat(2000) @(posedge clk); 

        // 7. Exit DMA Mode
        toggle = 0;

        // Wait a bit longer before closing
        #5000; 
        $display("[%0t] Test Complete.", $time);
        $finish;
    end

endmodule
