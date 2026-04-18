# FIFO Design

Synchronous and Asynchronous FIFO RTL implementation with full verification.

## Project Structure
- `Sync_FIFO_project/` — Synchronous FIFO (single clock domain)
- `Async_FIFO_project/` — Asynchronous FIFO (dual clock, CDC)

## Key Features
- (N+1)-bit pointer scheme for full/empty flag generation
- Gray-code pointer synchronization for CDC
- Two-stage synchronizer for metastability mitigation
-  SystemVerilog testbench with self-checking reference model

## Simulation Tool
Icarus Verilog , GTKWave

## Run
### Synchronous FIFO
```bash
cd Sync_FIFO_project
iverilog -g2012 -o test.vvp dut.v tb.sv
vvp test.vvp
gtkwave wave.vcd
```

### Asynchronous FIFO
```bash
cd Async_FIFO_project
iverilog -g2012 -o test.vvp dut.v tb.sv
vvp test.vvp
gtkwave wave.vcd
```


## Report
Full design report available in `FIFO Controller Design Report.pdf`

