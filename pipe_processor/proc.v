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

////////////////////////////////////////////////////////////
//////////////////// LOAD HAZARD SIGNAL ////////////////////
////////////////////////////////////////////////////////////

// This signal becomes 1 when a load-use hazard occurs.
//
// Example hazard:
//
//    ld x5,0(x1)
//    add x6,x5,x2
//
// The add instruction needs x5 before the load has finished
// accessing memory.

wire load_use_hazard;

////////////////////////////////////////////////////////////
//////////////////// PC STALL CONTROL //////////////////////
////////////////////////////////////////////////////////////

// If a load hazard occurs, the PC should NOT advance.
// That means the same instruction will be fetched again.

wire pc_write_enable;

assign pc_write_enable = ~load_use_hazard;

////////////////////////////////////////////////////////////
//////////////////// PC MODULE /////////////////////////////
////////////////////////////////////////////////////////////

pc pcc (
    .clk(clk),
    .reset(reset),
    .pc_write_enable(pc_write_enable), // PC updates only when no hazard
    .imm_data(id_ex_imm),
    .branch(ex_mem_branch),
    .zero_flag(ex_mem_zero),
    .pc_out(pc_out)
);

////////////////////////////////////////////////////////////
//////////////////// INSTRUCTION MEMORY ////////////////////
////////////////////////////////////////////////////////////

instruction_memory imem (
    .clk(clk),
    .reset(reset),
    .addr(pc_out),
    .instr(instruction)
);

////////////////////////////////////////////////////////////
/////////////////// IF / ID PIPELINE REG ///////////////////
////////////////////////////////////////////////////////////

// This register stores instruction fetched in IF stage
// so it can be decoded in the next cycle.

reg [31:0] if_id_instruction;
reg [63:0] if_id_pc;

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        if_id_instruction <= 0;
        if_id_pc <= 0;
    end

    // During load hazard we STALL the pipeline
    // so we do NOT update IF/ID register.

    else if(load_use_hazard)
    begin
        if_id_instruction <= if_id_instruction;
        if_id_pc <= if_id_pc;
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

// Control signals
wire [1:0] alu_op;
wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;

// Register outputs
wire [63:0] read_data1, read_data2;

// Immediate output
wire [63:0] imm_data;

// Control unit decodes instruction
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

// Register file read
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

// Immediate generation
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
        id_ex_reg_write <= 0;
        id_ex_mem_read <= 0;
        id_ex_mem_write <= 0;
        id_ex_branch <= 0;
    end

    ////////////////////////////////////////////////////////
    // INSERT BUBBLE DURING LOAD HAZARD
    ////////////////////////////////////////////////////////
    //
    // Instead of allowing the dependent instruction to
    // proceed into EX stage, we convert it into a NOP
    // by clearing control signals.

    else if(load_use_hazard)
    begin
        id_ex_reg_write <= 0;
        id_ex_mem_read <= 0;
        id_ex_mem_write <= 0;
        id_ex_branch <= 0;
        id_ex_mem_to_reg <= 0;
        id_ex_alu_src <= 0;
        id_ex_alu_op <= 0;
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
//////////////// LOAD HAZARD DETECTION /////////////////////
////////////////////////////////////////////////////////////

// Hazard occurs if:
//
// Instruction in EX stage is a LOAD
// AND
// Destination register matches source of next instruction

assign load_use_hazard =
    id_ex_mem_read &&
    (
        (id_ex_rd == if_id_instruction[19:15]) ||
        (id_ex_rd == if_id_instruction[24:20])
    );

////////////////////////////////////////////////////////////
/////////////////////// FORWARDING UNIT ////////////////////
////////////////////////////////////////////////////////////

// Forwarding logic remains unchanged
// (already handles ALU hazards)

reg [1:0] forwardA;
reg [1:0] forwardB;

always @(*) begin

    forwardA = 2'b00;
    forwardB = 2'b00;

    if (ex_mem_reg_write &&
        (ex_mem_rd != 0) &&
        (ex_mem_rd == id_ex_rs1))
            forwardA = 2'b10;

    if (ex_mem_reg_write &&
        (ex_mem_rd != 0) &&
        (ex_mem_rd == id_ex_rs2))
            forwardB = 2'b10;

    if (mem_wb_reg_write &&
        (mem_wb_rd != 0) &&
        !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs1)) &&
        (mem_wb_rd == id_ex_rs1))
            forwardA = 2'b01;

    if (mem_wb_reg_write &&
        (mem_wb_rd != 0) &&
        !(ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == id_ex_rs2)) &&
        (mem_wb_rd == id_ex_rs2))
            forwardB = 2'b01;

end

////////////////////////////////////////////////////////////
/////////////////////// EX STAGE ///////////////////////////
////////////////////////////////////////////////////////////

// ALU control
wire [3:0] alu_control;

alucon ac (
    .ALUOp(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7_30(id_ex_funct7_30),
    .ALUControl(alu_control)
);

// Values forwarded to ALU
reg [63:0] alu_operand_A;
reg [63:0] alu_operand_B_pre_mux;

always @(*) begin

    // Default values
    alu_operand_A = id_ex_read_data1; // first operand going to ALU
    alu_operand_B_pre_mux = id_ex_read_data2; // second operand before mux , deciding whether it is register value or immediate

    // Forwarding for operand A
    case(forwardA)
        2'b10: alu_operand_A = ex_mem_alu_result;
        2'b01: alu_operand_A = write_back_data;
    endcase

    // Forwarding for operand B
    case(forwardB)
        2'b10: alu_operand_B_pre_mux = ex_mem_alu_result;
        2'b01: alu_operand_B_pre_mux = write_back_data;
    endcase

end

// ALU input mux (immediate vs register)
wire [63:0] alu_operand_B =
    (id_ex_alu_src) ? id_ex_imm : alu_operand_B_pre_mux;

// ALU
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