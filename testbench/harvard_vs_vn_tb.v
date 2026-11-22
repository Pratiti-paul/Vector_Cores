`timescale 1ns / 1ps
// Harvard vs Von Neumann Comparison Testbench
//
// Runs the SAME programs on:
//   - top_module    : Harvard (separate instruction + data memory, single-cycle)
//   - vn_top_module : Von Neumann baseline (one shared single-port memory)
//
// For each program it:
//   1. Checks both processors reach the same, expected architectural state
//      (registers R0-R3 and data memory).
//   2. Checks the Von Neumann instruction region was never overwritten.
//   3. Measures cycles, retired instructions, CPI, memory-instruction count,
//      Harvard same-cycle fetch+data overlaps and Von Neumann stall cycles.
//   4. Checks measured cycle counts against the analytical model
//      Harvard = N,  Von Neumann = N + M   (N = instructions, M = LOAD/STORE).
//
// Programs:
//   P1 program.hex     : mixed ALU + memory (the project's main program)
//   P2 memory-heavy    : 7 of 10 instructions are LOAD/STORE
//   P3 compute loop    : ADDI/BEQ/JUMP loop, no memory instructions
//
// Run from the repository root (memories load program.hex by relative path).
module harvard_vs_vn_tb;

    reg clk;
    reg reset;

    // ---------------- Harvard DUT ----------------
    wire [3:0]  h_pc;
    wire [15:0] h_instr;
    wire [7:0]  h_alu_out, h_wdata;
    wire        h_zero, h_halted;

    top_module harvard (
        .clk(clk), .reset(reset),
        .pc_out(h_pc), .instr(h_instr), .alu_out(h_alu_out),
        .write_data(h_wdata), .zero(h_zero), .halted(h_halted)
    );

    // ---------------- Von Neumann DUT ----------------
    wire [3:0]  v_pc;
    wire [15:0] v_instr;
    wire [7:0]  v_alu_out, v_wdata;
    wire        v_zero, v_halted;
    wire [4:0]  v_mem_addr;
    wire        v_mem_phase, v_stall, v_retire;

    vn_top_module vn (
        .clk(clk), .reset(reset),
        .pc_out(v_pc), .instr(v_instr), .alu_out(v_alu_out),
        .write_data(v_wdata), .zero(v_zero),
        .mem_addr(v_mem_addr), .mem_phase(v_mem_phase),
        .stall(v_stall), .retire(v_retire), .halted(v_halted)
    );

    // Harvard memory-access activity (data port busy while fetch also happens)
    wire h_data_access = harvard.mem_read | harvard.mem_write;

    always #5 clk = ~clk;   // 100 MHz simulation clock (10 ns period)

    // ---------------- Bookkeeping ----------------
    reg [15:0] prog [0:15];
    integer i;
    integer pass_count, fail_count;
    integer h_cycles, h_instrs, h_overlap;
    integer v_cycles, v_instrs, v_stalls, v_memops;
    integer guard;
    real    h_cpi, v_cpi, speedup;

    // Summary table storage
    integer s_n [1:3], s_m [1:3], s_hc [1:3], s_vc [1:3];

    task check;
        input [255:0] name;
        input integer actual;
        input integer expected;
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("  [PASS] %0s = %0d", name, actual);
            end
            else begin
                fail_count = fail_count + 1;
                $display("  [FAIL] %0s = %0d (expected %0d)", name, actual, expected);
            end
        end
    endtask

    // Load prog[] into BOTH processors' instruction storage
    task load_program;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                harvard.imem_inst.mem[i] = prog[i];
                vn.umem_inst.mem[i]      = prog[i];
            end
        end
    endtask

    task fill_halt;
        begin
            for (i = 0; i < 16; i = i + 1)
                prog[i] = 16'hF000;
        end
    endtask

    // Reset both cores, run until both halt, collect metrics
    task run_program;
        begin
            reset = 1'b1;
            @(posedge clk); @(posedge clk);
            #1 reset = 1'b0;

            h_cycles = 0; h_instrs = 0; h_overlap = 0;
            v_cycles = 0; v_instrs = 0; v_stalls = 0; v_memops = 0;
            guard    = 0;

            while (!(h_halted && v_halted) && guard < 200) begin
                @(negedge clk);   // sample settled combinational signals
                if (!h_halted) begin
                    h_cycles = h_cycles + 1;
                    if (harvard.pc_enable) h_instrs  = h_instrs + 1;
                    if (h_data_access)     h_overlap = h_overlap + 1;
                end
                if (!v_halted) begin
                    v_cycles = v_cycles + 1;
                    if (v_retire)                v_instrs = v_instrs + 1;
                    if (v_stall)                 v_stalls = v_stalls + 1;
                    if (v_mem_phase)             v_memops = v_memops + 1;
                end
                @(posedge clk);
                guard = guard + 1;
            end
            if (guard >= 200)
                $display("  [WARN] timeout before both processors halted");
        end
    endtask

    task report_metrics;
        input integer idx;
        begin
            h_cpi   = (h_instrs > 0) ? (1.0 * h_cycles) / h_instrs : 0.0;
            v_cpi   = (v_instrs > 0) ? (1.0 * v_cycles) / v_instrs : 0.0;
            speedup = (h_cycles > 0) ? (1.0 * v_cycles) / h_cycles : 0.0;
            $display("  Harvard     : cycles=%0d instrs=%0d CPI=%0.3f same-cycle fetch+data=%0d",
                     h_cycles, h_instrs, h_cpi, h_overlap);
            $display("  Von Neumann : cycles=%0d instrs=%0d CPI=%0.3f stall cycles=%0d",
                     v_cycles, v_instrs, v_cpi, v_stalls);
            $display("  Harvard speed-up over Von Neumann = %0.3fx", speedup);
            s_n[idx]  = h_instrs;
            s_m[idx]  = h_overlap;
            s_hc[idx] = h_cycles;
            s_vc[idx] = v_cycles;
        end
    endtask

    // Shared checks: equivalence + analytical cycle model + region protection
    task common_checks;
        input integer exp_instrs;
        input integer exp_memops;
        begin
            check("Harvard retired instructions", h_instrs, exp_instrs);
            check("VN retired instructions",      v_instrs, exp_instrs);
            check("Harvard cycles (= N)",         h_cycles, exp_instrs);
            check("VN cycles (= N + M)",          v_cycles, exp_instrs + exp_memops);
            check("Harvard fetch+data overlap cycles (= M)", h_overlap, exp_memops);
            check("VN structural stall cycles (= M)",        v_stalls,  exp_memops);
            check("Harvard halted", h_halted, 1);
            check("VN halted",      v_halted, 1);
            check("Final PC match", v_pc, h_pc);
            for (i = 0; i < 4; i = i + 1)
                check("Register match (Harvard vs VN)",
                      vn.rf_inst.registers[i], harvard.rf_inst.registers[i]);
            for (i = 0; i < 16; i = i + 1)
                check("DMEM match (Harvard vs VN data region)",
                      vn.umem_inst.mem[16 + i][7:0], harvard.dmem_inst.mem[i]);
            for (i = 0; i < 16; i = i + 1)
                check("VN instruction region intact", vn.umem_inst.mem[i], prog[i]);
        end
    endtask

    initial begin
        $dumpfile("simulation/waveforms/harvard_vs_vn_wave.vcd");
        $dumpvars(0, harvard_vs_vn_tb);

        clk = 1'b0; reset = 1'b1;
        pass_count = 0; fail_count = 0;
        #1;

        $display("==============================================================");
        $display(" Harvard vs Von Neumann (shared memory) Comparison");
        $display("==============================================================");

        // ---------------------------------------------------------------
        // P1: program.hex (mixed ALU + memory)
        // ---------------------------------------------------------------
        fill_halt;
        prog[0] = 16'h5405;  // ADDI R1, R0, 5
        prog[1] = 16'h5803;  // ADDI R2, R0, 3
        prog[2] = 16'h3580;  // ADD  R1, R1, R2   -> 8
        prog[3] = 16'h2480;  // STORE R1, [2]     -> DMEM[2] = 8
        prog[4] = 16'h4580;  // SUB  R1, R1, R2   -> 5
        prog[5] = 16'h1C80;  // LOAD R3, [2]      -> 8
        prog[6] = 16'h5F01;  // ADDI R3, R3, 1    -> 9
        prog[7] = 16'hF000;  // HALT
        load_program;
        $display("\n--- P1: program.hex (mixed ALU + memory) ---");
        run_program;
        report_metrics(1);
        common_checks(7, 2);
        check("P1 R1", harvard.rf_inst.registers[1], 5);
        check("P1 R2", harvard.rf_inst.registers[2], 3);
        check("P1 R3", harvard.rf_inst.registers[3], 9);
        check("P1 DMEM[2]", harvard.dmem_inst.mem[2], 8);
        check("P1 final PC", h_pc, 7);

        // ---------------------------------------------------------------
        // P2: memory-heavy (7 LOAD/STORE out of 10 instructions)
        // ---------------------------------------------------------------
        fill_halt;
        prog[0] = 16'h5407;  // ADDI  R1, R0, 7
        prog[1] = 16'h2400;  // STORE R1, [0]
        prog[2] = 16'h2440;  // STORE R1, [1]
        prog[3] = 16'h5809;  // ADDI  R2, R0, 9
        prog[4] = 16'h2BC0;  // STORE R2, [15]
        prog[5] = 16'h1C00;  // LOAD  R3, [0]     -> 7
        prog[6] = 16'h1840;  // LOAD  R2, [1]     -> 7
        prog[7] = 16'h3F80;  // ADD   R3, R3, R2  -> 14
        prog[8] = 16'h2D40;  // STORE R3, [5]
        prog[9] = 16'h17C0;  // LOAD  R1, [15]    -> 9
        prog[10] = 16'hF000; // HALT
        load_program;
        $display("\n--- P2: memory-heavy ---");
        run_program;
        report_metrics(2);
        common_checks(10, 7);
        check("P2 R1", harvard.rf_inst.registers[1], 9);
        check("P2 R2", harvard.rf_inst.registers[2], 7);
        check("P2 R3", harvard.rf_inst.registers[3], 14);
        check("P2 DMEM[0]",  harvard.dmem_inst.mem[0], 7);
        check("P2 DMEM[1]",  harvard.dmem_inst.mem[1], 7);
        check("P2 DMEM[5]",  harvard.dmem_inst.mem[5], 14);
        check("P2 DMEM[15]", harvard.dmem_inst.mem[15], 9);
        check("P2 final PC", h_pc, 10);

        // ---------------------------------------------------------------
        // P3: compute-only loop (no memory instructions)
        // ---------------------------------------------------------------
        fill_halt;
        prog[0] = 16'h5400;  // ADDI R1, R0, 0
        prog[1] = 16'h5805;  // ADDI R2, R0, 5
        prog[2] = 16'h5501;  // loop: ADDI R1, R1, 1
        prog[3] = 16'h6601;  // BEQ  R1, R2, +1  -> addr 5 when R1 == 5
        prog[4] = 16'h7002;  // JUMP 2
        prog[5] = 16'hF000;  // HALT
        load_program;
        $display("\n--- P3: compute-only loop ---");
        run_program;
        report_metrics(3);
        common_checks(16, 0);
        check("P3 R1", harvard.rf_inst.registers[1], 5);
        check("P3 R2", harvard.rf_inst.registers[2], 5);
        check("P3 final PC", h_pc, 5);

        // ---------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------
        $display("\n==============================================================");
        $display(" Summary  (N = instructions, M = LOAD/STORE)");
        $display("--------------------------------------------------------------");
        $display(" Program        N   M  Harvard cyc  VN cyc  Harvard CPI  VN CPI  Speed-up");
        for (i = 1; i <= 3; i = i + 1)
            $display(" P%0d          %3d %3d  %11d  %6d  %11.3f  %6.3f  %7.3fx",
                     i, s_n[i], s_m[i], s_hc[i], s_vc[i],
                     (1.0 * s_hc[i]) / s_n[i], (1.0 * s_vc[i]) / s_n[i],
                     (1.0 * s_vc[i]) / s_hc[i]);
        $display("--------------------------------------------------------------");
        $display(" Total Checks Passed: %0d", pass_count);
        $display(" Total Checks Failed: %0d", fail_count);
        if (fail_count == 0)
            $display(" >>> ALL HARVARD vs VON NEUMANN COMPARISON TESTS PASSED <<<");
        else
            $display(" >>> SOME COMPARISON TESTS FAILED <<<");
        $display("==============================================================");
        $finish;
    end

endmodule
