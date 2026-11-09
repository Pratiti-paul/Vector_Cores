# Individual Contributions Report

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Course:** MCA Computer Architecture Coursework  
**Repository:** [Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)  

---

## Team Overview & Responsibility Matrix

| Member | Contributor | Assigned Components & Responsibilities | Implementation Status |
|---|---|---|---|
| **Member 1** | Pratiti Paul | Program Counter, Control Unit, Top Module, System Scaffolding | PC & Control Unit Completed & Verified; Top Module in progress |
| **Member 2** | Anuradha Raghuwanshi | Instruction Memory, Instruction Encoding, Test Program | Completed & Verified |
| **Member 3** | Team Contributor | Data Memory, Address Decoder | In Development |
| **Member 4** | Team Contributor | Arithmetic Logic Unit (ALU), Register File | In Development |
| **Member 5** | Team Contributor | Full Processor Verification, Waveform Analysis, Synthesis | In Development (Pending integration) |

---

## Member 1 – Pratiti Paul: Program Counter, Control Unit, and Architectural Scaffolding

**Contributor:** Pratiti Paul  
**Main code contributions:**
- Program Counter (`rtl/program_counter.v`) and testbench (`testbench/program_counter_tb.v`)
- Control Unit (`rtl/control_unit.v`) and testbench (`testbench/control_unit_tb.v`)
- Project structure, technical documentation, and simulation workflows

### 1. Work Completed
- Designed and implemented the synchronous 4-bit Program Counter module.
- Designed and implemented the combinational Control Unit decoding all 8 processor opcodes.
- Authored dedicated unit testbenches for both modules in Verilog HDL.
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

### 4. Verification Summary
- **Program Counter:** Verified with `testbench/program_counter_tb.v`. Validated reset to zero, sequential increment (`PC=1`, `PC=2`), jump destination update (`PC=10`), and hold on `pc_enable = 0`.
- **Control Unit:** Verified with `testbench/control_unit_tb.v`. Tested all 8 opcodes (`LOAD`, `STORE`, `ADD`, `SUB`, `ADDI`, `BEQ`, `JUMP`, `HALT`) against expected control bus patterns.

---

## Member 2 – Anuradha Raghuwanshi: Instruction Memory and Instruction Tests

**Contributor:** Anuradha Raghuwanshi

**Main code contribution:** Instruction Memory (`rtl/instruction_memory.v`)  
**Additional contribution:** Instruction tests (`testbench/instruction_memory_tb.v`, `program.hex`)

### 1. Work completed
- Designed and implemented the instruction memory module of the Harvard-style processor.
- Wrote a self-checking Verilog testbench that verifies every memory location and decodes each fetched instruction using the team's instruction format.
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
1. Read of all 16 locations, compared against `program.hex`.
2. Non-sequential address changes (0 -> 15 -> 5) to confirm the combinational read.
3. Check that unused locations (8-15) return HALT.
4. Decode of every fetched instruction with the agreed field layout, and a check that all unused bits are zero.

---

## Member 3 – In Development: Data Memory and Address Decoder
- **Assigned Modules:** `rtl/data_memory.v`, `rtl/address_decoder.v`, `testbench/data_memory_tb.v`
- **Scope:** 16 × 8-bit RAM module with synchronous write and asynchronous read, address decoding logic for data selection.
- **Current Status:** Module interface and file scaffolding in place; implementation in progress.

---

## Member 4 – In Development: Arithmetic Logic Unit (ALU) and Register File
- **Assigned Modules:** `rtl/alu.v`, `rtl/register_file.v`, `testbench/alu_tb.v`
- **Scope:** 8-bit ALU supporting addition, subtraction, zero flag generation; 4 × 8-bit dual-read single-write register file.
- **Current Status:** Module interface and file scaffolding in place; implementation in progress.

---

## Member 5 – In Development: Full Processor Verification, Waveform Analysis, and Synthesis
- **Assigned Scope:** `testbench/processor_tb.v`, integration test execution, waveform analysis, and FPGA synthesis reporting.
- **Current Status:** Scaffolding in place; execution scheduled following completion of Members 3 and 4 modules and top-level datapath integration.
