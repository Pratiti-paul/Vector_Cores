# Vector Cores: Technical Specification

**Project:** Vector Cores — 16-Bit Harvard Architecture Processor  
**Course:** MCA Computer Architecture Coursework  
**Document Version:** 1.0  
**Status:** In Development  

---

## 1. Architectural Overview

### 1.1 Harvard Architecture Principles
**Vector Cores** implements a single-cycle processor based on the **Harvard Architecture**. The key architectural feature is the strict physical separation of the instruction storage and data storage subsystems:

- **Instruction Memory (IMEM):** 16 locations × 16 bits, dedicated read-only port for instruction fetch.
- **Data Memory (DMEM):** 16 locations × 8 bits, dedicated read/write port for runtime data storage.

In contrast to the classical Von Neumann architecture—where instructions and data compete for a shared memory bus and memory access port—the Harvard architecture allows instruction fetching and data memory read/write operations to occur concurrently within the same clock cycle without structural hazards or bus contention.

### 1.2 Processor Parameters

| Parameter | Value | Description |
|---|---|---|
| **Architecture Type** | Harvard Architecture | Independent instruction and data memories |
| **Execution Model** | Single-Cycle Datapath | One instruction executed per clock cycle |
| **Instruction Width** | 16 bits | Fixed-length instruction word |
| **Data Width** | 8 bits | 8-bit integer datapath and ALU operations |
| **Program Counter Width** | 4 bits | Addresses 16 instruction memory words (`0x0`–`0xF`) |
| **Instruction Memory Size** | 16 × 16 bits | Asynchronous / combinational read-only memory |
| **Data Memory Size** | 16 × 8 bits | Synchronous write, asynchronous read RAM |
| **Register File Size** | 4 registers × 8 bits | R0, R1, R2, R3 (R0 initialized to 0) |
| **Register Address Width** | 2 bits | Selects 1 of 4 registers (`00`=R0, `01`=R1, `10`=R2, `11`=R3) |
| **Data Address Width** | 4 bits | Addresses 16 data memory bytes (`0x0`–`0xF`) |
| **Clocking** | Single-phase | Positive-edge triggered (`posedge clk`) |
| **Reset** | Synchronous | Active-high reset (`reset = 1'b1`) |

---

## 2. Instruction Set Architecture (ISA) & Encoding

### 2.1 Instruction Format Definition
All instructions are 16 bits wide. Bits `[15:12]` strictly designate the **4-bit opcode**.  
The interpretation of bits `[11:0]` depends on the instruction category. All unused bits in any instruction word **must be set to zero (`0`)**.

```text
 15        12 11     10 9       8 7       6 5                      0
+------------+---------+---------+---------+------------------------+
|   Opcode   |   rd    |   rs    |   rt    |      unused (000000)   | ADD / SUB
+------------+---------+---------+---------+------------------------+
|   Opcode   |   rd    |   rs    |       signed immediate [7:0]     | ADDI
+------------+---------+---------+---------+------------------------+
|   Opcode   |   rs    |   rt    |       signed offset [7:0]        | BEQ
+------------+---------+---------+---------+------------------------+
|   Opcode   |   rd    |   address [9:6]   |      unused (000000)   | LOAD
+------------+---------+---------+---------+------------------------+
|   Opcode   |   rs    |   address [9:6]   |      unused (000000)   | STORE
+------------+---------+---------+---------+------------------------+
|   Opcode   |          unused [11:4]          |   target addr [3:0]    | JUMP
+------------+---------------------------------+------------------------+
|   Opcode   |                  unused [11:0]                           | HALT
+------------+----------------------------------------------------------+
```

### 2.2 Instruction Encoding Table

| Instruction | Opcode `[15:12]` | Bitfields `[11:0]` | Description | Operation |
|---|---|---|---|---|
| **LOAD** | `0001` | `[11:10]` rd<br>`[9:6]` address<br>`[5:0]` unused (`6'b000000`) | Load byte from Data Memory into destination register | $R[rd] \leftarrow \text{DMEM}[address]$ |
| **STORE** | `0010` | `[11:10]` rs<br>`[9:6]` address<br>`[5:0]` unused (`6'b000000`) | Store byte from source register into Data Memory | $\text{DMEM}[address] \leftarrow R[rs]$ |
| **ADD** | `0011` | `[11:10]` rd<br>`[9:8]` rs<br>`[7:6]` rt<br>`[5:0]` unused (`6'b000000`) | Add registers `rs` and `rt`, store sum in `rd` | $R[rd] \leftarrow R[rs] + R[rt]$ |
| **SUB** | `0100` | `[11:10]` rd<br>`[9:8]` rs<br>`[7:6]` rt<br>`[5:0]` unused (`6'b000000`) | Subtract register `rt` from `rs`, store difference in `rd` | $R[rd] \leftarrow R[rs] - R[rt]$ |
| **ADDI** | `0101` | `[11:10]` rd<br>`[9:8]` rs<br>`[7:0]` signed immediate | Add 8-bit signed immediate to `rs`, store in `rd` | $R[rd] \leftarrow R[rs] + imm$ |
| **BEQ** | `0110` | `[11:10]` rs<br>`[9:8]` rt<br>`[7:0]` signed offset | Branch to $PC + 1 + offset$ if $R[rs] == R[rt]$ | $\text{if } (R[rs] == R[rt]) \quad PC \leftarrow PC + 1 + offset$ |
| **JUMP** | `0111` | `[11:4]` unused (`8'b00000000`)<br>`[3:0]` target address | Unconditional jump to 4-bit target instruction address | $PC \leftarrow address$ |
| **HALT** | `1111` | `[11:0]` unused (`12'b000000000000`) | Halt processor execution, freeze PC | $pc\_enable \leftarrow 0, \quad halted \leftarrow 1$ |

> [!IMPORTANT]
> Unused bit positions (`6'b000000` for LOAD, STORE, ADD, SUB; `8'b00000000` for JUMP; `12'b000000000000` for HALT) are reserved and must always be encoded as binary zeros. Any non-zero values in these bits are considered invalid.

---

## 3. Control Unit Specification

The Control Unit is a combinational decoding block that evaluates opcode `instr[15:12]` and asserts the appropriate datapath control signals.

### 3.1 Control Signal Descriptions

| Signal Name | Width | Type | Active | Functional Description |
|---|---|---|---|---|
| `pc_enable` | 1 bit | Output | High (`1`) | Enables the Program Counter register update. Deasserted on `HALT` or invalid opcode. |
| `reg_write` | 1 bit | Output | High (`1`) | Write enable for the Register File (asserted for `LOAD`, `ADD`, `SUB`, `ADDI`). |
| `mem_read` | 1 bit | Output | High (`1`) | Read enable for Data Memory (asserted for `LOAD`). |
| `mem_write` | 1 bit | Output | High (`1`) | Write enable for Data Memory (asserted for `STORE`). |
| `alu_control` | 2 bits | Output | Binary | Operation selector for the ALU:<br>• `2'b00`: Addition (`ADD`, `ADDI`)<br>• `2'b01`: Subtraction (`SUB`, `BEQ`) |
| `alu_src` | 1 bit | Output | High (`1`) | Selects ALU second operand source:<br>• `0`: Register `rt` operand (`read_data2`)<br>• `1`: 8-bit sign-extended immediate (`imm[7:0]`) |
| `mem_to_reg` | 1 bit | Output | High (`1`) | Selects destination register writeback data:<br>• `0`: ALU output (`alu_out`)<br>• `1`: Data Memory output (`mem_data`) |
| `branch_enable`| 1 bit | Output | High (`1`) | Enables branch evaluation for `BEQ` when ALU zero flag is set. |
| `jump_enable` | 1 bit | Output | High (`1`) | Enables unconditional jump to target address (`JUMP`). |
| `halted` | 1 bit | Output | High (`1`) | Status flag indicating processor has halted execution (`HALT`). |

### 3.2 Control Unit Truth Table

| Instruction | Opcode `[15:12]` | `pc_enable` | `reg_write` | `mem_read` | `mem_write` | `alu_control` | `alu_src` | `mem_to_reg` | `branch_enable` | `jump_enable` | `halted` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **LOAD** | `0001` | 1 | 1 | 1 | 0 | 00 | 0 | 1 | 0 | 0 | 0 |
| **STORE** | `0010` | 1 | 0 | 0 | 1 | 00 | 0 | 0 | 0 | 0 | 0 |
| **ADD** | `0011` | 1 | 1 | 0 | 0 | 00 | 0 | 0 | 0 | 0 | 0 |
| **SUB** | `0100` | 1 | 1 | 0 | 0 | 01 | 0 | 0 | 0 | 0 | 0 |
| **ADDI** | `0101` | 1 | 1 | 0 | 0 | 00 | 1 | 0 | 0 | 0 | 0 |
| **BEQ** | `0110` | 1 | 0 | 0 | 0 | 01 | 0 | 0 | 1 | 0 | 0 |
| **JUMP** | `0111` | 1 | 0 | 0 | 0 | 00 | 0 | 0 | 0 | 1 | 0 |
| **HALT** | `1111` | 0 | 0 | 0 | 0 | 00 | 0 | 0 | 0 | 0 | 1 |
| *Default* | *Others* | 0 | 0 | 0 | 0 | 00 | 0 | 0 | 0 | 0 | 0 |

---

## 4. Module Interface Specifications

### 4.1 Program Counter (`program_counter.v`)
- **Function:** 4-bit synchronous register storing the current instruction memory fetch address.
- **Ports:**
  - `input wire clk`: Positive-edge system clock.
  - `input wire reset`: Synchronous active-high reset. Forces `pc_out <= 4'b0000`.
  - `input wire pc_enable`: Clock enable signal from control unit. When `0`, `pc_out` holds its previous value.
  - `input wire [3:0] pc_next`: Next Program Counter address (from sequential incrementer, branch adder, or jump target).
  - `output reg [3:0] pc_out`: Current 4-bit address presented to Instruction Memory.

### 4.2 Instruction Memory (`instruction_memory.v`)
- **Function:** 16 × 16-bit read-only memory holding the program instructions.
- **Characteristics:** Asynchronous (combinational) read. Initialized from `program.hex` via `$readmemh`. Unused entries default to `16'hF000` (`HALT`).
- **Ports:**
  - `input wire [3:0] addr`: 4-bit instruction address driven by `program_counter.pc_out`.
  - `output wire [15:0] instr`: 16-bit instruction word fetched combinationally.

### 4.3 Control Unit (`control_unit.v`)
- **Function:** Opcode decoder generating all datapath steering and control signals.
- **Ports:**
  - `input wire [3:0] opcode`: Bits `[15:12]` of fetched instruction.
  - `output reg pc_enable`: PC advance enable.
  - `output reg reg_write`: Register file write enable.
  - `output reg mem_read`: Data memory read enable.
  - `output reg mem_write`: Data memory write enable.
  - `output reg [1:0] alu_control`: ALU function code.
  - `output reg alu_src`: ALU second operand multiplexer select.
  - `output reg mem_to_reg`: Writeback multiplexer select.
  - `output reg branch_enable`: Branch qualifier.
  - `output reg jump_enable`: Jump target select.
  - `output reg halted`: Processor halted indicator.

### 4.4 Register File (`register_file.v`)
- **Function:** 4 general-purpose 8-bit registers (R0, R1, R2, R3).
- **Ports:**
  - `input wire clk`: System clock.
  - `input wire reset`: Reset signal.
  - `input wire reg_write`: Synchronous write enable.
  - `input wire [1:0] read_reg1`: Address for operand 1 (from `instr[9:8]` or `instr[11:10]`).
  - `input wire [1:0] read_reg2`: Address for operand 2 (from `instr[7:6]` or `instr[9:8]`).
  - `input wire [1:0] write_reg`: Address for destination register (`instr[11:10]`).
  - `input wire [7:0] write_data`: 8-bit data to write on positive clock edge.
  - `output wire [7:0] read_data1`: Asynchronous read data for operand 1.
  - `output wire [7:0] read_data2`: Asynchronous read data for operand 2.

### 4.5 Arithmetic Logic Unit (`alu.v`)
- **Function:** 8-bit integer arithmetic unit.
- **Ports:**
  - `input wire [7:0] alu_in1`: First 8-bit operand (from register `rs`).
  - `input wire [7:0] alu_in2`: Second 8-bit operand (from register `rt` or sign-extended immediate).
  - `input wire [1:0] alu_control`: Operation select (`00`=ADD, `01`=SUB).
  - `output reg [7:0] alu_out`: 8-bit arithmetic result.
  - `output wire zero`: Asserted when `alu_out == 8'b00000000`.

### 4.6 Data Memory & Address Decoder (`data_memory.v`, `address_decoder.v`)
- **Function:** 16 locations × 8 bits RAM for program variables and memory access.
- **Ports:**
  - `input wire clk`: System clock.
  - `input wire mem_write`: Synchronous write enable.
  - `input wire mem_read`: Read enable.
  - `input wire [3:0] addr`: 4-bit memory address (`instr[9:6]`).
  - `input wire [7:0] write_data`: 8-bit data to store.
  - `output wire [7:0] read_data`: 8-bit data retrieved from memory.

### 4.7 Top Module (`top_module.v`)
- **Function:** Top-level structural module connecting PC, Instruction Memory, Control Unit, Register File, ALU, and Data Memory.
- **Ports:**
  - `input wire clk`: Clock source.
  - `input wire reset`: Master synchronous reset.

---

## 5. Verification Program Specification

### 5.1 Test Program Definition (`program.hex`)
The standardized test program validates memory operations, arithmetic operations, immediate handling, and processor halt.

| Address | Machine Code (Hex) | Binary Encoding | Assembly Syntax | Detailed Operation | Expected Result |
|:---:|:---:|:---:|---|---|---|
| `0x0` | `5405` | `0101 0100 0000 0101` | `ADDI R1, R0, 5` | $R1 \leftarrow R0 + 5 = 0 + 5$ | $R1 = 5$ |
| `0x1` | `5803` | `0101 1000 0000 0011` | `ADDI R2, R0, 3` | $R2 \leftarrow R0 + 3 = 0 + 3$ | $R2 = 3$ |
| `0x2` | `3580` | `0011 0101 1000 0000` | `ADD R1, R1, R2` | $R1 \leftarrow R1 + R2 = 5 + 3$ | $R1 = 8$ |
| `0x3` | `2480` | `0010 0100 1000 0000` | `STORE R1, [2]` | $\text{DMEM}[2] \leftarrow R1$ | $\text{DMEM}[2] = 8$ |
| `0x4` | `4580` | `0100 0101 1000 0000` | `SUB R1, R1, R2` | $R1 \leftarrow R1 - R2 = 8 - 3$ | $R1 = 5$ |
| `0x5` | `1C80` | `0001 1100 1000 0000` | `LOAD R3, [2]` | $R3 \leftarrow \text{DMEM}[2]$ | $R3 = 8$ |
| `0x6` | `5F01` | `0101 1111 0000 0001` | `ADDI R3, R3, 1` | $R3 \leftarrow R3 + 1 = 8 + 1$ | $R3 = 9$ |
| `0x7` | `F000` | `1111 0000 0000 0000` | `HALT` | Stop execution, deassert `pc_enable` | $PC = 7$, halted |
| `0x8`–`0xF` | `F000` | `1111 0000 0000 0000` | `HALT` | Unused locations initialized to HALT | Traps invalid execution |

### 5.2 Expected Architectural State After Execution

Upon completion of the test program and assertion of the `halted` signal:
- **Register R0:** `0` (Reference zero register)
- **Register R1:** `5` (`8'h05`)
- **Register R2:** `3` (`8'h03`)
- **Register R3:** `9` (`8'h09`)
- **Data Memory Location 2 (`DMEM[2]`):** `8` (`8'h08`)
- **Program Counter (`PC`):** `7` (`4'h7`), execution frozen.

---

## 6. Simulation & File Path Requirements

1. **Working Directory:** All simulation compilation (`iverilog`) and execution (`vvp`) commands **must be executed from the repository root directory**.
2. **Hex File Path Resolution:** Both `rtl/instruction_memory.v` and `testbench/instruction_memory_tb.v` invoke `$readmemh("program.hex", ...)`. Because the file path is relative, running from the repository root guarantees that `program.hex` is correctly located and loaded without moving or duplicating files.
3. **Instruction Memory Verification:** The self-checking testbench `testbench/instruction_memory_tb.v` validates all 16 instruction memory locations (`0x0`–`0xF`), confirming combinational access, non-sequential addressing, correct opcode and field decoding, zero-padded unused bits, and default `HALT` (`16'hF000`) initialization for unused words.

