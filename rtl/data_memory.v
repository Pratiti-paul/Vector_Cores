// Data Memory (Harvard architecture - separate from instruction memory)
// 16 locations x 8 bits, synchronous write, asynchronous (combinational) read.
//
// The data memory is the runtime read/write storage used by LOAD and STORE
// instructions. It is entirely separate from instruction memory (Harvard),
// allowing simultaneous instruction fetch and data access in the same cycle.
//
// Address decoding is performed by an internal address_decoder instance.
// In physical hardware, the decoder's one-hot select lines would directly
// gate the individual memory word-line cells.
//
// Timing:
//   Write — synchronous on posedge clk when mem_write is asserted.
//   Read  — asynchronous (combinational) when mem_read is asserted;
//           output is 8'h00 when mem_read is deasserted.
//   Reset — active-high synchronous; clears all 16 locations to 8'h00.
module data_memory (
    input  wire       clk,             // System clock
    input  wire       reset,           // Active-high synchronous reset
    input  wire       mem_read,        // Read enable  (from control_unit)
    input  wire       mem_write,       // Write enable (from control_unit)
    input  wire [3:0] addr,            // 4-bit memory address (from instruction [9:6])
    input  wire [7:0] write_data,      // 8-bit data input (register value for STORE)
    output wire [7:0] read_data        // 8-bit data output (to register writeback for LOAD)
);

    reg [7:0] mem [0:15];
    integer i;

    // --- Address decoder integration ---
    // Directly used here to demonstrate the decoded word-select lines.
    // write_select[k] is high only when mem_write is asserted AND addr == k.
    wire [15:0] write_select;

    address_decoder addr_dec (
        .enable (mem_write),
        .addr   (addr),
        .select_lines (write_select)
    );

    // --- Synchronous write and reset ---
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 8'h00;
        end
        else begin
            // Write to the location selected by the address decoder
            for (i = 0; i < 16; i = i + 1) begin
                if (write_select[i])
                    mem[i] <= write_data;
            end
        end
    end

    // --- Asynchronous (combinational) read ---
    // Output is gated by mem_read to prevent stale data leaking onto the bus.
    assign read_data = (mem_read) ? mem[addr] : 8'h00;

endmodule
