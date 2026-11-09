# Vector Cores
### Design and Implementation of an Instruction and Data Memory Hierarchy Using Harvard Architecture

![Language](https://img.shields.io/badge/Language-Verilog-blue)
![Architecture](https://img.shields.io/badge/Architecture-Harvard-purple)
![Domain](https://img.shields.io/badge/Domain-Computer%20Architecture-orange)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)

## Overview

**Vector Cores** is a Computer Architecture project that focuses on designing and implementing a simplified processor using **Harvard Architecture** and Verilog HDL.

The project demonstrates how separating instruction memory and data memory enables independent access to instructions and data. Unlike the traditional Von Neumann architecture, where instructions and data share a common memory path, Harvard Architecture provides separate memory units and access paths.

The processor is designed to execute a small instruction set and demonstrate fundamental processor operations, including instruction fetching, decoding, arithmetic execution, memory access, and register writeback.

The implementation also explores processor control logic, memory organization, and simulation-based functional verification.

## Objectives

- Understand and implement the fundamental concepts of Harvard Architecture.
- Design separate instruction and data memory modules.
- Develop a simplified processor datapath using Verilog HDL.
- Implement instruction decoding and control signal generation.
- Perform arithmetic and logical operations using an ALU.
- Implement register-based data storage and memory access.
- Verify processor functionality through simulation and testbenches.
- Analyze processor behavior using waveform visualization.

## Architecture

### Harvard Architecture

The proposed processor follows Harvard Architecture, where instruction memory and data memory operate independently.

**Key characteristics:**

- Separate Instruction Memory (IMEM) and Data Memory (DMEM).
- Independent instruction-fetch and data-access paths.
- Simultaneous instruction fetching and data-memory access.
- Dedicated processor control and datapath components.

### Processor Datapath

The processor consists of the following major components:

| Component | Responsibility |
|---|---|
| Program Counter (PC) | Holds the address of the next instruction. |
| Instruction Memory | Stores and supplies processor instructions. |
| Control Unit | Decodes instructions and generates control signals. |
| Register File | Stores processor registers and provides operands. |
| ALU | Performs arithmetic and logical operations. |
| Data Memory | Stores and retrieves program data. |
| Address Decoder | Decodes memory addresses for data selection. |
| Top Module | Integrates the processor components into one system. |

### Instruction Execution Cycle

The processor follows these fundamental stages:

1. **Fetch:** The Program Counter provides an address to Instruction Memory.
2. **Decode:** The Control Unit interprets the instruction opcode.
3. **Execute:** The ALU performs the required operation.
4. **Memory Access:** Data Memory is accessed when required.
5. **Write Back:** The result is stored in the destination register.

## Design Specifications

| Parameter | Specification |
|---|---|
| Architecture | Harvard Architecture |
| HDL | Verilog |
| Processor Design | Single-cycle |
| Instruction Width | 16 bits |
| Data Width | 8 bits |
| Instruction Memory | 16 × 16 bits |
| Data Memory | 16 × 8 bits |
| Register File | 4 registers × 8 bits |
| Program Counter Width | 4 bits |
| Clock | Single rising-edge clock |
| Reset | Active-high synchronous reset |

## Instruction Set Architecture (ISA)

The processor supports the following basic instruction set:

| Instruction | Opcode | Description |
|---|---|---|
| LOAD | `0001` | Loads data from memory into a register. |
| STORE | `0010` | Stores register data into memory. |
| ADD | `0011` | Adds two register values. |
| SUB | `0100` | Subtracts one register value from another. |
| ADDI | `0101` | Adds an immediate value to a register. |
| BEQ | `0110` | Branches when two register values are equal. |
| JUMP | `0111` | Transfers execution to a specified address. |
| HALT | `1111` | Stops processor execution. |

Each instruction is represented using a 16-bit instruction word. The opcode occupies bits `[15:12]`. The remaining fields depend on the instruction format.

Refer to the project's technical specification for the finalized field-level instruction encoding.

## Project Structure

```text
Vector_Cores/
│
├── rtl/
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── data_memory.v
│   ├── address_decoder.v
│   ├── control_unit.v
│   ├── alu.v
│   ├── register_file.v
│   └── top_module.v
│
├── testbench/
│   ├── program_counter_tb.v
│   ├── instruction_memory_tb.v
│   ├── data_memory_tb.v
│   ├── control_unit_tb.v
│   ├── alu_tb.v
│   └── processor_tb.v
│
├── docs/
│   ├── architecture/
│   │   └── block_diagram.png
│   ├── report/
│   └── individual_contributions.md
│
├── simulation/
│   ├── waveforms/
│   └── logs/
│
├── synthesis/
│   └── results.md
│
├── program.hex
├── README.md
└── .gitignore
```

## Technology Stack and Tools

| Tool | Purpose |
|---|---|
| Verilog HDL | Hardware description and processor implementation |
| Icarus Verilog | Verilog compilation and simulation |
| GTKWave | Waveform visualization |
| Visual Studio Code | Development environment |
| Git & GitHub | Version control and team collaboration |
| Vivado (if available) | Synthesis and hardware analysis |

## Getting Started

### Prerequisites

Install the following tools:

- Git
- Icarus Verilog
- GTKWave (optional, for waveform visualization)

On macOS, Icarus Verilog can be installed using Homebrew:

```bash
brew install icarus-verilog
```

### Clone the Repository

```bash
git clone https://github.com/Pratiti-paul/Vector_Cores.git
```

Navigate to the project directory:

```bash
cd Vector_Cores
```

### Compile and Run Individual Modules

For example, to test the Program Counter:

```bash
iverilog -o pc_test rtl/program_counter.v testbench/program_counter_tb.v
vvp pc_test
```

To test the Control Unit:

```bash
iverilog -o control_test rtl/control_unit.v testbench/control_unit_tb.v
vvp control_test
```

To test Instruction Memory:

```bash
iverilog -o imem_test rtl/instruction_memory.v testbench/instruction_memory_tb.v
vvp imem_test
```

### View Simulation Waveforms

If a testbench generates a `.vcd` waveform file, open it using:

```bash
gtkwave filename.vcd
```

Replace `filename.vcd` with the generated waveform filename.

## Verification and Testing

Each hardware module is verified independently using dedicated Verilog testbenches.

The verification process includes:

- Program Counter reset, address update, and hold operations.
- Instruction Memory address-based instruction retrieval.
- Data Memory read and write operations.
- Control Unit opcode decoding and control signal generation.
- ALU arithmetic and logical operations.
- Register File read and write operations.
- Complete processor instruction execution.

The final processor-level testbench will verify the execution of a sample program and validate the resulting register and memory values.

## Team Contributions

The project is developed collaboratively by a team of five members.

| Member | Responsibilities |
|---|---|
| Member 1 | Program Counter, Control Unit, Top Module, and system integration |
| Member 2 | Instruction Memory and instruction memory verification |
| Member 3 | Data Memory and Address Decoder |
| Member 4 | ALU and Register File |
| Member 5 | Processor verification, testbenches, waveform analysis, and synthesis |

Each member is responsible for implementing, testing, and documenting their assigned components.

## GitHub Collaboration Workflow

The project follows a branch-based Git workflow.

1. Each member works on a dedicated feature branch.
2. Implementations are committed with meaningful commit messages.
3. Pull Requests are created to propose changes.
4. Changes are reviewed before merging into the main branch.
5. Integration testing is performed after modules are merged.

Example:

```bash
git checkout -b feature/module-name

git add .
git commit -m "feat: implement module-name"

git push origin feature/module-name
```

## Expected Outcomes

Upon completion, the project aims to demonstrate:

- A functional simplified Harvard Architecture processor.
- Independent instruction and data memory access.
- Correct instruction decoding and execution.
- Working arithmetic, register, and memory operations.
- Successful execution of a sample instruction program.
- Simulation waveforms demonstrating processor behavior.
- Synthesis results and basic hardware resource analysis.

## Future Improvements

Potential extensions include:

- Expanding the instruction set.
- Increasing memory and register capacities.
- Adding support for additional addressing modes.
- Implementing a pipelined processor architecture.
- Exploring cache memory and memory hierarchy optimizations.
- Comparing Harvard and Von Neumann architecture performance.

## Contributors

**Vector Cores — Computer Architecture Project**

Developed as part of the MCA Computer Architecture coursework.

**Repository:** [Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)

---

*Building a deeper understanding of processor architecture through hardware design, implementation, and simulation.*
