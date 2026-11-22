`timescale 1ns / 1ps
// Memory Hierarchy Testbench (shared lower-level memory)
//
// Runs the SAME programs on four processors that share the same core
// (PC, control unit, register file, ALU) and differ only in memory system:
//
//   harvard : top_module     - separate single-cycle IMEM + DMEM (ideal Harvard)
//   vn      : vn_top_module  - one single-cycle shared memory (Von Neumann)
//   mh      : mh_top_module  - L1 I-cache + L1 D-cache over a shared slow
//                              lower-level memory (modified Harvard)
//   nc      : mh_top_module  - same shared slow memory, caches disabled
//
// The shared lower-level memory has WAIT_CYCLES = 2 wait states, so:
//   I-cache miss        : +3 cycles
//   LOAD miss / STORE   : +2 cycles (D-cache is write-through)
//
// For each program it checks:
//   1. All four processors reach the same, expected final state
//      (registers, data memory, PC). For mh/nc the data is checked in the
//      shared memory, which write-through keeps up to date.
//   2. Cycle counts, cache refills, LOAD hits and STOREs against values
//      worked out by hand from the cache organization.
//   3. Cycle counts against the model
//        cycles = N + 3 * (I-cache misses) + 2 * (LOAD misses + STOREs)
//      using the counts measured in simulation.
//
// Programs:
//   P1 program.hex     : straight-line mixed ALU + memory
//   P2 memory-heavy    : 7 of 10 instructions are LOAD/STORE
//   P3 compute loop    : ADDI/BEQ/JUMP loop, no memory instructions
//   P4 memory loop     : LOAD / ADDI / STORE loop, 6 iterations
//
// Run from the repository root.
module memory_hierarchy_tb;

    localparam WAIT = 2;

    reg clk;
    reg reset;
    always #5 clk = ~clk;

    // ---------------- Harvard ----------------
    wire [3:0]  h_pc;   wire [15:0] h_instr;
    wire [7:0]  h_alu, h_wd; wire h_zero, h_halted;
    top_module harvard (
        .clk(clk), .reset(reset), .pc_out(h_pc), .instr(h_instr), .alu_out(h_alu),
        .write_data(h_wd), .zero(h_zero), .halted(h_halted)
    );

    // ---------------- Von Neumann ----------------
    wire [3:0]  v_pc;   wire [15:0] v_instr;
    wire [7:0]  v_alu, v_wd; wire v_zero, v_halted, v_phase, v_stall, v_retire;
    wire [4:0]  v_maddr;
    vn_top_module vn (
        .clk(clk), .reset(reset), .pc_out(v_pc), .instr(v_instr), .alu_out(v_alu),
        .write_data(v_wd), .zero(v_zero), .mem_addr(v_maddr), .mem_phase(v_phase),
        .stall(v_stall), .retire(v_retire), .halted(v_halted)
    );

    // ---------------- Memory hierarchy (caches on) ----------------
    wire [3:0]  m_pc;   wire [15:0] m_instr;
    wire [7:0]  m_alu, m_wd;
    wire m_zero, m_stall, m_retire, m_ihit, m_ifill, m_dhit, m_dfill, m_dwrite, m_halted;
    mh_top_module #(.WAIT_CYCLES(WAIT), .CACHE_ENABLE(1)) mh (
        .clk(clk), .reset(reset), .pc_out(m_pc), .instr(m_instr), .alu_out(m_alu),
        .write_data(m_wd), .zero(m_zero), .stall(m_stall), .retire(m_retire),
        .i_hit(m_ihit), .i_fill(m_ifill), .d_hit(m_dhit), .d_fill(m_dfill),
        .d_write(m_dwrite), .halted(m_halted)
    );

    // ---------------- Memory hierarchy (caches off) ----------------
    wire [3:0]  n_pc;   wire [15:0] n_instr;
    wire [7:0]  n_alu, n_wd;
    wire n_zero, n_stall, n_retire, n_ihit, n_ifill, n_dhit, n_dfill, n_dwrite, n_halted;
    mh_top_module #(.WAIT_CYCLES(WAIT), .CACHE_ENABLE(0)) nc (
        .clk(clk), .reset(reset), .pc_out(n_pc), .instr(n_instr), .alu_out(n_alu),
        .write_data(n_wd), .zero(n_zero), .stall(n_stall), .retire(n_retire),
        .i_hit(n_ihit), .i_fill(n_ifill), .d_hit(n_dhit), .d_fill(n_dfill),
        .d_write(n_dwrite), .halted(n_halted)
    );

    // ---------------- Bookkeeping ----------------
    reg [15:0] prog [0:15];
    integer i, guard, pass_count, fail_count;

    integer h_cyc, v_cyc, m_cyc, n_cyc, n_instrs;
    integer m_ifills, m_loads, m_lhits, m_lmiss, m_stores;
    integer n_ifills, n_lmiss, n_stores;

    // summary storage
    integer s_n [1:4], s_h [1:4], s_v [1:4], s_m [1:4], s_nc [1:4];
    integer s_if [1:4], s_ld [1:4], s_lh [1:4];

    task check;
        input [8*48-1:0] name;
        input integer actual;
        input integer expected;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s = %0d", name, actual);
            end else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s = %0d (expected %0d)", name, actual, expected);
            end
        end
    endtask

    task fill_halt;
        begin
            for (i = 0; i < 16; i = i + 1) prog[i] = 16'hF000;
        end
    endtask

    task load_program;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                harvard.imem_inst.mem[i] = prog[i];
                vn.umem_inst.mem[i]      = prog[i];
                mh.smem_inst.mem[i]      = prog[i];
                nc.smem_inst.mem[i]      = prog[i];
            end
        end
    endtask

    task run_program;
        begin
            reset = 1'b1;
            @(posedge clk); @(posedge clk);
            #1 reset = 1'b0;

            h_cyc = 0; v_cyc = 0; m_cyc = 0; n_cyc = 0; n_instrs = 0;
            m_ifills = 0; m_loads = 0; m_lhits = 0; m_lmiss = 0; m_stores = 0;
            n_ifills = 0; n_lmiss = 0; n_stores = 0;
            guard = 0;

            while (!(h_halted && v_halted && m_halted && n_halted) && guard < 400) begin
                @(negedge clk);
                if (!h_halted) begin
                    h_cyc = h_cyc + 1;
                    if (harvard.pc_enable) n_instrs = n_instrs + 1;
                end
                if (!v_halted) v_cyc = v_cyc + 1;
                if (!m_halted) begin
                    m_cyc = m_cyc + 1;
                    if (m_ifill)  m_ifills = m_ifills + 1;
                    if (m_dfill)  m_lmiss  = m_lmiss  + 1;
                    if (m_dwrite) m_stores = m_stores + 1;
                    if (m_retire && mh.mem_read) begin
                        m_loads = m_loads + 1;
                        if (m_dhit) m_lhits = m_lhits + 1;
                    end
                end
                if (!n_halted) begin
                    n_cyc = n_cyc + 1;
                    if (n_ifill)  n_ifills = n_ifills + 1;
                    if (n_dfill)  n_lmiss  = n_lmiss  + 1;
                    if (n_dwrite) n_stores = n_stores + 1;
                end
                @(posedge clk);
                guard = guard + 1;
            end
            if (guard >= 400)
                $display("  [WARN] timeout before all processors halted");
        end
    endtask

    // Final-state equivalence of all four processors against Harvard
    task check_state;
        begin
            check("all four halted", h_halted & v_halted & m_halted & n_halted, 1);
            check("final PC  VN   == Harvard", v_pc, h_pc);
            check("final PC  MH   == Harvard", m_pc, h_pc);
            check("final PC  MH-nocache == Harvard", n_pc, h_pc);
            for (i = 0; i < 4; i = i + 1) begin
                check("register  VN   == Harvard", vn.rf_inst.registers[i], harvard.rf_inst.registers[i]);
                check("register  MH   == Harvard", mh.rf_inst.registers[i], harvard.rf_inst.registers[i]);
                check("register  MH-nocache == Harvard", nc.rf_inst.registers[i], harvard.rf_inst.registers[i]);
            end
            for (i = 0; i < 16; i = i + 1) begin
                check("data mem  VN   == Harvard", vn.umem_inst.mem[16 + i][7:0], harvard.dmem_inst.mem[i]);
                check("shared mem MH  == Harvard DMEM", mh.smem_inst.mem[16 + i][7:0], harvard.dmem_inst.mem[i]);
                check("shared mem MH-nocache == Harvard DMEM", nc.smem_inst.mem[16 + i][7:0], harvard.dmem_inst.mem[i]);
            end
            for (i = 0; i < 16; i = i + 1)
                check("MH instruction region intact", mh.smem_inst.mem[i], prog[i]);
        end
    endtask

    // Expected counts (worked out by hand) and the analytical cycle model
    task check_counts;
        input integer idx;
        input integer exp_n;
        input integer exp_h, exp_v, exp_m, exp_nc;
        input integer exp_ifills, exp_loads, exp_lhits, exp_stores;
        begin
            check("instructions (N)", n_instrs, exp_n);
            check("Harvard cycles", h_cyc, exp_h);
            check("Von Neumann cycles", v_cyc, exp_v);
            check("MH cycles", m_cyc, exp_m);
            check("MH-nocache cycles", n_cyc, exp_nc);
            check("MH I-cache refills (misses)", m_ifills, exp_ifills);
            check("MH LOADs executed", m_loads, exp_loads);
            check("MH LOAD hits", m_lhits, exp_lhits);
            check("MH STORE write-throughs", m_stores, exp_stores);
            check("MH model N+3*Imiss+2*(Lmiss+ST)",
                  m_cyc, exp_n + (WAIT + 1) * m_ifills + WAIT * (m_lmiss + m_stores));
            check("nocache fetches = N + 1 (incl. HALT)", n_ifills, exp_n + 1);
            check("nocache model N+3*fetch+2*(LD+ST)",
                  n_cyc, exp_n + (WAIT + 1) * n_ifills + WAIT * (n_lmiss + n_stores));

            s_n[idx] = n_instrs; s_h[idx] = h_cyc; s_v[idx] = v_cyc;
            s_m[idx] = m_cyc;   s_nc[idx] = n_cyc;
            s_if[idx] = m_ifills; s_ld[idx] = m_loads; s_lh[idx] = m_lhits;

            $display("  Harvard %0d | Von Neumann %0d | MH (L1 + shared L2) %0d | shared L2 only %0d cycles",
                     h_cyc, v_cyc, m_cyc, n_cyc);
            $display("  I-cache: %0d/%0d hits (%0.1f%%)   D-cache LOAD: %0d/%0d hits",
                     n_instrs + 1 - m_ifills, n_instrs + 1,
                     100.0 * (n_instrs + 1 - m_ifills) / (n_instrs + 1), m_lhits, m_loads);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/memory_hierarchy_wave.vcd");
        $dumpvars(0, memory_hierarchy_tb);

        clk = 1'b0; reset = 1'b1;
        pass_count = 0; fail_count = 0;
        #1;

        $display("==============================================================");
        $display(" Memory Hierarchy: Harvard vs Von Neumann vs L1 caches + shared L2");
        $display(" Shared lower-level memory: %0d wait states", WAIT);
        $display("==============================================================");

        // ---------------- P1: program.hex ----------------
        fill_halt;
        prog[0] = 16'h5405; prog[1] = 16'h5803; prog[2] = 16'h3580; prog[3] = 16'h2480;
        prog[4] = 16'h4580; prog[5] = 16'h1C80; prog[6] = 16'h5F01; prog[7] = 16'hF000;
        load_program;
        $display("\n--- P1: program.hex (straight-line, mixed) ---");
        run_program;
        check_state;
        //           idx  N   H   V   MH  NC  Ifill LD LH ST
        check_counts(1,   7,  7,  9,  33, 35,  8,   1, 1, 1);
        check("P1 R3", harvard.rf_inst.registers[3], 9);
        check("P1 DMEM[2]", harvard.dmem_inst.mem[2], 8);

        // ---------------- P2: memory-heavy ----------------
        fill_halt;
        prog[0] = 16'h5407; prog[1] = 16'h2400; prog[2] = 16'h2440; prog[3] = 16'h5809;
        prog[4] = 16'h2BC0; prog[5] = 16'h1C00; prog[6] = 16'h1840; prog[7] = 16'h3F80;
        prog[8] = 16'h2D40; prog[9] = 16'h17C0; prog[10] = 16'hF000;
        load_program;
        $display("\n--- P2: memory-heavy ---");
        run_program;
        check_state;
        check_counts(2,  10, 10, 17,  51, 57, 11,   3, 3, 4);
        check("P2 R1", harvard.rf_inst.registers[1], 9);
        check("P2 DMEM[5]", harvard.dmem_inst.mem[5], 14);

        // ---------------- P3: compute-only loop ----------------
        fill_halt;
        prog[0] = 16'h5400; prog[1] = 16'h5805; prog[2] = 16'h5501;
        prog[3] = 16'h6601; prog[4] = 16'h7002; prog[5] = 16'hF000;
        load_program;
        $display("\n--- P3: compute-only loop ---");
        run_program;
        check_state;
        check_counts(3,  16, 16, 16,  34, 67,  6,   0, 0, 0);
        check("P3 R1", harvard.rf_inst.registers[1], 5);

        // ---------------- P4: memory loop ----------------
        //   0: ADDI R1,R0,0      i = 0
        //   1: ADDI R2,R0,6      n = 6
        //   2: LOAD R3,[0]       loop: acc = mem[0]
        //   3: ADDI R3,R3,5            acc += 5
        //   4: STORE R3,[0]            mem[0] = acc
        //   5: ADDI R1,R1,1            i++
        //   6: BEQ R1,R2,+1            if (i == n) exit
        //   7: JUMP 2
        //   8: HALT
        fill_halt;
        prog[0] = 16'h5400; prog[1] = 16'h5806; prog[2] = 16'h1C00; prog[3] = 16'h5F05;
        prog[4] = 16'h2C00; prog[5] = 16'h5501; prog[6] = 16'h6601; prog[7] = 16'h7002;
        prog[8] = 16'hF000;
        load_program;
        $display("\n--- P4: memory loop (6 iterations) ---");
        run_program;
        check_state;
        check_counts(4,  37, 37, 49,  78, 175, 9,   6, 5, 6);
        check("P4 R1", harvard.rf_inst.registers[1], 6);
        check("P4 R3", harvard.rf_inst.registers[3], 30);
        check("P4 DMEM[0]", harvard.dmem_inst.mem[0], 30);

        // ---------------- Summary ----------------
        $display("\n==============================================================");
        $display(" Summary (cycles; shared L2 has %0d wait states)", WAIT);
        $display("--------------------------------------------------------------");
        $display(" Prog   N  Harvard  VonNeumann  L1+L2  L2-only  I-hit%%  LOAD hits");
        for (i = 1; i <= 4; i = i + 1)
            $display(" P%0d   %3d  %7d  %10d  %5d  %7d  %6.1f   %0d/%0d",
                     i, s_n[i], s_h[i], s_v[i], s_m[i], s_nc[i],
                     100.0 * (s_n[i] + 1 - s_if[i]) / (s_n[i] + 1), s_lh[i], s_ld[i]);
        $display("--------------------------------------------------------------");
        $display(" Total Checks Passed: %0d", pass_count);
        $display(" Total Checks Failed: %0d", fail_count);
        if (fail_count == 0)
            $display(" >>> ALL MEMORY HIERARCHY TESTS PASSED <<<");
        else
            $display(" >>> SOME MEMORY HIERARCHY TESTS FAILED <<<");
        $display("==============================================================");
        $finish;
    end

endmodule
