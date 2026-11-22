// Unified Memory (Von Neumann baseline - shared instruction + data storage)
// 32 locations x 16 bits, ONE shared port: synchronous write, asynchronous
// (combinational) read.
//
// This is the shared-memory counterpart of the Harvard design's separate
// instruction_memory (16 x 16) and data_memory (16 x 8). Both instructions
// and data live in the same array and are reached through the same single
// address/data port, so only ONE access (fetch OR data) can happen per cycle.
//
// Memory map (5-bit address):
//   0x00 - 0x0F : instruction region (loaded from program.hex, read-only)
//   0x10 - 0x1F : data region        (data word stored in bits [7:0])
//
// Region decoding: addr[4] selects the region; inside the data region the
// existing 4-to-16 address_decoder generates the word-select lines, exactly
// as it does inside the Harvard data_memory.
//
// Timing:
//   Write - synchronous on posedge clk, data region only (instruction region
//           is write-protected so a STORE can never corrupt the program).
//   Read  - asynchronous (combinational) for both regions.
//   Reset - active-high synchronous; clears the data region to 16'h0000
//           (matches data_memory reset). The instruction region is retained.
module unified_memory (
    input  wire        clk,         // System clock
    input  wire        reset,       // Active-high synchronous reset
    input  wire [4:0]  addr,        // Shared 5-bit address (region + word)
    input  wire        write_en,    // Write enable (STORE data phase)
    input  wire [15:0] write_data,  // Write data ({8'h00, register} for STORE)
    output wire [15:0] read_data    // Shared read port (instruction or data)
);

    reg [15:0] mem [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            mem[i] = 16'h0000;
        $readmemh("program.hex", mem, 0, 15);
    end

    // --- Region + word decoding ---
    // Only data-region writes are decoded; instruction-region writes are blocked.
    wire        data_region  = addr[4];
    wire [15:0] write_select;

    address_decoder addr_dec (
        .enable       (write_en & data_region),
        .addr         (addr[3:0]),
        .select_lines (write_select)
    );

    // --- Synchronous write and reset (data region only) ---
    always @(posedge clk) begin
        if (reset) begin
            for (i = 16; i < 32; i = i + 1)
                mem[i] <= 16'h0000;
        end
        else begin
            for (i = 0; i < 16; i = i + 1) begin
                if (write_select[i])
                    mem[16 + i] <= write_data;
            end
        end
    end

    // --- Asynchronous (combinational) shared read port ---
    assign read_data = mem[addr];

endmodule
