// Instruction Memory (Harvard architecture - separate from data memory)
// 16 locations x 16 bits, read-only, asynchronous (combinational) read.
//
// Instruction formats (all unused bits are 0):
//   LOAD  rd, [addr]      : 0001 | rd[11:10] | addr[9:6]  | 000000
//   STORE rs, [addr]      : 0010 | rs[11:10] | addr[9:6]  | 000000
//   ADD   rd, rs, rt      : 0011 | rd[11:10] | rs[9:8] | rt[7:6] | 000000
//   SUB   rd, rs, rt      : 0100 | rd[11:10] | rs[9:8] | rt[7:6] | 000000
//   ADDI  rd, rs, imm     : 0101 | rd[11:10] | rs[9:8] | imm[7:0] (signed)
//   BEQ   rs, rt, offset  : 0110 | rs[11:10] | rt[9:8] | offset[7:0] (signed)
//   JUMP  addr            : 0111 | 00000000 | addr[3:0]
//   HALT                  : 1111 | 000000000000
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