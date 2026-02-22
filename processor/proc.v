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
    // --- Internal Wires ---
    wire [63:0] pc_out;
    wire [63:0] pc_in;
    wire [63:0] pc_plus_4;
    wire [63:0] branch_target;
    wire [31:0] instruction;
    
    // Control Signals [cite: 72, 352]
    wire [1:0] alu_op;
    wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
    
    // Register File Wires [cite: 59, 339]
    wire [63:0] read_data1, read_data2;
    wire [63:0] write_back_data;
    
    // Immediate and ALU Wires [cite: 76, 85, 88, 356, 365, 368]
    wire [63:0] imm_data;
    wire [3:0] alu_control;
    wire [63:0] alu_result;
    wire zero_flag;
    
    // Data Memory Wires [cite: 92, 372]
    wire [63:0] mem_read_data;

    pc pcc (
         .clk(clk),
         .reset(reset),
         .pc_in(pc_in),
         .pc_out(pc_out)
    );

    // --- PC Update Logic ---
    // PC + 4 calculation for sequential execution [cite: 56, 104, 336, 384]
    assign pc_plus_4 = pc_out + 4;
    
    // Branch Target calculation: PC + Immediate [cite: 79, 104, 359, 384]
    // Note: your imm_gen already handles the left-shift by 1 for B-type instructions
    assign branch_target = pc_out + imm_data;
    
    // PC Source Mux: Choose between PC+4 or Branch Target [cite: 56, 336]
    assign pc_in = (branch & zero_flag) ? branch_target : pc_plus_4;

    // --- Module Instantiations ---

    // Instruction Memory: Fetches 32-bit Big-Endian instructions [cite: 66, 67, 108, 346, 347, 388]
    instruction_memory imem (
        .clk(clk),
        .reset(reset),
        .addr(pc_out),
        .instr(instruction)
    );

    // Control Unit: Decodes opcode to generate control signals [cite: 70, 72, 350, 352]
    control_unit control (
        .opcode(instruction[6:0]),
        .Branch(branch),
        .MemRead(mem_read),
        .MemtoReg(mem_to_reg),
        .MemWrite(mem_write),
        .ALUSrc(alu_src),
        .RegWrite(reg_write),
        .ALUOp(alu_op)
    );

    // Register File: 32 x 64-bit registers [cite: 58, 60, 338, 340]
    regblock registers (
        .clk(clk),
        .reset(reset),
        .read_reg1(instruction[19:15]), // [cite: 26, 306]
        .read_reg2(instruction[24:20]), // [cite: 28, 308]
        .write_reg(instruction[11:7]),  // [cite: 32, 312]
        .write_data(write_back_data),
        .reg_write_en(reg_write),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // Immediate Generation: Sign-extends based on instruction type [cite: 77, 78, 357, 358]
    imm_gen ig (
        .instr(instruction),
        .imm(imm_data)
    );

    // ALU Control: Updated to include funct3 and funct7_30 [cite: 83, 86, 363, 366]
    alucon ac (
        .ALUOp(alu_op),
        .funct3(instruction[14:12]),   // instruction bits [14:12] 
        .funct7_30(instruction[30]),  // instruction bit [30] 
        .ALUControl(alu_control)
    );

    // ALU Input Mux: Select between Reg2 data and Immediate [cite: 102, 382]
    wire [63:0] alu_input2 = (alu_src) ? imm_data : read_data2;

    // ALU: Performs arithmetic/logic operations [cite: 87, 89, 367, 369]
    alu_64_bit main_alu (
        .a(read_data1),
        .b(alu_input2),
        .opcode(alu_control),
        .result(alu_result),
        .zero_flag(zero_flag)
    );

    // Data Memory: 1024 bytes, 1-cycle latency, Big-Endian [cite: 91, 94, 99, 108, 371, 374, 379, 388]
    data_memory dmem (
        .clk(clk),
        .reset(reset),
        .address(alu_result[9:0]), // Using 10 bits for 1024-byte addressing
        .write_data(read_data2),
        .MemRead(mem_read),
        .MemWrite(mem_write),
        .read_data(mem_read_data)
    );

    // Write-back Mux: Select between ALU Result and Memory Read Data [cite: 102, 382]
    assign write_back_data = (mem_to_reg) ? mem_read_data : alu_result;

endmodule