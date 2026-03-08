module control_unit (
    input [6:0] opcode,
    output reg Branch, MemRead, MemtoReg, MemWrite, ALUSrc, RegWrite,
    output reg [1:0] ALUOp
);
    always @(*) begin
        // Default values to prevent latches
        {Branch, MemRead, MemtoReg, MemWrite, ALUSrc, RegWrite, ALUOp} = 8'b0;
        case (opcode)
            7'b0110011: begin // R-type
                RegWrite = 1; ALUOp = 2'b10;
            end
            7'b0010011: begin // I-type (addi)
                RegWrite = 1; ALUSrc = 1; ALUOp = 2'b00;
            end
            7'b0000011: begin // ld
                RegWrite = 1; ALUSrc = 1; MemRead = 1; MemtoReg = 1; ALUOp = 2'b00;
            end
            7'b0100011: begin // sd
                ALUSrc = 1; MemWrite = 1; ALUOp = 2'b00;
            end
            7'b1100011: begin // beq
                Branch = 1; ALUOp = 2'b01;
            end
        endcase
    end
endmodule