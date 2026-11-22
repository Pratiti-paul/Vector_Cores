# Vector Cores

## Design and Implementation of an Instruction and Data Memory Hierarchy Using Harvard Architecture

A Verilog HDL implementation of a simplified **16-bit, single-cycle processor** based on Harvard Architecture. The processor uses separate instruction and data memories and supports arithmetic, logical, memory-access, conditional-branch, jump, and halt instructions.

**Course:** MCA Computer Architecture

---

## 1. Project Overview

Vector Cores is an educational processor implemented using Verilog HDL (IEEE 1364-2001). It follows Harvard Architecture, with separate instruction and data memories and independent memory paths. The processor uses a single-cycle execution model: each completed instruction executes in one clock cycle.

### Project objectives

- Design a modular processor architecture.
- Implement instruction fetching and opcode decoding.
- Perform register operations and 8-bit arithmetic and logical operations.
- Support data-memory reads and writes.
- Implement conditional branches, jumps, and HALT.
- Extend the instruction set with AND, OR, and XOR operations.
- Assemble symbolic assembly programs into machine-code instructions.
- Verify module-level and processor-level behavior with Verilog testbenches.
- Analyze the synthesized logic using Yosys.

## 2. Architecture Specifications

| Component | Specification |
|---|---|
| Architecture | Harvard Architecture |
| Processor type | Single-cycle |
| Instruction width | 16 bits |
| Data width | 8 bits |
| Opcode | 4 bits (`instr[15:12]`) |
| Program Counter | 4 bits |
| Instruction Memory | 16 × 16 bits |
| Data Memory | 16 × 8 bits |
| Register File | 4 × 8-bit registers (`R0`–`R3`) |
| ALU control | 3 bits |
| Clock edge | Rising edge (`posedge clk`) |
| Reset | Active-high synchronous reset |

`R0` is hardwired to zero. `R1`, `R2`, and `R3` are writable. Arithmetic results are 8 bits wide and wrap modulo 256.

## 3. System Architecture

### 3.1 Program Counter (`program_counter`)

- Maintains the current instruction address using a 4-bit register.
- Updates to the selected next address when enabled.
- Supports sequential execution, branches, and jumps.
- Holds its value when HALT disables the PC.

### 3.2 Instruction Memory (`instruction_memory`)

- Stores 16 instructions, each 16 bits wide.
- Uses combinational (asynchronous) reads.
- Initializes its contents from `program.hex` using `$readmemh`.

### 3.3 Control Unit (`control_unit`)

Decodes the 4-bit opcode and generates control signals for register writes, memory operations, ALU selection, write-back selection, branches, jumps, PC enable, and HALT. The Phase II Control Unit supports all 11 instructions listed in Section 4 and uses a 3-bit ALU control signal.

### 3.4 Register File (`register_file`)

- Four 8-bit registers (`R0`–`R3`).
- Two combinational read ports and one synchronous write port.
- Reads from `R0` return zero; writes to `R0` are blocked.

### 3.5 Arithmetic Logic Unit (`alu`)

- Supports addition and subtraction.
- Supports bitwise AND, OR, and XOR.
- Produces an 8-bit result and a zero flag.
- Arithmetic results wrap modulo 256.

The 3-bit ALU control mapping is:

| ALU control | Operation |
|---|---|
| `000` | ADD |
| `001` | SUB |
| `010` | AND |
| `011` | OR |
| `100` | XOR |
| `101`–`111` | Reserved (default result: `8'h00`) |

### 3.6 Data Memory (`data_memory`)

- Contains 16 locations of 8 bits each.
- Supports combinational reads and synchronous writes.
- Synchronously clears all locations during reset.
- Instantiates the 4-to-16 Address Decoder internally.

### 3.7 Address Decoder (`address_decoder`)

Implements a 4-to-16 one-hot decoder. It is instantiated inside Data Memory, not as a separate top-level datapath module.

### 3.8 Next-PC Selection

The Top Module selects the next PC from:

- Sequential execution: `PC + 1`.
- Conditional branch: `PC + 1 + signed_offset`.
- Jump: absolute 4-bit target.
- HALT: hold the current PC.

The branch target is truncated to the 4-bit PC address space and therefore wraps within `0x0`–`0xF`.

### 3.9 Block Diagram

![Vector Cores processor block diagram](docs/architecture/block_diagram.png)

The diagram is stored at [`docs/architecture/block_diagram.png`](docs/architecture/block_diagram.png).

## 4. Supported Instruction Set

All instructions are 16 bits wide. The opcode occupies bits `[15:12]`.

| Instruction | Opcode | Operation |
|---|---:|---|
| `LOAD` | `0001` | `R[rd] = DMEM[address]` |
| `STORE` | `0010` | `DMEM[address] = R[rs]` |
| `ADD` | `0011` | `R[rd] = R[rs] + R[rt]` |
| `SUB` | `0100` | `R[rd] = R[rs] - R[rt]` |
| `ADDI` | `0101` | `R[rd] = R[rs] + signed_immediate` |
| `BEQ` | `0110` | Branch if `R[rs] == R[rt]` |
| `JUMP` | `0111` | `PC = target` |
| `AND` | `1000` | `R[rd] = R[rs] & R[rt]` |
| `OR` | `1001` | `R[rd] = R[rs] \| R[rt]` |
| `XOR` | `1010` | `R[rd] = R[rs] ^ R[rt]` |
| `HALT` | `1111` | Disable PC updates and assert `halted` |

### 4.1 Instruction Encoding

| Instruction | Bit fields |
|---|---|
| `LOAD` | `[15:12]` opcode, `[11:10]` `rd`, `[9:6]` address, `[5:0]` zero |
| `STORE` | `[15:12]` opcode, `[11:10]` `rs`, `[9:6]` address, `[5:0]` zero |
| `ADD` / `SUB` / `AND` / `OR` / `XOR` | `[15:12]` opcode, `[11:10]` `rd`, `[9:8]` `rs`, `[7:6]` `rt`, `[5:0]` zero |
| `ADDI` | `[15:12]` opcode, `[11:10]` `rd`, `[9:8]` `rs`, `[7:0]` signed immediate |
| `BEQ` | `[15:12]` opcode, `[11:10]` `rs`, `[9:8]` `rt`, `[7:0]` signed offset |
| `JUMP` | `[15:12]` opcode, `[11:4]` zero, `[3:0]` target |
| `HALT` | `[15:12]` opcode, `[11:0]` zero |

The `BEQ` offset is signed and added to `PC + 1`; the resulting target is truncated to 4 bits. `JUMP` uses an absolute 4-bit target address. The three logical instructions use the same R-type field layout as `ADD` and `SUB`.

## 5. Repository Structure

```text
Vector_Cores/
├── README.md
├── program.hex
├── rtl/
│   ├── address_decoder.v
│   ├── alu.v
│   ├── control_unit.v
│   ├── data_memory.v
│   ├── instruction_memory.v
│   ├── program_counter.v
│   ├── register_file.v
│   └── top_module.v
├── testbench/
│   ├── alu_tb.v
│   ├── address_decoder_tb.v
│   ├── boundary_reset_tb.v
│   ├── control_flow_tb.v
│   ├── control_unit_tb.v
│   ├── data_memory_tb.v
│   ├── instruction_memory_tb.v
│   ├── logical_ops_tb.v
│   ├── processor_tb.v
│   ├── program_counter_tb.v
│   └── register_file_tb.v
├── assembler/
│   ├── assembler.py
│   └── samples/
├── tests/
├── simulation/
│   ├── logs/
│   └── waveforms/
├── docs/
│   ├── architecture/
│   │   └── block_diagram.png
│   └── report/
│       └── individual_contribution_report.md
└── synthesis/
    └── results.md
```

This is a high-level guide to the repository. Some generated logs, waveforms, and supporting files may be present in addition to the paths shown above.

## 6. Team Members and Individual Contributions

| Team member | Responsibilities |
|---|---|
| **Pratiti Paul** | Implemented the Program Counter and Control Unit; developed the Top Module; handled processor integration, processor-level verification, waveform analysis, and synthesis. |
| **Anuradha Raghuwanshi** | Implemented Instruction Memory and its testbench; prepared the Phase I program image; developed the Phase II Python two-pass assembler, assembler tests, and sample assembly programs. |
| **Ganga** | Implemented Data Memory and the 4-to-16 Address Decoder; developed expanded memory and decoder verification. |
| **Alisha Gupta** | Implemented the ALU and Register File; extended the ALU with AND, OR, and XOR operations and developed the related testbenches. |

The modules were integrated collaboratively, with team members coordinating interfaces and reviewing processor behavior.

## 7. Technologies and Tools

| Tool / Technology | Purpose |
|---|---|
| Verilog HDL (IEEE 1364-2001) | Hardware description and RTL implementation |
| Icarus Verilog | Compilation and functional simulation |
| GTKWave | VCD waveform visualization |
| Yosys | Generic synthesis and structural checks |
| Python 3 | Two-pass assembler implementation |
| pytest | Assembler test suite |
| Git and GitHub | Version control and collaboration |

## 8. Getting Started

### 8.1 Prerequisites

Install Git, Icarus Verilog (`iverilog` and `vvp`), Python 3, and pytest. GTKWave is optional and can be used to inspect VCD waveforms. Install Yosys if you want to reproduce synthesis results.

### 8.2 Clone the Repository

```bash
git clone https://github.com/Pratiti-paul/Vector_Cores.git
cd Vector_Cores
```

### 8.3 Compile and Run the Processor Integration Test

Run from the repository root because Instruction Memory loads `program.hex` using a relative path.

```bash
iverilog -g2012 -s processor_tb -o proc_test rtl/*.v testbench/processor_tb.v
vvp proc_test
rm -f proc_test
```

### 8.4 Run the Logical-Operations System Test

```bash
iverilog -g2012 -s logical_ops_tb -o logical_test rtl/*.v testbench/logical_ops_tb.v
vvp logical_test
rm -f logical_test
```

### 8.5 Run the Python Assembler Tests

From the repository root:

```bash
python3 -m pytest tests/ -v
```

### 8.6 Assemble a Sample Program

The assembler accepts an assembly source file and writes hexadecimal machine code. For example:

```bash
python3 -m assembler.assembler assembler/samples/logical_ops.asm -o /tmp/logical_ops.hex
```

The generated file can be loaded into Instruction Memory for simulation. Check the assembler help or project documentation for supported command-line options and assembly syntax.

### 8.7 Run the Complete Verilog Regression

The Phase II regression comprises 11 testbenches. Run the project's regression commands or compile and execute each testbench individually. The following table lists the testbench top modules:

| Testbench | Top module |
|---|---|
| Program Counter | `program_counter_tb` |
| Control Unit | `control_unit_tb` |
| Instruction Memory | `instruction_memory_tb` |
| Data Memory | `data_memory_tb` |
| Address Decoder | `address_decoder_tb` |
| ALU | `alu_tb` |
| Register File | `register_file_tb` |
| Processor Integration | `processor_tb` |
| Control Flow | `control_flow_tb` |
| Boundary and Reset | `boundary_reset_tb` |
| Logical Operations | `logical_ops_tb` |

Example compilation pattern (run from the repository root):

```bash
iverilog -g2012 -s <testbench_top> -o /tmp/test_run rtl/*.v testbench/<testbench_file>.v
vvp /tmp/test_run
rm -f /tmp/test_run
```

Replace the placeholders with the corresponding top-module and testbench filenames from the table. Some module-specific testbenches may compile only the RTL files they need.

## 9. Verification and Testing

Phase II verification includes module-level tests, processor-level integration tests, logical-operation execution, and assembler tests.

### 9.1 Verilog Regression Results

The recorded Phase II regression contains 11 Verilog testbenches and **390 checks passed with 0 failures**.

| Testbench | Checks passed | Failed |
|---|---:|---:|
| Program Counter | 15 | 0 |
| Instruction Memory | 16 | 0 |
| Register File | 6 | 0 |
| ALU | 13 | 0 |
| Address Decoder | 40 | 0 |
| Data Memory | 79 | 0 |
| Control Unit | 130 | 0 |
| Processor Integration | 7 | 0 |
| Control Flow | 13 | 0 |
| Boundary and Reset | 15 | 0 |
| Logical Operations | 56 | 0 |
| **Total** | **390** | **0** |

### 9.2 Python Assembler Tests

The recorded Python assembler test suite completed **203 tests with 0 failures** using pytest.

### 9.3 Verification Coverage

Testing covers:

- Individual module functionality.
- Instruction fetching and decoding.
- Addition, subtraction, and immediate arithmetic.
- Bitwise AND, OR, and XOR operations.
- Register-file read and write behavior, including hardwired `R0`.
- Data-memory reads, writes, and address decoding.
- Branch taken and not-taken conditions.
- Forward and backward branch offsets.
- Jump execution.
- HALT behavior and PC freeze.
- Negative branch offsets and PC wraparound.
- Reset behavior across processor components.
- Assembler parsing, label resolution, instruction encoding, and sample programs.
- Execution of assembler-generated logical-operation machine code on the processor.

### 9.4 Logical-Operations Integration Example

The Phase II logical-operations system test exercises AND, OR, and XOR through the integrated processor. The recorded example initializes `R1 = 12` and `R2 = 10`, then checks:

| Operation | Expected result |
|---|---:|
| `12 AND 10` | 8 |
| `12 OR 10` | 14 |
| `12 XOR 10` | 6 |

The system test also checks register write-back, zero-result behavior, the hardwired-zero register, and HALT/PC-freeze behavior. The recorded logical-operations testbench reported 56 checks passed and 0 failures.

## 10. Synthesis and Resource Analysis

The complete processor hierarchy was synthesized using Yosys with `top_module` as the top-level module.

### 10.1 Generic Synthesis Flow

Run from the repository root:

```bash
yosys -p "
read_verilog rtl/program_counter.v rtl/instruction_memory.v rtl/control_unit.v rtl/register_file.v rtl/alu.v rtl/address_decoder.v rtl/data_memory.v rtl/top_module.v
hierarchy -check -top top_module
proc
opt
memory
opt
check
stat
" | tee simulation/logs/yosys_synthesis_phase2.log
```

The recorded Phase II generic synthesis report states:

- **125 generic cells**.
- **0 structural problems** reported by Yosys `check`.
- No reported undriven wires, multiple-driver conflicts, or inferred latches in the audited result.
- The reported sequential-cell breakdown includes 17 `$sdffe` cells and 4 `$dffe` cells.

### 10.2 Generic Cell Statistics

The recorded generic cell counts are:

| Cell type | Count |
|---|---:|
| `$mux` | 50 |
| `$eq` | 21 |
| `$sdffe` | 17 |
| `$and` | 10 |
| `$logic_not` | 5 |
| `$reduce_bool` | 5 |
| `$dffe` | 4 |
| `$add` | 3 |
| `$not` | 2 |
| `$pmux` | 2 |
| `$sub` | 1 |
| `$xor` | 1 |
| `$or` | 1 |
| `$shl` | 1 |
| `$logic_and` | 1 |
| `$logic_or` | 1 |
| **Total generic cells** | **125** |

These are generic Yosys synthesis statistics, not FPGA LUT utilization, timing, power, or board measurements. They should not be compared directly with technology-mapped resource counts from a different synthesis flow.

### 10.3 Memory Mapping Observation

The reported Yosys flow replaced the Data Memory array with registers. The implementation synchronously clears all 16 memory locations during reset, so the reported generic synthesis flow maps the storage to registers rather than conventional block RAM.

## 11. Waveform Archives

Simulation waveforms (`.vcd`) can be inspected with GTKWave when the corresponding testbench generates them. For example:

```bash
gtkwave simulation/waveforms/logical_ops_wave.vcd
gtkwave simulation/waveforms/control_flow_wave.vcd
gtkwave simulation/waveforms/boundary_reset_wave.vcd
```

Waveform files are generated simulation artifacts. Their availability depends on which simulations have been run and which artifacts are included in the repository.

## 12. Limitations and Future Improvements

1. **Data Memory mapping:** Synchronous reset clears all memory locations. The reported synthesis flow therefore maps the memory to registers instead of conventional block RAM.
2. **Asynchronous Instruction Memory:** Instruction Memory uses combinational reads. A different implementation may be needed for FPGA block RAM configurations.
3. **Relative program-file path:** Instruction Memory loads `program.hex` using a relative path. Run simulations from the repository root.
4. **Small address space:** The 4-bit address buses limit instruction and data memories to 16 locations each.
5. **Instruction set:** The current ISA contains 11 instructions. Further arithmetic, logical, and control-flow operations could be added.
6. **Datapath capacity:** Future versions could increase data width, register count, and memory capacity.
7. **Further hardware characterization:** Board-level testing, maximum-frequency measurement, critical-path timing analysis, and power measurement remain future work.

## 13. Performance Metrics

The processor uses a single-cycle execution model:

- **Cycles per instruction (CPI):** 1 for each completed instruction.
- **Ideal throughput:** 1 instruction per clock cycle.
- **Instruction width:** 16 bits.
- **Data width:** 8 bits.

The throughput is an architectural ideal. Actual operating frequency and instructions per second have not been measured.

## 14. Conclusion

Vector Cores demonstrates the design and implementation of a simplified single-cycle processor using Harvard Architecture and Verilog HDL. The Phase II implementation integrates instruction fetching, decoding, register operations, arithmetic and logical processing, data-memory access, and control-flow management. It also includes a Python two-pass assembler for translating assembly programs into machine code.

The recorded Phase II verification includes **390 Verilog checks across 11 testbenches** and **203 Python assembler tests**, all passing. Generic synthesis using Yosys reported **125 generic cells** and **0 structural problems**. These results demonstrate functional and structural verification; they do not represent measured FPGA timing, power, or board utilization.

## 15. Individual Contributions Report

The detailed contribution report is available at [`docs/report/individual_contribution_report.md`](docs/report/individual_contribution_report.md).
