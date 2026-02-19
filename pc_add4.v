module pc_add4 (
    input  [31:0] pc,
    output [31:0] pc_plus_4
);
    assign pc_plus_4 = pc + 32'd4;
endmodule