`timescale 1ns/1ps
// Control Unit Self-Checking Testbench
//
// The control unit is purely combinational. For every opcode the testbench
// compares ALL eleven outputs against a reference decode table and reports
// each mismatching signal by name.
//
// Tests:
//   C1  Forward sweep of all 16 opcodes (0000 -> 1111)
//   C2  Reverse sweep of all 16 opcodes (1111 -> 0000), so every opcode is
//       entered from a different previous opcode (catches latched outputs)
//
// Reference decode table:
//   opcode  instr    pc_en reg_wr mem_rd mem_wr alu  src m2r br  jmp halt
//   0001    LOAD       1     1      1      0    000   0   1   0   0   0
//   0010    STORE      1     0      0      1    000   0   0   0   0   0
//   0011    ADD        1     1      0      0    000   0   0   0   0   0
//   0100    SUB        1     1      0      0    001   0   0   0   0   0
//   0101    ADDI       1     1      0      0    000   1   0   0   0   0
//   0110    BEQ        1     0      0      0    001   0   0   1   0   0
//   0111    JUMP       1     0      0      0    000   0   0   0   1   0
//   1000    AND        1     1      0      0    010   0   0   0   0   0
//   1001    OR         1     1      0      0    011   0   0   0   0   0
//   1010    XOR        1     1      0      0    100   0   0   0   0   0
//   1111    HALT       0     0      0      0    000   0   0   0   0   1
//   other   invalid    0     0      0      0    000   0   0   0   0   0
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

    // Packed output vector, MSB first:
    // {pc_enable, reg_write, mem_read, mem_write, alu_control[2:0],
    //  alu_src, mem_to_reg, branch_enable, jump_enable, halted}
    wire [11:0] actual = {pc_enable, reg_write, mem_read, mem_write, alu_control,
                          alu_src, mem_to_reg, branch_enable, jump_enable, halted};

    integer pass_count;
    integer fail_count;
    integer k;

    // Reference model
    function [11:0] expected_ctrl;
        input [3:0] op;
        begin
            case (op)
                //                     pc rw mr mw  alu    src m2r br jmp halt
                4'b0001: expected_ctrl = {1'b1,1'b1,1'b1,1'b0,3'b000,1'b0,1'b1,1'b0,1'b0,1'b0}; // LOAD
                4'b0010: expected_ctrl = {1'b1,1'b0,1'b0,1'b1,3'b000,1'b0,1'b0,1'b0,1'b0,1'b0}; // STORE
                4'b0011: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b000,1'b0,1'b0,1'b0,1'b0,1'b0}; // ADD
                4'b0100: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b001,1'b0,1'b0,1'b0,1'b0,1'b0}; // SUB
                4'b0101: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b000,1'b1,1'b0,1'b0,1'b0,1'b0}; // ADDI
                4'b0110: expected_ctrl = {1'b1,1'b0,1'b0,1'b0,3'b001,1'b0,1'b0,1'b1,1'b0,1'b0}; // BEQ
                4'b0111: expected_ctrl = {1'b1,1'b0,1'b0,1'b0,3'b000,1'b0,1'b0,1'b0,1'b1,1'b0}; // JUMP
                4'b1000: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b010,1'b0,1'b0,1'b0,1'b0,1'b0}; // AND
                4'b1001: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b011,1'b0,1'b0,1'b0,1'b0,1'b0}; // OR
                4'b1010: expected_ctrl = {1'b1,1'b1,1'b0,1'b0,3'b100,1'b0,1'b0,1'b0,1'b0,1'b0}; // XOR
                4'b1111: expected_ctrl = {1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,1'b0,1'b0,1'b0,1'b1}; // HALT
                default: expected_ctrl = {1'b0,1'b0,1'b0,1'b0,3'b000,1'b0,1'b0,1'b0,1'b0,1'b0}; // invalid
            endcase
        end
    endfunction

    function [8*7-1:0] op_name;
        input [3:0] op;
        begin
            case (op)
                4'b0001: op_name = "LOAD";
                4'b0010: op_name = "STORE";
                4'b0011: op_name = "ADD";
                4'b0100: op_name = "SUB";
                4'b0101: op_name = "ADDI";
                4'b0110: op_name = "BEQ";
                4'b0111: op_name = "JUMP";
                4'b1000: op_name = "AND";
                4'b1001: op_name = "OR";
                4'b1010: op_name = "XOR";
                4'b1111: op_name = "HALT";
                default: op_name = "invalid";
            endcase
        end
    endfunction

    // Apply an opcode and compare every output with the reference table
    task check_opcode;
        input [3:0]      op;
        input [8*3-1:0]  tag;
        reg   [11:0]     exp;
        begin
            opcode = op;
            #10;
            exp = expected_ctrl(op);
            if (actual === exp) begin
                $display("PASS %0s opcode=%b %-7s pc_en=%b reg_wr=%b mem_rd=%b mem_wr=%b alu=%b src=%b m2r=%b br=%b jmp=%b halt=%b",
                         tag, op, op_name(op), pc_enable, reg_write, mem_read, mem_write,
                         alu_control, alu_src, mem_to_reg, branch_enable, jump_enable, halted);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL %0s opcode=%b %0s", tag, op, op_name(op));
                if (actual[11]    !== exp[11])    $display("       pc_enable     = %b (expected %b)", actual[11], exp[11]);
                if (actual[10]    !== exp[10])    $display("       reg_write     = %b (expected %b)", actual[10], exp[10]);
                if (actual[9]    !== exp[9])    $display("       mem_read      = %b (expected %b)", actual[9], exp[9]);
                if (actual[8]    !== exp[8])    $display("       mem_write     = %b (expected %b)", actual[8], exp[8]);
                if (actual[7:5]   !== exp[7:5])   $display("       alu_control   = %b (expected %b)", actual[7:5], exp[7:5]);
                if (actual[4]     !== exp[4])     $display("       alu_src       = %b (expected %b)", actual[4], exp[4]);
                if (actual[3]     !== exp[3])     $display("       mem_to_reg    = %b (expected %b)", actual[3], exp[3]);
                if (actual[2]     !== exp[2])     $display("       branch_enable = %b (expected %b)", actual[2], exp[2]);
                if (actual[1]     !== exp[1])     $display("       jump_enable   = %b (expected %b)", actual[1], exp[1]);
                if (actual[0]   !== exp[0])   $display("       halted        = %b (expected %b)", actual[0], exp[0]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);

        pass_count = 0;
        fail_count = 0;
        opcode     = 4'b0000;

        $display("Starting Control Unit Tests");

        // C1: forward sweep
        $display("--- C1: forward sweep of all 16 opcodes ---");
        for (k = 0; k < 16; k = k + 1)
            check_opcode(k[3:0], "C1");

        // C2: reverse sweep
        $display("--- C2: reverse sweep of all 16 opcodes ---");
        for (k = 15; k >= 0; k = k - 1)
            check_opcode(k[3:0], "C2");

        $display("Control Unit Checks Passed: %0d", pass_count);
        $display("Control Unit Checks Failed: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL CONTROL UNIT TESTS PASSED");
        else
            $display("SOME CONTROL UNIT TESTS FAILED");

        $finish;
    end

endmodule
