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

## Report
Full design report available in `doc/fifo_report.pdf`
（如果你还没把pdf放进去，这行先删掉）
