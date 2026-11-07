## Member 2 – Anuradha Raghuwanshi: Instruction Memory and Instruction Tests

**Contributor:** Anuradha Raghuwanshi

**Main code contribution:** Instruction Memory (`rtl/instruction_memory.v`)
**Additional contribution:** Instruction tests (`testbench/instruction_memory_tb.v`, `program.hex`)

### 1. Work completed
- Designed and implemented the instruction memory module of the Harvard-style processor.
- Wrote a self-checking Verilog testbench that verifies every memory location.
- Wrote a test program (`program.hex`) that uses all six required instructions (LOAD, STORE, ADD, SUB, ADDI, HALT) for later full-processor testing.
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
`[15:12] opcode | [11:10] rd | [9:8] rs | [7:0] immediate / address`

| Instruction | Opcode | Operation |
|---|---|---|
| LOAD | 0001 | R[rd] = DMEM[addr] |
| STORE | 0010 | DMEM[addr] = R[rd] |
| ADD | 0011 | R[rd] = R[rd] + R[rs] |
| SUB | 0100 | R[rd] = R[rd] - R[rs] |
| ADDI | 0101 | R[rd] = R[rd] + imm |
| BEQ | 0110 | Branch (present in control unit) |
| JUMP | 0111 | Jump (present in control unit) |
| HALT | 1111 | Stop the program counter |

The opcodes match `control_unit.v`.

### 4. Test program (`program.hex`)
| Addr | Hex | Instruction | Expected effect |
|---|---|---|---|
| 0 | 5405 | ADDI R1, 5 | R1 = 5 |
| 1 | 5803 | ADDI R2, 3 | R2 = 3 |
| 2 | 3600 | ADD R1, R2 | R1 = 8 |
| 3 | 2402 | STORE R1 -> M[2] | M[2] = 8 |
| 4 | 4600 | SUB R1, R2 | R1 = 5 |
| 5 | 1C02 | LOAD R3 <- M[2] | R3 = 8 |
| 6 | 5C01 | ADDI R3, 1 | R3 = 9 |
| 7 | F000 | HALT | PC stops |

Expected final state after full-processor simulation: R1 = 5, R2 = 3, R3 = 9, DMEM[2] = 8.

### 5. Verification
The testbench (`instruction_memory_tb.v`) performs:
1. Read of all 16 locations, compared against `program.hex`.
2. Non-sequential address changes (0 -> 15 -> 5) to confirm the combinational read.
3. Check that unused locations (8-15) return HALT.
4. Check that the opcodes fetched match the expected instructions.