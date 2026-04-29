`include "params.vh"
module csr_file (
    input wire clk,
    input wire rst,
    
    // --- Software (Instruction) Ports ---
    input wire [11:0] csr_addr,   
    input wire [31:0] wdata,      
    input wire [1:0]  csr_op,     
    input wire        csr_we,     
    output reg [31:0] rdata,      
    
    input wire        inst_retire,

    // --- Hardware Trap Ports ---
    input wire        trap_en,    
    input wire [31:0] trap_pc,    
    input wire [31:0] trap_cause, 

    // --- MRET Port ---
    input wire        mret_en,    

    // --- External Interrupt Inputs ---
    input wire        timer_irq,  

    // --- Interrupt Decision Output ---
    output wire       take_interrupt, 

    // --- PC Redirect Outputs ---
    output wire [31:0] mtvec_out, 
    output wire [31:0] mepc_out   
);

    // =====================================================================
    //  CSR Registers
    // =====================================================================
    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [31:0] mstatus;    
    reg [31:0] mie;        
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mepc;
    reg [31:0] mcause;

    wire [31:0] mip = {24'b0, timer_irq, 7'b0};  // bit 7 = MTIP

    // =====================================================================
    //  Interrupt Decision
    // =====================================================================
    assign take_interrupt = mstatus[3]    // MIE 
                          & mie[7]        // MTIE 
                          & mip[7];       // MTIP 

    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

    // =====================================================================
    //  Helper Function: Apply CSR Operations
    // =====================================================================
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

    // =====================================================================
    //  CSR Read Mux (Combinational + Internal Bypass Hazard Fix)
    // =====================================================================
    always @(*) begin
        // 1. Fetch the actual register values
        case (csr_addr)
            `CSR_MCYCLE,   `CSR_CYCLE:    rdata = cycle_cnt[31:0];
            `CSR_MCYCLEH,  `CSR_CYCLEH:   rdata = cycle_cnt[63:32];
            `CSR_MINSTRET, `CSR_INSTRET:  rdata = instret_cnt[31:0];
            `CSR_MINSTRETH,`CSR_INSTRETH: rdata = instret_cnt[63:32];
            
            `CSR_MSTATUS:  rdata = mstatus;
            `CSR_MIE:      rdata = mie;
            `CSR_MTVEC:    rdata = mtvec;
            `CSR_MSCRATCH: rdata = mscratch;
            `CSR_MEPC:     rdata = mepc;
            `CSR_MCAUSE:   rdata = mcause;
            `CSR_MIP:      rdata = mip;       
            default:       rdata = 32'b0;
        endcase

        // 2. Internal Forwarding Bypass
        // If a software instruction is reading AND writing this exact register 
        // in the same cycle, forward the new modified data directly to the read port.
        if (csr_we && csr_addr != `CSR_MIP) begin
            if (csr_addr == `CSR_MSTATUS) begin
                // Maintain M-mode hardwiring and mask out reserved bits during bypass
                rdata = {19'b0, 2'b11, 3'b0, csr_apply(mstatus, wdata, csr_op)[7], 3'b0, csr_apply(mstatus, wdata, csr_op)[3], 3'b0};
            end else begin
                rdata = csr_apply(rdata, wdata, csr_op);
            end
        end
    end

    // =====================================================================
    //  CSR Write Logic (Sequential)
    // =====================================================================
    always @(posedge clk) begin
        if (rst) begin
            // Reset state: M-mode, interrupts disabled (MIE=0)
            cycle_cnt   <= 64'b0;
            instret_cnt <= 64'b0;
            mstatus     <= {19'b0, 2'b11, 11'b0}; 
            mie         <= 32'b0;
            mtvec       <= 32'b0;
            mscratch    <= 32'b0;
            mepc        <= 32'b0;
            mcause      <= 32'b0;
        end else begin
            
            // --- 1. Counters (Software Writable + Auto Increment) ---
            // cycle
            if (csr_we && (csr_addr == `CSR_MCYCLE || csr_addr == `CSR_CYCLE))
                cycle_cnt[31:0] <= csr_apply(cycle_cnt[31:0], wdata, csr_op);
            else 
                cycle_cnt[31:0] <= cycle_cnt[31:0] + 1'b1;

            // cycleh
            if (csr_we && (csr_addr == `CSR_MCYCLEH || csr_addr == `CSR_CYCLEH))
                cycle_cnt[63:32] <= csr_apply(cycle_cnt[63:32], wdata, csr_op);
            else if (cycle_cnt[31:0] == 32'hFFFFFFFF && !(csr_we && (csr_addr == `CSR_MCYCLE || csr_addr == `CSR_CYCLE)))
                cycle_cnt[63:32] <= cycle_cnt[63:32] + 1'b1;

            // instret
            if (csr_we && (csr_addr == `CSR_MINSTRET || csr_addr == `CSR_INSTRET))
                instret_cnt[31:0] <= csr_apply(instret_cnt[31:0], wdata, csr_op);
            else if (inst_retire)
                instret_cnt[31:0] <= instret_cnt[31:0] + 1'b1;

            // instreth
            if (csr_we && (csr_addr == `CSR_MINSTRETH || csr_addr == `CSR_INSTRETH))
                instret_cnt[63:32] <= csr_apply(instret_cnt[63:32], wdata, csr_op);
            else if (inst_retire && instret_cnt[31:0] == 32'hFFFFFFFF && !(csr_we && (csr_addr == `CSR_MINSTRET || csr_addr == `CSR_INSTRET)))
                instret_cnt[63:32] <= instret_cnt[63:32] + 1'b1;


            // --- 2. Hardware Trap / Return Logic ---
            if (trap_en) begin
                mepc    <= trap_pc;
                mcause  <= trap_cause;
                mstatus[7] <= mstatus[3];   // MPIE ← MIE
                mstatus[3] <= 1'b0;         // MIE  ← 0
            end
            else if (mret_en) begin
                mstatus[3] <= mstatus[7];   // MIE  ← MPIE
                mstatus[7] <= 1'b1;         // MPIE ← 1
            end
            
            // --- 3. Software CSR Instructions ---
            else if (csr_we) begin
                case (csr_addr)
                    `CSR_MSTATUS: begin
                        // Hardwire MPP (bits 12:11) to 2'b11, mask reserved bits, write to MPIE (7) and MIE (3)
                        mstatus <= {19'b0, 2'b11, 3'b0, csr_apply(mstatus, wdata, csr_op)[7], 3'b0, csr_apply(mstatus, wdata, csr_op)[3], 3'b0};
                    end
                    `CSR_MIE:      mie      <= csr_apply(mie, wdata, csr_op);
                    `CSR_MTVEC:    mtvec    <= csr_apply(mtvec, wdata, csr_op);
                    `CSR_MSCRATCH: mscratch <= csr_apply(mscratch, wdata, csr_op);
                    `CSR_MEPC:     mepc     <= csr_apply(mepc, wdata, csr_op);
                    `CSR_MCAUSE:   mcause   <= csr_apply(mcause, wdata, csr_op);
                endcase
            end
        end
    end
endmodule