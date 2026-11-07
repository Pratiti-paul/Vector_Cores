// Instruction Memory (Harvard architecture - separate from data memory)
// 16 locations x 16 bits, read-only, asynchronous (combinational) read.
// Instruction format: [15:12] opcode | [11:10] rd | [9:8] rs | [7:0] imm/addr
module instruction_memory (
    input  wire [3:0]  addr,    // from program_counter.pc_out
    output wire [15:0] instr
);

    reg [15:0] mem [0:15];
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 16'hF000;          // unused locations = HALT
        $readmemh("program.hex", mem);  // test program
    end

    assign instr = mem[addr];

endmodule