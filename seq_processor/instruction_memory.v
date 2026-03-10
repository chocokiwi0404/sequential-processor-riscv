module instruction_memory (
    input clk,
    input reset,
    input [63:0] addr,
    output [31:0] instr,
    output flag_fetch
);

    reg [7:0] mem [0:4095];

    integer fd;
    integer r;
    integer byte_ptr;

    reg [7:0] b0, b1, b2, b3;
    reg [63:0] last_addr;

    initial begin
        fd = $fopen("instructions.txt","r");
        byte_ptr = 0;

        if (fd == 0) begin
            $display("File open failed");
            $finish;
        end

        while (!$feof(fd)) begin

            r = $fscanf(fd,"%h\n",b0);
            r = $fscanf(fd,"%h\n",b1);
            r = $fscanf(fd,"%h\n",b2);
            r = $fscanf(fd,"%h\n",b3);

            mem[byte_ptr]     = b0;
            mem[byte_ptr + 1] = b1;
            mem[byte_ptr + 2] = b2;
            mem[byte_ptr + 3] = b3;

            byte_ptr = byte_ptr + 4;
        end

        last_addr = byte_ptr - 4;

        $fclose(fd);
    end


    assign instr = (reset) ? 32'b0 :
                   {mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};


    assign flag_fetch = (addr <= last_addr);

endmodule