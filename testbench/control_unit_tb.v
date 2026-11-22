
`timescale 1ns/1ps

module control_unit_tb;

    reg [3:0] opcode;

    wire pc_enable;
    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire [2:0] alu_control;
    wire alu_src;
    wire mem_to_reg;
    wire branch_enable;
    wire jump_enable;
    wire halted;

    integer passed;
    integer failed;

    control_unit uut (
        .opcode(opcode),
        .pc_enable(pc_enable),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_control(alu_control),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .branch_enable(branch_enable),
        .jump_enable(jump_enable),
        .halted(halted)
    );

    task check_instruction;
        input [3:0] test_opcode;
        input [127:0] instruction_name;
        input expected_pc_enable;
        input expected_reg_write;
        input expected_mem_read;
        input expected_mem_write;
        input [2:0] expected_alu_control;
        input expected_alu_src;
        input expected_mem_to_reg;
        input expected_branch_enable;
        input expected_jump_enable;
        input expected_halted;
        integer failures_before;
        begin
            opcode = test_opcode;
            #1;
            failures_before = failed;

            if (pc_enable !== expected_pc_enable) begin
                $display("FAIL %s: pc_enable expected %b, got %b",
                         instruction_name, expected_pc_enable, pc_enable);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (reg_write !== expected_reg_write) begin
                $display("FAIL %s: reg_write expected %b, got %b",
                         instruction_name, expected_reg_write, reg_write);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (mem_read !== expected_mem_read) begin
                $display("FAIL %s: mem_read expected %b, got %b",
                         instruction_name, expected_mem_read, mem_read);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (mem_write !== expected_mem_write) begin
                $display("FAIL %s: mem_write expected %b, got %b",
                         instruction_name, expected_mem_write, mem_write);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (alu_control !== expected_alu_control) begin
                $display("FAIL %s: alu_control expected %b, got %b",
                         instruction_name, expected_alu_control, alu_control);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (alu_src !== expected_alu_src) begin
                $display("FAIL %s: alu_src expected %b, got %b",
                         instruction_name, expected_alu_src, alu_src);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (mem_to_reg !== expected_mem_to_reg) begin
                $display("FAIL %s: mem_to_reg expected %b, got %b",
                         instruction_name, expected_mem_to_reg, mem_to_reg);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (branch_enable !== expected_branch_enable) begin
                $display("FAIL %s: branch_enable expected %b, got %b",
                         instruction_name, expected_branch_enable, branch_enable);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (jump_enable !== expected_jump_enable) begin
                $display("FAIL %s: jump_enable expected %b, got %b",
                         instruction_name, expected_jump_enable, jump_enable);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end
            if (halted !== expected_halted) begin
                $display("FAIL %s: halted expected %b, got %b",
                         instruction_name, expected_halted, halted);
                failed = failed + 1;
            end else begin
                passed = passed + 1;
            end

            if (failed == failures_before) begin
                $display("PASS %s", instruction_name);
            end
        end
    endtask

    initial begin
        passed = 0;
        failed = 0;
        $display("Starting Control Unit Tests");

        check_instruction(4'b0001, "LOAD",  1'b1, 1'b1, 1'b1, 1'b0,
                          3'b000, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b0010, "STORE", 1'b1, 1'b0, 1'b0, 1'b1,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b0011, "ADD",   1'b1, 1'b1, 1'b0, 1'b0,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b0100, "SUB",   1'b1, 1'b1, 1'b0, 1'b0,
                          3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b0101, "ADDI",  1'b1, 1'b1, 1'b0, 1'b0,
                          3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b0110, "BEQ",   1'b1, 1'b0, 1'b0, 1'b0,
                          3'b001, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        check_instruction(4'b0111, "JUMP",  1'b1, 1'b0, 1'b0, 1'b0,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        check_instruction(4'b1000, "AND",   1'b1, 1'b1, 1'b0, 1'b0,
                          3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b1001, "OR",    1'b1, 1'b1, 1'b0, 1'b0,
                          3'b011, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b1010, "XOR",   1'b1, 1'b1, 1'b0, 1'b0,
                          3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b1111, "HALT",  1'b0, 1'b0, 1'b0, 1'b0,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);

        check_instruction(4'b0000, "INVALID_0", 1'b0, 1'b0, 1'b0, 1'b0,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check_instruction(4'b1011, "INVALID_B", 1'b0, 1'b0, 1'b0, 1'b0,
                          3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        $display("Control Unit Tests Completed");
        $display("Total checks passed: %0d", passed);
        $display("Total checks failed: %0d", failed);

        $finish;

    end

endmodule
