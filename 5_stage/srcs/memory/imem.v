module imem(
    input clk,
    //asynch cpu ports
    input [31:0] pc,
    output reg [31:0] inst,
    // synch uart loaded ports
    input load,
    input [31:0] data,
    input [31:0] addr
);
    reg [31:0] mem [0:16383];//64KB memory (16384 words)
    always @(posedge clk) begin
        if (load) begin
            mem[addr[15:2]] <= data;
        end
        inst <= mem[pc[15:2]];
    end

    //initial begin
    //    $readmemh("./software/program.mem", mem);
    //end

endmodule
