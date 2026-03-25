`include "params.vh"
module pc (
	input 					clk,
	input 					rst,
	input 		[31:0] 		pc_next,
	output reg 	[31:0] 		pc_out
);

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			pc_out <= `RESET_VECTOR;
		end else begin 
			pc_out <= pc_next;
		end
	end
endmodule
