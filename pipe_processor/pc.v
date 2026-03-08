module pc (
    input wire clk,
    input wire reset,

    // NEW: controls whether PC updates this cycle
    input wire pc_write_enable,

    input wire [63:0] imm_data,
    input wire branch,
    input wire zero_flag,

    output reg [63:0] pc_out
);

    ////////////////////////////////////////////////////////////
    //////////////////// PC UPDATE LOGIC ///////////////////////
    ////////////////////////////////////////////////////////////

    // PC + 4 calculation for normal sequential execution
    wire [63:0] pc_plus_4;
    assign pc_plus_4 = pc_out + 64'd4;

    // Branch target computation
    // Target = PC + immediate offset
    wire [63:0] branch_target;
    assign branch_target = pc_out + imm_data;

    // Select next PC based on branch decision
    // If branch instruction AND condition satisfied → jump
    // Otherwise continue sequential execution

    wire [63:0] next_pc;
    assign next_pc = (branch & zero_flag) ? branch_target : pc_plus_4;

    ////////////////////////////////////////////////////////////
    ////////////////// SEQUENTIAL UPDATE ///////////////////////
    ////////////////////////////////////////////////////////////

    always @(posedge clk) begin

        // Reset condition
        if (reset) begin
            pc_out <= 64'b0;
        end

        // NORMAL UPDATE
        // PC only updates when pc_write_enable is high
        // This allows the hazard detection unit to STALL
        // the pipeline during load-use hazards

        else if (pc_write_enable) begin
            pc_out <= next_pc;
        end

        // STALL CONDITION
        // If pc_write_enable = 0 we simply hold the current PC value
        // This causes the IF stage to refetch the same instruction
        // for one more cycle

        else begin
            pc_out <= pc_out;
        end
    end

endmodule