`timescale 1ns / 1ps

// =============================================================================
// Testbench: logical_ops_tb
// Project:   Vector_Cores — 16-Bit Harvard Architecture Processor
// Scope:     Phase II System-Level Logical Operations Verification
//            Instantiates the full top_module datapath and verifies:
//              1. AND (12 & 10 = 8)
//              2. OR  (12 | 10 = 14)
//              3. XOR (12 ^ 10 = 6)
//              4. AND producing zero and asserting zero flag
//              5. XOR of identical operands producing zero and asserting zero flag
//              6. Destination register writeback to R1, R2, R3
//              7. R0 hardwired zero / write-protection during logical ops
//              8. No unintended writes to other registers
//              9. HALT and PC freeze behavior
//             10. Co-verification with Python assembler generated machine code
// =============================================================================

module logical_ops_tb;

    // Clock and Reset inputs
    reg clk;
    reg reset;

    // Processor outputs
    wire [3:0]  pc_out;
    wire [15:0] instr;
    wire [7:0]  alu_out;
    wire [7:0]  write_data;
    wire        zero;
    wire        halted;

    // Counters and status tracking
    integer passed_checks;
    integer failed_checks;
    integer cycle_count;

    // Instantiate Full Processor Top Module
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

    // Assertion helper task
    task assert_check;
        input condition;
        input [8*140-1:0] test_description;
        begin
            if (condition) begin
                $display("  [PASS] %0s", test_description);
                passed_checks = passed_checks + 1;
            end else begin
                $display("  [FAIL] %0s", test_description);
                failed_checks = failed_checks + 1;
            end
        end
    endtask

    // Main Test Sequence
    initial begin
        // Configure waveform dump
        $dumpfile("simulation/waveforms/logical_ops_wave.vcd");
        $dumpvars(0, logical_ops_tb);

        clk           = 0;
        reset         = 1;
        passed_checks = 0;
        failed_checks = 0;
        cycle_count   = 0;

        $display("==================================================================");
        $display("   VECTOR CORES: LOGICAL OPERATIONS SYSTEM VERIFICATION TESTBENCH");
        $display("==================================================================");

        // =====================================================================
        // SUITE 1: COMPREHENSIVE DATAPATH LOGICAL VERIFICATION
        // =====================================================================
        // Test Program Encoding:
        //   Addr 0:  ADDI R1, R0, 12   (540C) -> R1 = 12 (0x0C)
        //   Addr 1:  ADDI R2, R0, 10   (580A) -> R2 = 10 (0x0A)
        //   Addr 2:  AND  R3, R1, R2   (8D80) -> R3 = 12 & 10 = 8 (0x08)
        //   Addr 3:  OR   R3, R1, R2   (9D80) -> R3 = 12 | 10 = 14 (0x0E)
        //   Addr 4:  XOR  R3, R1, R2   (AD80) -> R3 = 12 ^ 10 = 6 (0x06)
        //   Addr 5:  AND  R3, R1, R0   (8D00) -> R3 = 12 & 0 = 0 (Zero flag=1)
        //   Addr 6:  XOR  R3, R2, R2   (AE80) -> R3 = 10 ^ 10 = 0 (Zero flag=1)
        //   Addr 7:  AND  R1, R1, R2   (8580) -> R1 = 12 & 10 = 8 (Writeback to R1)
        //   Addr 8:  XOR  R2, R1, R2   (A980) -> R2 = 8 ^ 10 = 2 (Writeback to R2)
        //   Addr 9:  AND  R0, R1, R2   (8180) -> R0 write attempt (R0 lock=0)
        //   Addr 10: HALT              (F000) -> Stop processor
        // =====================================================================

        #1; // Settle time-0 initial blocks
        uut.imem_inst.mem[0]  = 16'h540C; // ADDI R1, R0, 12
        uut.imem_inst.mem[1]  = 16'h580A; // ADDI R2, R0, 10
        uut.imem_inst.mem[2]  = 16'h8D80; // AND  R3, R1, R2
        uut.imem_inst.mem[3]  = 16'h9D80; // OR   R3, R1, R2
        uut.imem_inst.mem[4]  = 16'hAD80; // XOR  R3, R1, R2
        uut.imem_inst.mem[5]  = 16'h8D00; // AND  R3, R1, R0 (AND producing zero)
        uut.imem_inst.mem[6]  = 16'hAE80; // XOR  R3, R2, R2 (XOR identical producing zero)
        uut.imem_inst.mem[7]  = 16'h8580; // AND  R1, R1, R2 (Writeback to R1)
        uut.imem_inst.mem[8]  = 16'hA980; // XOR  R2, R1, R2 (Writeback to R2)
        uut.imem_inst.mem[9]  = 16'h8180; // AND  R0, R1, R2 (R0 write protection test)
        uut.imem_inst.mem[10] = 16'hF000; // HALT
        uut.imem_inst.mem[11] = 16'hF000; // Padding
        uut.imem_inst.mem[12] = 16'hF000;
        uut.imem_inst.mem[13] = 16'hF000;
        uut.imem_inst.mem[14] = 16'hF000;
        uut.imem_inst.mem[15] = 16'hF000;

        // Hold reset across 2 clock cycles
        @(posedge clk);
        @(posedge clk);
        #1;
        reset = 0;
        $display("\n--- SUITE 1: Executing Direct Logical Instructions on Datapath ---");

        // Cycle 1: PC=0 -> ADDI R1, R0, 12
        @(negedge clk);
        assert_check(pc_out == 4'd0 && alu_out == 8'd12, "Cycle 1 execution: PC=0, ADDI R1, R0, 12 evaluated");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[1] == 8'd12,  "Cycle 1 writeback: R1 = 12 (0x0C)");
        assert_check(uut.rf_inst.registers[0] == 8'd0,   "Cycle 1: R0 remains 0");

        // Cycle 2: PC=1 -> ADDI R2, R0, 10
        @(negedge clk);
        assert_check(pc_out == 4'd1 && alu_out == 8'd10, "Cycle 2 execution: PC=1, ADDI R2, R0, 10 evaluated");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[2] == 8'd10,  "Cycle 2 writeback: R2 = 10 (0x0A)");
        assert_check(uut.rf_inst.registers[1] == 8'd12,  "Cycle 2: R1 preserved (12)");

        // Cycle 3: PC=2 -> AND R3, R1, R2 (12 & 10 = 8)
        @(negedge clk);
        assert_check(pc_out == 4'd2,                     "Test 1: PC = 2 (AND R3, R1, R2)");
        assert_check(alu_out == 8'd8,                    "Test 1: ALU combinational output 12 & 10 = 8");
        assert_check(zero == 1'b0,                       "Test 1: ALU zero flag is 0 (non-zero result)");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[3] == 8'd8,   "Test 1: Writeback R3 = 8 confirmed");
        assert_check(uut.rf_inst.registers[1] == 8'd12,  "Test 1: Source R1 unmodified (12)");
        assert_check(uut.rf_inst.registers[2] == 8'd10,  "Test 1: Source R2 unmodified (10)");
        assert_check(uut.rf_inst.registers[0] == 8'd0,   "Test 1: R0 unchanged (0)");

        // Cycle 4: PC=3 -> OR R3, R1, R2 (12 | 10 = 14)
        @(negedge clk);
        assert_check(pc_out == 4'd3,                     "Test 2: PC = 3 (OR R3, R1, R2)");
        assert_check(alu_out == 8'd14,                   "Test 2: ALU combinational output 12 | 10 = 14");
        assert_check(zero == 1'b0,                       "Test 2: ALU zero flag is 0");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[3] == 8'd14,  "Test 2: Writeback R3 = 14 confirmed");
        assert_check(uut.rf_inst.registers[1] == 8'd12,  "Test 2: Source R1 unmodified (12)");
        assert_check(uut.rf_inst.registers[2] == 8'd10,  "Test 2: Source R2 unmodified (10)");

        // Cycle 5: PC=4 -> XOR R3, R1, R2 (12 ^ 10 = 6)
        @(negedge clk);
        assert_check(pc_out == 4'd4,                     "Test 3: PC = 4 (XOR R3, R1, R2)");
        assert_check(alu_out == 8'd6,                    "Test 3: ALU combinational output 12 ^ 10 = 6");
        assert_check(zero == 1'b0,                       "Test 3: ALU zero flag is 0");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[3] == 8'd6,   "Test 3: Writeback R3 = 6 confirmed");
        assert_check(uut.rf_inst.registers[1] == 8'd12,  "Test 3: Source R1 unmodified (12)");
        assert_check(uut.rf_inst.registers[2] == 8'd10,  "Test 3: Source R2 unmodified (10)");

        // Cycle 6: PC=5 -> AND R3, R1, R0 (12 & 0 = 0)
        @(negedge clk);
        assert_check(pc_out == 4'd5,                     "Test 4: PC = 5 (AND R3, R1, R0 producing zero)");
        assert_check(alu_out == 8'd0,                    "Test 4: ALU output is zero");
        assert_check(zero == 1'b1,                       "Test 4: ALU zero flag asserted (zero=1)");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[3] == 8'd0,   "Test 4: Writeback R3 = 0 confirmed");

        // Cycle 7: PC=6 -> XOR R3, R2, R2 (10 ^ 10 = 0)
        @(negedge clk);
        assert_check(pc_out == 4'd6,                     "Test 5: PC = 6 (XOR R3, R2, R2 identical operands)");
        assert_check(alu_out == 8'd0,                    "Test 5: ALU output is zero");
        assert_check(zero == 1'b1,                       "Test 5: ALU zero flag asserted (zero=1)");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[3] == 8'd0,   "Test 5: Writeback R3 = 0 confirmed");

        // Cycle 8: PC=7 -> AND R1, R1, R2 (12 & 10 = 8 writeback into R1)
        @(negedge clk);
        assert_check(pc_out == 4'd7,                     "Test 6: PC = 7 (AND R1, R1, R2 writeback to R1)");
        assert_check(alu_out == 8'd8,                    "Test 6: ALU output = 8");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[1] == 8'd8,   "Test 6: Writeback into R1 = 8 confirmed");
        assert_check(uut.rf_inst.registers[2] == 8'd10,  "Test 6: R2 preserved (10)");

        // Cycle 9: PC=8 -> XOR R2, R1, R2 (8 ^ 10 = 2 writeback into R2)
        @(negedge clk);
        assert_check(pc_out == 4'd8,                     "Test 7: PC = 8 (XOR R2, R1, R2 writeback to R2)");
        assert_check(alu_out == 8'd2,                    "Test 7: ALU output = 2 (8 ^ 10 = 2)");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[2] == 8'd2,   "Test 7: Writeback into R2 = 2 confirmed");
        assert_check(uut.rf_inst.registers[1] == 8'd8,   "Test 7: R1 preserved (8)");

        // Cycle 10: PC=9 -> AND R0, R1, R2 (attempt write to R0)
        @(negedge clk);
        assert_check(pc_out == 4'd9,                     "Test 8: PC = 9 (AND R0, R1, R2 write to R0 attempt)");
        @(posedge clk); #1;
        assert_check(uut.rf_inst.registers[0] == 8'd0,   "Test 8: R0 remains 0 (hardwired zero protection verified)");

        // Cycle 11: PC=10 -> HALT
        @(negedge clk);
        assert_check(pc_out == 4'd10,                    "Test 9: PC = 10 reached (HALT instruction)");
        assert_check(halted == 1'b1,                     "Test 9: Signal halted is asserted");
        @(posedge clk); #1;

        // Verify PC hold over 3 subsequent clock cycles
        @(posedge clk); #1;
        assert_check(pc_out == 4'd10 && halted == 1'b1,  "Test 10: Post-HALT Hold Cycle 1 (PC=10, halted=1)");
        @(posedge clk); #1;
        assert_check(pc_out == 4'd10 && halted == 1'b1,  "Test 10: Post-HALT Hold Cycle 2 (PC=10, halted=1)");
        @(posedge clk); #1;
        assert_check(pc_out == 4'd10 && halted == 1'b1,  "Test 10: Post-HALT Hold Cycle 3 (PC=10, halted=1)");

        // =====================================================================
        // SUITE 2: HARDWARE-SOFTWARE CO-VERIFICATION
        // (Executing machine code produced by Anuradha's Python Assembler)
        // =====================================================================
        $display("\n--- SUITE 2: Hardware-Software Co-Verification (simulation/logical_ops_assembled.hex) ---");

        // Re-assert synchronous reset
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        #1;

        // Load assembler output into instruction memory
        $readmemh("simulation/logical_ops_assembled.hex", uut.imem_inst.mem);

        // Deassert reset
        reset = 0;
        cycle_count = 0;

        // Run until halted or timeout (max 20 cycles)
        while (!halted && cycle_count < 20) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        #1;

        $display("Assembled program terminated at cycle %0d with PC = %0d, halted = %0d",
                 cycle_count, pc_out, halted);

        assert_check(halted == 1'b1,                    "Co-Verif: Program reached HALT successfully");
        assert_check(pc_out == 4'd5,                    "Co-Verif: Final PC = 5 (0x05)");
        assert_check(uut.rf_inst.registers[0] == 8'd0,  "Co-Verif: Final R0 = 0");
        assert_check(uut.rf_inst.registers[1] == 8'd12, "Co-Verif: Final R1 = 12 (0x0C)");
        assert_check(uut.rf_inst.registers[2] == 8'd10, "Co-Verif: Final R2 = 10 (0x0A)");
        assert_check(uut.rf_inst.registers[3] == 8'd6,  "Co-Verif: Final R3 = 6 (0x06 from 12 ^ 10)");

        // Hold verification for assembled program
        @(posedge clk); #1;
        assert_check(pc_out == 4'd5 && halted == 1'b1,  "Co-Verif: Post-HALT Hold Cycle 1");
        @(posedge clk); #1;
        assert_check(pc_out == 4'd5 && halted == 1'b1,  "Co-Verif: Post-HALT Hold Cycle 2");

        // =====================================================================
        // FINAL SUMMARY REPORT
        // =====================================================================
        $display("\n==================================================================");
        $display("   LOGICAL OPERATIONS VERIFICATION SUMMARY");
        $display("==================================================================");
        $display("  Total Checks Passed : %0d", passed_checks);
        $display("  Total Checks Failed : %0d", failed_checks);
        $display("==================================================================");

        if (failed_checks == 0) begin
            $display(">>> ALL LOGICAL OPERATIONS & CO-VERIFICATION TESTS PASSED! <<<");
        end else begin
            $display(">>> TEST SUITE FAILED WITH %0d ERRORS! <<<", failed_checks);
        end
        $display("==================================================================\n");

        $finish;
    end

endmodule
