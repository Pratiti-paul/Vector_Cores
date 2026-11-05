
`timescale 1ns/1ps

module control_unit_tb;

    reg [3:0] opcode;

    wire pc_enable;
    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire [1:0] alu_control;
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

    initial begin

        $display("Starting Control Unit Tests");

        opcode = 4'b0001; #10;
        $display("LOAD: reg_write=%b mem_read=%b mem_to_reg=%b",
                  reg_write, mem_read, mem_to_reg);

        opcode = 4'b0010; #10;
        $display("STORE: mem_write=%b", mem_write);

        opcode = 4'b0011; #10;
        $display("ADD: reg_write=%b alu_control=%b",
                  reg_write, alu_control);

        opcode = 4'b0100; #10;
        $display("SUB: reg_write=%b alu_control=%b",
                  reg_write, alu_control);

        opcode = 4'b0101; #10;
        $display("ADDI: reg_write=%b alu_src=%b",
                  reg_write, alu_src);

        opcode = 4'b0110; #10;
        $display("BEQ: branch_enable=%b", branch_enable);

        opcode = 4'b0111; #10;
        $display("JUMP: jump_enable=%b", jump_enable);

        opcode = 4'b1111; #10;
        $display("HALT: pc_enable=%b halted=%b",
                  pc_enable, halted);

        $display("Control Unit Tests Completed");

        $finish;

    end

endmodule
