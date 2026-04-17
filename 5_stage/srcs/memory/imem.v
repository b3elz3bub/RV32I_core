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
    reg [31:0] mem [0:1023]; //4K memory
    always @(posedge clk) begin
        if (load) begin
            mem[addr[11:2]] <= data;
        end
        inst <= mem[pc[11:2]];
    end

    initial begin
        //preload the memory with the program.mem file (change as per your path, you don' have a user named mayan bruh!)
        $readmemh("C:/Users/mayan/Desktop/RV32I_core/5_stage/software/program.mem", mem);
    end

endmodule
