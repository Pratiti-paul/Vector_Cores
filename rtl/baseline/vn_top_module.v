// Von Neumann Baseline Processor (shared-memory organization)
//
// Same ISA, register file, ALU, control unit and program counter as the
// Harvard top_module, but instructions and data share ONE single-port
// unified_memory. This creates a structural hazard: a LOAD/STORE needs the
// memory port twice (instruction fetch + data access), which cannot happen
// in the same cycle.
//
// Execution model (2-state FSM):
//   S_FETCH : The port is addressed by the PC ({1'b0, pc}) and the fetched
//             word is decoded combinationally.
//             - Non-memory instructions (ADD, SUB, ADDI, BEQ, JUMP, HALT)
//               complete in this same cycle, exactly like the Harvard design.
//             - LOAD / STORE: the instruction is latched into IR, the PC and
//               register file are held, and the FSM moves to S_DATA.
//   S_DATA  : The port is addressed by the data address ({1'b1, addr}).
//             LOAD writes mem[7:0] into rd; STORE writes {8'h00, rs}.
//             The PC advances and the FSM returns to S_FETCH.
//
// Resulting CPI: 1 for non-memory instructions, 2 for LOAD/STORE.
// The Harvard design completes every instruction (including LOAD/STORE)
// in 1 cycle because fetch and data access use separate memories.
module vn_top_module (
    input  wire        clk,        // Master system clock
    input  wire        reset,      // Active-high synchronous reset
    output wire [3:0]  pc_out,     // Current Program Counter address
    output wire [15:0] instr,      // Instruction being executed (fetched word or IR)
    output wire [7:0]  alu_out,    // ALU calculation output
    output wire [7:0]  write_data, // Register writeback data
    output wire        zero,       // ALU zero condition flag
    output wire [4:0]  mem_addr,   // Shared memory port address
    output wire        mem_phase,  // 0 = port used for fetch, 1 = port used for data
    output wire        stall,      // Fetch cycle stalled by a pending data access
    output wire        retire,     // An instruction completes this cycle
    output wire        halted      // Processor execution halted status
);

    localparam S_FETCH = 1'b0;
    localparam S_DATA  = 1'b1;

    // =========================================================================
    // 1. Internal Signals
    // =========================================================================
    reg         state;
    reg  [15:0] ir;              // Holds LOAD/STORE across the data phase

    wire [3:0]  pc_current;
    wire [3:0]  pc_next;
    wire [3:0]  pc_plus_1;
    wire [3:0]  branch_target;
    wire        pc_enable;

    wire [15:0] mem_rdata;
    wire [15:0] instr_word;

    wire [3:0]  opcode;
    wire [1:0]  rd;
    wire [1:0]  rs_std;
    wire [1:0]  rt_std;
    wire [3:0]  dmem_addr;
    wire [7:0]  imm;
    wire [7:0]  offset;
    wire [3:0]  jump_target;

    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire [2:0]  alu_control;
    wire        alu_src;
    wire        mem_to_reg;
    wire        branch_enable;
    wire        jump_enable;
    wire        halted_sig;

    wire [1:0]  read_reg1;
    wire [1:0]  read_reg2;
    wire [7:0]  reg_write_data;
    wire [7:0]  read_data1;
    wire [7:0]  read_data2;

    wire [7:0]  alu_in2;
    wire [7:0]  alu_result;
    wire        zero_flag;
    wire        branch_taken;

    wire        is_mem_op;
    wire        reg_write_eff;
    wire        mem_write_eff;
    wire        pc_enable_eff;

    // =========================================================================
    // 2. Shared-Port Instruction Selection and Decode
    // =========================================================================
    // In S_FETCH the port returns the instruction; in S_DATA it returns data,
    // so the in-flight LOAD/STORE is taken from IR instead.
    assign instr_word  = (state == S_DATA) ? ir : mem_rdata;

    assign opcode      = instr_word[15:12];
    assign rd          = instr_word[11:10];
    assign rs_std      = instr_word[9:8];
    assign rt_std      = instr_word[7:6];
    assign dmem_addr   = instr_word[9:6];
    assign imm         = instr_word[7:0];
    assign offset      = instr_word[7:0];
    assign jump_target = instr_word[3:0];

    assign is_mem_op   = (opcode == 4'b0001) || (opcode == 4'b0010);

    // Structural hazard: memory instruction seen in the fetch phase
    assign stall       = (state == S_FETCH) && is_mem_op;

    // =========================================================================
    // 3. Shared Memory Port Arbitration
    // =========================================================================
    assign mem_addr    = (state == S_DATA) ? {1'b1, dmem_addr} : {1'b0, pc_current};

    // =========================================================================
    // 4. Control Gating
    // =========================================================================
    assign reg_write_eff = reg_write & ~stall;              // no writeback while stalled
    assign mem_write_eff = mem_write & (state == S_DATA);   // STORE writes in data phase
    assign pc_enable_eff = pc_enable & ~stall;              // hold PC while stalled

    // =========================================================================
    // 5. Register Steering, ALU Operands, Writeback (identical to Harvard)
    // =========================================================================
    assign read_reg1      = (opcode == 4'b0010 || opcode == 4'b0110) ? instr_word[11:10] : rs_std;
    assign read_reg2      = (opcode == 4'b0110) ? rs_std : rt_std;
    assign alu_in2        = (alu_src) ? imm : read_data2;
    assign reg_write_data = (mem_to_reg) ? mem_rdata[7:0] : alu_result;

    // =========================================================================
    // 6. Next-PC Logic (identical to Harvard)
    // =========================================================================
    assign pc_plus_1     = pc_current + 4'b0001;
    assign branch_taken  = branch_enable & zero_flag;
    assign branch_target = pc_plus_1 + offset[3:0];
    assign pc_next       = (jump_enable)  ? jump_target   :
                           (branch_taken) ? branch_target :
                                            pc_plus_1;

    // =========================================================================
    // 7. FSM / Instruction Register
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            state <= S_FETCH;
            ir    <= 16'h0000;
        end
        else if (stall) begin
            ir    <= mem_rdata;
            state <= S_DATA;
        end
        else begin
            state <= S_FETCH;
        end
    end

    // =========================================================================
    // 8. Submodule Instantiations
    // =========================================================================
    program_counter pc_inst (
        .clk       (clk),
        .reset     (reset),
        .pc_enable (pc_enable_eff),
        .pc_next   (pc_next),
        .pc_out    (pc_current)
    );

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

    register_file rf_inst (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (reg_write_eff),
        .read_reg1  (read_reg1),
        .read_reg2  (read_reg2),
        .write_reg  (rd),
        .write_data (reg_write_data),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    alu alu_inst (
        .alu_in1     (read_data1),
        .alu_in2     (alu_in2),
        .alu_control (alu_control),
        .alu_out     (alu_result),
        .zero        (zero_flag)
    );

    // Single shared memory: instructions AND data through one port
    unified_memory umem_inst (
        .clk        (clk),
        .reset      (reset),
        .addr       (mem_addr),
        .write_en   (mem_write_eff),
        .write_data ({8'h00, read_data1}),
        .read_data  (mem_rdata)
    );

    // =========================================================================
    // 9. Output Port Assignments
    // =========================================================================
    assign pc_out     = pc_current;
    assign instr      = instr_word;
    assign alu_out    = alu_result;
    assign write_data = reg_write_data;
    assign zero       = zero_flag;
    assign mem_phase  = state;
    assign retire     = pc_enable_eff;
    assign halted     = halted_sig;

endmodule
