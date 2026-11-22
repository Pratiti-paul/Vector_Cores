`timescale 1ns / 1ps
// Logical Instructions (AND / OR / XOR) Processor-Level Testbench
//
// Executes a program that uses AND (1000), OR (1001) and XOR (1010) on:
//   - top_module    : Harvard processor
//   - vn_top_module : Von Neumann baseline (same control unit)
// and checks register write-back, STORE of logical results, the ALU zero
// flag, use of R0 as an operand, and that writes to R0 stay blocked.
//
// Program (R1 = 12 = 0000_1100, R2 = 10 = 0000_1010):
//   0: 540C  ADDI  R1, R0, 12
//   1: 580A  ADDI  R2, R0, 10
//   2: 8D80  AND   R3, R1, R2   -> 8  (0000_1000)
//   3: 2C00  STORE R3, [0]      -> DMEM[0] = 8
//   4: 9D80  OR    R3, R1, R2   -> 14 (0000_1110)
//   5: 2C40  STORE R3, [1]      -> DMEM[1] = 14
//   6: AD80  XOR   R3, R1, R2   -> 6  (0000_0110)
//   7: 2C80  STORE R3, [2]      -> DMEM[2] = 6
//   8: A540  XOR   R1, R1, R1   -> 0, zero flag = 1
//   9: 9A00  OR    R2, R2, R0   -> 10 (R0 reads as 0)
//  10: 8280  AND   R0, R2, R2   -> write to R0 blocked, R0 stays 0
//  11: F000  HALT
//
// Run from the repository root (memories load program.hex by relative path;
// this testbench then overwrites instruction storage with the program above).
module logical_ops_tb;

    reg clk;
    reg reset;

    wire [3:0]  h_pc;
    wire [15:0] h_instr;
    wire [7:0]  h_alu_out, h_wdata;
    wire        h_zero, h_halted;

    top_module harvard (
        .clk(clk), .reset(reset),
        .pc_out(h_pc), .instr(h_instr), .alu_out(h_alu_out),
        .write_data(h_wdata), .zero(h_zero), .halted(h_halted)
    );

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

    always #5 clk = ~clk;

    reg [15:0] prog [0:15];
    integer i, guard;
    integer pass_count, fail_count;

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

    initial begin
        $dumpfile("simulation/waveforms/logical_ops_wave.vcd");
        $dumpvars(0, logical_ops_tb);

        clk = 1'b0; reset = 1'b1;
        pass_count = 0; fail_count = 0;
        #1;

        for (i = 0; i < 16; i = i + 1) prog[i] = 16'hF000;
        prog[0]  = 16'h540C;
        prog[1]  = 16'h580A;
        prog[2]  = 16'h8D80;
        prog[3]  = 16'h2C00;
        prog[4]  = 16'h9D80;
        prog[5]  = 16'h2C40;
        prog[6]  = 16'hAD80;
        prog[7]  = 16'h2C80;
        prog[8]  = 16'hA540;
        prog[9]  = 16'h9A00;
        prog[10] = 16'h8280;
        prog[11] = 16'hF000;
        for (i = 0; i < 16; i = i + 1) begin
            harvard.imem_inst.mem[i] = prog[i];
            vn.umem_inst.mem[i]      = prog[i];
        end

        $display("==============================================================");
        $display(" Logical Instructions (AND / OR / XOR) Processor Test");
        $display("==============================================================");

        @(posedge clk); @(posedge clk);
        #1 reset = 1'b0;

        // ---- Per-instruction ALU results on the Harvard core ----
        $display("\n--- Harvard: per-instruction ALU results ---");
        guard = 0;
        while (!h_halted && guard < 50) begin
            @(negedge clk);
            case (h_pc)
                4'd2:  begin check("AND  R1&R2 alu_out", h_alu_out, 8);  check("AND  zero flag", h_zero, 0); end
                4'd4:  begin check("OR   R1|R2 alu_out", h_alu_out, 14); check("OR   zero flag", h_zero, 0); end
                4'd6:  begin check("XOR  R1^R2 alu_out", h_alu_out, 6);  check("XOR  zero flag", h_zero, 0); end
                4'd8:  begin check("XOR  R1^R1 alu_out", h_alu_out, 0);  check("XOR  R1^R1 zero flag", h_zero, 1); end
                4'd9:  check("OR   R2|R0 alu_out", h_alu_out, 10);
                4'd10: check("AND  R2&R2 alu_out (to R0)", h_alu_out, 10);
                default: ;
            endcase
            @(posedge clk);
            guard = guard + 1;
        end

        // Let the Von Neumann core finish too (it takes extra cycles for STOREs)
        guard = 0;
        while (!v_halted && guard < 50) begin
            @(posedge clk);
            guard = guard + 1;
        end
        #1;

        $display("\n--- Harvard: final state ---");
        check("Harvard halted",   h_halted, 1);
        check("Harvard final PC", h_pc, 11);
        check("Harvard R0", harvard.rf_inst.registers[0], 0);
        check("Harvard R1", harvard.rf_inst.registers[1], 0);
        check("Harvard R2", harvard.rf_inst.registers[2], 10);
        check("Harvard R3", harvard.rf_inst.registers[3], 6);
        check("Harvard DMEM[0] (AND)", harvard.dmem_inst.mem[0], 8);
        check("Harvard DMEM[1] (OR)",  harvard.dmem_inst.mem[1], 14);
        check("Harvard DMEM[2] (XOR)", harvard.dmem_inst.mem[2], 6);

        $display("\n--- Von Neumann baseline: final state ---");
        check("VN halted",   v_halted, 1);
        check("VN final PC", v_pc, 11);
        check("VN R0", vn.rf_inst.registers[0], 0);
        check("VN R1", vn.rf_inst.registers[1], 0);
        check("VN R2", vn.rf_inst.registers[2], 10);
        check("VN R3", vn.rf_inst.registers[3], 6);
        check("VN DMEM[0] (AND)", vn.umem_inst.mem[16][7:0], 8);
        check("VN DMEM[1] (OR)",  vn.umem_inst.mem[17][7:0], 14);
        check("VN DMEM[2] (XOR)", vn.umem_inst.mem[18][7:0], 6);

        $display("\n==============================================================");
        $display(" Logical-Op Checks Passed: %0d", pass_count);
        $display(" Logical-Op Checks Failed: %0d", fail_count);
        if (fail_count == 0)
            $display(" >>> ALL LOGICAL INSTRUCTION TESTS PASSED <<<");
        else
            $display(" >>> SOME LOGICAL INSTRUCTION TESTS FAILED <<<");
        $display("==============================================================");
        $finish;
    end

endmodule
