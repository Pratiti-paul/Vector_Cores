# Synthesis & Verification Results

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Course:** MCA Computer Architecture Coursework  
**Document Status:** Pre-Synthesis Functional Verification Complete; Full-Processor Synthesis Pending Integration  

---

## 1. Synthesis Status Overview

Hardware logic synthesis (resource utilization, slice logic, maximum operating frequency $F_{\max}$, and timing slack) is scheduled to be performed on the complete top-level processor (`rtl/top_module.v`) once all submodule implementations (`alu.v`, `register_file.v`, `data_memory.v`, `address_decoder.v`) are completed and integrated.

- **Current Status:** In Development (Pre-Synthesis).
- **Assigned Contributor:** Member 5 (Full processor verification, synthesis, and hardware resource analysis).
- **Target Synthesis Tool:** AMD Xilinx Vivado / FPGA synthesis toolchain.

### Target Synthesis Metrics (To Be Populated Post-Integration)

| Metric | Target / Result | Notes |
|---|---|---|
| **Target Device** | *To be determined* | E.g., Artix-7 / Basys 3 FPGA |
| **Slice LUTs** | *Pending synthesis* | Logic utilization |
| **Slice Registers (FFs)** | *Pending synthesis* | Sequential elements (PC, Registers) |
| **Distributed / Block RAM** | *Pending synthesis* | Instruction & Data memory utilization |
| **Worst Negative Slack (WNS)** | *Pending synthesis* | Timing analysis |
| **Maximum Frequency ($F_{\max}$)** | *Pending synthesis* | Critical path constraint |

> [!NOTE]
> In accordance with project integrity standards, no estimated or invented synthesis measurements are recorded prior to executing the actual hardware synthesis toolflow.

---

## 2. Pre-Synthesis Functional Verification Results

Prior to top-level synthesis, individual hardware modules undergo standalone functional verification using Icarus Verilog (`iverilog`) and waveform inspection.

### 2.1 Instruction Memory Verification

- **Module:** `rtl/instruction_memory.v`
- **Testbench:** `testbench/instruction_memory_tb.v`
- **Verification Environment:** Icarus Verilog, GTKWave / Surfer waveform viewer
- **Verification Scope:** Standalone verification of all 16 instruction memory locations (`0x0`–`0xF`), combinational read latency, and instruction field decoding with zero unused bits.
- **Execution Command (run from repository root):**
  ```bash
  iverilog -o imem_test rtl/instruction_memory.v testbench/instruction_memory_tb.v
  vvp imem_test
  ```

**Result:** All 16 instruction memory locations passed verification and every instruction decoded correctly.

**Simulation Log Output:**
```text
VCD info: dumpfile instruction_memory.vcd opened for output.
Starting Instruction Memory Tests
PASS addr=0 instr=5405
PASS addr=1 instr=5803
PASS addr=2 instr=3580
PASS addr=3 instr=2480
PASS addr=4 instr=4580
PASS addr=5 instr=1c80
PASS addr=6 instr=5f01
PASS addr=7 instr=f000
PASS addr=8 instr=f000
PASS addr=9 instr=f000
PASS addr=10 instr=f000
PASS addr=11 instr=f000
PASS addr=12 instr=f000
PASS addr=13 instr=f000
PASS addr=14 instr=f000
PASS addr=15 instr=f000
--- Instruction format check ---
addr=0 ADDI  rd=R1, rs=R0, imm=5
addr=1 ADDI  rd=R2, rs=R0, imm=3
addr=2 ADD   rd=R1, rs=R1, rt=R2
addr=3 STORE rs=R1, [2]
addr=4 SUB   rd=R1, rs=R1, rt=R2
addr=5 LOAD  rd=R3, [2]
addr=6 ADDI  rd=R3, rs=R3, imm=1
addr=7 HALT
addr=15 HALT
ALL INSTRUCTION MEMORY TESTS PASSED
```

### Waveform Inspection
![Instruction memory waveform](../docs/report/instruction_memory_waveform.png)

*Figure 1: Waveform demonstrating asynchronous combinational instruction fetch. The `instr` bus updates immediately with address changes. Program instructions are retrieved from addresses `0x0`–`0x6`, addresses `0x7`–`0xF` return `HALT` (`16'hF000`), and non-sequential address transitions verify combinational behavior.*

### Functional Observations
- **Combinational Fetch:** Instruction memory is read-only and unclocked, yielding purely combinational read latency.
- **Harvard Architecture Advantage:** Having independent instruction and data memory paths enables simultaneous instruction fetch and data operand access in the same clock cycle without memory port contention.
- **Unused Instruction Trap:** Unused memory space is safely populated with `HALT` (`16'hF000`) instructions, preventing runaway execution.

### 2.2 Program Counter & Control Unit Verification Summary
- **Program Counter (`rtl/program_counter.v`):** Verified via `testbench/program_counter_tb.v`. Confirmed synchronous reset to `4'b0000`, sequential increment, jump address loading, and `pc_enable` hold functionality.
- **Control Unit (`rtl/control_unit.v`):** Verified via `testbench/control_unit_tb.v`. Confirmed exact control signal decoding for all 8 ISA opcodes (`LOAD`, `STORE`, `ADD`, `SUB`, `ADDI`, `BEQ`, `JUMP`, `HALT`).
