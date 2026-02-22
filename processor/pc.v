module pc (
    input clk,
    input reset,
    input [63:0] pc_in,
    output reg [63:0] pc_out
);
    always @(posedge clk) begin
        if (reset) begin
            pc_out <= 64'b0;
        end else begin
            pc_out <= pc_in;
        end
    end
endmodule
