# Vector Cores
## Design and Implementation of an Instruction and Data Memory Hierarchy Using Harvard Architecture

A Verilog-based implementation of a **16-bit, single-cycle processor** following the Harvard Architecture. The processor uses separate instruction and data memories and supports arithmetic, memory-access, branching, jumping and halt instructions.

---

## 1. Project Overview

Vector Cores is a simplified processor designed and implemented using Verilog HDL.

The processor follows the **Harvard Architecture**, in which instruction memory and data memory are separate. This separation allows the processor to fetch instructions independently of its data-memory operations.

The processor uses a single-cycle execution model, meaning that each instruction completes in one clock cycle.

The project focuses on:
- Designing a modular processor architecture.
- Implementing instruction fetching and decoding.
- Performing arithmetic operations using an ALU.
- Managing registers and data memory.
- Supporting conditional branching and jump instructions.
- Verifying functionality through Verilog simulation and testbenches.
- Evaluating the synthesized hardware structure using Yosys.

## 2. Architecture Specifications

| Component | Specification |
|---|---|
| Architecture | Harvard Architecture |
| Processor Type | Single-Cycle Processor |
| Instruction Width | 16 bits |
| Data Width | 8 bits |
| Program Counter | 4 bits |
| Instruction Memory | 16 × 16 bits |
| Data Memory | 16 × 8 bits |
| Register File | 4 × 8-bit registers |
| Number of Registers | 4 (R0–R3) |
| Clock Edge | Rising edge |
| Reset | Active-high synchronous reset |

**Register File:** R0 is hardwired to zero. The remaining registers, R1, R2 and R3, are writable.

**Data Representation:** Arithmetic results are stored in 8 bits, with overflow wrapping around modulo 256.

## 3. System Architecture

The processor consists of the following major components:

### 3.1 Program Counter (PC)
- Maintains the address of the current instruction.
- Provides a 4-bit instruction address.
- Updates to the next address when enabled.
- Supports sequential execution, branching and jumping.
- Holds its value when the processor executes HALT.

### 3.2 Instruction Memory
- Stores 16-bit instructions.
- Has 16 addressable locations.
- Uses combinational read operation.
- Loads the instruction program from `program.hex`.

### 3.3 Control Unit
- Decodes the opcode of the fetched instruction.
- Generates control signals for the processor.
- Controls register writes, memory operations, ALU operations, branching, jumping and halt behavior.

### 3.4 Register File
- Contains four 8-bit registers: R0, R1, R2 and R3.
- Supports two combinational read ports.
- Supports synchronous register writes.
- Keeps R0 permanently equal to zero.

### 3.5 Arithmetic Logic Unit (ALU)
- Performs arithmetic operations.
- Supports addition and subtraction.
- Produces an 8-bit result.
- Generates a zero flag used by conditional branching.

### 3.6 Data Memory
- Contains 16 locations, each storing 8 bits.
- Supports memory read and write operations.
- Uses combinational reads and synchronous writes.
- Includes an internally instantiated 4-to-16 address decoder.

### 3.7 Next PC Selection Logic

Determines the next instruction address based on:
- Sequential execution: PC + 1.
- Conditional branch: PC + 1 + signed offset.
- Jump: absolute 4-bit target address.
- HALT: PC remains unchanged.

## 4. Supported Instruction Set

The processor implements the following eight instructions:

| Instruction | Opcode | Operation |
|---|---|---|
| ADD | `0011` | Rd = Rs + Rt |
| SUB | `0100` | Rd = Rs - Rt |
| ADDI | `0101` | Rd = Rs + Immediate |
| LOAD | `0001` | Rd = Memory[Address] |
| STORE | `0010` | Memory[Address] = Rs |
| BEQ | `0110` | Branch if Rs == Rt |
| JUMP | `0111` | PC = Target |
| HALT | `1111` | Stop execution |

### Instruction Encoding

All instructions are 16 bits wide, with the opcode occupying bits `[15:12]`.

| Instruction | Bit Fields |
|---|---|
| LOAD | `[15:12]` Opcode, `[11:10]` Rd, `[9:6]` Address |
| STORE | `[15:12]` Opcode, `[11:10]` Rs, `[9:6]` Address |
| ADD | `[15:12]` Opcode, `[11:10]` Rd, `[9:8]` Rs, `[7:6]` Rt |
| SUB | `[15:12]` Opcode, `[11:10]` Rd, `[9:8]` Rs, `[7:6]` Rt |
| ADDI | `[15:12]` Opcode, `[11:10]` Rd, `[9:8]` Rs, `[7:0]` Immediate |
| BEQ | `[15:12]` Opcode, `[11:10]` Rs, `[9:8]` Rt, `[7:0]` Offset |
| JUMP | `[15:12]` Opcode, `[3:0]` Target |
| HALT | `[15:12]` Opcode |

Unused instruction bits are set to zero. The BEQ offset is signed and the branch target wraps within the 4-bit PC address space.

## 5. Project Structure

```text
Vector_Cores/
│
├── rtl/
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── control_unit.v
│   ├── register_file.v
│   ├── alu.v
│   ├── address_decoder.v
│   ├── data_memory.v
│   └── top_module.v
│
├── testbench/
│   ├── program_counter_tb.v
│   ├── control_unit_tb.v
│   ├── instruction_memory_tb.v
│   ├── data_memory_tb.v
│   ├── alu_tb.v
│   ├── register_file_tb.v
│   ├── processor_tb.v
│   ├── control_flow_tb.v
│   └── boundary_reset_tb.v
│
├── simulation/
│   ├── waveforms/
│   └── logs/
│
├── docs/
│   ├── report/
│   └── synthesis/
│
├── program.hex
└── README.md
```

## 6. Team Members and Individual Contributions

The project was developed collaboratively, with responsibilities divided across processor modules, integration, verification and synthesis.

| Team Member | Responsibilities |
|---|---|
| **Pratiti Paul** | Designed and implemented the Program Counter and Control Unit. Developed the Top Module and integrated the individual processor components into a complete system. |
| **Anuradha** | Implemented Instruction Memory, developed its testbench, prepared `program.hex` and worked on instruction encoding verification. |
| **Ganga** | Implemented Data Memory and the 4-to-16 Address Decoder. Developed and executed the Data Memory testbench. |
| **Alisha** | Implemented the Arithmetic Logic Unit (ALU) and Register File. Developed their respective testbenches. |

### Collaborative Integration

All individual modules were integrated into the final processor through the Top Module. The complete system was tested to verify correct instruction execution, data transfer, arithmetic operations, branching, jumping, reset behavior and HALT functionality.

## 7. Technologies and Tools

| Tool | Purpose |
|---|---|
| Verilog HDL | Hardware description and RTL implementation |
| Icarus Verilog | Compilation and functional simulation |
| GTKWave | Waveform visualization |
| Yosys | Logic synthesis and structural analysis |
| Git and GitHub | Version control and project collaboration |

## 8. Getting Started

### Prerequisites

Install the following tools:

- Git
- Icarus Verilog
- GTKWave (for viewing waveforms)
- Yosys

### Clone the Repository

```bash
git clone https://github.com/Pratiti-paul/Vector_Cores.git
cd Vector_Cores
```

### Compile the Processor

Run the following command from the repository root:

```bash
iverilog -o processor_sim \
rtl/program_counter.v \
rtl/instruction_memory.v \
rtl/control_unit.v \
rtl/register_file.v \
rtl/alu.v \
rtl/address_decoder.v \
rtl/data_memory.v \
rtl/top_module.v \
testbench/processor_tb.v
```

### Run the Simulation

```bash
vvp processor_sim
```

Run simulations from the repository root because the Instruction Memory loads its program using `program.hex`.

### View Waveforms

If a testbench generates a VCD file, open it using:

```bash
gtkwave simulation/waveforms/processor_wave.vcd
```

The waveform filename should match the VCD file generated by the testbench.

## 9. Verification and Testing

The processor was verified using nine dedicated Verilog testbenches.

| Testbench | Checks Passed | Failed |
|---|---:|---:|
| Program Counter | 5 | 0 |
| Control Unit | 8 | 0 |
| Instruction Memory | 43 | 0 |
| Data Memory | 38 | 0 |
| ALU | 7 | 0 |
| Register File | 6 | 0 |
| Processor Integration | 7 | 0 |
| Control Flow | 13 | 0 |
| Boundary and Reset | 15 | 0 |
| **Total** | **142** | **0** |

### Verification Coverage

Testing includes:
- Individual module functionality.
- Instruction fetching and decoding.
- Arithmetic operations.
- Register read and write operations.
- Data memory load and store operations.
- Conditional branch taken and not-taken conditions.
- Forward and backward branching.
- Jump instruction execution.
- HALT behavior and PC freeze.
- Negative branch offsets and PC wraparound.
- Reset behavior across processor components.

### Processor-Level Test Program

The sample program in `program.hex` performs the following operations:

1. Load immediate value 5 into R1.
2. Load immediate value 3 into R2.
3. Add R1 and R2.
4. Store the result in Data Memory location 2.
5. Subtract R2 from R1.
6. Load the stored value into R3.
7. Increment R3 by 1.
8. Halt execution.

### Expected Final State

| Component | Expected Value |
|---|---:|
| R0 | 0 |
| R1 | 5 |
| R2 | 3 |
| R3 | 9 |
| Data Memory[2] | 8 |
| Program Counter | 7 |
| Halted | 1 |

The processor-level simulation verifies these expected results and confirms that the PC remains unchanged after HALT.

## 10. Synthesis and Resource Analysis

The complete processor hierarchy was synthesized using Yosys.

### Synthesis Environment

- Synthesis Tool: Yosys
- Version: 0.70+post
- Top Module: `top_module`
- Synthesis Type: Generic logic synthesis

### Synthesis Results

| Metric | Result |
|---|---:|
| Total Generic Cells | 116 |
| Multiplexers (`$mux`) | 47 |
| Equality Comparators (`$eq`) | 18 |
| Synchronous Enable Storage (`$sdffe`) | 17 |
| Enable Storage (`$dffe`) | 4 |
| Other Generic Cells | 30 |
| Structural Problems | 0 |

### Memory Mapping

Yosys reported that the Data Memory array was replaced with a list of registers.

This occurs because the Data Memory implementation synchronously clears all 16 memory locations during reset. The resulting structure uses register-based storage rather than a conventional block RAM inference.

The synthesis check completed with zero structural problems.

**Note:** These are generic synthesis statistics. They are not FPGA-specific LUT, BRAM or DSP utilization figures.

## 11. Performance Metrics

The processor follows a single-cycle execution model.

Therefore:

- **Cycles Per Instruction (CPI):** 1 for each completed instruction.
- **Ideal Throughput:** 1 instruction per clock cycle.
- **Instruction Width:** 16 bits.
- **Data Width:** 8 bits.

The throughput is an architectural ideal based on the single-cycle design. Actual operating frequency and instructions-per-second have not been measured.

## 12. Limitations and Future Improvements

The current implementation is a simplified educational processor. Possible future improvements include:

- Supporting additional arithmetic and logical instructions.
- Increasing instruction and data memory capacity.
- Expanding the register file.
- Implementing a wider data path.
- Exploring memory inference suitable for FPGA block RAM.
- Performing FPGA-specific synthesis and timing analysis.
- Measuring maximum operating frequency and hardware resource utilization.
- Comparing performance with alternative processor architectures.

## 13. Conclusion

Vector_Cores demonstrates the design and implementation of a simplified single-cycle processor using Harvard Architecture and Verilog HDL.

The implementation integrates instruction fetching, instruction decoding, register operations, arithmetic processing, memory access and control-flow management.

Functional verification was performed using nine dedicated testbenches, with **142 successful checks and zero failures**. Generic synthesis using Yosys also completed with zero structural problems.

The project provides a practical demonstration of processor organization, RTL design, functional verification and hardware synthesis.

---

## Repository

**Project:** Vector Cores  
**GitHub:** [Pratiti-paul/Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)

Developed as part of the MCA Computer Architecture project.