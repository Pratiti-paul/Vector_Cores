
`timescale 1ns/1ps

module alu_tb;

    reg [7:0] alu_in1;
    reg [7:0] alu_in2;
    reg [2:0] alu_control;

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
        alu_control = 3'b000;
        check_result(8'd8, 1'b0, "ADD: 5 + 3");

        // Test 2: Subtraction
        alu_in1 = 8'd8;
        alu_in2 = 8'd3;
        alu_control = 3'b001;
        check_result(8'd5, 1'b0, "SUB: 8 - 3");

        // Test 3: Zero result
        alu_in1 = 8'd5;
        alu_in2 = 8'd5;
        alu_control = 3'b001;
        check_result(8'd0, 1'b1, "SUB: 5 - 5");

        // Test 4: Addition overflow
        alu_in1 = 8'hFF;
        alu_in2 = 8'h01;
        alu_control = 3'b000;
        check_result(8'h00, 1'b1, "ADD: 255 + 1");

        // Test 5: Subtraction underflow
        alu_in1 = 8'd3;
        alu_in2 = 8'd5;
        alu_control = 3'b001;
        check_result(8'hFE, 1'b0, "SUB: 3 - 5");

        // Test 6: Addition with zero
        alu_in1 = 8'd0;
        alu_in2 = 8'd0;
        alu_control = 3'b000;
        check_result(8'd0, 1'b1, "ADD: 0 + 0");

        // Test 7: Maximum addition without overflow
        alu_in1 = 8'd100;
        alu_in2 = 8'd100;
        alu_control = 3'b000;
        check_result(8'd200, 1'b0, "ADD: 100 + 100");

        // Test 8: Bitwise AND
        alu_in1 = 8'b11001100;
        alu_in2 = 8'b10101010;
        alu_control = 3'b010;
        check_result(8'b10001000, 1'b0, "AND: CC & AA");

        // Test 9: AND producing zero
        alu_in1 = 8'hF0;
        alu_in2 = 8'h0F;
        alu_control = 3'b010;
        check_result(8'h00, 1'b1, "AND: F0 & 0F");

        // Test 10: Bitwise OR
        alu_in1 = 8'b11001100;
        alu_in2 = 8'b10101010;
        alu_control = 3'b011;
        check_result(8'b11101110, 1'b0, "OR: CC | AA");

        // Test 11: OR with zero operands
        alu_in1 = 8'h00;
        alu_in2 = 8'h00;
        alu_control = 3'b011;
        check_result(8'h00, 1'b1, "OR: 00 | 00");

        // Test 12: Bitwise XOR
        alu_in1 = 8'b11001100;
        alu_in2 = 8'b10101010;
        alu_control = 3'b100;
        check_result(8'b01100110, 1'b0, "XOR: CC ^ AA");

        // Test 13: XOR of equal operands
        alu_in1 = 8'h5A;
        alu_in2 = 8'h5A;
        alu_control = 3'b100;
        check_result(8'h00, 1'b1, "XOR: 5A ^ 5A");

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

