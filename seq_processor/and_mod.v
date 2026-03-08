module and_mod (
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] res,
    output        carry_flag,
    output        overflow,
    output        zero_flag
);

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin 
            assign res[i]   = a[i] & b[i];
        end
    endgenerate

    assign carry_flag = 1'b0;
    assign overflow  = 1'b0; 

    // Zero flag
    assign zero_flag = (res == 64'b0);

endmodule
