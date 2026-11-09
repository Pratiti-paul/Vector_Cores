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