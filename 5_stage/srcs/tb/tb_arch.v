`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst;
    
    // DMA loader signals
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

    // ----------------------------------------------------
    // SIMULATION BOOTLOADER
    // ----------------------------------------------------
    reg [1023:0] mem_file_path; 
    
    // Create a 512 KB temporary unified memory to hold the raw .mem file
    // 131,072 words is massive enough to catch the 0x50000 tohost boundary
    reg [31:0] temp_mem [0:131071]; 
    integer i;

    initial begin
        // 1. Grab the file path
        if (!$value$plusargs("HEX_FILE=%s", mem_file_path)) begin
            $display("ERROR: No .mem file provided!");
            $finish;
        end
        
        $display("==================================================");
        $display(" Loading test: %s", mem_file_path);
        $display("==================================================");

        // 2. Load the ENTIRE unified file into our massive temporary memory
        $readmemh(mem_file_path, temp_mem);

        // 3. Flash Instruction Memory (VMA: 0x00000000)
        // Copy the first 256 KB (65,536 words) into your imem array
        for (i = 0; i < 65536; i = i + 1) begin
            dut.imem_inst.mem[i] = temp_mem[i];
        end

        // 4. Flash Data Memory (VMA: 0x00040000 -> Word Index: 65536)
        // Your dmem holds 64 KB (16,384 words). Copy them byte-by-byte into the 4 banks.
        for (i = 0; i < 16384; i = i + 1) begin
            dut.system_bus_inst.ram_inst.mem0[i] = temp_mem[65536 + i][7:0];
            dut.system_bus_inst.ram_inst.mem1[i] = temp_mem[65536 + i][15:8];
            dut.system_bus_inst.ram_inst.mem2[i] = temp_mem[65536 + i][23:16];
            dut.system_bus_inst.ram_inst.mem3[i] = temp_mem[65536 + i][31:24];
        end
        
        $display("Memory flashing complete. Booting core...");

        // 5. Apply Reset
        rst = 1;
        #20;
        rst = 0;

        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
        // 6. Timeout safeguard
        #5000000; 
        $display("TIMEOUT: Simulation took too long!");
        $display("FINAL PC: %h", dut.if_pc);
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