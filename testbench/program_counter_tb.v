`timescale 1ns/1ps
// Program Counter Self-Checking Testbench
//
// Inputs are driven on the falling edge and pc_out is checked 1 ns after
// the rising edge, so every check sees the value registered by that edge.
//
// Tests:
//   P1  Reset loads 0
//   P2  Sequential update (pc_next = 1, then 2)
//   P3  Jump to a non-sequential address (10)
//   P4  Hold: pc_enable = 0 keeps the PC, even when pc_next changes
//   P5  Resume after hold
//   P6  Every 4-bit address can be loaded (0-15)
//   P7  Wraparound 15 -> 0
//   P8  Reset is synchronous: no change until the next rising edge
//   P9  Reset has priority over pc_enable
//   P10 Reset works while pc_enable = 0 (during hold)
//   P11 PC stays at 0 for consecutive reset cycles, then resumes
module program_counter_tb;

    reg clk;
    reg reset;
    reg pc_enable;
    reg [3:0] pc_next;

    wire [3:0] pc_out;

    // Instantiate Program Counter
    program_counter uut (
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .pc_next(pc_next),
        .pc_out(pc_out)
    );

    // Generate clock (10 ns period, rising edges at 5, 15, 25, ...)
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;
    integer k;

    task check;
        input [3:0]   expected;
        input [8*48-1:0] name;   // up to 48 characters
        begin
            if (pc_out === expected) begin
                $display("PASS %0s: PC = %0d", name, pc_out);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL %0s: PC = %0d (expected %0d)", name, pc_out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Drive inputs on the falling edge, then sample just after the rising edge
    task step;
        input       rst;
        input       en;
        input [3:0] nxt;
        begin
            @(negedge clk);
            reset     = rst;
            pc_enable = en;
            pc_next   = nxt;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("program_counter.vcd");
        $dumpvars(0, program_counter_tb);

        clk        = 0;
        reset      = 1;
        pc_enable  = 0;
        pc_next    = 0;
        pass_count = 0;
        fail_count = 0;

        $display("Starting Program Counter Tests");

        // P1: reset
        @(posedge clk); #1;
        check(4'd0, "P1 reset");

        // P2: sequential update
        step(0, 1, 4'd1);  check(4'd1, "P2 sequential update to 1");
        step(0, 1, 4'd2);  check(4'd2, "P2 sequential update to 2");

        // P3: jump
        step(0, 1, 4'd10); check(4'd10, "P3 jump to 10");

        // P4: hold, including a changing pc_next
        step(0, 0, 4'd10); check(4'd10, "P4 hold (pc_next unchanged)");
        step(0, 0, 4'd3);  check(4'd10, "P4 hold (pc_next = 3 ignored)");
        step(0, 0, 4'd15); check(4'd10, "P4 hold (pc_next = 15 ignored)");

        // P5: resume after hold
        step(0, 1, 4'd11); check(4'd11, "P5 resume after hold");

        // P6: every address can be loaded
        for (k = 0; k < 16; k = k + 1) begin
            step(0, 1, k[3:0]);
            check(k[3:0], "P6 load address");
        end

        // P7: wraparound 15 -> 0 (PC is at 15 after P6)
        step(0, 1, pc_out + 4'd1); check(4'd0, "P7 wraparound 15 -> 0");

        // P8: synchronous reset - set PC to 7, assert reset between edges
        step(0, 1, 4'd7);  check(4'd7, "P8 setup PC = 7");
        @(negedge clk);
        reset = 1; pc_enable = 1; pc_next = 4'd9;
        #2;                check(4'd7, "P8 no change before rising edge");
        @(posedge clk); #1;
        check(4'd0, "P8 reset takes effect on rising edge");

        // P9: reset has priority over pc_enable
        step(0, 1, 4'd12); check(4'd12, "P9 setup PC = 12");
        step(1, 1, 4'd5);  check(4'd0, "P9 reset overrides pc_enable");

        // P10: reset during hold
        step(0, 1, 4'd6);  check(4'd6, "P10 setup PC = 6");
        step(1, 0, 4'd6);  check(4'd0, "P10 reset while pc_enable = 0");

        // P11: consecutive reset cycles, then resume
        step(1, 1, 4'd4);  check(4'd0, "P11 reset cycle 1");
        step(1, 1, 4'd8);  check(4'd0, "P11 reset cycle 2");
        step(0, 1, 4'd1);  check(4'd1, "P11 resume after reset");

        $display("Program Counter Checks Passed: %0d", pass_count);
        $display("Program Counter Checks Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL PROGRAM COUNTER TESTS PASSED");
        else
            $display("SOME PROGRAM COUNTER TESTS FAILED");

        $finish;
    end

endmodule
