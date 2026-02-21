`timescale 1ns / 1ps
`include "proc.v"

module seq_tb;
    reg clk;
    reg reset;
    integer i;
    integer f;
    integer cycle_count;

    // Instantiate the Top-Level Processor
    RISCV_Processor dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simulation sequence
    initial begin
        // Initialize signals
        reset = 1;
        cycle_count = 0;

        // Apply reset for 2 cycles
        #20;
        reset = 0;

        // Run for a specific number of cycles
        // Based on your sample output, 15 cycles are expected [cite: 275]
        for (cycle_count = 0; cycle_count < 15; cycle_count = cycle_count + 1) begin
            @(posedge clk);
        end

        // Wait a small amount for the final write-back to settle
        #5;

        // Write to register_file.txt as required [cite: 119, 123, 399, 403]
        f = $fopen("register_file.txt", "w");
        if (f) begin
            for (i = 0; i < 32; i = i + 1) begin
                // Accessing the internal regfile within the registers instance
                $fwrite(f, "%h\n", dut.registers.regfile[i]);
            end
            // Append the final cycle count in decimal 
            $fwrite(f, "%0d\n", cycle_count);
            $fclose(f);
        end

        $display("Simulation finished. register_file.txt generated.");
        $finish;
    end

endmodule