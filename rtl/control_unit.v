
module control_unit (
    input wire [3:0] opcode,

    output reg pc_enable,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,

    output reg [1:0] alu_control,

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

        alu_control  = 2'b00;

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
                alu_control = 2'b00;
            end

            // SUB
            4'b0100: begin
                reg_write   = 1'b1;
                alu_control = 2'b01;
            end

            // ADDI
            4'b0101: begin
                reg_write   = 1'b1;
                alu_control = 2'b00;
                alu_src     = 1'b1;
            end

            // BEQ
            4'b0110: begin
                branch_enable = 1'b1;
                alu_control   = 2'b01;
            end

            // JUMP
            4'b0111: begin
                jump_enable = 1'b1;
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
