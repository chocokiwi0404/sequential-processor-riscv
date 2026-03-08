`include "registers.v"
`include "immgen.v"
`include "instruction_memory.v"
`include "alucon.v"
`include "alu.v"
`include "control_unit.v"
`include "data_memory.v"
`include "pc.v"

module RISCV_Processor (
    input clk,
    input reset
);

////////////////////////////////////////////////////////////
/////////////////////// IF STAGE ///////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] pc_out;
wire [31:0] instruction;

pc pcc (
    .clk(clk),
    .reset(reset),
    .imm_data(id_ex_imm),
    .branch(ex_mem_branch),
    .zero_flag(ex_mem_zero),
    .pc_out(pc_out)
);

instruction_memory imem (
    .clk(clk),
    .reset(reset),
    .addr(pc_out),
    .instr(instruction)
);

////////////////////////////////////////////////////////////
/////////////////// IF / ID PIPELINE REG ///////////////////
////////////////////////////////////////////////////////////

reg [31:0] if_id_instruction;
reg [63:0] if_id_pc;

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        if_id_instruction <= 0;
        if_id_pc <= 0;
    end
    else
    begin
        if_id_instruction <= instruction;
        if_id_pc <= pc_out;
    end
end

////////////////////////////////////////////////////////////
/////////////////////// ID STAGE ///////////////////////////
////////////////////////////////////////////////////////////

wire [1:0] alu_op;
wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;

wire [63:0] read_data1, read_data2;
wire [63:0] imm_data;

control_unit control (
    .opcode(if_id_instruction[6:0]),
    .Branch(branch),
    .MemRead(mem_read),
    .MemtoReg(mem_to_reg),
    .MemWrite(mem_write),
    .ALUSrc(alu_src),
    .RegWrite(reg_write),
    .ALUOp(alu_op)
);

regblock registers (
    .clk(clk),
    .reset(reset),
    .read_reg1(if_id_instruction[19:15]),
    .read_reg2(if_id_instruction[24:20]),
    .write_reg(mem_wb_rd),
    .write_data(write_back_data),
    .reg_write_en(mem_wb_reg_write),
    .read_data1(read_data1),
    .read_data2(read_data2)
);

imm_gen ig (
    .instr(if_id_instruction),
    .imm(imm_data)
);

////////////////////////////////////////////////////////////
/////////////////// ID / EX PIPELINE REG ///////////////////
////////////////////////////////////////////////////////////

reg [63:0] id_ex_read_data1;
reg [63:0] id_ex_read_data2;
reg [63:0] id_ex_imm;

reg [4:0] id_ex_rs1;
reg [4:0] id_ex_rs2;
reg [4:0] id_ex_rd;

reg [1:0] id_ex_alu_op;

reg id_ex_branch;
reg id_ex_mem_read;
reg id_ex_mem_write;
reg id_ex_mem_to_reg;
reg id_ex_alu_src;
reg id_ex_reg_write;

reg [2:0] id_ex_funct3;
reg id_ex_funct7_30;

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        id_ex_read_data1 <= 0;
        id_ex_read_data2 <= 0;
        id_ex_imm <= 0;
    end
    else
    begin
        id_ex_read_data1 <= read_data1;
        id_ex_read_data2 <= read_data2;
        id_ex_imm <= imm_data;

        id_ex_rs1 <= if_id_instruction[19:15];
        id_ex_rs2 <= if_id_instruction[24:20];
        id_ex_rd  <= if_id_instruction[11:7];

        id_ex_funct3 <= if_id_instruction[14:12];
        id_ex_funct7_30 <= if_id_instruction[30];

        id_ex_branch <= branch;
        id_ex_mem_read <= mem_read;
        id_ex_mem_write <= mem_write;
        id_ex_mem_to_reg <= mem_to_reg;
        id_ex_alu_src <= alu_src;
        id_ex_reg_write <= reg_write;

        id_ex_alu_op <= alu_op;
    end
end

////////////////////////////////////////////////////////////
/////////////////////// FORWARDING UNIT ////////////////////
////////////////////////////////////////////////////////////

reg [1:0] forwardA;
reg [1:0] forwardB;

// always @(*) begin

//     forwardA = 2'b00;
//     forwardB = 2'b00;

//     if (ex_mem_reg_write &&
//         (ex_mem_rd != 0) &&
//         (ex_mem_rd == id_ex_rs1))
//             forwardA = 2'b10;

//     if (ex_mem_reg_write &&
//         (ex_mem_rd != 0) &&
//         (ex_mem_rd == id_ex_rs2))
//             forwardB = 2'b10;

//     if (mem_wb_reg_write &&
//         (mem_wb_rd != 0) &&
//         (mem_wb_rd == id_ex_rs1))
//             forwardA = 2'b01;

//     if (mem_wb_reg_write &&
//         (mem_wb_rd != 0) &&
//         (mem_wb_rd == id_ex_rs2))
//             forwardB = 2'b01;

// end

////////////////////////////////////////////////////////////
/////////////////////// EX STAGE ///////////////////////////
////////////////////////////////////////////////////////////

wire [3:0] alu_control;

alucon ac (
    .ALUOp(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7_30(id_ex_funct7_30),
    .ALUControl(alu_control)
);

reg [63:0] alu_operand_A;
reg [63:0] alu_operand_B_pre_mux;

always @(*) begin

    alu_operand_A = id_ex_read_data1;
    alu_operand_B_pre_mux = id_ex_read_data2;

    case(forwardA)
        2'b10: alu_operand_A = ex_mem_alu_result;
        2'b01: alu_operand_A = write_back_data;
    endcase

    case(forwardB)
        2'b10: alu_operand_B_pre_mux = ex_mem_alu_result;
        2'b01: alu_operand_B_pre_mux = write_back_data;
    endcase

end

wire [63:0] alu_operand_B =
    (id_ex_alu_src) ? id_ex_imm : alu_operand_B_pre_mux;

wire [63:0] alu_result;
wire zero_flag;

alu_64_bit main_alu (
    .a(alu_operand_A),
    .b(alu_operand_B),
    .opcode(alu_control),
    .result(alu_result),
    .zero_flag(zero_flag)
);

////////////////////////////////////////////////////////////
/////////////////// EX / MEM PIPELINE REG //////////////////
////////////////////////////////////////////////////////////

reg [63:0] ex_mem_alu_result;
reg [63:0] ex_mem_write_data;

reg [4:0] ex_mem_rd;

reg ex_mem_branch;
reg ex_mem_mem_read;
reg ex_mem_mem_write;
reg ex_mem_mem_to_reg;
reg ex_mem_reg_write;

reg ex_mem_zero;

always @(posedge clk or posedge reset)
begin
    if(reset)
        ex_mem_alu_result <= 0;
    else
    begin
        ex_mem_alu_result <= alu_result;
        ex_mem_write_data <= alu_operand_B_pre_mux;

        ex_mem_rd <= id_ex_rd;

        ex_mem_branch <= id_ex_branch;
        ex_mem_mem_read <= id_ex_mem_read;
        ex_mem_mem_write <= id_ex_mem_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_reg_write <= id_ex_reg_write;

        ex_mem_zero <= zero_flag;
    end
end

////////////////////////////////////////////////////////////
/////////////////////// MEM STAGE //////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] mem_read_data;

data_memory dmem (
    .clk(clk),
    .reset(reset),
    .address(ex_mem_alu_result[9:0]),
    .write_data(ex_mem_write_data),
    .MemRead(ex_mem_mem_read),
    .MemWrite(ex_mem_mem_write),
    .read_data(mem_read_data)
);

////////////////////////////////////////////////////////////
/////////////////// MEM / WB PIPELINE REG //////////////////
////////////////////////////////////////////////////////////

reg [63:0] mem_wb_mem_data;
reg [63:0] mem_wb_alu_result;

reg [4:0] mem_wb_rd;

reg mem_wb_reg_write;
reg mem_wb_mem_to_reg;

always @(posedge clk or posedge reset)
begin
    if(reset)
        mem_wb_mem_data <= 0;
    else
    begin
        mem_wb_mem_data <= mem_read_data;
        mem_wb_alu_result <= ex_mem_alu_result;

        mem_wb_rd <= ex_mem_rd;

        mem_wb_reg_write <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
    end
end

////////////////////////////////////////////////////////////
/////////////////////// WB STAGE ///////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] write_back_data;

assign write_back_data =
        (mem_wb_mem_to_reg) ?
        mem_wb_mem_data :
        mem_wb_alu_result;

endmodule