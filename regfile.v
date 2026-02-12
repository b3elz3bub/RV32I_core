module regfile(
    input clk,
    input reset,
    input [4:0] rs1,
    input [4:0] rs2,
    output [31:0] a,
    output [31:0] b,
    input [4:0] write_reg,
    input [31:0] write_data,
    input write_en
);

    reg [31:0] register [0:31];
    always @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
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
