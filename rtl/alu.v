
module alu (
    input wire [7:0] alu_in1,
    input wire [7:0] alu_in2,
    input wire [1:0] alu_control,
    output reg [7:0] alu_out,
    output wire zero
);

    // Combinational ALU operations
    always @(*) begin
        case (alu_control)

            2'b00: begin
                // Addition
                alu_out = alu_in1 + alu_in2;
            end

            2'b01: begin
                // Subtraction
                alu_out = alu_in1 - alu_in2;
            end

            default: begin
                // Unsupported operation
                alu_out = 8'b00000000;
            end

        endcase
    end

    // Zero flag
    assign zero = (alu_out == 8'b00000000);

endmodule

