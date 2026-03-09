module pc (
    input wire clk,
    input wire reset,
    input wire [63:0] imm_data,
    input wire branch,
    input wire zero_flag,
    output reg [63:0] pc_out
);

    // Internal wires for the update logic
    wire [63:0] pc_plus_4;
    wire [63:0] branch_target;
    wire [63:0] next_pc;

    // --- PC Update Logic ---
    // PC + 4 calculation for sequential execution
    assign pc_plus_4 = pc_out + 64'd4;
    
    // Branch Target calculation: PC + Immediate
    assign branch_target = pc_out + imm_data;
    
    // PC Source Mux: Choose between PC+4 or Branch Target
    assign next_pc = (branch & zero_flag) ? branch_target : pc_plus_4;

    // --- Sequential Logic ---
    always @(posedge clk) begin
        if (reset) begin
            pc_out <= 64'b0;
        end else begin
            pc_out <= next_pc;
        end
    end

endmodule