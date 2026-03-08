module slt_mod (
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] res,      
    output        carry_out,
    output        overflow,
    output        zero_flag
);

    wire [64:0] carry;
    assign carry[0] = 1'b0;

    wire [63:0] b_neg;
    assign b_neg = ~b + 64'b1;

    wire [63:0] diff;

    reg  [63:0] res_wire;   // FIX 1: reg, not wire

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign diff[i]    = a[i] ^ b_neg[i] ^ carry[i];
            assign carry[i+1] = (a[i] & b_neg[i]) |
                                (carry[i] & (a[i] ^ b_neg[i]));
        end
    endgenerate

    assign carry_out = 1'b0;
    assign overflow  = 1'b0;

    always @(*) begin
        if (a[63] == b[63]) begin
            // a and b have same sign
            res_wire = {63'b0, diff[63]};   // FIX 2: no assign
        end
        else if (a[63] == 1'b1 && b[63] == 1'b0) begin
            // a negative, b positive => a < b
            res_wire = 64'd1;
        end
        else begin
            // a positive, b negative => a > b
            res_wire = 64'd0;
        end
    end

    assign res = res_wire;
    assign zero_flag = (res == 64'b0);

endmodule
