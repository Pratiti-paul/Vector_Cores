# Vector Cores Phase II – Python Assembler Design Document

## 1. Overview
The Vector Cores Python Assembler converts assembly language programs into 16-bit hexadecimal machine code formatted for loading into the processor's Instruction Memory via the Verilog `$readmemh` system task.

- **Architecture:** 16-bit Harvard Architecture Single-Cycle Processor
- **Instruction Memory:** 16 locations × 16 bits (4-bit program counter)
- **Registers:** 4 general-purpose registers `R0`–`R3` (2-bit address, `R0` hardwired to 0)
- **Data Memory:** 16 locations × 8 bits (4-bit memory address)

---

## 2. Supported Instructions & Encodings

The assembler supports all 11 instructions:

| Instruction | Syntax | Opcode (4b) | Format | Description |
|---|---|:---:|---|---|
| **LOAD** | `LOAD rd, [addr]` | `0001` | `0001 dd aaaa 000000` | Load 8-bit value from DMEM[`addr`] into `rd` |
| **STORE** | `STORE rs, [addr]` | `0010` | `0010 ss aaaa 000000` | Store 8-bit value from `rs` into DMEM[`addr`] |
| **ADD** | `ADD rd, rs, rt` | `0011` | `0011 dd ss tt 000000` | `rd = rs + rt` |
| **SUB** | `SUB rd, rs, rt` | `0100` | `0100 dd ss tt 000000` | `rd = rs - rt` |
| **ADDI** | `ADDI rd, rs, imm` | `0101` | `0101 dd ss iiiiiiii` | `rd = rs + imm8` (signed 8-bit immediate) |
| **BEQ** | `BEQ rs, rt, offset` | `0110` | `0110 ss tt oooooooo` | Branch if `rs == rt` to `PC + 1 + offset8` |
| **JUMP** | `JUMP addr` | `0111` | `0111 00000000 aaaa` | Unconditional jump to 4-bit absolute `addr` |
| **AND** | `AND rd, rs, rt` | `1000` | `1000 dd ss tt 000000` | `rd = rs & rt` (Bitwise AND) |
| **OR** | `OR rd, rs, rt` | `1001` | `1001 dd ss tt 000000` | `rd = rs \| rt` (Bitwise OR) |
| **XOR** | `XOR rd, rs, rt` | `1010` | `1010 dd ss tt 000000` | `rd = rs ^ rt` (Bitwise XOR) |
| **HALT** | `HALT` | `1111` | `1111 000000000000` | Halts execution, deasserts `pc_enable` |

*Note on Logical Instructions:*
Opcodes `1000`, `1001`, and `1010` are defined and encoded by the assembler. Hardware support for ALU logical operations is implemented on the `alisha/alu-3bit` branch and awaiting final merge into the top-level Control Unit.

---

## 3. Bit Field Definitions
All instructions are exactly 16 bits wide:
- `[15:12]` : 4-bit Opcode
- `[11:10]` : 2-bit Destination Register (`rd`) or Source Register (`rs` for STORE and BEQ)
- `[9:8]`   : 2-bit Source Register 1 (`rs`) or Source Register 2 (`rt` for BEQ)
- `[7:6]`   : 2-bit Source Register 2 (`rt`) for R-type instructions (ADD, SUB, AND, OR, XOR)
- `[9:6]`   : 4-bit Data Memory Address for LOAD and STORE
- `[7:0]`   : 8-bit Signed Immediate / Offset for ADDI and BEQ
- `[3:0]`   : 4-bit Absolute Instruction Address for JUMP
- All unused / reserved bits are explicitly filled with zeros.

---

## 4. Branch & Jump Semantics
- **BEQ (Branch if Equal):**
  Uses PC+1-relative addressing:
  $$\text{target\_address} = (\text{current\_PC} + 1) + \text{offset}$$
  $$\text{offset} = \text{target\_address} - (\text{current\_PC} + 1)$$
  The assembler calculates this offset automatically when labels are used. Both numeric offsets and symbolic labels are supported.
- **JUMP:**
  Uses 4-bit absolute instruction addresses (`0` to `15`).

---

## 5. Software Architecture
The assembler is modularized into clean Python components:
- `assembler/instructions.py`: Centralized opcode mapping, instruction definitions, constants, and limits.
- `assembler/parser.py`: Two-pass parser supporting label definitions, comment stripping (`#` and `;`), case-insensitivity, and line-tracking.
- `assembler/validator.py`: Strict validation of register identifiers (`R0`–`R3`), 4-bit memory addresses (`0`–`15`), 8-bit signed immediates (`-128` to `+127`), operand counts, and program size ($\le 16$ instructions).
- `assembler/encoder.py`: Field packing and formatting to 16-bit binary and 4-character uppercase hexadecimal.
- `assembler/assembler.py`: Command-line interface and orchestrator for assembling files.

---

## 6. Hex File Format (`$readmemh` Compatibility)
- Exactly 16 lines corresponding to 16 words in Instruction Memory.
- 4 uppercase hexadecimal digits per line (e.g., `5405`, `F000`).
- No prefixes (`0x`), commas, or trailing spaces.
- Unused memory locations are padded with `F000` (`HALT`).
