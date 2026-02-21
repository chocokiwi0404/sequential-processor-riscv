module sltu_mod (
    input  [63:0] a,
    input  [63:0] b,
    output [63:0] res,      
    output        carry_flag,
    output        overflow,
    output        zero_flag
);

    wire [64:0] carry;
    assign carry[0] = 1'b1;

    wire [63:0] b_neg;
    assign b_neg = ~b;  

    wire [63:0] diff;
    reg [63:0] res_wire;

    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign diff[i]    = a[i] ^ b_neg[i] ^ carry[i];
            assign carry[i+1] = (a[i] & b_neg[i]) | (carry[i] & (a[i] ^ b_neg[i]));
        end
    endgenerate

    assign carry_flag = 1'b0;

    assign overflow = 1'b0;

    always @(*) begin
        if (carry[64])
            res_wire = 64'd0;
        else
            res_wire = 64'd1;
    end

    assign res = res_wire;
    // Zero flag
    assign zero_flag = (res == 64'b0);

endmodule
