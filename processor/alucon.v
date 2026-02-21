module alucon (
    input [1:0] ALUOp,
    input [2:0] funct3,  
    input funct7_30, 
    output reg [3:0] ALUControl
);
    always @(*) begin
        case(ALUOp) 
            2'b00: ALUControl = 4'b0000;
            2'b01: ALUControl = 4'b1000; 
            2'b10: begin                
                case(funct3)
                    3'b000: ALUControl = (funct7_30 && ALUOp[1]) ? 4'b1000 : 4'b0000; 
                    3'b111: ALUControl = 4'b0111; 
                    3'b110: ALUControl = 4'b0110; 
                    default: ALUControl = 4'b0000;
                endcase
            end
            default: ALUControl = 4'b0000;
        endcase
    end
endmodule