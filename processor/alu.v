// module for all the alu instructions, calling all instructions in here

`include "add_mod.v"
`include "sub_mod.v"
`include "and_mod.v"
`include "or_mod.v"
`include "xor_mod.v"
`include "slt_mod.v"
`include "sltu_mod.v"
`include "sll_mod.v"
`include "srl_mod.v"
`include "sra_mod.v"

module alu_64_bit (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  opcode,
    output [63:0] result,
    output        cout,
    output        carry_flag,
    output        overflow_flag,
    output        zero_flag
);

    // -------- internal wires for each module --------
    wire [63:0] add_res, sub_res, and_res, or_res, xor_res;
    wire [63:0] slt_res, sltu_res;
    wire [63:0] sll_res, srl_res, sra_res;

    wire add_cout, sub_cout;
    wire add_overflow, sub_overflow;


    add_mod add_inst (
        .a(a), .b(b),
        .res(add_res),
        .carry_out(add_cout),
        .carry_flag(add_carry_flag),
        .overflow(add_overflow),
        .zero_flag()
    );

    sub_mod sub_inst (
        .a(a), .b(b),
        .res(sub_res),
        .carry_out(sub_cout),
        .carry_flag(sub_carry_flag),
        .overflow(sub_overflow),
        .zero_flag()
    );

    and_mod and_inst (.a(a), .b(b), .res(and_res));
    or_mod  or_inst  (.a(a), .b(b), .res(or_res));
    xor_mod xor_inst (.a(a), .b(b), .res(xor_res));

    slt_mod  slt_inst  (.a(a), .b(b), .res(slt_res));
    sltu_mod sltu_inst (.a(a), .b(b), .res(sltu_res));

    sll_mod sll_inst (.a(a), .b(b), .res(sll_res));
    srl_mod srl_inst (.a(a), .b(b), .res(srl_res));
    sra_mod sra_inst (.a(a), .b(b), .res(sra_res));

    reg [63:0] result_r;
    reg        cout_r;
    reg        carry_flag_r;
    reg        overflow_flag_r;

    always @(*) begin
        result_r        = 64'b0;
        cout_r          = 1'b0;
        carry_flag_r    = 1'b0;
        overflow_flag_r = 1'b0;

        case (opcode)
            4'b0000: begin // ADD
                result_r        = add_res;
                cout_r          = add_cout;
                carry_flag_r    = add_carry_flag;
                overflow_flag_r = add_overflow;
            end

            4'b0001: result_r = sll_res;   // SLL
            4'b0010: result_r = slt_res;   // SLT
            4'b0011: result_r = sltu_res;  // SLTU
            4'b0100: result_r = xor_res;   // XOR
            4'b0101: result_r = srl_res;   // SRL
            4'b0110: result_r = or_res;    // OR
            4'b0111: result_r = and_res;   // AND

            4'b1000: begin // SUB
                result_r        = sub_res;
                cout_r          = sub_cout;
                carry_flag_r    = sub_carry_flag;   // borrow
                overflow_flag_r = sub_overflow;
            end

            4'b1101: result_r = sra_res;   // SRA
        endcase
    end

    // -------- final outputs --------
    assign result        = result_r;
    assign cout          = cout_r;
    assign carry_flag    = carry_flag_r;
    assign overflow_flag = overflow_flag_r;
    assign zero_flag     = (result_r == 64'b0);

endmodule
