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