module sub_mod (
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] res,
    output        carry_out,
    output        carry_flag,
    output        overflow,
    output        zero_flag
);

    wire [64:0] carry;
    assign carry[0] = 1'b1;

    wire [63:0] b_neg;
    assign b_neg = ~b;  // Two's complement for subtraction

    //res = a - b;

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign res[i]   = a[i] ^ b_neg[i] ^ carry[i];
            assign carry[i+1] = (a[i] & b_neg[i]) | (carry[i] & (a[i] ^ b_neg[i]));
        end
    endgenerate

    // Final carry-out
    assign carry_out = carry[64]; // carry[64] is ~borrow out for subtraction
    // carry_out is 1 meaning borrow has occured

    assign carry_flag = ~carry_out; // carry_flag is 1 when there's a borrow

    // Signed overflow detection
    assign overflow = (a[63] != b[63]) && (res[63] != a[63]);

    // Zero flag
    assign zero_flag = (res == 64'b0);

endmodule
