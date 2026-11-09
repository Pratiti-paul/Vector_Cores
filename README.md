# Vector Cores
### Design and Implementation of an Instruction and Data Memory Hierarchy Using Harvard Architecture

![Language](https://img.shields.io/badge/Language-Verilog-blue)
![Architecture](https://img.shields.io/badge/Architecture-Harvard-purple)
![Domain](https://img.shields.io/badge/Domain-Computer%20Architecture-orange)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)

---

## 1. Project Overview

**Vector Cores** is a Computer Architecture design and verification project developed as part of MCA coursework. The project focuses on designing, implementing, and verifying a simplified single-cycle processor datapath using **Harvard Architecture** and Verilog HDL.

In traditional Von Neumann architecture, instructions and data share a single physical bus and memory space, causing the classic *Von Neumann bottleneck* where instruction fetches and data memory accesses must be serialized. In contrast, the **Harvard Architecture** implements separate physical memories and distinct bus hierarchies:
- **Instruction Memory (IMEM):** 16 locations × 16 bits, dedicated to instruction fetching.
- **Data Memory (DMEM):** 16 locations × 8 bits, dedicated to program data read/write operations.

This separation allows concurrent instruction fetch and data operand read/write within the same clock cycle, supporting high-throughput single-cycle execution.

### Objectives
- Understand and implement the core concepts of Harvard Architecture in Verilog HDL.
- Design independent instruction and data memory modules with proper address decoding.
- Implement a 4-bit Program Counter and combinational Control Unit decoding 8 distinct instructions.
- Design an 8-bit Arithmetic Logic Unit (ALU) and 4-entry dual-read Register File.
- Execute a standardized test program (`program.hex`) verifying arithmetic, memory, and control transfer operations.
- Establish modular verification workflows using Icarus Verilog and waveform analysis.

---

## 2. System Architecture & Datapath

### Processor Datapath Modules

| Component | Source File | Responsibility |
|---|---|---|
| **Program Counter (PC)** | `rtl/program_counter.v` | 4-bit synchronous register holding the current instruction fetch address. |
| **Instruction Memory** | `rtl/instruction_memory.v` | 16 × 16-bit read-only memory supplying instructions asynchronously. |
| **Control Unit** | `rtl/control_unit.v` | Decodes 4-bit opcode `[15:12]` and generates datapath steering signals. |
| **Register File** | `rtl/register_file.v` | 4 general-purpose 8-bit registers (`R0`–`R3`) with dual read and single write ports. |
| **Arithmetic Logic Unit (ALU)** | `rtl/alu.v` | Performs 8-bit arithmetic operations (ADD, SUB) and generates zero flag. |
| **Data Memory** | `rtl/data_memory.v` | 16 × 8-bit RAM storing runtime program variables and data. |
| **Address Decoder** | `rtl/address_decoder.v` | Decodes 4-bit addresses for data memory selection. |
| **Top Module** | `rtl/top_module.v` | Integrates all submodules into a unified single-cycle processor system. |

### Single-Cycle Execution Stages
Every instruction completes within one clock cycle through five functional stages:
1. **Instruction Fetch (IF):** Program Counter outputs a 4-bit address to Instruction Memory, retrieving a 16-bit instruction word combinationally.
2. **Instruction Decode (ID):** Control Unit interprets opcode `[15:12]`, while Register File reads source operands (`rs`, `rt`).
3. **Execution (EX):** ALU performs arithmetic calculation or evaluates branch conditions.
4. **Memory Access (MEM):** Data Memory is read on `LOAD` or written on `STORE`.
5. **Write Back (WB):** Result from the ALU or Data Memory is written back into the destination register `rd`.

### Architecture Parameters

| Parameter | Specification | Details |
|---|---|---|
| **Architecture** | Harvard Architecture | Physically separate instruction and data memories |
| **HDL** | Verilog HDL | IEEE 1364-2001 standard |
| **Datapath Model** | Single-cycle | Single instruction per clock cycle |
| **Instruction Width** | 16 bits | Fixed-length 16-bit instruction word |
| **Data Width** | 8 bits | 8-bit byte-wide data operations |
| **Program Counter Width** | 4 bits | Addresses 16 words (`0x0`–`0xF`) |
| **Instruction Memory** | 16 × 16 bits | Read-only, combinational read, loaded from `program.hex` |
| **Data Memory** | 16 × 8 bits | Synchronous write, asynchronous read |
| **Register File** | 4 registers × 8 bits | R0, R1, R2, R3 (R0 initialized to 0) |
| **Clock / Reset** | Single clock | Positive-edge clock, active-high synchronous reset |

---

## 3. Instruction Set Architecture (ISA) & Encoding

The processor implements a 16-bit instruction set. Bits `[15:12]` represent the **4-bit opcode**, while bits `[11:0]` encode operands, immediate values, or memory addresses.

> [!IMPORTANT]
> All unused bit positions are strictly reserved and **must be set to binary zero (`0`)**.

| Instruction | Opcode `[15:12]` | Syntax | Bitfield Breakdown `[11:0]` | Description |
|---|:---:|---|---|---|
| **LOAD** | `0001` | `LOAD rd, [addr]` | `[11:10]` rd, `[9:6]` address, `[5:0]` unused (`6'b0`) | Load byte from DMEM into register `rd` |
| **STORE** | `0010` | `STORE rs, [addr]` | `[11:10]` rs, `[9:6]` address, `[5:0]` unused (`6'b0`) | Store byte from register `rs` into DMEM |
| **ADD** | `0011` | `ADD rd, rs, rt` | `[11:10]` rd, `[9:8]` rs, `[7:6]` rt, `[5:0]` unused (`6'b0`) | Add registers: $R[rd] \leftarrow R[rs] + R[rt]$ |
| **SUB** | `0100` | `SUB rd, rs, rt` | `[11:10]` rd, `[9:8]` rs, `[7:6]` rt, `[5:0]` unused (`6'b0`) | Subtract registers: $R[rd] \leftarrow R[rs] - R[rt]$ |
| **ADDI** | `0101` | `ADDI rd, rs, imm` | `[11:10]` rd, `[9:8]` rs, `[7:0]` signed immediate | Add immediate: $R[rd] \leftarrow R[rs] + imm$ |
| **BEQ** | `0110` | `BEQ rs, rt, offset` | `[11:10]` rs, `[9:8]` rt, `[7:0]` signed offset | Branch if $R[rs] == R[rt]$ to $PC + 1 + offset$ |
| **JUMP** | `0111` | `JUMP addr` | `[11:4]` unused (`8'b0`), `[3:0]` target address | Unconditional jump to target address |
| **HALT** | `1111` | `HALT` | `[11:0]` unused (`12'b0`) | Freeze PC advance and halt execution |

For complete bitfield diagrams, control signal truth tables, and decoding logic, see the [Technical Specification](docs/technical_specification.md).

---

## 4. Standard Verification Program (`program.hex`)

A standardized machine-code program resides in `program.hex` to validate processor functionality across arithmetic, data memory, immediate operations, and halt behavior.

```text
5405
5803
3580
2480
4580
1C80
5F01
F000
```

### Trace of Operations

| Addr | Hex | Instruction | Bitfields | Operation | Architectural Effect |
|:---:|:---:|---|---|---|---|
| `0x0` | `5405` | `ADDI R1, R0, 5` | `rd=R1, rs=R0, imm=5` | $R1 \leftarrow R0 + 5$ | $R1 = 5$ |
| `0x1` | `5803` | `ADDI R2, R0, 3` | `rd=R2, rs=R0, imm=3` | $R2 \leftarrow R0 + 3$ | $R2 = 3$ |
| `0x2` | `3580` | `ADD R1, R1, R2` | `rd=R1, rs=R1, rt=R2` | $R1 \leftarrow R1 + R2$ | $R1 = 8$ |
| `0x3` | `2480` | `STORE R1, [2]` | `rs=R1, addr=2` | $\text{DMEM}[2] \leftarrow R1$ | $\text{DMEM}[2] = 8$ |
| `0x4` | `4580` | `SUB R1, R1, R2` | `rd=R1, rs=R1, rt=R2` | $R1 \leftarrow R1 - R2$ | $R1 = 5$ |
| `0x5` | `1C80` | `LOAD R3, [2]` | `rd=R3, addr=2` | $R3 \leftarrow \text{DMEM}[2]$ | $R3 = 8$ |
| `0x6` | `5F01` | `ADDI R3, R3, 1` | `rd=R3, rs=R3, imm=1` | $R3 \leftarrow R3 + 1$ | $R3 = 9$ |
| `0x7` | `F000` | `HALT` | `unused=12'b0` | Halt execution | $PC = 7$, halted |
| `0x8`–`0xF` | `F000` | `HALT` | `unused=12'b0` | Trap unused space | Halt safeguard |

### Expected Final State After Execution
- **$R1 = 5$**
- **$R2 = 3$**
- **$R3 = 9$**
- **$\text{DMEM}[2] = 8$**
- **$PC = 7$** (with `halted = 1`, `pc_enable = 0`)

---

## 5. Repository Structure

```text
Vector_Cores/
│
├── rtl/                                  # Synthesizable Verilog RTL source files
│   ├── program_counter.v                 # 4-bit Program Counter module
│   ├── instruction_memory.v              # 16x16-bit Harvard Instruction Memory
│   ├── data_memory.v                     # 16x8-bit Harvard Data Memory
│   ├── address_decoder.v                 # Memory address decoding logic
│   ├── control_unit.v                    # Instruction opcode decoder & control generator
│   ├── alu.v                             # 8-bit Arithmetic Logic Unit
│   ├── register_file.v                   # 4x8-bit dual-port Register File
│   └── top_module.v                      # Processor datapath top-level integration
│
├── testbench/                            # Verilog simulation testbenches
│   ├── program_counter_tb.v              # Program Counter unit testbench
│   ├── instruction_memory_tb.v           # Instruction Memory self-checking testbench
│   ├── control_unit_tb.v                 # Control Unit unit testbench
│   ├── data_memory_tb.v                  # Data Memory unit testbench
│   ├── alu_tb.v                          # ALU unit testbench
│   └── processor_tb.v                    # Top-level full processor testbench
│
├── docs/                                 # Project documentation
│   ├── technical_specification.md        # Comprehensive ISA, datapath, and module spec
│   ├── architecture/
│   │   └── block_diagram.png             # Processor datapath architectural diagram
│   └── report/
│       ├── individual_contributions.md   # Team contribution breakdown and progress report
│       └── instruction_memory_waveform.png # Verified simulation waveform for IMEM
│
├── simulation/                           # Simulation artifacts
│   ├── waveforms/                        # Value Change Dump (.vcd) simulation traces
│   └── logs/                             # Simulation output execution logs
│
├── synthesis/                            # Synthesis reports and resource utilization
│   └── results.md                        # Pre-synthesis verification & synthesis status
│
├── program.hex                           # 16-bit hexadecimal test program
├── README.md                             # Project overview and user guide
└── .gitignore                            # Git ignore rules for build and temp files
```

---

## 6. Development Tools & Prerequisites

| Tool | Purpose | Source / Installation |
|---|---|---|
| **Verilog HDL** | Hardware Description Language | IEEE 1364-2001 standard |
| **Icarus Verilog (`iverilog`)** | Simulation compiler and runtime engine (`vvp`) | `brew install icarus-verilog` (macOS) / `apt install iverilog` (Ubuntu) |
| **GTKWave / Surfer** | Waveform viewer for `.vcd` files | `brew install --cask gtkwave` / [Surfer](https://gitlab.com/surfer-project/surfer) |
| **Git & GitHub** | Version control and collaborative development | `git` CLI |
| **AMD Xilinx Vivado** | FPGA logic synthesis and resource estimation | Post-integration synthesis |

---

## 7. Compiling and Running Simulations

> [!IMPORTANT]
> **Working Directory Notice:** Always run simulation commands from the **repository root directory** (`Vector_Cores/`). `rtl/instruction_memory.v` and its testbench reference `"program.hex"` using relative paths.

### 1. Test Instruction Memory
Validates all 16 instruction memory locations, combinational retrieval, non-sequential address fetching, unused location traps, and full field-level instruction decoding:
```bash
iverilog -o imem_test rtl/instruction_memory.v testbench/instruction_memory_tb.v
vvp imem_test
```

### 2. Test Program Counter
Validates synchronous reset, sequential increment, jump address loading, and hold functionality:
```bash
iverilog -o pc_test rtl/program_counter.v testbench/program_counter_tb.v
vvp pc_test
```

### 3. Test Control Unit
Validates control signal decoding across all 8 instructions (`LOAD`, `STORE`, `ADD`, `SUB`, `ADDI`, `BEQ`, `JUMP`, `HALT`):
```bash
iverilog -o control_test rtl/control_unit.v testbench/control_unit_tb.v
vvp control_test
```

### 4. Waveform Visualization
To inspect signal transitions in GTKWave:
```bash
gtkwave instruction_memory.vcd
```

---

## 8. Verification Status & Project Progress

| Subsystem / Task | Assigned Lead | Implementation Status | Functional Verification | Synthesis Status |
|---|---|---|---|---|
| **Program Counter** | Member 1 (Pratiti Paul) | **Complete** | **Passed** (`program_counter_tb.v`) | Pending top integration |
| **Control Unit** | Member 1 (Pratiti Paul) | **Complete** | **Passed** (`control_unit_tb.v`) | Pending top integration |
| **Instruction Memory** | Member 2 (Anuradha Raghuwanshi) | **Complete** | **Passed** (`instruction_memory_tb.v`) | Pending top integration |
| **Data Memory & Address Decoder** | Member 3 | *In Development* | Pending | Pending |
| **ALU & Register File** | Member 4 | *In Development* | Pending | Pending |
| **Top Module Integration** | Member 1 (Pratiti Paul) | *In Development* | Pending submodules | Pending |
| **Full Processor Testbench** | Member 5 | *In Development* | Pending integration | Pending |
| **FPGA Synthesis & Timing** | Member 5 | *Scheduled* | Pending integration | Scheduled (Vivado) |

*Note: In accordance with project engineering ethics, synthesis resource numbers and maximum frequencies are not recorded until physical synthesis is executed by Member 5.*

---

## 9. Team Contributions & Git Workflow

The project is developed collaboratively by five team members following a branch-and-PR workflow:

| Contributor | Assigned Scope & Modules | Verified Contributions | Status |
|---|---|---|---|
| **Member 1 (Pratiti Paul)** | Project Lead; Program Counter, Control Unit, Top Module integration, Scaffolding | Program Counter (`rtl/program_counter.v`), Control Unit (`rtl/control_unit.v`), Testbenches, Repository Scaffolding, Documentation | PC & Control Unit Completed & Verified; Top Module in progress |
| **Member 2 (Anuradha Raghuwanshi)** | Memory Systems & Instruction Encoding | Instruction Memory (`rtl/instruction_memory.v`), Testbench (`testbench/instruction_memory_tb.v`), Instruction Format Verification, `program.hex` | Completed & Verified |
| **Member 3** | Data Memory Subsystem & Address Decoding (`rtl/data_memory.v`, `rtl/address_decoder.v`, `testbench/data_memory_tb.v`) | *None (Pending implementation)* | In Development |
| **Member 4** | ALU & Register File (`rtl/alu.v`, `rtl/register_file.v`, `testbench/alu_tb.v`) | *None (Pending implementation)* | In Development |
| **Member 5** | System Verification, Waveforms, Synthesis (`testbench/processor_tb.v`, Vivado Synthesis) | *None (Pending integration)* | In Development (Scheduled post-integration) |

Detailed individual contributions, design rationale, and verification logs are maintained in [Individual Contributions Report](docs/report/individual_contributions.md).

---

## 10. Contributors & License

**Vector Cores — Computer Architecture Project**  
Developed as part of the MCA Computer Architecture coursework.  
**Repository:** [https://github.com/Pratiti-paul/Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)

---
*Demonstrating hardware-level separation of instruction and data hierarchies through clean Verilog design and modular verification.*
