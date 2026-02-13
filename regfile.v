module regfile(
    input clk,
    input reset,
    input write_en,
    input [4:0] rs1, rs2, write_reg,
    input [31:0] write_data,
    output reg [31:0] a,b
);
    integer i;
    reg [31:0] register [0:31];
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i++) begin
                register[i] <= 32'b0;
            end
        end else if (write_en && write_reg != 5'b0) begin
            register[write_reg] <= write_data;
        end else begin
            register[write_reg] <= register[write_reg];
        end
        a <= register[rs1];
        b <= register[rs2];
    end
endmodule
