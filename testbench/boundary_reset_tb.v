// Phase 7B Additional Verification: Boundary and Reset Testing
// Testbench: testbench/boundary_reset_tb.v
//
// Formally verifies:
//   TEST 1 — Negative Branch Address Wraparound:
//     - Hierarchical instruction loading into instruction memory array.
//     - Two registers initialized with equal values.
//     - BEQ at PC=0 with signed offset -2 (8'hFE).
//     - Expected target: (0 + 1 - 2) modulo 16 = 15.
//     - Verify PC becomes 15 and instruction at address 15 executes.
//
//   TEST 2 — Reset Reassertion:
//     - Execute instructions modifying multiple registers and data memory locations.
//     - Processor reaches HALT (halted = 1).
//     - Assert reset again across at least two positive clock edges.
//     - Verify PC returns to 0.
//     - Verify all 4 registers (R0-R3) are cleared to 8'h00.
//     - Verify all 16 data memory locations (DMEM[0..15]) are cleared to 8'h00.
//     - Verify halted is deasserted to 0 after reset.

`timescale 1ns/1ps

module boundary_reset_tb;

    reg clk;
    reg reset;

    wire [3:0]  pc_out;
    wire [15:0] instr;
    wire [7:0]  alu_out;
    wire [7:0]  write_data;
    wire        zero;
    wire        halted;

    integer cycle_count;
    integer errors;
    integer passed_checks;
    integer dmem_all_zero;
    integer i;

    // Instantiate single-cycle Harvard Architecture top_module
    top_module uut (
        .clk        (clk),
        .reset      (reset),
        .pc_out     (pc_out),
        .instr      (instr),
        .alu_out    (alu_out),
        .write_data (write_data),
        .zero       (zero),
        .halted     (halted)
    );

    // Clock generation: 10 ns period (100 MHz)
    always #5 clk = ~clk;

    // Assertion helper task with formatted output
    task assert_condition;
        input condition;
        input [8*120-1:0] test_description;
        begin
            if (condition) begin
                $display("  [PASS] %0s", test_description);
                passed_checks = passed_checks + 1;
            end else begin
                $display("  [FAIL] %0s", test_description);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Configure waveform dump
        $dumpfile("simulation/waveforms/boundary_reset_wave.vcd");
        $dumpvars(0, boundary_reset_tb);

        clk           = 0;
        reset         = 1;
        cycle_count   = 0;
        errors        = 0;
        passed_checks = 0;

        $display("==================================================================");
        $display("   VECTOR CORES: BOUNDARY AND RESET VERIFICATION TESTBENCH");
        $display("==================================================================");

        // ---------------------------------------------------------------------
        // Hierarchically load test program into instruction memory
        // ---------------------------------------------------------------------
        #1; // Allow time-0 simulation constructs to settle
        uut.imem_inst.mem[0]  = 16'h66FE; // PC=0:  BEQ R1, R2, -2 (offset=8'hFE -> (0+1-2)%16=15)
        uut.imem_inst.mem[1]  = 16'h58BB; // PC=1:  ADDI R2, R0, 8'hBB (R2 = 0xBB)
        uut.imem_inst.mem[2]  = 16'h5CCC; // PC=2:  ADDI R3, R0, 8'hCC (R3 = 0xCC)
        uut.imem_inst.mem[3]  = 16'h2540; // PC=3:  STORE R1, [5]      (DMEM[5] = R1 = 0xAA)
        uut.imem_inst.mem[4]  = 16'h2A40; // PC=4:  STORE R2, [9]      (DMEM[9] = R2 = 0xBB)
        uut.imem_inst.mem[5]  = 16'hF000; // PC=5:  HALT               (halted = 1)
        uut.imem_inst.mem[6]  = 16'hF000; // PC=6:  HALT trap
        uut.imem_inst.mem[7]  = 16'hF000; // PC=7:  HALT trap
        uut.imem_inst.mem[8]  = 16'hF000; // PC=8:  HALT trap
        uut.imem_inst.mem[9]  = 16'hF000; // PC=9:  HALT trap
        uut.imem_inst.mem[10] = 16'hF000; // PC=10: HALT trap
        uut.imem_inst.mem[11] = 16'hF000; // PC=11: HALT trap
        uut.imem_inst.mem[12] = 16'hF000; // PC=12: HALT trap
        uut.imem_inst.mem[13] = 16'hF000; // PC=13: HALT trap
        uut.imem_inst.mem[14] = 16'hF000; // PC=14: HALT trap
        uut.imem_inst.mem[15] = 16'h54AA; // PC=15: ADDI R1, R0, 8'hAA (target of PC=0 branch wraparound)

        // Hold initial reset across 2 clock edges
        #20;
        @(negedge clk);
        // Pre-initialize R1 and R2 with equal non-zero values to test BEQ
        uut.rf_inst.registers[1] = 8'd20;
        uut.rf_inst.registers[2] = 8'd20;
        reset = 0;
        $display("Time=%0t ns: Initial reset released. R1=20, R2=20.", $time);
        $display("------------------------------------------------------------------");
        $display("   TEST 1: NEGATIVE BRANCH ADDRESS WRAPAROUND (PC=0 -> PC=15)");
        $display("------------------------------------------------------------------");

        // Cycle 1: PC=0, BEQ R1, R2, -2
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | ALU_Out=%h | Zero=%b",
                 cycle_count, $time, pc_out, instr, alu_out, zero);
        assert_condition(pc_out === 4'd15,
                         "TEST 1.1: BEQ at PC=0 with offset -2 correctly wrapped PC to 15 ((0+1-2)%16=15)");

        // Cycle 2: PC=15, ADDI R1, R0, 8'hAA executes at address 15
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | ALU_Out=%h | Zero=%b",
                 cycle_count, $time, pc_out, instr, alu_out, zero);
        assert_condition(uut.rf_inst.registers[1] === 8'hAA,
                         "TEST 1.2: Instruction at address 15 (ADDI R1, R0, 0xAA) successfully executed (R1=0xAA)");
        assert_condition(pc_out === 4'd0,
                         "TEST 1.3: Sequential execution after PC=15 correctly wrapped PC back to 0 ((15+1)%16=0)");

        // Cycle 3: PC=0, BEQ R1, R2, -2 evaluated with R1=0xAA != R2=20 (Not Taken)
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | ALU_Out=%h | Zero=%b",
                 cycle_count, $time, pc_out, instr, alu_out, zero);
        assert_condition(pc_out === 4'd1,
                         "TEST 1.4: BEQ at PC=0 NOT taken when R1!=R2 -> fell through to PC=1");

        $display("------------------------------------------------------------------");
        $display("   TEST 2: EXECUTE MODIFICATIONS & VERIFY PRE-RESET STATE");
        $display("------------------------------------------------------------------");

        // Cycle 4: PC=1, ADDI R2, R0, 8'hBB
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | ALU_Out=%h",
                 cycle_count, $time, pc_out, instr, alu_out);
        assert_condition(uut.rf_inst.registers[2] === 8'hBB,
                         "Cycle 4: Executed ADDI R2, R0, 0xBB -> R2=0xBB");

        // Cycle 5: PC=2, ADDI R3, R0, 8'hCC
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | ALU_Out=%h",
                 cycle_count, $time, pc_out, instr, alu_out);
        assert_condition(uut.rf_inst.registers[3] === 8'hCC,
                         "Cycle 5: Executed ADDI R3, R0, 0xCC -> R3=0xCC");

        // Cycle 6: PC=3, STORE R1, [5] -> DMEM[5] = 0xAA
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | Write_Data=%h",
                 cycle_count, $time, pc_out, instr, write_data);
        assert_condition(uut.dmem_inst.mem[5] === 8'hAA,
                         "Cycle 6: Executed STORE R1, [5] -> DMEM[5]=0xAA");

        // Cycle 7: PC=4, STORE R2, [9] -> DMEM[9] = 0xBB
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | Write_Data=%h",
                 cycle_count, $time, pc_out, instr, write_data);
        assert_condition(uut.dmem_inst.mem[9] === 8'hBB,
                         "Cycle 7: Executed STORE R2, [9] -> DMEM[9]=0xBB");

        // Cycle 8: PC=5, HALT -> halted asserts
        @(posedge clk);
        #1;
        cycle_count = cycle_count + 1;
        $display("Cycle %02d | Time=%0t ns | PC=%02d | Instr=%h | Halted=%b",
                 cycle_count, $time, pc_out, instr, halted);
        assert_condition(halted === 1'b1 && pc_out === 4'd5,
                         "Cycle 8: Reached HALT instruction at PC=5 -> halted=1 asserted");

        // Verify pre-reset modified architectural state
        $display("------------------------------------------------------------------");
        $display("   CONFIRMING MODIFIED PRE-RESET STATE BEFORE REASSERTION");
        $display("------------------------------------------------------------------");
        assert_condition(uut.rf_inst.registers[1] === 8'hAA &&
                         uut.rf_inst.registers[2] === 8'hBB &&
                         uut.rf_inst.registers[3] === 8'hCC,
                         "Pre-Reset: Registers R1=0xAA, R2=0xBB, R3=0xCC confirmed non-zero");
        assert_condition(uut.dmem_inst.mem[5] === 8'hAA &&
                         uut.dmem_inst.mem[9] === 8'hBB,
                         "Pre-Reset: DMEM[5]=0xAA and DMEM[9]=0xBB confirmed non-zero");

        // ---------------------------------------------------------------------
        // TEST 2: Reset Reassertion across two positive clock edges
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------------");
        $display("   TEST 2: REASSERTING SYNCHRONOUS RESET ACROSS >=2 CLOCK EDGES");
        $display("------------------------------------------------------------------");
        @(negedge clk);
        reset = 1;
        $display("Time=%0t ns: Synchronous reset reasserted.", $time);

        // Clock across 2 positive clock edges while reset = 1
        @(posedge clk);
        #1;
        $display("Time=%0t ns: Reset active edge 1 - PC=%0d, halted=%b", $time, pc_out, halted);
        @(posedge clk);
        #1;
        $display("Time=%0t ns: Reset active edge 2 - PC=%0d, halted=%b", $time, pc_out, halted);

        // Release reset on negedge clk to prevent setup/hold races
        @(negedge clk);
        reset = 0;
        $display("Time=%0t ns: Synchronous reset deasserted.", $time);

        // Allow combinational outputs to settle
        #1;

        // Verify all 4 required reset conditions
        $display("------------------------------------------------------------------");
        $display("   VERIFYING POST-RESET ARCHITECTURAL RESTORATION");
        $display("------------------------------------------------------------------");

        // 1. Verify PC returns to 0
        assert_condition(pc_out === 4'd0,
                         "TEST 2.1: PC successfully returned to 0 (pc_out = 4'd0)");

        // 2. Verify all four registers are cleared to 8'h00
        assert_condition(uut.rf_inst.registers[0] === 8'h00 &&
                         uut.rf_inst.registers[1] === 8'h00 &&
                         uut.rf_inst.registers[2] === 8'h00 &&
                         uut.rf_inst.registers[3] === 8'h00,
                         "TEST 2.2: All four registers (R0, R1, R2, R3) cleared to 8'h00");

        // 3. Verify all 16 data memory locations are cleared to 8'h00
        dmem_all_zero = 1;
        for (i = 0; i < 16; i = i + 1) begin
            if (uut.dmem_inst.mem[i] !== 8'h00) begin
                dmem_all_zero = 0;
                $display("  [FAIL] DMEM[%0d] = %h (expected 8'h00)", i, uut.dmem_inst.mem[i]);
            end
        end
        assert_condition(dmem_all_zero === 1,
                         "TEST 2.3: All 16 Data Memory locations (mem[0..15]) cleared to 8'h00");

        // 4. Verify halted is deasserted after reset
        assert_condition(halted === 1'b0,
                         "TEST 2.4: Signal halted successfully deasserted to 0");

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("==================================================================");
        $display("Boundary & Reset Checks Passed: %0d", passed_checks);
        $display("Boundary & Reset Checks Failed: %0d", errors);
        $display("==================================================================");

        if (errors == 0) begin
            $display(">>> ALL BOUNDARY AND RESET TESTS PASSED SUCCESSFULLY! <<<");
            $display("==================================================================\n");
        end else begin
            $display(">>> BOUNDARY AND RESET TESTS FAILED! (%0d errors) <<<", errors);
            $display("==================================================================\n");
        end

        $finish;
    end

    // Simulation watchdog timeout
    initial begin
        #500;
        if ($time >= 500) begin
            $display("\n[ERROR] Simulation watchdog timeout reached at %0t ns!", $time);
            errors = errors + 1;
            $finish;
        end
    end

endmodule

