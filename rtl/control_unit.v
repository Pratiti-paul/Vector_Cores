
module control_unit (
    input wire [3:0] opcode,

    output reg pc_enable,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,

    output reg [2:0] alu_control,   // 3-bit ALU op select (matches alu.v)

    output reg alu_src,
    output reg mem_to_reg,

    output reg branch_enable,
    output reg jump_enable,
    output reg halted
);

    always @(*) begin

        // Default values
        pc_enable    = 1'b1;
        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;

        alu_control  = 3'b000;

        alu_src      = 1'b0;
        mem_to_reg   = 1'b0;

        branch_enable = 1'b0;
        jump_enable   = 1'b0;
        halted        = 1'b0;

        case (opcode)

            // LOAD
            4'b0001: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end

            // STORE
            4'b0010: begin
                mem_write = 1'b1;
            end

            // ADD
            4'b0011: begin
                reg_write   = 1'b1;
                alu_control = 3'b000;
            end

            // SUB
            4'b0100: begin
                reg_write   = 1'b1;
                alu_control = 3'b001;
            end

            // ADDI
            4'b0101: begin
                reg_write   = 1'b1;
                alu_control = 3'b000;
                alu_src     = 1'b1;
            end

            // BEQ
            4'b0110: begin
                branch_enable = 1'b1;
                alu_control   = 3'b001;
            end

            // JUMP
            4'b0111: begin
                jump_enable = 1'b1;
            end

            // AND  (R-type: rd, rs, rt)
            4'b1000: begin
                reg_write   = 1'b1;
                alu_control = 3'b010;
            end

            // OR   (R-type: rd, rs, rt)
            4'b1001: begin
                reg_write   = 1'b1;
                alu_control = 3'b011;
            end

            // XOR  (R-type: rd, rs, rt)
            4'b1010: begin
                reg_write   = 1'b1;
                alu_control = 3'b100;
            end

            // HALT
            4'b1111: begin
                pc_enable = 1'b0;
                halted    = 1'b1;
            end

            // Invalid opcode
            default: begin
                pc_enable = 1'b0;
            end

        endcase

    end

endmodule
