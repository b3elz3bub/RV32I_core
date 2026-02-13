module regfile(
    input clk,
    input write_en,
    input [4:0] rs1, rs2, write_reg,
    input [31:0] write_data,
    output [31:0] a,b
);
    integer i;
    reg [31:0] register [0:31];
    always @(posedge clk) begin
        if (write_en && write_reg != 5'b0) begin
            register[write_reg] <= write_data;
        end
    end
    assign a =
        (rs1 == 5'd0) ? 32'b0 :
        (write_en && write_reg == rs1) ? write_data :
        register[rs1];

    assign b =
        (rs2 == 5'd0) ? 32'b0 :
        (write_en && write_reg == rs2) ? write_data :
        register[rs2];
endmodule
