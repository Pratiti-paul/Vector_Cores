// Phase 7B: Control-Flow Verification Testbench
// Member 5: Verification, Waveform Analysis, and System-Level Testing
//
// Formally verifies all processor control-flow transfer mechanisms:
//   1. BEQ forward taken when registers are equal (R1 == R2).
//   2. BEQ not taken when registers are unequal (R1 != R3).
//   3. BEQ backward taken using a negative signed offset (offset = -2).
//   4. JUMP to an absolute 4-bit target address (target = 10 / 0xA).
//   5. HALT and PC freeze/hold behavior over multiple clock cycles.
//
// Loading Method:
//   Testbench-only hierarchical loading into 'uut.imem_inst.mem' while holding
//   synchronous reset, preserving 'program.hex' untouched.

`timescale 1ns/1ps

module control_flow_tb;

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
    reg     timeout;

    // Instantiate the single-cycle Harvard Architecture processor
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

    // Helper task to check assertions
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
        $dumpfile("simulation/waveforms/control_flow_wave.vcd");
        $dumpvars(0, control_flow_tb);

        clk           = 0;
        reset         = 1;
        cycle_count   = 0;
        errors        = 0;
        passed_checks = 0;
        timeout       = 0;

        $display("==================================================================");
        $display("       VECTOR CORES: CONTROL-FLOW VERIFICATION TESTBENCH");
        $display("==================================================================");

        // ---------------------------------------------------------------------
        // Hierarchically load custom control-flow program into instruction memory
        // ---------------------------------------------------------------------
        #1; // Allow time-0 initial blocks to settle before overriding
        uut.imem_inst.mem[0]  = 16'h5405; // 0x0: ADDI R1, R0, 5  (R1 = 5)
        uut.imem_inst.mem[1]  = 16'h5805; // 0x1: ADDI R2, R0, 5  (R2 = 5)
        uut.imem_inst.mem[2]  = 16'h5C01; // 0x2: ADDI R3, R0, 1  (R3 = 1)
        uut.imem_inst.mem[3]  = 16'h6702; // 0x3: BEQ R1, R3, +2  (Not taken: 5 != 1 -> PC = 4)
        uut.imem_inst.mem[4]  = 16'h6602; // 0x4: BEQ R1, R2, +2  (Taken: 5 == 5 -> PC = 4 + 1 + 2 = 7)
        uut.imem_inst.mem[5]  = 16'hF000; // 0x5: HALT (Error Trap - should be skipped)
        uut.imem_inst.mem[6]  = 16'hF000; // 0x6: HALT (Error Trap - should be skipped)
        uut.imem_inst.mem[7]  = 16'h700A; // 0x7: JUMP 10         (Taken: absolute address 10 -> PC = 10)
        uut.imem_inst.mem[8]  = 16'hF000; // 0x8: HALT (Error Trap - should be skipped)
        uut.imem_inst.mem[9]  = 16'hF000; // 0x9: HALT (Error Trap - should be skipped)
        uut.imem_inst.mem[10] = 16'h5FFF; // 0xA: ADDI R3, R3, -1 (Pass 1: R3 = 0; Pass 2: R3 = 255)
        uut.imem_inst.mem[11] = 16'h6CFE; // 0xB: BEQ R3, R0, -2  (Pass 1: 0 == 0 taken -> 10; Pass 2: 255 != 0 -> 12)
        uut.imem_inst.mem[12] = 16'hF000; // 0xC: HALT            (End of program -> PC freezes at 12)
        uut.imem_inst.mem[13] = 16'hF000; // 0xD: HALT
        uut.imem_inst.mem[14] = 16'hF000; // 0xE: HALT
        uut.imem_inst.mem[15] = 16'hF000; // 0xF: HALT

        // Hold synchronous reset across 2 rising clock edges
        #20;
        @(negedge clk);
        reset = 0;
        $display("Time=%0t ns: Synchronous reset released. Beginning execution...", $time);
        $display("------------------------------------------------------------------");

        // Trace cycle-by-cycle execution
        while (!halted && cycle_count < 30) begin
            @(posedge clk);
            #1; // Sample shortly after rising clock edge
            cycle_count = cycle_count + 1;

            $display("Cycle %02d | Time=%0t ns | PC=%02d (0x%h) | Instr=%h | ALU_Out=%h | Zero=%b | Halted=%b",
                     cycle_count, $time, pc_out, pc_out, instr, alu_out, zero, halted);

            // Cycle-specific assertions
            case (cycle_count)
                1: assert_condition(pc_out === 4'd1 && uut.rf_inst.registers[1] === 8'd5,
                                    "Cycle 1: Executed ADDI R1, R0, 5 -> R1=5, PC=1");
                2: assert_condition(pc_out === 4'd2 && uut.rf_inst.registers[2] === 8'd5,
                                    "Cycle 2: Executed ADDI R2, R0, 5 -> R2=5, PC=2");
                3: assert_condition(pc_out === 4'd3 && uut.rf_inst.registers[3] === 8'd1,
                                    "Cycle 3: Executed ADDI R3, R0, 1 -> R3=1, PC=3");
                4: assert_condition(pc_out === 4'd4,
                                    "Cycle 4: Test 1 - BEQ R1, R3 NOT TAKEN (5 != 1) -> Sequential PC=4");
                5: assert_condition(pc_out === 4'd7,
                                    "Cycle 5: Test 2 - BEQ R1, R2 FORWARD TAKEN (5 == 5) -> Branch target PC=7");
                6: assert_condition(pc_out === 4'd10,
                                    "Cycle 6: Test 3 - JUMP 10 ABSOLUTE TAKEN -> Jump target PC=10 (0xA)");
                7: assert_condition(pc_out === 4'd11 && uut.rf_inst.registers[3] === 8'd0,
                                    "Cycle 7: Executed ADDI R3, R3, -1 -> R3=0, PC=11 (0xB)");
                8: assert_condition(pc_out === 4'd10,
                                    "Cycle 8: Test 4 - BEQ R3, R0 BACKWARD TAKEN (0 == 0, offset=-2) -> PC=10 (0xA)");
                9: assert_condition(pc_out === 4'd11 && uut.rf_inst.registers[3] === 8'd255,
                                    "Cycle 9: Executed loop ADDI R3, R3, -1 -> R3=255 (0xFF), PC=11 (0xB)");
                10: assert_condition(pc_out === 4'd12 && halted === 1'b1,
                                     "Cycle 10: Test 5 - BEQ R3, R0 loop exit NOT TAKEN (255 != 0) -> Reached HALT at PC=12");
            endcase
        end

        // Check for simulation timeout
        if (cycle_count >= 30 && !halted) begin
            $display("\n[ERROR] Simulation timed out after %0d cycles without asserting HALT!", cycle_count);
            errors = errors + 1;
            timeout = 1;
        end else begin
            $display("\nTime=%0t ns: HALT detected at PC=%0d after %0d execution cycles.", $time, pc_out, cycle_count);
        end

        // ---------------------------------------------------------------------
        // Verify Post-Halt PC Hold Behavior over 3 Clock Cycles
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------------");
        $display("       VERIFYING HALT FREEZE AND PC HOLD OVER 3 CYCLES");
        $display("------------------------------------------------------------------");

        repeat (3) begin
            @(posedge clk);
            #1;
            assert_condition(pc_out === 4'd12 && halted === 1'b1,
                             "Post-Halt Hold: PC remains frozen at 12 and halted remains asserted");
        end

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("==================================================================");
        $display("Control-Flow Checks Passed: %0d", passed_checks);
        $display("Control-Flow Checks Failed: %0d", errors);
        $display("==================================================================");

        if (errors == 0 && !timeout) begin
            $display(">>> ALL CONTROL-FLOW TESTS PASSED SUCCESSFULLY! <<<");
            $display("==================================================================\n");
        end else begin
            $display(">>> CONTROL-FLOW TESTS FAILED! (%0d errors) <<<", errors);
            $display("==================================================================\n");
        end

        $finish;
    end

endmodule
