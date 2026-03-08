// Updated data_memory.v
module data_memory (
    input clk, reset,
    input [9:0] address,
    input [63:0] write_data,
    input MemRead, MemWrite,
    output [63:0] read_data // Removed 'reg'
);
    reg [7:0] mem [0:1023];

    // Asynchronous Read: Data is available immediately in the same cycle
    assign read_data = (MemRead) ? {mem[address],   mem[address+1], mem[address+2], mem[address+3],
                                    mem[address+4], mem[address+5], mem[address+6], mem[address+7]} : 64'b0;

    // Synchronous Write: Writing still happens on the clock edge
    always @(posedge clk) begin
        if (MemWrite) begin
            {mem[address],   mem[address+1], mem[address+2], mem[address+3],
             mem[address+4], mem[address+5], mem[address+6], mem[address+7]} <= write_data;
        end
    end
endmodule