`timescale 1ns/1ps

module instruction_memory_tb;

    reg  [3:0]  addr;
    wire [15:0] instr;
    integer i, errors;
    reg [15:0] expected [0:15];

    instruction_memory uut (.addr(addr), .instr(instr));

    initial begin
        $dumpfile("instruction_memory.vcd");
        $dumpvars(0, instruction_memory_tb);
        errors = 0;
        $readmemh("program.hex", expected);

        $display("Starting Instruction Memory Tests");

        // Test 1: read every location
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #10;
            if (instr !== expected[i]) begin
                $display("FAIL addr=%0d instr=%h expected=%h", i, instr, expected[i]);
                errors = errors + 1;
            end else
                $display("PASS addr=%0d instr=%h opcode=%b rd=%0d rs=%0d imm=%0d",
                          i, instr, instr[15:12], instr[11:10], instr[9:8], instr[7:0]);
        end

        // Test 2: boundary / non-sequential jumps (combinational read)
        addr = 4'd0;  #10; if (instr !== expected[0])  errors = errors + 1;
        addr = 4'd15; #10; if (instr !== expected[15]) errors = errors + 1;
        addr = 4'd5;  #10; if (instr !== expected[5])  errors = errors + 1;

        // Test 3: unused locations must be HALT
        for (i = 8; i < 16; i = i + 1) begin
            addr = i; #10;
            if (instr[15:12] !== 4'b1111) begin
                $display("FAIL addr=%0d not HALT", i);
                errors = errors + 1;
            end
        end

        // Test 4: opcodes present in program
        $display("Opcode check: ADDI@0=%b ADD@2=%b STORE@3=%b SUB@4=%b LOAD@5=%b HALT@7=%b",
                  expected[0][15:12], expected[2][15:12], expected[3][15:12],
                  expected[4][15:12], expected[5][15:12], expected[7][15:12]);

        if (errors == 0) $display("ALL INSTRUCTION MEMORY TESTS PASSED");
        else             $display("%0d INSTRUCTION MEMORY TESTS FAILED", errors);

        $finish;
    end

endmodule