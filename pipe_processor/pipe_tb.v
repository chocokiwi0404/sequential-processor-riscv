`timescale 1ns / 1ps
`include "pipe.v"

module pipe_tb;
    reg clk;
    reg reset;
    integer i;
    integer f;
    integer cycle_num;
    integer cycle_count;
    reg stop_clock;

    // Instantiate the Top-Level Processor
    pipe_processor dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 10ns period
    initial begin
        
        clk = 0;
        stop_clock = 0;

        if(stop_clock == 0)
        begin
            forever begin 
                clk = ~clk;
                #5;
            end
        end
         
     end

    // Simulation sequence
    initial begin
        // Initialize signals
        reset = 1;
        cycle_num = 0;

        cycle_count = 0;

        // Apply reset for 2 cycles
        #20;
        reset = 0;

        // Run for a specific number of cycles
        // Based on your sample output, 15 cycles are expected [cite: 275]
        
    for (cycle_num = 0; cycle_num < 500; cycle_num = cycle_num + 1) begin
        
        @(posedge clk);

        $display("\n Cycle no. %0d , instruction = %h, flag_fetch = %b", cycle_num , dut.if_instruction, dut.flag_fetch);
    

        cycle_count <= cycle_count + 1;

        if(dut.flag_fetch==0)
        begin
             cycle_num = 501;     
             stop_clock = 1;


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

    end


      
    end

endmodule