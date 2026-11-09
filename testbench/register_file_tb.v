`timescale 1ns/1ps

module register_file_tb;

    reg clk, reset, reg_write;
    reg [1:0] read_reg1, read_reg2, write_reg;
    reg [7:0] write_data;

    wire [7:0] read_data1, read_data2;

    integer passed, failed;

    register_file uut (
        .clk(clk),
        .reset(reset),
        .reg_write(reg_write),
        .read_reg1(read_reg1),
        .read_reg2(read_reg2),
        .write_reg(write_reg),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    always #5 clk = ~clk;

    task check;
        input [7:0] expected1, expected2;
        input [8*40-1:0] test_name;
        begin
            #1;
            if (read_data1 === expected1 && read_data2 === expected2) begin
                $display("PASS: %s", test_name);
                passed = passed + 1;
            end
            else begin
                $display("FAIL: %s | Expected: %h, %h | Got: %h, %h",
                    test_name, expected1, expected2, read_data1, read_data2);
                failed = failed + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 0;
        reg_write = 0;
        read_reg1 = 0;
        read_reg2 = 0;
        write_reg = 0;
        write_data = 0;
        passed = 0;
        failed = 0;

        $display("--------------------------------");
        $display(" REGISTER FILE TESTBENCH");
        $display("--------------------------------");

        // Reset all registers
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;

        // Test R0
        read_reg1 = 0;
        read_reg2 = 0;
        check(8'd0, 8'd0, "R0 always reads zero");

        // Write 10 into R1
        @(negedge clk);
        write_reg = 1;
        write_data = 10;
        reg_write = 1;
        @(posedge clk);
        #1;
        reg_write = 0;
        read_reg1 = 1;
        read_reg2 = 0;
        check(8'd10, 8'd0, "Write and read R1");

        // Write 20 into R2
        @(negedge clk);
        write_reg = 2;
        write_data = 20;
        reg_write = 1;
        @(posedge clk);
        #1;
        reg_write = 0;
        read_reg1 = 1;
        read_reg2 = 2;
        check(8'd10, 8'd20, "Read R1 and R2");

        // Write 30 into R3
        @(negedge clk);
        write_reg = 3;
        write_data = 30;
        reg_write = 1;
        @(posedge clk);
        #1;
        reg_write = 0;
        read_reg1 = 2;
        read_reg2 = 3;
        check(8'd20, 8'd30, "Write and read R3");

        // Verify R0 cannot be overwritten
        @(negedge clk);
        write_reg = 0;
        write_data = 99;
        reg_write = 1;
        @(posedge clk);
        #1;
        reg_write = 0;
        read_reg1 = 0;
        read_reg2 = 1;
        check(8'd0, 8'd10, "R0 write protection");

        // Verify writing disabled
        @(negedge clk);
        write_reg = 1;
        write_data = 99;
        reg_write = 0;
        @(posedge clk);
        #1;
        read_reg1 = 1;
        read_reg2 = 2;
        check(8'd10, 8'd20, "No write when disabled");

        $display("--------------------------------");
        $display("TOTAL PASSED: %0d", passed);
        $display("TOTAL FAILED: %0d", failed);
        $display("--------------------------------");

        if (failed == 0)
            $display("ALL REGISTER FILE TESTS PASSED!");
        else
            $display("REGISTER FILE TESTING FAILED!");

        $finish;
    end

endmodule
