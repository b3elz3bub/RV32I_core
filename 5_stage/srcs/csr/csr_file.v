`include "params.vh"
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

    // --- Hardware Trap Ports ---
    input wire        trap_en,    // High when an exception/ECALL occurs (from pipeline)
    input wire [31:0] trap_pc,    // The PC of the trapping instruction
    input wire [31:0] trap_cause, // The exception code

    // --- MRET Port ---
    input wire        mret_en,    // High when MRET instruction executes

    // --- External Interrupt Inputs ---
    input wire        timer_irq,  // From timer peripheral (level-triggered)

    // --- Interrupt Decision Output ---
    output wire       take_interrupt, // To datapath: redirect PC to mtvec NOW

    // --- PC Redirect Outputs ---
    output wire [31:0] mtvec_out, // Trap vector base address
    output wire [31:0] mepc_out   // Return address for MRET
);

    // =====================================================================
    //  CSR Registers
    // =====================================================================
    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [31:0] mstatus;    // [3]=MIE (global interrupt enable), [7]=MPIE (previous MIE)
    reg [31:0] mie;        // [7]=MTIE (machine timer interrupt enable)
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;

    // mip is partially hardwired — bit 7 (MTIP) reflects the timer_irq line
    wire [31:0] mip = {24'b0, timer_irq, 7'b0};  // bit 7 = MTIP

    // =====================================================================
    //  Interrupt Decision
    // =====================================================================
    // Take an interrupt when: global interrupts enabled AND timer interrupt
    // is both enabled AND pending.
    // This is a level signal — the datapath samples it once to inject the trap.
    assign take_interrupt = mstatus[3]    // MIE — global enable
                          & mie[7]        // MTIE — timer interrupt enable
                          & mip[7];       // MTIP — timer interrupt pending

    // =====================================================================
    //  Direct Outputs
    // =====================================================================
    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // =====================================================================
    //  CSR Read Mux (combinational)
    // =====================================================================
    always @(*) begin
        case (csr_addr)
            // Performance counters (M-mode + U-mode aliases)
            `CSR_MCYCLE,   `CSR_CYCLE:    rdata = cycle_cnt[31:0];
            `CSR_MCYCLEH,  `CSR_CYCLEH:   rdata = cycle_cnt[63:32];
            `CSR_MINSTRET, `CSR_INSTRET:  rdata = instret_cnt[31:0];
            `CSR_MINSTRETH,`CSR_INSTRETH: rdata = instret_cnt[63:32];
            
            // Machine-mode trap CSRs
            `CSR_MSTATUS:  rdata = mstatus;
            `CSR_MIE:      rdata = mie;
            `CSR_MTVEC:    rdata = mtvec;
            `CSR_MSCRATCH: rdata = mscratch;
            `CSR_MEPC:     rdata = mepc;
            `CSR_MCAUSE:   rdata = mcause;
            `CSR_MIP:      rdata = mip;       // Read-only (hardwired to timer_irq)
            default:       rdata = 32'b0;
        endcase
    end

    // =====================================================================
    //  CSR Write Logic (sequential)
    // =====================================================================
    // Priority: reset > hardware trap > mret > software CSR instruction
    //
    // On trap entry (trap_en OR take_interrupt triggers this via the datapath):
    //   mepc   ← trap_pc (PC of interrupted/faulting instruction)
    //   mcause ← trap_cause
    //   mstatus.MPIE ← mstatus.MIE  (save current interrupt state)
    //   mstatus.MIE  ← 0            (disable interrupts in handler)
    //
    // On mret:
    //   mstatus.MIE  ← mstatus.MPIE (restore interrupt state)
    //   mstatus.MPIE ← 1

    // Helper: apply CSR write/set/clear operation
    function [31:0] csr_apply;
        input [31:0] old_val;
        input [31:0] new_val;
        input [1:0]  op;
        begin
            case (op)
                2'b01:   csr_apply = new_val;              // CSRRW
                2'b10:   csr_apply = old_val | new_val;    // CSRRS
                2'b11:   csr_apply = old_val & ~new_val;   // CSRRC
                default: csr_apply = old_val;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            cycle_cnt   <= 64'b0;
            instret_cnt <= 64'b0;
            mstatus     <= 32'b0;       // MIE=0: interrupts disabled on reset
            mie         <= 32'b0;
            mtvec       <= 32'b0;
            mscratch    <= 32'b0;
            mepc        <= 32'b0;
            mcause      <= 32'b0;
        end else begin
            
            // --- Counters (always run) ---
            cycle_cnt <= cycle_cnt + 1'b1; 
            
            if (inst_retire) begin
                instret_cnt <= instret_cnt + 1'b1; 
            end

            // --- Hardware Trap Entry (Highest Priority) ---
            // This covers both synchronous traps (ecall) and asynchronous
            // interrupts. The datapath asserts trap_en for both cases and
            // supplies the appropriate trap_pc and trap_cause.
            if (trap_en) begin
                mepc    <= trap_pc;
                mcause  <= trap_cause;
                // Save and disable interrupts
                mstatus[7] <= mstatus[3];   // MPIE ← MIE
                mstatus[3] <= 1'b0;         // MIE  ← 0
            end
            // --- MRET (restore interrupt state) ---
            else if (mret_en) begin
                mstatus[3] <= mstatus[7];   // MIE  ← MPIE
                mstatus[7] <= 1'b1;         // MPIE ← 1
            end
            // --- Software CSR Instructions ---
            else if (csr_we) begin
                case (csr_addr)
                    `CSR_MSTATUS: mstatus  <= csr_apply(mstatus, wdata, csr_op);
                    `CSR_MIE:     mie      <= csr_apply(mie, wdata, csr_op);
                    `CSR_MTVEC:   mtvec    <= csr_apply(mtvec, wdata, csr_op);
                    `CSR_MSCRATCH:mscratch <= csr_apply(mscratch, wdata, csr_op);
                    `CSR_MEPC:    mepc     <= csr_apply(mepc, wdata, csr_op);
                    `CSR_MCAUSE:  mcause   <= csr_apply(mcause, wdata, csr_op);
                    // MIP is read-only — writes to it are silently ignored
                endcase
            end
        end
    end
endmodule