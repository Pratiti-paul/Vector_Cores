// Address Decoder (4-to-16 one-hot decoder with enable)
// Decodes a 4-bit memory address into 16 individual word-select lines.
// In physical implementation, these select lines drive the individual
// memory word lines in the data memory array.
//
// Used by data_memory.v for word-level selection during read/write.
// Pure combinational logic — no clock required.
module address_decoder (
    input  wire        enable,          // Active when mem_read or mem_write is asserted
    input  wire [3:0]  addr,            // 4-bit memory address from instruction [9:6]
    output reg  [15:0] select_lines     // 16-bit one-hot decoded word-select
);

    always @(*) begin
        if (enable)
            select_lines = 16'b1 << addr;
        else
            select_lines = 16'b0;
    end

endmodule
