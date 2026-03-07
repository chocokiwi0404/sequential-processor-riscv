module regblock (
    input clk, reset,
    input [4:0] read_reg1, read_reg2, write_reg, 
    input [63:0] write_data,
    input reg_write_en,
    output [63:0] read_data1, read_data2
);

    reg [63:0] regfile [0:31];
    assign read_data1 = regfile[read_reg1];
    assign read_data2 = regfile[read_reg2];
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                regfile[i] <= 64'b0;
            end
        end 
        else if (reg_write_en && write_reg != 5'b0) begin
            regfile[write_reg] <= write_data;
        end
    end
endmodule

