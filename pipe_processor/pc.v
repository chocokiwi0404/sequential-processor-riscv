module pc (
    input wire clk,
    input wire reset,
    input wire [63:0] imm_data,
    input wire branch,
    input wire zero_flag,
    output reg [63:0] pc_out
);

////////////////////////////////////////////////////////////
//////////////////// PC UPDATE LOGIC ///////////////////////
////////////////////////////////////////////////////////////

// Sequential execution → PC + 4
wire [63:0] pc_plus_4;
assign pc_plus_4 = pc_out + 64'd4;

// Branch target address
wire [63:0] branch_target;
assign branch_target = pc_out + imm_data;

// Select next PC
// If branch instruction AND condition true → jump
// Otherwise continue sequential execution

wire [63:0] next_pc;
assign next_pc = (branch && zero_flag) ? branch_target : pc_plus_4;

////////////////////////////////////////////////////////////
//////////////////// SEQUENTIAL LOGIC //////////////////////
////////////////////////////////////////////////////////////

always @(posedge clk) begin

    // Reset initializes PC to 0
    if (reset) begin
        pc_out <= 64'b0;
    end

    // Normal update every cycle
    else begin
        pc_out <= next_pc;
    end

end

endmodule