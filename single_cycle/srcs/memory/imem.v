module imem(
    input clk,
    //asynch cpu ports
    input [31:0] pc,
    output [31:0] inst,
    // synch uart loaded ports
    input load,
    input [31:0] data,
    input [31:0] addr
);
    reg [31:0] mem [0:1023]; //4K memory
    always @(posedge clk) begin
        if (load) begin
            mem[addr[11:2]] <= data;
        end
    end
    assign inst = mem[pc[11:2]];

    initial begin
        //preload the memory with the program.mem file
        $readmemh("./software/program.mem", mem);
    end

endmodule
