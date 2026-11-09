// Full Processor Verification Testbench
// Member 5: Verification, Waveform Analysis, and System-Level Testing
//
// Verifies end-to-end execution of the single-cycle Harvard Architecture processor
// executing the standard verification program loaded from 'program.hex'.
//
// Program Trace:
//   Addr 0x0: 5405 -> ADDI R1, R0, 5  (R1 = 5)
//   Addr 0x1: 5803 -> ADDI R2, R0, 3  (R2 = 3)
//   Addr 0x2: 3580 -> ADD  R1, R1, R2 (R1 = 8)
//   Addr 0x3: 2480 -> STORE R1, [2]   (DMEM[2] = 8)
//   Addr 0x4: 4580 -> SUB  R1, R1, R2 (R1 = 5)
//   Addr 0x5: 1C80 -> LOAD R3, [2]    (R3 = 8)
//   Addr 0x6: 5F01 -> ADDI R3, R3, 1  (R3 = 9)
//   Addr 0x7: F000 -> HALT            (PC freezes at 7, halted = 1)
//
// Expected Final State:
//   R0 = 0, R1 = 5, R2 = 3, R3 = 9, DMEM[2] = 8, PC = 7, halted = 1

`timescale 1ns/1ps

module processor_tb;

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

    // Instantiate the single-cycle Harvard processor
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

    // Clock generation: 10 ns clock period (100 MHz)
    always #5 clk = ~clk;

    // Helper task to check assertions
    task assert_equal;
        input [31:0] actual;
        input [31:0] expected;
        input [8*60-1:0] signal_name;
        begin
            if (actual === expected) begin
                $display("  [PASS] %0s = %0d (0x%h)", signal_name, actual, actual);
                passed_checks = passed_checks + 1;
            end else begin
                $display("  [FAIL] %0s: expected %0d (0x%h), got %0d (0x%h)",
                         signal_name, expected, expected, actual, actual);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("processor.vcd");
        $dumpvars(0, processor_tb);

        clk           = 0;
        reset         = 1;
        cycle_count   = 0;
        errors        = 0;
        passed_checks = 0;
        timeout       = 0;

        $display("==================================================================");
        $display("      VECTOR CORES: FULL PROCESSOR INTEGRATION TESTBENCH");
        $display("==================================================================");

        // Hold active-high reset for 2 clock cycles
        #20;
        @(negedge clk);
        reset = 0;
        $display("Time=%0t ns: Synchronous reset released. Beginning execution...", $time);
        $display("------------------------------------------------------------------");

        // Execute instructions and trace cycle-by-cycle execution
        while (!halted && cycle_count < 50) begin
            @(posedge clk);
            #1; // Sample shortly after rising edge
            cycle_count = cycle_count + 1;

            $display("Cycle %02d | Time=%0t ns | PC=%02d (0x%h) | Instr=%h | ALU_Out=%h | WriteData=%h | Zero=%b | Halted=%b",
                     cycle_count, $time, pc_out, pc_out, instr, alu_out, write_data, zero, halted);
        end

        // Check for simulation timeout
        if (cycle_count >= 50 && !halted) begin
            $display("\n[ERROR] Simulation timed out after %0d cycles without asserting HALT!", cycle_count);
            errors = errors + 1;
            timeout = 1;
        end else begin
            $display("\nTime=%0t ns: HALT signal detected after %0d execution cycles.", $time, cycle_count);
        end

        // Allow 3 additional clock cycles to verify PC freeze and write inhibition
        $display("Observing post-halt hold behavior for 3 cycles...");
        repeat (3) begin
            @(posedge clk);
            #1;
            if (pc_out !== 4'd7) begin
                $display("  [FAIL] Post-halt PC drift detected! PC=%0d (expected 7)", pc_out);
                errors = errors + 1;
            end
            if (halted !== 1'b1) begin
                $display("  [FAIL] Post-halt 'halted' flag deasserted unexpectedly!");
                errors = errors + 1;
            end
        end

        // =====================================================================
        // Final Architectural State Verification
        // =====================================================================
        $display("\n------------------------------------------------------------------");
        $display("           FINAL ARCHITECTURAL STATE VERIFICATION");
        $display("------------------------------------------------------------------");

        assert_equal(pc_out, 4'd7, "Program Counter (PC)");
        assert_equal(halted, 1'b1, "Halted Signal");
        assert_equal(uut.rf_inst.registers[0], 8'd0, "Register R0 (constant zero)");
        assert_equal(uut.rf_inst.registers[1], 8'd5, "Register R1 (final result)");
        assert_equal(uut.rf_inst.registers[2], 8'd3, "Register R2 (final result)");
        assert_equal(uut.rf_inst.registers[3], 8'd9, "Register R3 (final result)");
        assert_equal(uut.dmem_inst.mem[2],     8'd8, "Data Memory DMEM[2]");

        $display("------------------------------------------------------------------");
        $display("Total Assertions Passed: %0d", passed_checks);
        $display("Total Assertions Failed: %0d", errors);
        $display("==================================================================");

        if (errors == 0 && !timeout) begin
            $display(">>> ALL FULL-PROCESSOR INTEGRATION TESTS PASSED SUCCESSFULLY! <<<");
            $display("==================================================================\n");
        end else begin
            $display(">>> FULL-PROCESSOR INTEGRATION TESTS FAILED! (%0d errors) <<<", errors);
            $display("==================================================================\n");
        end

        $finish;
    end

endmodule