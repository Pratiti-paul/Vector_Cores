// Top Module: 16-Bit Harvard Architecture Processor Datapath
// Integrates Program Counter, Instruction Memory, Control Unit,
// Register File, ALU, and Data Memory into a unified single-cycle processor.
//
// Harvard Architecture:
//   - Instruction Memory (16 x 16-bit) and Data Memory (16 x 8-bit) reside
//     on completely separate physical memories and buses.
//   - Enables concurrent instruction fetch and data memory access in the same clock cycle.
//
// Execution Model:
//   - Single-cycle execution with active-high synchronous reset.
//   - 4 general-purpose registers (R0-R3, R0 hardwired to 0).
//   - 16-bit instruction word with 4-bit opcode [15:12].

module top_module (
    input  wire        clk,        // Master system clock
    input  wire        reset,      // Active-high synchronous reset
    output wire [3:0]  pc_out,     // Current Program Counter address
    output wire [15:0] instr,      // Current fetched instruction word
    output wire [7:0]  alu_out,    // ALU calculation output
    output wire [7:0]  write_data, // Register writeback data
    output wire        zero,       // ALU zero condition flag
    output wire        halted      // Processor execution halted status
);

    // =========================================================================
    // 1. Internal Signal Declarations
    // =========================================================================

    // Program Counter Signals
    wire [3:0] pc_current;
    wire [3:0] pc_next;
    wire [3:0] pc_plus_1;
    wire [3:0] branch_target;
    wire       pc_enable;

    // Instruction Memory Signals
    wire [15:0] instr_word;

    // Decoded Instruction Fields
    wire [3:0] opcode;
    wire [1:0] rd;
    wire [1:0] rs_std;
    wire [1:0] rt_std;
    wire [3:0] dmem_addr;
    wire [7:0] imm;
    wire [7:0] offset;
    wire [3:0] jump_target;

    // Control Unit Signals
    wire       reg_write;
    wire       mem_read;
    wire       mem_write;
    wire [1:0] alu_control;
    wire       alu_src;
    wire       mem_to_reg;
    wire       branch_enable;
    wire       jump_enable;
    wire       halted_sig;

    // Register File Signals
    wire [1:0] read_reg1;
    wire [1:0] read_reg2;
    wire [1:0] write_reg;
    wire [7:0] reg_write_data;
    wire [7:0] read_data1;
    wire [7:0] read_data2;

    // ALU Signals
    wire [7:0] alu_in1;
    wire [7:0] alu_in2;
    wire [7:0] alu_result;
    wire       zero_flag;

    // Data Memory Signals
    wire [7:0] dmem_read_data;

    // Branch Condition
    wire       branch_taken;

    // =========================================================================
    // 2. Instruction Field Decoding
    // =========================================================================
    assign opcode      = instr_word[15:12];
    assign rd          = instr_word[11:10]; // Destination register for LOAD, ADD, SUB, ADDI
    assign rs_std      = instr_word[9:8];   // Source register rs for ADD, SUB, ADDI
    assign rt_std      = instr_word[7:6];   // Source register rt for ADD, SUB
    assign dmem_addr   = instr_word[9:6];   // 4-bit memory address for LOAD, STORE
    assign imm         = instr_word[7:0];   // 8-bit immediate for ADDI
    assign offset      = instr_word[7:0];   // 8-bit signed branch offset for BEQ
    assign jump_target = instr_word[3:0];   // 4-bit jump target address

    // =========================================================================
    // 3. Register File Address Steering Logic
    // =========================================================================
    // Read Port 1 address:
    //   - STORE (0010): instr[11:10] specifies source register to store into memory
    //   - BEQ   (0110): instr[11:10] specifies first comparison register (rs)
    //   - Other instructions (ADD, SUB, ADDI): instr[9:8] specifies rs
    assign read_reg1 = (opcode == 4'b0010 || opcode == 4'b0110) ? instr_word[11:10] : rs_std;

    // Read Port 2 address:
    //   - BEQ   (0110): instr[9:8] specifies second comparison register (rt)
    //   - Other instructions (ADD, SUB): instr[7:6] specifies rt
    assign read_reg2 = (opcode == 4'b0110) ? rs_std : rt_std;

    // Write Destination Register:
    //   - Always encoded in instr[11:10] (rd) for LOAD, ADD, SUB, ADDI
    assign write_reg = rd;

    // =========================================================================
    // 4. ALU Operand & Writeback Multiplexers
    // =========================================================================
    // ALU Operand 1: register file read_data1
    assign alu_in1 = read_data1;

    // ALU Operand 2:
    //   - alu_src = 1: 8-bit immediate from instruction (ADDI)
    //   - alu_src = 0: register file read_data2 (ADD, SUB, BEQ)
    assign alu_in2 = (alu_src) ? imm : read_data2;

    // Register Writeback Data:
    //   - mem_to_reg = 1: Data Memory output (LOAD)
    //   - mem_to_reg = 0: ALU result (ADD, SUB, ADDI)
    assign reg_write_data = (mem_to_reg) ? dmem_read_data : alu_result;

    // =========================================================================
    // 5. Program Counter & Next-Address Logic
    // =========================================================================
    // Sequential PC increment: PC + 1 (wrapped modulo 16)
    assign pc_plus_1 = pc_current + 4'b0001;

    // Branch condition: taken when BEQ is decoded and ALU indicates equality (zero flag)
    assign branch_taken = branch_enable & zero_flag;

    // Branch target calculation: PC + 1 + signed offset (wrapped to 4 bits)
    assign branch_target = pc_plus_1 + offset[3:0];

    // Next PC selection multiplexer:
    //   1. JUMP: absolute 4-bit target address from instr[3:0]
    //   2. Taken BEQ: relative target (PC + 1 + offset)
    //   3. Default: sequential next instruction (PC + 1)
    assign pc_next = (jump_enable)  ? jump_target   :
                     (branch_taken) ? branch_target :
                                      pc_plus_1;

    // =========================================================================
    // 6. Submodule Instantiations
    // =========================================================================

    // 6.1 Program Counter
    program_counter pc_inst (
        .clk       (clk),
        .reset     (reset),
        .pc_enable (pc_enable),
        .pc_next   (pc_next),
        .pc_out    (pc_current)
    );

    // 6.2 Instruction Memory (Harvard Architecture: separate 16x16-bit ROM)
    instruction_memory imem_inst (
        .addr  (pc_current),
        .instr (instr_word)
    );

    // 6.3 Control Unit
    control_unit cu_inst (
        .opcode        (opcode),
        .pc_enable     (pc_enable),
        .reg_write     (reg_write),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .alu_control   (alu_control),
        .alu_src       (alu_src),
        .mem_to_reg    (mem_to_reg),
        .branch_enable (branch_enable),
        .jump_enable   (jump_enable),
        .halted        (halted_sig)
    );

    // 6.4 Register File (4 x 8-bit registers, R0 hardwired to 0)
    register_file rf_inst (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (reg_write),
        .read_reg1  (read_reg1),
        .read_reg2  (read_reg2),
        .write_reg  (write_reg),
        .write_data (reg_write_data),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    // 6.5 Arithmetic Logic Unit (ALU)
    alu alu_inst (
        .alu_in1     (alu_in1),
        .alu_in2     (alu_in2),
        .alu_control (alu_control),
        .alu_out     (alu_result),
        .zero        (zero_flag)
    );

    // 6.6 Data Memory (Harvard Architecture: separate 16x8-bit RAM)
    // Note: address_decoder is integrated internally inside data_memory.v
    data_memory dmem_inst (
        .clk        (clk),
        .reset      (reset),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (dmem_addr),
        .write_data (read_data1),
        .read_data  (dmem_read_data)
    );

    // =========================================================================
    // 7. Output Port Assignments (for verification probes)
    // =========================================================================
    assign pc_out     = pc_current;
    assign instr      = instr_word;
    assign alu_out    = alu_result;
    assign write_data = reg_write_data;
    assign zero       = zero_flag;
    assign halted     = halted_sig;

endmodule

