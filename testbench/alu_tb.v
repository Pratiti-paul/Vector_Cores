
`timescale 1ns/1ps

module alu_tb;

    reg [7:0] alu_in1;
    reg [7:0] alu_in2;
    reg [1:0] alu_control;

    wire [7:0] alu_out;
    wire zero;

    integer passed;
    integer failed;

    // Instantiate ALU
    alu uut (
        .alu_in1(alu_in1),
        .alu_in2(alu_in2),
        .alu_control(alu_control),
        .alu_out(alu_out),
        .zero(zero)
    );

    // Self-checking task
    task check_result;
        input [7:0] expected_out;
        input expected_zero;
        input [8*40-1:0] test_name;

        begin
            #10;

            if (alu_out === expected_out &&
                zero === expected_zero) begin

                $display("PASS: %s | Output=%h | Zero=%b",
                         test_name, alu_out, zero);
                passed = passed + 1;

            end
            else begin

                $display("FAIL: %s | Expected=%h, Got=%h | Expected Zero=%b, Got=%b",
                         test_name, expected_out, alu_out,
                         expected_zero, zero);
                failed = failed + 1;

            end
        end
    endtask

    initial begin

        passed = 0;
        failed = 0;

        $display("--------------------------------------");
        $display("       ALU SELF-CHECKING TESTBENCH");
        $display("--------------------------------------");

        // Test 1: Addition
        alu_in1 = 8'd5;
        alu_in2 = 8'd3;
        alu_control = 2'b00;
        check_result(8'd8, 1'b0, "ADD: 5 + 3");

        // Test 2: Subtraction
        alu_in1 = 8'd8;
        alu_in2 = 8'd3;
        alu_control = 2'b01;
        check_result(8'd5, 1'b0, "SUB: 8 - 3");

        // Test 3: Zero result
        alu_in1 = 8'd5;
        alu_in2 = 8'd5;
        alu_control = 2'b01;
        check_result(8'd0, 1'b1, "SUB: 5 - 5");

        // Test 4: Addition overflow
        alu_in1 = 8'hFF;
        alu_in2 = 8'h01;
        alu_control = 2'b00;
        check_result(8'h00, 1'b1, "ADD: 255 + 1");

        // Test 5: Subtraction underflow
        alu_in1 = 8'd3;
        alu_in2 = 8'd5;
        alu_control = 2'b01;
        check_result(8'hFE, 1'b0, "SUB: 3 - 5");

        // Test 6: Addition with zero
        alu_in1 = 8'd0;
        alu_in2 = 8'd0;
        alu_control = 2'b00;
        check_result(8'd0, 1'b1, "ADD: 0 + 0");

        // Test 7: Maximum addition without overflow
        alu_in1 = 8'd100;
        alu_in2 = 8'd100;
        alu_control = 2'b00;
        check_result(8'd200, 1'b0, "ADD: 100 + 100");

        $display("--------------------------------------");
        $display("TOTAL PASSED: %0d", passed);
        $display("TOTAL FAILED: %0d", failed);
        $display("--------------------------------------");

        if (failed == 0)
            $display("ALL ALU TESTS PASSED!");
        else
            $display("ALU TESTING FAILED!");

        $finish;

    end

endmodule

