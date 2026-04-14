module csr_file (
    input wire clk,
    input wire rst,
    
    // --- Software (Instruction) Ports ---
    input wire [11:0] csr_addr,   // 12-bit CSR address from instr[31:20]
    input wire [31:0] wdata,      // Data to write (from rs1 or zimm)
    input wire [1:0]  csr_op,     // Operation: 01=Write, 10=Set, 11=Clear
    input wire        csr_we,     // Write Enable from control unit
    output reg [31:0] rdata,      // Data read from CSR, goes to Write-Back stage
    
    input wire        inst_retire,// High when a valid instruction finishes WB stage

    // --- NEW: Hardware Trap Ports ---
    input wire        trap_en,    // High when an exception/ECALL occurs
    input wire [31:0] trap_pc,    // The PC of the trapping instruction
    input wire [31:0] trap_cause  // The exception code
);

    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;
    
    always @(*) begin
        case (csr_addr)
            // Added M-Mode (0xB--) alongside User-Mode (0xC--)
            12'hB00, 12'hC00: rdata = cycle_cnt[31:0];   // mcycle / cycle
            12'hB80, 12'hC80: rdata = cycle_cnt[63:32];  // mcycleh / cycleh
            12'hB02, 12'hC02: rdata = instret_cnt[31:0]; // minstret / instret
            12'hB82, 12'hC82: rdata = instret_cnt[63:32];// minstreth / instreth
            
            12'h300: rdata = mstatus;
            12'h305: rdata = mtvec;
            12'h341: rdata = mepc;
            12'h342: rdata = mcause;
            default: rdata = 32'b0; // Unknown CSRs read as 0
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            cycle_cnt   <= 64'b0;
            instret_cnt <= 64'b0;
            mstatus     <= 32'b0;
            mtvec       <= 32'b0;
            mepc        <= 32'b0;
            mcause      <= 32'b0;
        end else begin
            
            // --- Counters ---
            cycle_cnt <= cycle_cnt + 1'b1; 
            
            if (inst_retire) begin
                instret_cnt <= instret_cnt + 1'b1; 
            end

            // --- Hardware Trap Handling (Highest Priority) ---
            if (trap_en) begin
                mepc   <= trap_pc;
                mcause <= trap_cause;
            end 
            // --- Software CSR Instructions ---
            else if (csr_we) begin
                case (csr_addr)
                    12'h300: mstatus <= (csr_op == 2'b01) ? wdata : 
                                        (csr_op == 2'b10) ? (mstatus | wdata) : 
                                        (csr_op == 2'b11) ? (mstatus & ~wdata) : mstatus;
                                        
                    12'h305: mtvec   <= (csr_op == 2'b01) ? wdata : 
                                        (csr_op == 2'b10) ? (mtvec | wdata) : 
                                        (csr_op == 2'b11) ? (mtvec & ~wdata) : mtvec;
                                        
                    12'h341: mepc    <= (csr_op == 2'b01) ? wdata : 
                                        (csr_op == 2'b10) ? (mepc | wdata) : 
                                        (csr_op == 2'b11) ? (mepc & ~wdata) : mepc;
                                        
                    12'h342: mcause  <= (csr_op == 2'b01) ? wdata : 
                                        (csr_op == 2'b10) ? (mcause | wdata) : 
                                        (csr_op == 2'b11) ? (mcause & ~wdata) : mcause;
                endcase
            end
        end
    end
endmodule