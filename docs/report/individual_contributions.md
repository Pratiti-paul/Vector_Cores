# Individual Contributions Report

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Course:** MCA Computer Architecture Coursework  
**Repository:** [Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)  

---

## Team Overview & Responsibility Matrix

| Member | Contributor | Assigned Components & Scope | Verified Contributions | Status |
|---|---|---|---|:---:|
| **Member 1** | Pratiti Paul | Program Counter, Control Unit, Top Module Integration, System Scaffolding | Program Counter (`rtl/program_counter.v`), Control Unit (`rtl/control_unit.v`), Top Module (`rtl/top_module.v`), Unit Testbenches, System Setup | **Completed & Verified** |
| **Member 2** | Anuradha Raghuwanshi | Instruction Memory, Instruction Encoding, Test Program | Instruction Memory (`rtl/instruction_memory.v`), Testbench (`testbench/instruction_memory_tb.v`), `program.hex` | **Completed & Verified** |
| **Member 3** | Ganga | Data Memory, Address Decoder, Data Memory Testbench | Data Memory (`rtl/data_memory.v`), Address Decoder (`rtl/address_decoder.v`), Testbench (`testbench/data_memory_tb.v`) | **Completed & Verified** |
| **Member 4** | Alisha Gupta | Arithmetic Logic Unit (ALU), Register File, Unit Testbenches | ALU (`rtl/alu.v`), Register File (`rtl/register_file.v`), Testbenches (`alu_tb.v`, `register_file_tb.v`) | **Completed & Verified** |
| **Member 5** | Team Contributor | Full Processor Verification, Waveform Analysis, System Simulation | Full Processor Testbench (`testbench/processor_tb.v`), Simulation Waveform (`simulation/waveforms/processor_wave.vcd`) | **Completed & Verified** |

---

## Member 1 – Pratiti Paul: Program Counter, Control Unit, and Top Module Integration

**Contributor:** Pratiti Paul  
**Main code contributions:**
- Program Counter (`rtl/program_counter.v`) and testbench (`testbench/program_counter_tb.v`)
- Control Unit (`rtl/control_unit.v`) and testbench (`testbench/control_unit_tb.v`)
- Top Module Datapath Integration (`rtl/top_module.v`)
- Project structure, technical documentation, and simulation workflows

### 1. Work Completed
- Designed and implemented the synchronous 4-bit Program Counter module with synchronous active-high reset and clock enable.
- Designed and implemented the combinational Control Unit decoding all 8 processor opcodes.
- Integrated all 7 submodules into the single-cycle Harvard Architecture processor datapath in `rtl/top_module.v`.
- Designed register read address steering logic for STORE and BEQ, ALU operand multiplexing, writeback selection, and next-PC generation.
- Authored dedicated unit testbenches for Program Counter and Control Unit in Verilog HDL.
- Established repository directory hierarchy, git configuration, build workflows, and architectural specifications.

### 2. Design of the Program Counter
| Parameter | Value |
|---|---|
| Address Width | 4 bits (`pc_out[3:0]`) |
| Range | `0x0` to `0xF` (16 instruction memory locations) |
| Clocking | Positive edge triggered (`posedge clk`) |
| Reset | Active-high synchronous reset (`reset = 1'b1` resets PC to `4'b0000`) |
| Control Signals | `pc_enable` (holds address when `0`, advances to `pc_next` when `1`) |

### 3. Design of the Control Unit
The Control Unit is a combinational module that maps opcode `instr[15:12]` to datapath steering signals:
- Generates `pc_enable`, `reg_write`, `mem_read`, `mem_write`, `alu_control[1:0]`, `alu_src`, `mem_to_reg`, `branch_enable`, `jump_enable`, and `halted`.
- Implements `HALT` (`1111`) handling by clearing `pc_enable = 0` and asserting `halted = 1`.
- Provides safe default signal states for unmapped or invalid opcodes.

### 4. Top Module Datapath Integration
`rtl/top_module.v` structurally interconnects the single-cycle processor components:
- **Register Read Port 1 Steering:** Evaluates `read_reg1 = (opcode == STORE || opcode == BEQ) ? instr[11:10] : instr[9:8];` to ensure correct source operand delivery.
- **Register Read Port 2 Steering:** Evaluates `read_reg2 = (opcode == BEQ) ? instr[9:8] : instr[7:6];`.
- **ALU Operand Multiplexing:** Routes `read_data2` or sign-extended `imm[7:0]` based on `alu_src`.
- **Writeback Multiplexing:** Selects Data Memory `read_data` on `LOAD` (`mem_to_reg = 1`) or ALU result (`mem_to_reg = 0`).
- **Next-PC Logic:** Supports sequential increment ($PC + 1$), relative branch ($PC + 1 + offset[3:0]$ on `BEQ` equality), and absolute jump (`instr[3:0]` on `JUMP`).

### 5. Verification Summary
- **Program Counter:** Verified with `testbench/program_counter_tb.v`. Validated reset to zero, sequential increment (`PC=1`, `PC=2`), jump destination update (`PC=10`), and hold on `pc_enable = 0`.
- **Control Unit:** Verified with `testbench/control_unit_tb.v`. Tested all 8 opcodes (`LOAD`, `STORE`, `ADD`, `SUB`, `ADDI`, `BEQ`, `JUMP`, `HALT`) against expected control bus patterns.
- **Top Module:** Compiled with 0 warnings/errors across all module dependencies.

---

## Member 2 – Anuradha Raghuwanshi: Instruction Memory and Instruction Tests

**Contributor:** Anuradha Raghuwanshi

**Main code contribution:** Instruction Memory (`rtl/instruction_memory.v`)  
**Additional contribution:** Instruction tests (`testbench/instruction_memory_tb.v`, `program.hex`)

### 1. Work completed
- Designed and implemented the instruction memory module of the Harvard-style processor.
- Wrote a self-checking Verilog testbench that verifies all 16 instruction memory locations and decodes each fetched instruction using the team's instruction format.
- Wrote a test program (`program.hex`) that uses LOAD, STORE, ADD, SUB, ADDI and HALT for later full-processor testing.
- Verified the design in Icarus Verilog and inspected the waveform in the Surfer waveform viewer.

### 2. Design of the instruction memory
| Parameter | Value |
|---|---|
| Size | 16 locations |
| Word width | 16 bits |
| Address width | 4 bits (driven by `program_counter.pc_out`) |
| Access | Read-only |
| Read type | Asynchronous (combinational) |
| Initialisation | `$readmemh("program.hex")`; unused locations default to HALT (`F000`) |

The memory is read-only because instructions are never modified during execution. The read is combinational so that, in the single-cycle processor, the instruction is available in the same cycle in which the program counter changes. Because instruction memory is separate from data memory (Harvard architecture), an instruction fetch and a data memory access can occur in the same cycle without conflict. A shared (von Neumann) memory would need a single port for both and would have to serialise them.

### 3. Instruction format
The instruction word is 16 bits wide and `[15:12]` is always the opcode. The remaining 12 bits depend on the instruction. All unused bits are zero. Register addresses are 2 bits (R0-R3), LOAD/STORE addresses are 4 bits (16 data memory locations).

| Instruction | Opcode | Syntax | Fields |
|---|---|---|---|
| LOAD | 0001 | `LOAD rd, [address]` | `[11:10]` rd, `[9:6]` address, `[5:0]` unused |
| STORE | 0010 | `STORE rs, [address]` | `[11:10]` rs, `[9:6]` address, `[5:0]` unused |
| ADD | 0011 | `ADD rd, rs, rt` | `[11:10]` rd, `[9:8]` rs, `[7:6]` rt, `[5:0]` unused |
| SUB | 0100 | `SUB rd, rs, rt` | `[11:10]` rd, `[9:8]` rs, `[7:6]` rt, `[5:0]` unused |
| ADDI | 0101 | `ADDI rd, rs, imm` | `[11:10]` rd, `[9:8]` rs, `[7:0]` signed immediate |
| BEQ | 0110 | `BEQ rs, rt, offset` | `[11:10]` rs, `[9:8]` rt, `[7:0]` signed offset (added to PC + 1) |
| JUMP | 0111 | `JUMP address` | `[11:4]` unused, `[3:0]` absolute address |
| HALT | 1111 | `HALT` | `[11:0]` unused |

The opcodes match `control_unit.v`.

### 4. Test program (`program.hex`)
| Addr | Hex | Instruction | Expected effect |
|---|---|---|---|
| 0 | 5405 | ADDI R1, R0, 5 | R1 = 5 |
| 1 | 5803 | ADDI R2, R0, 3 | R2 = 3 |
| 2 | 3580 | ADD R1, R1, R2 | R1 = 8 |
| 3 | 2480 | STORE R1, [2] | DMEM[2] = 8 |
| 4 | 4580 | SUB R1, R1, R2 | R1 = 5 |
| 5 | 1C80 | LOAD R3, [2] | R3 = 8 |
| 6 | 5F01 | ADDI R3, R3, 1 | R3 = 9 |
| 7 | F000 | HALT | PC stops |

The program assumes all registers are 0 after reset (R0 is used as a zero source). Expected final state after full-processor simulation: R1 = 5, R2 = 3, R3 = 9, DMEM[2] = 8.

### 5. Verification
The testbench (`instruction_memory_tb.v`) performs:
1. Read of all 16 instruction memory locations, compared against `program.hex`.
2. Non-sequential address changes (0 -> 15 -> 5) to confirm the combinational read.
3. Check that unused locations (8-15) return HALT.
4. Decode of every fetched instruction with the agreed field layout, and a check that all unused bits are zero.

---

## Member 3 – Ganga: Data Memory, Address Decoder, and Read/Write Tests

**Contributor:** Ganga

**Main code contribution:** Data Memory (`rtl/data_memory.v`), Address Decoder (`rtl/address_decoder.v`)  
**Additional contribution:** Read/Write tests (`testbench/data_memory_tb.v`)

### 1. Work completed
- Designed and implemented the address decoder module (4-to-16 one-hot combinational decoder with enable control).
- Designed and implemented the data memory module of the Harvard-style processor with synchronous write, asynchronous read, and active-high synchronous reset.
- Integrated the address decoder inside the data memory module to demonstrate decoded word-line selection during write operations.
- Wrote a comprehensive self-checking Verilog testbench covering reset verification, basic read/write, exhaustive 16-location access, write inhibit, read inhibit, program compatibility (STORE/LOAD matching `program.hex`), and overwrite scenarios.
- Generated VCD waveform output (`data_memory.vcd`) for waveform inspection.

### 2. Design of the address decoder

| Parameter | Value |
|---|---|
| Input address width | 4 bits |
| Output select lines | 16 bits (one-hot) |
| Enable control | Active-high; output is all zeros when disabled |
| Logic type | Pure combinational (no clock) |

The address decoder converts the 4-bit memory address into a 16-bit one-hot word-select signal. When `enable` is asserted (driven by `mem_read` or `mem_write` from the control unit), exactly one of the 16 `select_lines` is set high, corresponding to the addressed memory location. When `enable` is deasserted, all select lines are zero, preventing unintended memory access. In physical implementation, these decoded select lines would directly drive the word lines of the SRAM cell array.

### 3. Design of the data memory

| Parameter | Value |
|---|---|
| Size | 16 locations |
| Word width | 8 bits |
| Address width | 4 bits (from instruction bits `[9:6]` for LOAD/STORE) |
| Access | Read/Write |
| Write type | Synchronous (posedge clk, gated by `mem_write`) |
| Read type | Asynchronous (combinational, gated by `mem_read`) |
| Reset | Active-high synchronous; clears all locations to `8'h00` |
| Address decoding | Internal `address_decoder` instance for write word-select |

The data memory is the runtime read/write storage for the processor, accessed exclusively by LOAD and STORE instructions. It is entirely separate from instruction memory (Harvard architecture), which means an instruction fetch and a data memory access can occur simultaneously in the same clock cycle without structural hazard.

**Write path:** On the rising edge of `clk`, if `mem_write` is asserted, the internal address decoder produces a one-hot `write_select` signal. The write loop iterates over all 16 locations and updates only the location whose select line is active. This mirrors how a physical memory array uses decoded word lines to gate individual cells.

**Read path:** The read is combinational (`assign`), gated by `mem_read`. When `mem_read` is deasserted, `read_data` outputs `8'h00` to prevent stale data from leaking onto the datapath bus. This asynchronous read ensures the loaded value is available in the same cycle for register writeback in the single-cycle processor.

### 4. Interface with existing modules

The data memory integrates with the following control signals from `control_unit.v`:
- `mem_read` (opcode `0001` LOAD): enables the combinational read path.
- `mem_write` (opcode `0010` STORE): enables the synchronous write path.
- `mem_to_reg` (LOAD): used by the top module to mux `read_data` into the register writeback.

The memory address is extracted from instruction bits `[9:6]` for LOAD and STORE instructions as specified in the team's instruction format.

### 5. Verification

The testbench (`testbench/data_memory_tb.v`) performs the following tests with automated PASS/FAIL tracking:

1. **Reset verification:** Assert reset, then read all 16 locations to confirm each returns `8'h00`.
2. **Basic write and read:** Write `0xAA` to addr 0 and `0x55` to addr 1, read both back.
3. **Exhaustive 16-location write and read:** Write a unique pattern `(addr * 11 + 5) & 0xFF` to all 16 locations, then read all back to verify zero cross-talk between addresses.
4. **Write inhibit:** With `mem_write = 0`, attempt to write `0xFF` to addr 0 — verify the existing value is preserved.
5. **Read inhibit:** With `mem_read = 0`, verify `read_data` outputs `8'h00` regardless of stored content.
6. **Program compatibility:** Simulate the `STORE R1, [2]` and `LOAD R3, [2]` sequence from `program.hex` — write value `8` to addr 2, read it back, and confirm the result.
7. **Overwrite:** Write `0x42` to addr 5, then overwrite with `0xBE` — verify only the latest value is retained.

---

## Member 4 – Alisha Gupta: Arithmetic Logic Unit (ALU) and Register File

**Contributor:** Alisha Gupta  
**Main code contributions:**
- Arithmetic Logic Unit (`rtl/alu.v`) and testbench (`testbench/alu_tb.v`)
- Register File (`rtl/register_file.v`) and testbench (`testbench/register_file_tb.v`)

### 1. Work Completed
- Designed and implemented the 8-bit combinational Arithmetic Logic Unit supporting addition, subtraction, modulo-256 wraparound, and zero flag generation.
- Designed and implemented the 4-entry 8-bit dual-read single-write Register File with active-high synchronous reset and hardware zero protection for register R0.
- Authored automated self-checking unit testbenches for both modules.
- Formally verified both modules with 100% pass rates in Icarus Verilog.

### 2. Design of the Arithmetic Logic Unit (ALU)
| Parameter | Value |
|---|---|
| Operand Width | 8 bits (`alu_in1[7:0]`, `alu_in2[7:0]`) |
| Result Width | 8 bits (`alu_out[7:0]`) |
| Control Input | 2 bits (`alu_control[1:0]` from control unit) |
| Operations | `2'b00` = ADD (`ADD`, `ADDI`), `2'b01` = SUB (`SUB`, `BEQ`) |
| Zero Flag | Asserted (`1'b1`) when `alu_out == 8'b00000000` |
| Timing | Pure combinational logic (zero clock cycle latency) |

The ALU handles addition and subtraction for arithmetic instructions and branch comparisons. Arithmetic overflow cleanly wraps modulo-256 (e.g., $255 + 1 = 0$), and negative differences produce correct two's complement representations (e.g., $3 - 5 = 254$ / `8'hFE`).

### 3. Design of the Register File
| Parameter | Value |
|---|---|
| Register Count | 4 general-purpose registers (`R0`, `R1`, `R2`, `R3`) |
| Register Width | 8 bits per register |
| Read Ports | 2 asynchronous (combinational) read ports (`read_data1`, `read_data2`) |
| Write Port | 1 synchronous write port (`write_data`, gated by `reg_write`) |
| Reset | Active-high synchronous; clears all registers to `8'h00` |
| R0 Hardwiring | Reads to address `00` return `8'h00`; writes to `00` are blocked |

The Register File features combinational dual-read access so that both source operands are immediately available to the ALU during the single-cycle execution stage. Synchronous writing on `posedge clk` commits the result at cycle completion. Hardwiring R0 to constant zero guarantees a safe zero source for `ADDI` operations.

### 4. Verification Summary
- **ALU Testbench (`testbench/alu_tb.v`):** Self-checking testbench covering addition, subtraction, zero result equality, addition overflow, subtraction underflow, zero addition, and maximum non-overflow addition. Result: **7/7 PASSED (0 errors)**.
- **Register File Testbench (`testbench/register_file_tb.v`):** Self-checking testbench verifying reset, independent dual reads, single-port synchronous writes, write-inhibit when `reg_write = 0`, and R0 write protection. Result: **6/6 PASSED (0 errors)**.

---

## Member 5 – Full Processor Verification, Waveform Analysis, and System-Level Testing

**Contributor:** Member 5  
**Main code contributions:**
- Full Processor Integration Testbench (`testbench/processor_tb.v`)
- Simulation Waveform Analysis (`simulation/waveforms/processor_wave.vcd`)

### 1. Work Completed
- Developed a comprehensive self-checking system-level testbench instantiating `top_module.v`.
- Configured a 100 MHz clock source (`10 ns` period) and active-high synchronous reset protocol.
- Executed the complete verification program (`program.hex`) through the processor datapath.
- Implemented real-time cycle-by-cycle execution tracing of PC, instruction word, ALU outputs, writeback data, and status flags.
- Implemented automated post-halt verification to confirm PC freeze and write inhibition across subsequent clock cycles.
- Recorded and archived the complete value-change dump waveform (`processor_wave.vcd`).

### 2. Full Processor Verification Results (`program.hex`)
The processor executed all 7 program instructions and reached the `HALT` instruction in cycle 7, followed by 3 verification hold cycles:

| Cycle | PC | Instruction Word | Disassembly | Architectural State Change | Status |
|:---:|:---:|:---:|---|---|:---:|
| Reset | `0x0` | `5405` | `ADDI R1, R0, 5` | Reset active, internal state cleared to 0 | PASS |
| Cycle 1 | `0x1` | `5803` | `ADDI R2, R0, 3` | $R1 \leftarrow 0 + 5 = 5$ | PASS |
| Cycle 2 | `0x2` | `3580` | `ADD R1, R1, R2` | $R2 \leftarrow 0 + 3 = 3$ | PASS |
| Cycle 3 | `0x3` | `2480` | `STORE R1, [2]` | $R1 \leftarrow 5 + 3 = 8$ | PASS |
| Cycle 4 | `0x4` | `4580` | `SUB R1, R1, R2` | $\text{DMEM}[2] \leftarrow 8$ | PASS |
| Cycle 5 | `0x5` | `1C80` | `LOAD R3, [2]` | $R1 \leftarrow 8 - 3 = 5$ | PASS |
| Cycle 6 | `0x6` | `5F01` | `ADDI R3, R3, 1` | $R3 \leftarrow \text{DMEM}[2] = 8$ | PASS |
| Cycle 7 | `0x7` | `F000` | `HALT` | $R3 \leftarrow 8 + 1 = 9$; `halted = 1`, `pc_enable = 0` | PASS |
| Cycles 8–10 | `0x7` | `F000` | *Halt Hold Observation* | PC holds at 7, no extraneous writes | PASS |

### 3. Final Terminal Assertions
- `assert_equal(pc_out, 4'd7)` $\rightarrow$ **PASS**
- `assert_equal(halted, 1'b1)` $\rightarrow$ **PASS**
- `assert_equal(registers[0], 8'd0)` $\rightarrow$ **PASS**
- `assert_equal(registers[1], 8'd5)` $\rightarrow$ **PASS**
- `assert_equal(registers[2], 8'd3)` $\rightarrow$ **PASS**
- `assert_equal(registers[3], 8'd9)` $\rightarrow$ **PASS**
- `assert_equal(DMEM[2], 8'd8)` $\rightarrow$ **PASS**

**Summary:** **7/7 Assertions Passed, 0 Errors.**
