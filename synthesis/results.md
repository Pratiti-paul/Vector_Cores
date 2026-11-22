# Synthesis & Verification Results

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Course:** MCA Computer Architecture Coursework  
**Document Status:** Synthesis, place-and-route and timing complete (open-source iCE40 flow). Section 2 records the earlier pre-synthesis instruction-memory verification.

---

## 1. Synthesis, Place-and-Route and Timing Results

### 1.1 Flow

| Item | Value |
|---|---|
| Synthesis | Yosys 0.71 (`synth_ice40 -noflatten`) |
| Place and route / timing | nextpnr-ice40 0.11.1 |
| Target device | Lattice iCE40 HX8K, CT256 package (7,680 logic cells) |
| Designs | Harvard `top_module`, Von Neumann baseline `vn_top_module`, memory-hierarchy processor `mh_top_module` (L1 caches + shared L2) |
| Seeds | 5 placement seeds per design; the median Fmax is reported |
| Script | `synthesis/run_ice40.sh` (run from the repository root) |
| Raw reports | `synthesis/ice40/` |

Reproduce:

```bash
bash synthesis/run_ice40.sh
```

Method notes:

- **Hierarchy is kept** (`-noflatten`). If the design is flattened, Yosys propagates the constant contents of `program.hex` and removes data-memory bits that the sample program never writes. That would make the results depend on the program, so the hierarchical result is reported.
- **Fmax is measured flip-flop to flip-flop.** `synthesis/fmax_wrappers.v` registers every processor output. Without it, the timing analyser would include routing to unconstrained output pins.

### 1.2 Results

| Metric | Harvard (`top_module`) | Von Neumann (`vn_top_module`) | L1 caches + shared L2 (`mh_top_module`) |
|---|---:|---:|---:|
| Logic LUTs (`SB_LUT4`) | 321 | 571 | 689 |
| Flip-flops (`SB_DFF*`) | 156 | 301 | 476 |
| Carry cells (`SB_CARRY`) | 19 | 19 | 24 |
| Block RAM (`ICESTORM_RAM`) | 0 | 0 | 0 |
| **Fmax, median of 5 seeds** | **63.86 MHz** | **37.69 MHz** | **42.33 MHz** |
| Fmax range over 5 seeds | 58.98 – 65.65 MHz | 37.20 – 40.55 MHz | 41.84 – 43.25 MHz |
| Minimum clock period | 15.66 ns | 26.53 ns | 23.62 ns |

LUT and flip-flop counts are for the processor core only. The Fmax wrapper's output registers are not included.

**Flip-flop breakdown**
- **Harvard (156):** 128 data memory (16 × 8) + 24 register file (R1–R3) + 4 PC.
- **Von Neumann (301):** 256 unified-memory data region (16 words × 16 bits) + 16 instruction register + 24 register file + 4 PC + 1 FSM state.
- **Memory hierarchy (476):** 256 shared-memory data region + 144 I-cache (8 lines × (16 data + 1 tag + 1 valid)) + 44 D-cache (4 lines × (8 data + 2 tag + 1 valid)) + 24 register file + 4 PC + 4 wait counter.

The memories are cleared on reset (and the cache arrays are read combinationally), so they are built from flip-flops rather than block RAM. The Xilinx 7-Series mapping (`synthesis/run_yosys_reports.sh`) gives 202 / 287 / 325 LUTs and 156 / 301 / 300 flip-flops for the three designs; on Xilinx the cache data arrays map to 5 `RAM32M` distributed-RAM cells.

### 1.3 Critical Paths

| Design | Critical path |
|---|---|
| Harvard | PC → instruction ROM → register-file read → ALU (carry chain) → write-back |
| Von Neumann | PC → shared-port address mux → 32-word unified-memory read mux → instruction mux → decode → register-file read → ALU → write-back |
| L1 caches + shared L2 | PC → I-cache line read → decode → D-cache tag compare → arbiter address mux → shared-memory read → forwarded LOAD data → register file (a LOAD miss) |

In the Von Neumann design, instruction fetch has to pass through the shared memory's address multiplexer and its larger 32-word read multiplexer. This lengthens the critical path, so the shared-memory design is slower **per cycle** as well as needing more cycles.

### 1.4 Execution Time (Cycles × Clock Period)

Cycle counts come from `testbench/harvard_vs_vn_tb.v`. The clock periods are the median Fmax values above.

| Program | Harvard cycles | VN cycles | Harvard time | VN time | Harvard speed-up |
|---|---:|---:|---:|---:|---:|
| P1 `program.hex` (mixed) | 7 | 9 | 109.6 ns | 238.8 ns | **2.18×** |
| P2 memory-heavy | 10 | 17 | 156.6 ns | 451.0 ns | **2.88×** |
| P3 compute-only loop | 16 | 16 | 250.5 ns | 424.5 ns | **1.69×** |

### 1.5 Limitations

- These are post-route results for a Lattice iCE40 FPGA and were not measured on hardware. Xilinx (Vivado) results would differ in absolute value.
- The design was not run on a physical board, and power was not measured.

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
Running the testbench writes `instruction_memory.vcd` to the repository root (open it with `gtkwave instruction_memory.vcd`). The waveform shows asynchronous combinational instruction fetch: the `instr` bus updates as soon as the address changes. Program instructions are read from addresses `0x0`–`0x6`, addresses `0x7`–`0xF` return `HALT` (`16'hF000`), and non-sequential address changes confirm the combinational behavior.

Instruction fetch inside the running processor, one fetched instruction per cycle, is shown in the annotated timing diagram [`docs/waveforms/harvard_vs_vn_p1.svg`](../docs/waveforms/harvard_vs_vn_p1.svg) (row "IMEM -> instruction").

### Functional Observations
- **Combinational Fetch:** Instruction memory is read-only and unclocked, yielding purely combinational read latency.
- **Harvard Architecture Advantage:** Having independent instruction and data memory paths enables simultaneous instruction fetch and data operand access in the same clock cycle without memory port contention.
- **Unused Instruction Trap:** Unused memory space is safely populated with `HALT` (`16'hF000`) instructions, preventing runaway execution.

### 2.2 Program Counter & Control Unit Verification Summary
- **Program Counter (`rtl/program_counter.v`):** Verified via `testbench/program_counter_tb.v`. Confirmed synchronous reset to `4'b0000`, sequential increment, jump address loading, and `pc_enable` hold functionality.
- **Control Unit (`rtl/control_unit.v`):** Verified via `testbench/control_unit_tb.v`. Confirmed exact control signal decoding for all 8 ISA opcodes (`LOAD`, `STORE`, `ADD`, `SUB`, `ADDI`, `BEQ`, `JUMP`, `HALT`).
