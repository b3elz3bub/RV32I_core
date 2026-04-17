`include "params.vh"
module pc (
	input 					clk,
	input 					rst,
    input                   stall,    // <-- ADDED THIS
	input 		[31:0] 		pc_next,
	output reg 	[31:0] 		pc_out
);

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			pc_out <= `RESET_VECTOR;
		end else if (!stall) begin    // <-- ADDED THIS
			pc_out <= pc_next;
		end
        // If stall is high, do nothing (keep current pc_out value)
	end
endmodule
