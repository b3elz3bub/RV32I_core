// Machine Timer — provides mtime (free-running counter) and mtimecmp (compare register).
// When mtime >= mtimecmp, timer_irq is asserted (level-triggered, active-high).
//
// Memory-mapped registers (active when timer_en is high):
//   Base+0x0  mtime_lo      (RW)
//   Base+0x4  mtime_hi      (RW)
//   Base+0x8  mtimecmp_lo   (RW)
//   Base+0xC  mtimecmp_hi   (RW)
//
// Software clears the interrupt by writing a new mtimecmp > mtime.

module timer (
    input  wire        clk,
    input  wire        rst,

    // Bus interface (active when selected by mmio)
    input  wire [3:0]  addr,        // addr[3:0] selects register
    input  wire [31:0] write_data,
    input  wire        write_en,
    output reg  [31:0] read_data,

    // Interrupt output
    output wire        timer_irq
);

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // Level-triggered interrupt — stays high until software clears it
    assign timer_irq = (mtime >= mtimecmp);

    // Free-running counter + register writes
    always @(posedge clk) begin
        if (rst) begin
            mtime    <= 64'd0;
            mtimecmp <= 64'hFFFFFFFF_FFFFFFFF;  // max value → no spurious IRQ on reset
        end else begin
            mtime <= mtime + 64'd1;

            if (write_en) begin
                case (addr[3:2])
                    2'b00: mtime[31:0]     <= write_data;  // +0x0
                    2'b01: mtime[63:32]    <= write_data;  // +0x4
                    2'b10: mtimecmp[31:0]  <= write_data;  // +0x8
                    2'b11: mtimecmp[63:32] <= write_data;  // +0xC
                endcase
            end
        end
    end

    // Combinational read mux
    always @(*) begin
        case (addr[3:2])
            2'b00:   read_data = mtime[31:0];
            2'b01:   read_data = mtime[63:32];
            2'b10:   read_data = mtimecmp[31:0];
            2'b11:   read_data = mtimecmp[63:32];
            default: read_data = 32'd0;
        endcase
    end

endmodule
