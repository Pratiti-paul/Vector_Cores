// Memory-Hierarchy Processor (Modified Harvard with shared lower-level memory)
//
// Same ISA, program counter, control unit, register file and ALU as the
// Harvard top_module. The memory system is a two-level hierarchy:
//
//   Level 1 (Harvard):  icache (8 x 16-bit lines)   dcache (4 x 8-bit lines)
//                            \                        /
//                             +------ mem_arbiter ---+
//                                         |
//   Level 2 (shared):           shared_memory 32 x 16, single port,
//                               WAIT_CYCLES wait states per access
//
// The core keeps separate instruction and data paths at level 1, so on cache
// hits it behaves exactly like the Harvard processor (1 cycle per
// instruction). Misses and stores go to the single shared memory port:
//   - instruction-cache miss : WAIT_CYCLES + 1 extra cycles
//                              (request cycle + wait states, refill at the
//                               end of the last one, execute next cycle)
//   - data-cache LOAD miss   : WAIT_CYCLES extra cycles (data forwarded)
//   - STORE (write-through)  : WAIT_CYCLES extra cycles
// With WAIT_CYCLES = 2: I-miss +3 cycles, D access +2 cycles.
//
// Stall rules:
//   - While the fetched instruction is not valid (I-cache miss) the PC and
//     register file are held and no data access is issued.
//   - While a LOAD miss or a STORE is in progress the PC and register file
//     are held.
//
// CACHE_ENABLE = 0 disables both caches (every fetch and every LOAD go to the
// shared memory) so the benefit of the L1 caches can be measured.
module mh_top_module #(
    parameter WAIT_CYCLES  = 2,
    parameter CACHE_ENABLE = 1
) (
    input  wire        clk,
    input  wire        reset,
    output wire [3:0]  pc_out,
    output wire [15:0] instr,
    output wire [7:0]  alu_out,
    output wire [7:0]  write_data,
    output wire        zero,
    output wire        stall,       // core is waiting on the memory system
    output wire        retire,      // an instruction completes this cycle
    output wire        i_hit,       // I-cache hit for the current PC
    output wire        i_fill,      // I-cache refill completes this cycle
    output wire        d_hit,       // LOAD hit in the D-cache
    output wire        d_fill,      // LOAD miss completes from shared memory
    output wire        d_write,     // STORE write-through completes
    output wire        halted
);

    // =========================================================================
    // 1. Internal Signals
    // =========================================================================
    wire [3:0]  pc_current, pc_next, pc_plus_1, branch_target;
    wire        pc_enable;
    wire [15:0] instr_word;
    wire        i_valid;

    wire [3:0]  opcode     = instr_word[15:12];
    wire [1:0]  rd         = instr_word[11:10];
    wire [1:0]  rs_std     = instr_word[9:8];
    wire [1:0]  rt_std     = instr_word[7:6];
    wire [3:0]  dmem_addr  = instr_word[9:6];
    wire [7:0]  imm        = instr_word[7:0];
    wire [7:0]  offset     = instr_word[7:0];
    wire [3:0]  jump_target = instr_word[3:0];

    wire        reg_write, mem_read, mem_write, alu_src, mem_to_reg;
    wire        branch_enable, jump_enable, halted_sig;
    wire [2:0]  alu_control;

    wire [1:0]  read_reg1, read_reg2;
    wire [7:0]  read_data1, read_data2;
    wire [7:0]  reg_write_data, alu_in2, alu_result, d_rdata;
    wire        zero_flag, branch_taken;

    wire        d_rd, d_wr, d_done;
    wire        pc_enable_eff, reg_write_eff;

    // Memory-system interconnect
    wire        ic_req, ic_ready, dc_req, dc_we, dc_ready, grant_d;
    wire [4:0]  ic_addr, dc_addr, mem_addr;
    wire [15:0] dc_wdata, mem_wdata, mem_rdata;
    wire        mem_req, mem_we, mem_ready;

    // =========================================================================
    // 2. Stall Control
    // =========================================================================
    // Data accesses are issued only for a valid (cache-hit) instruction.
    assign d_rd  = mem_read  & i_valid;
    assign d_wr  = mem_write & i_valid;

    assign stall         = ~i_valid | ~d_done;
    assign pc_enable_eff = pc_enable & ~stall;
    assign reg_write_eff = reg_write & ~stall;

    // =========================================================================
    // 3. Register Steering, ALU Operands, Write-back (same as Harvard)
    // =========================================================================
    assign read_reg1      = (opcode == 4'b0010 || opcode == 4'b0110) ? instr_word[11:10] : rs_std;
    assign read_reg2      = (opcode == 4'b0110) ? rs_std : rt_std;
    assign alu_in2        = alu_src ? imm : read_data2;
    assign reg_write_data = mem_to_reg ? d_rdata : alu_result;

    // =========================================================================
    // 4. Next-PC Logic (same as Harvard)
    // =========================================================================
    assign pc_plus_1     = pc_current + 4'b0001;
    assign branch_taken  = branch_enable & zero_flag;
    assign branch_target = pc_plus_1 + offset[3:0];
    assign pc_next       = jump_enable  ? jump_target   :
                           branch_taken ? branch_target :
                                          pc_plus_1;

    // =========================================================================
    // 5. Core Submodules
    // =========================================================================
    program_counter pc_inst (
        .clk(clk), .reset(reset), .pc_enable(pc_enable_eff),
        .pc_next(pc_next), .pc_out(pc_current)
    );

    control_unit cu_inst (
        .opcode(opcode), .pc_enable(pc_enable), .reg_write(reg_write),
        .mem_read(mem_read), .mem_write(mem_write), .alu_control(alu_control),
        .alu_src(alu_src), .mem_to_reg(mem_to_reg), .branch_enable(branch_enable),
        .jump_enable(jump_enable), .halted(halted_sig)
    );

    register_file rf_inst (
        .clk(clk), .reset(reset), .reg_write(reg_write_eff),
        .read_reg1(read_reg1), .read_reg2(read_reg2), .write_reg(rd),
        .write_data(reg_write_data), .read_data1(read_data1), .read_data2(read_data2)
    );

    alu alu_inst (
        .alu_in1(read_data1), .alu_in2(alu_in2), .alu_control(alu_control),
        .alu_out(alu_result), .zero(zero_flag)
    );

    // =========================================================================
    // 6. Memory Hierarchy
    // =========================================================================
    icache #(.INDEX_BITS(3), .ENABLE(CACHE_ENABLE)) icache_inst (
        .clk(clk), .reset(reset), .pc(pc_current), .retire(pc_enable_eff),
        .instr(instr_word), .valid(i_valid), .hit(i_hit),
        .mem_req(ic_req), .mem_addr(ic_addr), .mem_ready(ic_ready), .mem_rdata(mem_rdata)
    );

    dcache #(.INDEX_BITS(2), .ENABLE(CACHE_ENABLE)) dcache_inst (
        .clk(clk), .reset(reset), .rd(d_rd), .wr(d_wr), .addr(dmem_addr),
        .wdata(read_data1), .rdata(d_rdata), .done(d_done), .hit(d_hit),
        .mem_req(dc_req), .mem_we(dc_we), .mem_addr(dc_addr), .mem_wdata(dc_wdata),
        .mem_ready(dc_ready), .mem_rdata(mem_rdata)
    );

    mem_arbiter arb_inst (
        .i_req(ic_req), .i_addr(ic_addr), .i_ready(ic_ready),
        .d_req(dc_req), .d_we(dc_we), .d_addr(dc_addr), .d_wdata(dc_wdata), .d_ready(dc_ready),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_ready(mem_ready), .grant_d(grant_d)
    );

    shared_memory #(.WAIT_CYCLES(WAIT_CYCLES)) smem_inst (
        .clk(clk), .reset(reset), .req(mem_req), .we(mem_we), .addr(mem_addr),
        .wdata(mem_wdata), .ready(mem_ready), .rdata(mem_rdata)
    );

    // =========================================================================
    // 7. Outputs
    // =========================================================================
    assign pc_out     = pc_current;
    assign instr      = instr_word;
    assign alu_out    = alu_result;
    assign write_data = reg_write_data;
    assign zero       = zero_flag;
    assign retire     = pc_enable_eff;
    assign i_fill     = ic_ready;
    assign d_fill     = dc_ready & ~dc_we;
    assign d_write    = dc_ready &  dc_we;
    assign halted     = halted_sig & i_valid;

endmodule
