`timescale 1ns / 1ps
`include "pipe.v"

module pipe_tb;
    reg clk;
    reg reset;
    reg done;

    integer i;
    integer f;
    integer cycle_count;
    integer nop_retired_streak;
    integer max_cycles;
    reg saw_nonzero_retire;

    pipe_processor dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 10ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reset and run configuration
    initial begin
        reset = 1'b1;
        done = 1'b0;
        cycle_count = 0;
        nop_retired_streak = 0;
        saw_nonzero_retire = 1'b0;
        max_cycles = 500;

        // Keep reset asserted for 2 cycles
        #20;
        reset = 1'b0;
    end

    // Completion logic
    always @(posedge clk) begin
        if (!reset && !done) begin
            cycle_count = cycle_count + 1;

            // Ignore bubbles (instr = 0). Track retired instructions at WB stage.
            if (dut.memwb_instr != 32'h00000000) begin
                saw_nonzero_retire = 1'b1;

                // Project doc says 4 trailing dummy instructions (add x0,x0,x0)
                if (dut.memwb_instr == 32'h00000033)
                    nop_retired_streak = nop_retired_streak + 1;
                else
                    nop_retired_streak = 0;
            end

            if (saw_nonzero_retire && (nop_retired_streak >= 4))
                done = 1'b1;

            if (cycle_count >= max_cycles)
                done = 1'b1;
        end
    end

    // Final output generation
    initial begin
        wait(done);
        #1;

        f = $fopen("register_file.txt", "w");
        if (f) begin
            for (i = 0; i < 32; i = i + 1) begin
                $fwrite(f, "%h\n", dut.registers.regfile[i]);
            end
            $fwrite(f, "%0d\n", cycle_count);
            $fclose(f);
        end

        $display("Simulation finished. register_file.txt generated. cycles=%0d", cycle_count);
        $finish;
    end

endmodule
