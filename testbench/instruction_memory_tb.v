`timescale 1ns/1ps

module instruction_memory_tb;

    reg  [3:0]  addr;
    wire [15:0] instr;
    integer i, errors;
    reg [15:0] expected [0:15];
    reg [15:0] w;

    instruction_memory uut (.addr(addr), .instr(instr));

    initial begin
        $dumpfile("instruction_memory.vcd");
        $dumpvars(0, instruction_memory_tb);
        errors = 0;
        $readmemh("program.hex", expected);

        $display("Starting Instruction Memory Tests");

        // Test 1: read every location and compare with program.hex
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #10;
            if (instr !== expected[i]) begin
                $display("FAIL addr=%0d instr=%h expected=%h", i, instr, expected[i]);
                errors = errors + 1;
            end else
                $display("PASS addr=%0d instr=%h", i, instr);
        end

        // Test 2: boundary / non-sequential addresses (combinational read)
        addr = 4'd0;  #10; if (instr !== expected[0])  errors = errors + 1;
        addr = 4'd15; #10; if (instr !== expected[15]) errors = errors + 1;
        addr = 4'd5;  #10; if (instr !== expected[5])  errors = errors + 1;

        // Test 3: unused locations must be HALT
        for (i = 8; i < 16; i = i + 1) begin
            addr = i; #10;
            if (instr !== 16'hF000) begin
                $display("FAIL addr=%0d not HALT", i);
                errors = errors + 1;
            end
        end

        // Test 4: decode every fetched instruction with the agreed format
        //         and check that all unused bits are zero
        $display("--- Instruction format check ---");
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #10; w = instr;
            case (w[15:12])
                4'b0001: begin
                    $display("addr=%0d LOAD  rd=R%0d, [%0d]", i, w[11:10], w[9:6]);
                    if (w[5:0] !== 6'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                4'b0010: begin
                    $display("addr=%0d STORE rs=R%0d, [%0d]", i, w[11:10], w[9:6]);
                    if (w[5:0] !== 6'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                4'b0011: begin
                    $display("addr=%0d ADD   rd=R%0d, rs=R%0d, rt=R%0d", i, w[11:10], w[9:8], w[7:6]);
                    if (w[5:0] !== 6'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                4'b0100: begin
                    $display("addr=%0d SUB   rd=R%0d, rs=R%0d, rt=R%0d", i, w[11:10], w[9:8], w[7:6]);
                    if (w[5:0] !== 6'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                4'b0101: $display("addr=%0d ADDI  rd=R%0d, rs=R%0d, imm=%0d", i, w[11:10], w[9:8], $signed(w[7:0]));
                4'b0110: $display("addr=%0d BEQ   rs=R%0d, rt=R%0d, offset=%0d", i, w[11:10], w[9:8], $signed(w[7:0]));
                4'b0111: begin
                    $display("addr=%0d JUMP  [%0d]", i, w[3:0]);
                    if (w[11:4] !== 8'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                4'b1111: begin
                    if (i < 8 || i == 15) $display("addr=%0d HALT", i);
                    if (w[11:0] !== 12'b0) begin $display("FAIL unused bits"); errors = errors + 1; end
                end
                default: begin $display("FAIL addr=%0d invalid opcode", i); errors = errors + 1; end
            endcase
        end

        if (errors == 0) $display("ALL INSTRUCTION MEMORY TESTS PASSED");
        else             $display("%0d INSTRUCTION MEMORY TESTS FAILED", errors);

        $finish;
    end

endmodule