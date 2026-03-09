`include "registers.v"
`include "immgen.v"
`include "instruction_memory.v"
`include "alucon.v"
`include "alu.v"
`include "control_unit.v"
`include "data_memory.v"

module pipe_processor (
    input clk,
    input reset
);

    // ============================================================
    // IF stage
    // ============================================================
    reg [63:0] pc_reg;
    wire [63:0] pc_plus_4;
    wire [63:0] pc_next;
    wire [31:0] if_instruction;

    assign pc_plus_4 = pc_reg + 64'd4;

    instruction_memory imem (
        .clk(clk),
        .reset(reset),
        .addr(pc_reg),
        .instr(if_instruction)
    );

    // IF/ID pipeline register
    reg [63:0] ifid_pc;
    reg [31:0] ifid_instr;

    // ============================================================
    // ID stage
    // ============================================================
    wire [4:0] id_rs1;
    wire [4:0] id_rs2;
    wire [4:0] id_rd;

    wire [63:0] id_rs1_data_raw;
    wire [63:0] id_rs2_data_raw;
    wire [63:0] id_imm;

    wire id_branch;
    wire id_mem_read;
    wire id_mem_to_reg;
    wire id_mem_write;
    wire id_alu_src;
    wire id_reg_write;
    wire [1:0] id_alu_op;

    assign id_rs1 = ifid_instr[19:15];
    assign id_rs2 = ifid_instr[24:20];
    assign id_rd  = ifid_instr[11:7];

    control_unit control_unit_inst (
        .opcode(ifid_instr[6:0]),
        .Branch(id_branch),
        .MemRead(id_mem_read),
        .MemtoReg(id_mem_to_reg),
        .MemWrite(id_mem_write),
        .ALUSrc(id_alu_src),
        .RegWrite(id_reg_write),
        .ALUOp(id_alu_op)
    );

    imm_gen immgen_inst (
        .instr(ifid_instr),
        .imm(id_imm)
    );

    // ============================================================
    // WB stage writeback signal (used by register file and forwarding)
    // ============================================================
    wire [63:0] wb_write_data;
    assign wb_write_data = memwb_mem_to_reg ? memwb_mem_data : memwb_alu_result;

    regblock registers (
        .clk(clk),
        .reset(reset),
        .read_reg1(id_rs1),
        .read_reg2(id_rs2),
        .write_reg(memwb_rd),
        .write_data(wb_write_data),
        .reg_write_en(memwb_reg_write),
        .read_data1(id_rs1_data_raw),
        .read_data2(id_rs2_data_raw)
    );

    // Read-after-write bypass into ID stage (same-cycle WB->ID dependency)
    wire [63:0] id_rs1_data;
    wire [63:0] id_rs2_data;

    assign id_rs1_data = (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == id_rs1)) ? wb_write_data : id_rs1_data_raw;
    assign id_rs2_data = (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == id_rs2)) ? wb_write_data : id_rs2_data_raw;

    // ID/EX pipeline register
    reg [63:0] idex_pc;
    reg [63:0] idex_rs1_data;
    reg [63:0] idex_rs2_data;
    reg [63:0] idex_imm;
    reg [4:0]  idex_rs1;
    reg [4:0]  idex_rs2;
    reg [4:0]  idex_rd;
    reg [2:0]  idex_funct3;
    reg        idex_funct7_30;
    reg        idex_branch;
    reg        idex_mem_read;
    reg        idex_mem_to_reg;
    reg        idex_mem_write;
    reg        idex_alu_src;
    reg        idex_reg_write;
    reg [1:0]  idex_alu_op;
    reg [31:0] idex_instr;

    // ============================================================
    // EX stage
    // ============================================================
    wire [3:0] ex_alu_control;
    wire [63:0] ex_alu_result;
    wire ex_zero_flag;
    wire ex_branch_taken;
    wire [63:0] ex_branch_target;

    // Forwarding unit (required: MEM->EX and WB->EX)
    reg [1:0] forward_a_sel;
    reg [1:0] forward_b_sel;

    wire [63:0] exmem_forward_data;
    wire exmem_can_forward;
    wire memwb_can_forward;

    assign exmem_forward_data = exmem_alu_result;
    assign exmem_can_forward = exmem_reg_write && !exmem_mem_to_reg && (exmem_rd != 5'd0);
    assign memwb_can_forward = memwb_reg_write && (memwb_rd != 5'd0);

    always @(*) begin
        forward_a_sel = 2'b00;
        forward_b_sel = 2'b00;

        // EX hazard: MEM -> EX
        if (exmem_can_forward && (exmem_rd == idex_rs1)) begin
            forward_a_sel = 2'b10;
        end else if (memwb_can_forward && (memwb_rd == idex_rs1)) begin
            // MEM hazard: WB -> EX
            forward_a_sel = 2'b01;
        end

        if (exmem_can_forward && (exmem_rd == idex_rs2)) begin
            forward_b_sel = 2'b10;
        end else if (memwb_can_forward && (memwb_rd == idex_rs2)) begin
            forward_b_sel = 2'b01;
        end
    end

    wire [63:0] ex_rs1_forwarded;
    wire [63:0] ex_rs2_forwarded;
    wire [63:0] ex_alu_in2;
    wire [63:0] ex_store_data;

    assign ex_rs1_forwarded = (forward_a_sel == 2'b10) ? exmem_forward_data :
                              (forward_a_sel == 2'b01) ? wb_write_data :
                                                         idex_rs1_data;

    assign ex_rs2_forwarded = (forward_b_sel == 2'b10) ? exmem_forward_data :
                              (forward_b_sel == 2'b01) ? wb_write_data :
                                                         idex_rs2_data;

    assign ex_alu_in2 = idex_alu_src ? idex_imm : ex_rs2_forwarded;
    assign ex_store_data = ex_rs2_forwarded;

    alucon alu_control_inst (
        .ALUOp(idex_alu_op),
        .funct3(idex_funct3),
        .funct7_30(idex_funct7_30),
        .ALUControl(ex_alu_control)
    );

    alu_64_bit alu_inst (
        .a(ex_rs1_forwarded),
        .b(ex_alu_in2),
        .opcode(ex_alu_control),
        .result(ex_alu_result),
        .cout(),
        .carry_flag(),
        .overflow_flag(),
        .zero_flag(ex_zero_flag)
    );

    assign ex_branch_taken = idex_branch && ex_zero_flag;
    assign ex_branch_target = idex_pc + idex_imm;

    // EX/MEM pipeline register
    reg [63:0] exmem_alu_result;
    reg [63:0] exmem_store_data;
    reg [4:0]  exmem_rd;
    reg        exmem_mem_read;
    reg        exmem_mem_to_reg;
    reg        exmem_mem_write;
    reg        exmem_reg_write;
    reg [31:0] exmem_instr;

    // ============================================================
    // MEM stage
    // ============================================================
    wire [63:0] mem_read_data;

    data_memory dmem (
        .clk(clk),
        .reset(reset),
        .address(exmem_alu_result[9:0]),
        .write_data(exmem_store_data),
        .MemRead(exmem_mem_read),
        .MemWrite(exmem_mem_write),
        .read_data(mem_read_data)
    );

    // MEM/WB pipeline register
    reg [63:0] memwb_mem_data;
    reg [63:0] memwb_alu_result;
    reg [4:0]  memwb_rd;
    reg        memwb_mem_to_reg;
    reg        memwb_reg_write;
    reg [31:0] memwb_instr;

    // ============================================================
    // Hazard detection (required load-use stall)
    // ============================================================
    wire [6:0] ifid_opcode;
    wire id_uses_rs1;
    wire id_uses_rs2;
    wire load_use_hazard;

    assign ifid_opcode = ifid_instr[6:0];

    assign id_uses_rs1 = (ifid_opcode == 7'b0110011) || // R-type
                         (ifid_opcode == 7'b0010011) || // I-type (addi)
                         (ifid_opcode == 7'b0000011) || // ld
                         (ifid_opcode == 7'b0100011) || // sd
                         (ifid_opcode == 7'b1100011);   // beq

    assign id_uses_rs2 = (ifid_opcode == 7'b0110011) || // R-type
                         (ifid_opcode == 7'b0100011) || // sd
                         (ifid_opcode == 7'b1100011);   // beq

    assign load_use_hazard = idex_mem_read && (idex_rd != 5'd0) &&
                             ((id_uses_rs1 && (idex_rd == id_rs1)) ||
                              (id_uses_rs2 && (idex_rd == id_rs2)));

    // If a branch is taken in EX, flushing takes priority over stalling
    wire flush_pipeline;
    wire stall_pipeline;

    assign flush_pipeline = ex_branch_taken;
    assign stall_pipeline = load_use_hazard && !flush_pipeline;

    assign pc_next = flush_pipeline ? ex_branch_target : pc_plus_4;

    // ============================================================
    // Sequential update of PC + pipeline registers
    // ============================================================
    always @(posedge clk) begin
        if (reset) begin
            pc_reg <= 64'd0;

            ifid_pc <= 64'd0;
            ifid_instr <= 32'd0;

            idex_pc <= 64'd0;
            idex_rs1_data <= 64'd0;
            idex_rs2_data <= 64'd0;
            idex_imm <= 64'd0;
            idex_rs1 <= 5'd0;
            idex_rs2 <= 5'd0;
            idex_rd <= 5'd0;
            idex_funct3 <= 3'd0;
            idex_funct7_30 <= 1'b0;
            idex_branch <= 1'b0;
            idex_mem_read <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_mem_write <= 1'b0;
            idex_alu_src <= 1'b0;
            idex_reg_write <= 1'b0;
            idex_alu_op <= 2'b00;
            idex_instr <= 32'd0;

            exmem_alu_result <= 64'd0;
            exmem_store_data <= 64'd0;
            exmem_rd <= 5'd0;
            exmem_mem_read <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
            exmem_mem_write <= 1'b0;
            exmem_reg_write <= 1'b0;
            exmem_instr <= 32'd0;

            memwb_mem_data <= 64'd0;
            memwb_alu_result <= 64'd0;
            memwb_rd <= 5'd0;
            memwb_mem_to_reg <= 1'b0;
            memwb_reg_write <= 1'b0;
            memwb_instr <= 32'd0;
        end else begin
            // PC update
            if (!stall_pipeline) begin
                pc_reg <= pc_next;
            end

            // IF/ID update: flush on taken branch, stall on load-use hazard
            if (flush_pipeline) begin
                ifid_pc <= 64'd0;
                ifid_instr <= 32'd0;
            end else if (!stall_pipeline) begin
                ifid_pc <= pc_reg;
                ifid_instr <= if_instruction;
            end

            // ID/EX update: flush on branch, bubble on load-use hazard
            if (flush_pipeline) begin
                idex_pc <= 64'd0;
                idex_rs1_data <= 64'd0;
                idex_rs2_data <= 64'd0;
                idex_imm <= 64'd0;
                idex_rs1 <= 5'd0;
                idex_rs2 <= 5'd0;
                idex_rd <= 5'd0;
                idex_funct3 <= 3'd0;
                idex_funct7_30 <= 1'b0;
                idex_branch <= 1'b0;
                idex_mem_read <= 1'b0;
                idex_mem_to_reg <= 1'b0;
                idex_mem_write <= 1'b0;
                idex_alu_src <= 1'b0;
                idex_reg_write <= 1'b0;
                idex_alu_op <= 2'b00;
                idex_instr <= 32'd0;
            end else if (stall_pipeline) begin
                idex_pc <= 64'd0;
                idex_rs1_data <= 64'd0;
                idex_rs2_data <= 64'd0;
                idex_imm <= 64'd0;
                idex_rs1 <= 5'd0;
                idex_rs2 <= 5'd0;
                idex_rd <= 5'd0;
                idex_funct3 <= 3'd0;
                idex_funct7_30 <= 1'b0;
                idex_branch <= 1'b0;
                idex_mem_read <= 1'b0;
                idex_mem_to_reg <= 1'b0;
                idex_mem_write <= 1'b0;
                idex_alu_src <= 1'b0;
                idex_reg_write <= 1'b0;
                idex_alu_op <= 2'b00;
                idex_instr <= 32'd0;
            end else begin
                idex_pc <= ifid_pc;
                idex_rs1_data <= id_rs1_data;
                idex_rs2_data <= id_rs2_data;
                idex_imm <= id_imm;
                idex_rs1 <= id_rs1;
                idex_rs2 <= id_rs2;
                idex_rd <= id_rd;
                idex_funct3 <= ifid_instr[14:12];
                idex_funct7_30 <= ifid_instr[30];
                idex_branch <= id_branch;
                idex_mem_read <= id_mem_read;
                idex_mem_to_reg <= id_mem_to_reg;
                idex_mem_write <= id_mem_write;
                idex_alu_src <= id_alu_src;
                idex_reg_write <= id_reg_write;
                idex_alu_op <= id_alu_op;
                idex_instr <= ifid_instr;
            end

            // EX/MEM update
            exmem_alu_result <= ex_alu_result;
            exmem_store_data <= ex_store_data;
            exmem_rd <= idex_rd;
            exmem_mem_read <= idex_mem_read;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_mem_write <= idex_mem_write;
            exmem_reg_write <= idex_reg_write;
            exmem_instr <= idex_instr;

            // MEM/WB update
            memwb_mem_data <= mem_read_data;
            memwb_alu_result <= exmem_alu_result;
            memwb_rd <= exmem_rd;
            memwb_mem_to_reg <= exmem_mem_to_reg;
            memwb_reg_write <= exmem_reg_write;
            memwb_instr <= exmem_instr;
        end
    end

endmodule
