# Individual Contributions Report

**Project:** Vector_Cores --- 16-Bit Harvard Architecture Processor\
**Course:** MCA Computer Architecture Coursework\
**Repository:**
[Vector_Cores](https://github.com/Pratiti-paul/Vector_Cores)

------------------------------------------------------------------------

## 1. Team Overview and Responsibility Matrix

The project was developed collaboratively by four members.
Responsibilities were divided across processor modules, instruction and
data memory, system integration, verification, and synthesis.

  --------------------------------------------------------------------------------------------
  Member            Contributor       Assigned          Verified Contributions
                                      Components and    
                                      Scope             
  ----------------- ----------------- ----------------- --------------------------------------
  Member 1          **Pratiti Paul**  Program Counter,  `rtl/program_counter.v`,
                                      Control Unit, Top `rtl/control_unit.v`,
                                      Module            `rtl/top_module.v`, unit testbenches,
                                      integration,      processor-level testbench,
                                      system            control-flow and boundary/reset
                                      verification and  verification, waveform analysis, Yosys
                                      synthesis         synthesis

  Member 2          **Anuradha**      Instruction       `rtl/instruction_memory.v`,
                    **Raghuwanshi**   Memory,           `testbench/instruction_memory_tb.v`,
                                      instruction       `program.hex`
                                      encoding and test 
                                      program           

  Member 3          **Ganga**         Data Memory,      `rtl/data_memory.v`,
                                      Address Decoder   `rtl/address_decoder.v`,
                                      and Data Memory   `testbench/data_memory_tb.v`
                                      verification      

  Member 4          **Alisha Gupta**  Arithmetic Logic  `rtl/alu.v`, `rtl/register_file.v`,
                                      Unit, Register    `testbench/alu_tb.v`,
                                      File and unit     `testbench/register_file_tb.v`
                                      verification      
  --------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 2. Member 1 -- Pratiti Paul

**Role:** Program Counter, Control Unit, Top Module Integration, System
Verification and Synthesis

### Main code contributions

-   Program Counter: `rtl/program_counter.v`
-   Program Counter testbench: `testbench/program_counter_tb.v`
-   Control Unit: `rtl/control_unit.v`
-   Control Unit testbench: `testbench/control_unit_tb.v`
-   Top Module integration: `rtl/top_module.v`
-   Processor-level and control-flow verification testbenches
-   Boundary and reset verification testbench
-   Synthesis analysis and related documentation

### 2.1 Work completed

-   Designed and implemented the synchronous 4-bit Program Counter with
    active-high synchronous reset and clock enable.
-   Designed and implemented the combinational Control Unit to decode
    all eight supported processor opcodes.
-   Integrated the processor components into the single-cycle Harvard
    Architecture datapath through `rtl/top_module.v`.
-   Implemented register read-address selection for STORE and BEQ
    instructions, ALU operand selection, write-back selection and
    next-PC generation.
-   Developed unit testbenches for the Program Counter and Control Unit.
-   Developed and ran processor-level verification, including
    control-flow, boundary-condition and reset tests.
-   Generated and inspected processor simulation waveforms.
-   Performed generic logic synthesis and structural checks using Yosys.

### 2.2 Program Counter design

  -----------------------------------------------------------------------
  Parameter                           Value
  ----------------------------------- -----------------------------------
  Address width                       4 bits (`pc_out[3:0]`)

  Address range                       `0x0` to `0xF` (16 instruction
                                      locations)

  Clocking                            Positive-edge triggered
                                      (`posedge clk`)

  Reset                               Active-high synchronous reset;
                                      resets PC to `4'b0000`

  Enable                              `pc_enable`; holds the address when
                                      low and loads `pc_next` when high
  -----------------------------------------------------------------------

The Program Counter supplies the instruction address and updates
according to the next-PC selection logic. It holds its current value
when disabled, including during HALT.

### 2.3 Control Unit design

The Control Unit is combinational and decodes the opcode in
`instr[15:12]`.

It generates the following control signals:

-   `pc_enable`
-   `reg_write`
-   `mem_read`
-   `mem_write`
-   `alu_control[1:0]`
-   `alu_src`
-   `mem_to_reg`
-   `branch_enable`
-   `jump_enable`
-   `halted`

For HALT (`1111`), the Control Unit disables the Program Counter and
asserts `halted`. Invalid opcodes are assigned safe default control
values.

### 2.4 Top Module integration

The Top Module connects the processor components and implements datapath
selection logic, including:

-   **Register read port 1:** Selects instruction bits `[11:10]` for
    STORE and BEQ, and `[9:8]` for the other relevant instructions.
-   **Register read port 2:** Selects `[9:8]` for BEQ and `[7:6]` for
    ADD and SUB.
-   **ALU operand selection:** Selects the second register operand or
    the immediate value according to `alu_src`.
-   **Write-back selection:** Selects Data Memory read data for LOAD or
    the ALU result for other register-writing instructions.
-   **Next-PC selection:** Supports sequential execution (`PC + 1`),
    conditional branching (`PC + 1 + signed offset`) and absolute jump
    using the 4-bit target.

### 2.5 System-level verification and synthesis

The following system-level verification work was completed:

-   Processor integration testbench: `testbench/processor_tb.v`
-   Control-flow testbench: `testbench/control_flow_tb.v`
-   Boundary and reset testbench: `testbench/boundary_reset_tb.v`
-   Processor waveform: `simulation/waveforms/processor_wave.vcd`
-   Control-flow waveform: `simulation/waveforms/control_flow_wave.vcd`
-   Boundary/reset waveform:
    `simulation/waveforms/boundary_reset_wave.vcd`

The system-level tests checked instruction execution, final register and
memory values, branch conditions, forward and backward branches, jumps,
HALT behavior, PC wraparound and reset behavior.

Yosys was used for generic synthesis and structural checking of the
integrated processor. The final reported synthesis contained 116 generic
cells and the structural check reported zero problems.

------------------------------------------------------------------------

## 3. Member 2 -- Anuradha Raghuwanshi

**Role:** Instruction Memory, Instruction Encoding and Test Program

### Main code contributions

-   Instruction Memory: `rtl/instruction_memory.v`
-   Instruction Memory testbench: `testbench/instruction_memory_tb.v`
-   Test program: `program.hex`

### 3.1 Work completed

-   Designed and implemented the instruction memory module for the
    Harvard-style processor.
-   Developed a self-checking Verilog testbench to verify
    instruction-memory locations and fetched instruction values.
-   Prepared the hexadecimal test program used for processor-level
    testing.
-   Worked on instruction encoding verification according to the agreed
    instruction format.
-   Verified the Instruction Memory using Icarus Verilog and inspected
    simulation waveforms.

### 3.2 Instruction Memory design

  Parameter        Value
  ---------------- ---------------------------------
  Capacity         16 locations
  Word width       16 bits
  Address width    4 bits
  Access           Read-only
  Read type        Asynchronous (combinational)
  Initialization   `$readmemh("program.hex", mem)`

The Instruction Memory provides the instruction addressed by the Program
Counter. Its combinational read makes the instruction available during
the current processor cycle. Instruction Memory is separate from Data
Memory, following the Harvard Architecture.

### 3.3 Instruction format

The instruction word is 16 bits wide, and bits `[15:12]` contain the
opcode. Register addresses are 2 bits wide, while LOAD/STORE data-memory
addresses are 4 bits wide.

  -----------------------------------------------------------------------------
  Instruction       Opcode            Syntax                  Fields
  ----------------- ----------------- ----------------------- -----------------
  LOAD              `0001`            `LOAD rd, [address]`    `[11:10]` rd,
                                                              `[9:6]` address

  STORE             `0010`            `STORE rs, [address]`   `[11:10]` rs,
                                                              `[9:6]` address

  ADD               `0011`            `ADD rd, rs, rt`        `[11:10]` rd,
                                                              `[9:8]` rs,
                                                              `[7:6]` rt

  SUB               `0100`            `SUB rd, rs, rt`        `[11:10]` rd,
                                                              `[9:8]` rs,
                                                              `[7:6]` rt

  ADDI              `0101`            `ADDI rd, rs, imm`      `[11:10]` rd,
                                                              `[9:8]` rs,
                                                              `[7:0]` immediate

  BEQ               `0110`            `BEQ rs, rt, offset`    `[11:10]` rs,
                                                              `[9:8]` rt,
                                                              `[7:0]` signed
                                                              offset

  JUMP              `0111`            `JUMP address`          `[3:0]` absolute
                                                              target

  HALT              `1111`            `HALT`                  `[11:0]` unused
  -----------------------------------------------------------------------------

Unused instruction fields are set to zero. The BEQ offset is signed and
is added to `PC + 1`.

### 3.4 Test program

The `program.hex` test program contains the following instructions:

    Address Hex      Instruction       Expected effect
  --------- -------- ----------------- -----------------
          0 `5405`   ADDI R1, R0, 5    R1 = 5
          1 `5803`   ADDI R2, R0, 3    R2 = 3
          2 `3580`   ADD R1, R1, R2    R1 = 8
          3 `2480`   STORE R1, \[2\]   DMEM\[2\] = 8
          4 `4580`   SUB R1, R1, R2    R1 = 5
          5 `1C80`   LOAD R3, \[2\]    R3 = 8
          6 `5F01`   ADDI R3, R3, 1    R3 = 9
          7 `F000`   HALT              Execution stops

### 3.5 Verification

The Instruction Memory testbench checks all 16 locations, tests
combinational reads at different addresses, checks the HALT values in
unused locations, and verifies instruction fields against the agreed
encoding.

------------------------------------------------------------------------

## 4. Member 3 -- Ganga

**Role:** Data Memory, Address Decoder and Data Memory Verification

### Main code contributions

-   Data Memory: `rtl/data_memory.v`
-   Address Decoder: `rtl/address_decoder.v`
-   Data Memory testbench: `testbench/data_memory_tb.v`

### 4.1 Work completed

-   Designed and implemented a 4-to-16 one-hot combinational Address
    Decoder with enable control.
-   Designed and implemented the processor's Data Memory with
    synchronous writes, asynchronous reads and active-high synchronous
    reset.
-   Integrated the Address Decoder inside the Data Memory module.
-   Developed a self-checking testbench covering reset, read/write
    operations, address selection, read/write inhibition and overwrite
    behavior.
-   Generated a VCD waveform for Data Memory verification.

### 4.2 Address Decoder design

  Parameter             Value
  --------------------- -------------------
  Input address width   4 bits
  Output select lines   16 bits (one-hot)
  Enable                Active-high
  Logic type            Combinational

The Address Decoder converts a 4-bit address into a 16-bit one-hot
selection signal. When disabled, all select lines are zero.

### 4.3 Data Memory design

  Parameter          Value
  ------------------ -------------------------------------------------------
  Capacity           16 locations
  Word width         8 bits
  Address width      4 bits
  Write type         Synchronous, on the rising clock edge
  Read type          Asynchronous (combinational)
  Reset              Active-high synchronous; clears all locations to zero
  Address decoding   Internal `address_decoder` instance

Data Memory is used by LOAD and STORE instructions and is separate from
Instruction Memory.

**Write path:** When `mem_write` is asserted, the internal decoder
selects the addressed location. The selected memory location is updated
on the rising edge of the clock.

**Read path:** When `mem_read` is asserted, the addressed data is
available through the combinational read output. When reading is
disabled, `read_data` is zero.

### 4.4 Verification

The Data Memory testbench covers:

1.  Reset verification across all 16 locations.
2.  Basic write and read operations.
3.  Write and read access across all 16 addresses.
4.  Write inhibition when `mem_write` is low.
5.  Read inhibition when `mem_read` is low.
6.  Compatibility with the STORE/LOAD sequence in `program.hex`.
7.  Overwriting previously stored values.

------------------------------------------------------------------------

## 5. Member 4 -- Alisha Gupta

**Role:** Arithmetic Logic Unit (ALU), Register File and Unit
Verification

### Main code contributions

-   ALU: `rtl/alu.v`
-   ALU testbench: `testbench/alu_tb.v`
-   Register File: `rtl/register_file.v`
-   Register File testbench: `testbench/register_file_tb.v`

### 5.1 Work completed

-   Designed and implemented the 8-bit combinational ALU supporting
    addition, subtraction, wraparound arithmetic and zero-flag
    generation.
-   Designed and implemented the 4-entry, 8-bit Register File with two
    combinational read ports and one synchronous write port.
-   Implemented active-high synchronous reset and write protection for
    R0.
-   Developed self-checking testbenches for both modules.

### 5.2 ALU design

  Parameter       Value
  --------------- --------------------------------------
  Operand width   8 bits
  Result width    8 bits
  Control input   2 bits
  `2'b00`         Addition (ADD and ADDI)
  `2'b01`         Subtraction (SUB and BEQ comparison)
  Zero flag       Asserted when `alu_out` equals zero
  Timing          Combinational

Arithmetic results are 8 bits wide and wrap modulo 256. The zero flag is
used by the processor's conditional branch logic.

### 5.3 Register File design

  Parameter        Value
  ---------------- ---------------------------------------
  Register count   4 (R0--R3)
  Register width   8 bits
  Read ports       2 asynchronous (combinational)
  Write ports      1 synchronous
  Reset            Active-high synchronous
  R0 behavior      Reads return zero; writes are blocked

The Register File provides two source operands to the datapath and
accepts a result through its write port. R0 is hardwired to zero.

### 5.4 Verification

-   **ALU testbench:** Covers addition, subtraction, zero-result
    detection, overflow, underflow and additional arithmetic cases.
    Result: **7/7 checks passed**.
-   **Register File testbench:** Covers reset, independent dual reads,
    synchronous writes, write inhibition and R0 write protection.
    Result: **6/6 checks passed**.

------------------------------------------------------------------------

## 6. Overall Project Verification

The complete processor was verified using nine dedicated testbenches.

  Testbench                 Checks Passed   Failed
  ----------------------- --------------- --------
  Program Counter                       5        0
  Control Unit                          8        0
  Instruction Memory                   43        0
  Data Memory                          38        0
  ALU                                   7        0
  Register File                         6        0
  Processor Integration                 7        0
  Control Flow                         13        0
  Boundary and Reset                   15        0
  **Total**                       **142**    **0**

System-level verification covered:

-   Execution of the sample instruction program.
-   Correct final register and Data Memory values.
-   Conditional branches, including taken and not-taken cases.
-   Forward and backward branch behavior.
-   Jump execution.
-   HALT behavior and Program Counter freeze.
-   Negative branch offsets and 4-bit PC wraparound.
-   Reset behavior across processor state.

### 6.1 Expected final processor state

After executing the sample program, the expected state is:

  Component            Expected value
  ------------------ ----------------
  R0                                0
  R1                                5
  R2                                3
  R3                                9
  Data Memory\[2\]                  8
  Program Counter                   7
  `halted`                          1

### 6.2 Waveform artifacts

The following system-level waveform files were generated for inspection:

-   `simulation/waveforms/processor_wave.vcd`
-   `simulation/waveforms/control_flow_wave.vcd`
-   `simulation/waveforms/boundary_reset_wave.vcd`

------------------------------------------------------------------------

## 7. Synthesis Contribution and Results

Generic synthesis and structural checking of the integrated processor
were performed using Yosys.

  Parameter                                     Result
  --------------------------------------------- --------------
  Synthesis tool                                Yosys
  Reported version                              0.70+post
  Top module                                    `top_module`
  Total generic cells                           116
  Multiplexers (`$mux`)                         47
  Equality comparators (`$eq`)                  18
  Synchronous-enable storage cells (`$sdffe`)   17
  Enable storage cells (`$dffe`)                4
  Structural problems reported by `check`       0

Yosys reported that the Data Memory array was replaced with a list of
registers. This is associated with the implementation's synchronous
reset that clears all memory locations. The reported figures are generic
synthesis statistics, not FPGA-specific LUT, BRAM or DSP utilization.

------------------------------------------------------------------------

## 8. Conclusion

The four-member team collaboratively designed and implemented a modular,
16-bit single-cycle processor based on Harvard Architecture using
Verilog HDL.

Each member contributed to a defined part of the processor, including
instruction memory, data memory, the Address Decoder, ALU, Register
File, Program Counter, Control Unit and system integration.

The integrated processor was verified using nine testbenches, with **142
checks passed and zero failures**. Generic synthesis and structural
checking were also performed using Yosys, with zero structural problems
reported.

This report records the individual responsibilities and the combined
verification and synthesis work completed for the Vector_Cores project.
