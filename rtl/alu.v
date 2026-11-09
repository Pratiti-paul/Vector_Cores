// Arithmetic Logic Unit (ALU)
// 8-bit integer arithmetic unit supporting ADD and SUB.
// Generates an 8-bit result and a zero flag for branch evaluation.
// Pure combinational logic — no clock or reset required.
//
// alu_control decoding:
//   2'b00: Addition    (ADD, ADDI)  -> alu_out = alu_in1 + alu_in2
//   2'b01: Subtraction (SUB, BEQ)   -> alu_out = alu_in1 - alu_in2
//   others: default to 8'h00
//
// zero flag:
//   Asserted (1'b1) when alu_out == 8'b00000000 (used by BEQ logic)
module alu (
    input  wire [7:0] alu_in1,       // 8-bit operand 1 (from rs)
    input  wire [7:0] alu_in2,       // 8-bit operand 2 (from rt or immediate)
    input  wire [1:0] alu_control,   // 2-bit operation selector (from control_unit)
    output reg  [7:0] alu_out,       // 8-bit arithmetic result
    output wire       zero           // 1-bit zero flag (asserted when alu_out == 0)
);

    always @(*) begin
        case (alu_control)
            2'b00:   alu_out = alu_in1 + alu_in2;
            2'b01:   alu_out = alu_in1 - alu_in2;
            default: alu_out = 8'h00;
        endcase
    end

    assign zero = (alu_out == 8'b00000000);

endmodule
