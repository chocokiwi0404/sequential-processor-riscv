
# RV64I RISC-V Processor

A Verilog implementation of **Single-Cycle** and **5-Stage Pipelined** RV64I RISC-V processors developed as part of the *Introduction to Processor Architecture* course.

## Repository Structure

```
.
├── pipe_processor/              # 5-stage pipelined processor implementation
├── seq_processor/               # Single-cycle processor implementation
├── Processor_Project_Doc.pdf
└── README.md
```

## Features

### Single-Cycle Processor
- Complete RV64I datapath
- ALU and Control Unit
- Register File
- Instruction & Data Memory

### 5-Stage Pipelined Processor
- IF, ID, EX, MEM, WB pipeline stages
- Pipeline registers
- Data forwarding
- Hazard detection and stall control
- Branch handling with pipeline flush

## Tools

- Verilog HDL
- Icarus Verilog
- GTKWave

## Documentation

The project specifications are included in the repository in the Processor_Project_Doc.pdf


## Run Instructions

### Sequential Processor

- `proc.v` contains the complete top-level implementation of the sequential processor.
- `seq_tb.v` is the testbench for the sequential processor.

Compile and run using:

```bash
iverilog -o seq_tb seq_tb.v
vvp seq_tb
```

- To view the simulation waveforms in **GTKWave**, add the `$dumpfile` and `$dumpvars` commands to the testbench, for example:

```verilog
initial begin
    $dumpfile("seq.vcd");
    $dumpvars(0, seq_tb);
end
```

Then open the generated waveform file:

```bash
gtkwave seq.vcd
```

- After execution, the final contents of the register file will be written to `register_file.txt`.

---

### Pipelined Processor

- `proc.v` contains the complete top-level implementation of the pipelined processor.
- `pipe_tb.v` is the testbench for the pipelined processor.

Compile and run using:

```bash
iverilog -o pipe_tb pipe_tb.v
vvp pipe_tb
```

- To view the simulation waveforms in **GTKWave**, add the `$dumpfile` and `$dumpvars` commands to the testbench, for example:

```verilog
initial begin
    $dumpfile("pipe.vcd");
    $dumpvars(0, pipe_tb);
end
```

Then open the generated waveform file:

```bash
gtkwave pipe.vcd
```

- After execution, the final contents of the register file will be written to `register_file.txt`.
