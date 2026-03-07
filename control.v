module control(
    input [31:0] inst,
    output reg [1:0] regwrite_ctrl,
    output reg regwrite_en,
    output reg memwrite_en,
    output reg [2:0] memload_ctrl,
    output reg [3:0] memstore_ctrl,
    output reg [3:0] alu_ctrl,
    output reg auipc_ctrl,
    output reg bsel_ctrl,
    output reg branch_en,
    output reg [2:0] branchcond_ctrl,
    output reg jal_ctrl,
    output reg jalr_ctrl
);
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] opcode = inst[6:0];
    wire [6:0] funct7 = inst[31:25];

    always @(*) begin
        // Default values to ensure no latches are inferred
        regwrite_en = 0;      memwrite_en = 0;    branch_en = 0;
        jal_ctrl = 0;         jalr_ctrl = 0;      auipc_ctrl = 0;
        bsel_ctrl = 0;        regwrite_ctrl = 2'b00;
        alu_ctrl = 4'b0000;   memstore_ctrl = 4'b0000;
        memload_ctrl = 3'b000; branchcond_ctrl = 3'b000;

        case (opcode)
            7'b0000011: begin // Load
                regwrite_en = 1;
                regwrite_ctrl = 2'b01;
                bsel_ctrl = 1;
                memload_ctrl = funct3;
            end
            7'b0010011: begin // I-type Arithmetic
                regwrite_en = 1;
                bsel_ctrl = 1;
                alu_ctrl = (funct3 == 3'b101 || funct3 == 3'b001) ? {funct3, inst[30]} : {funct3, 1'b0};
            end
            7'b0010111: begin // AUIPC
                regwrite_en = 1;
                auipc_ctrl = 1;
                bsel_ctrl = 1;
            end
            7'b0100011: begin // Store
                memwrite_en = 1;
                bsel_ctrl = 1;
                case(funct3)
                    3'b000: memstore_ctrl = 4'b0001;
                    3'b001: memstore_ctrl = 4'b0011;
                    3'b010: memstore_ctrl = 4'b1111;
                    default: memstore_ctrl = 4'b1111;
                endcase
            end
            7'b0110111: begin // LUI
                regwrite_en = 1;
                regwrite_ctrl = 2'b11;
            end
            7'b0110011: begin // R-type
                regwrite_en = 1;
                alu_ctrl = {funct3, funct7[5]};
            end
            7'b1100011: begin // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
                branch_en = 1;
                branchcond_ctrl = funct3;
                // Use SUB for BEQ/BNE/BLTU/BGEU, SLT for BLT/BGE so we can
                // drive the branch decision from the SLT result bit.
                case (funct3)
                    3'b100, 3'b101: alu_ctrl = 4'b0100; // BLT/BGE use SLT (signed)
                    default:        alu_ctrl = 4'b0001; // others use SUB
                endcase
            end
            7'b1101111: begin // JAL
                regwrite_en = 1;
                regwrite_ctrl = 2'b10;
                jal_ctrl = 1;
            end
            7'b1100111: begin // JALR
                regwrite_en = 1;
                regwrite_ctrl = 2'b10;
                jalr_ctrl = 1;
                bsel_ctrl = 1;
            end
        endcase
    end
endmodule