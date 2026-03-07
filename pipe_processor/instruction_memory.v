module instruction_memory (
    input clk, reset,   
    input [63:0] addr,    
    output [31:0] instr   
);

    reg [7:0] mem [0:4095];
    initial begin
        $readmemh("instructions.txt", mem);
    end
    assign instr = (reset)? 32'b0:{mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};
endmodule