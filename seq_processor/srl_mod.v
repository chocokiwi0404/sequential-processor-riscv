module srl_mod (
    input  [63:0] a,
    input  [63:0] b,          // b[5:0] = shift amount
    output [63:0] res,
    output        carry_flag,
    output        overflow,
    output        zero_flag
);

    wire [63:0] s0, s1, s2, s3, s4, s5;
    genvar i;

    reg [63:0] res_wire;

    // Stage 0: shift by 1 if b[0]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s0[i] = b[0] ?((i + 1 < 64) ? a[i+1] : 1'b0) :a[i];
        end
    endgenerate

    // Stage 1: shift by 2 if b[1]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s1[i] = b[1] ?((i + 2 < 64) ? s0[i+2] : 1'b0) :s0[i];
        end
    endgenerate

    // Stage 2: shift by 4 if b[2]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s2[i] = b[2] ?((i + 4 < 64) ? s1[i+4] : 1'b0) :s1[i];
        end
    endgenerate

    // Stage 3: shift by 8 if b[3]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s3[i] = b[3] ?((i + 8 < 64) ? s2[i+8] : 1'b0) :s2[i];
        end
    endgenerate

    // Stage 4: shift by 16 if b[4]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s4[i] = b[4] ?((i + 16 < 64) ? s3[i+16] : 1'b0) :s3[i];
        end
    endgenerate

    // Stage 5: shift by 32 if b[5]
    generate
        for (i = 0; i < 64; i = i + 1) begin
            assign s5[i] = b[5] ?((i + 32 < 64) ? s4[i+32] : 1'b0) :s4[i];
        end
    endgenerate

    always @(*) begin
        // if(b >=64) begin
        //     res_wire = {64{1'b0}};
        // end
        // else begin
            res_wire = s5;
        //end
    end

    // Final output
    assign res = res_wire;

    // Flags
    assign carry_flag = 1'b0;
    assign overflow  = 1'b0;
    assign zero_flag = (res == 64'b0);

endmodule
