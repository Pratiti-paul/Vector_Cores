// Shared Lower-Level Memory (Level 2)
// 32 locations x 16 bits, ONE port, shared by the L1 instruction cache and
// the L1 data cache through mem_arbiter.
//
// Memory map (5-bit address), identical to the Von Neumann unified_memory:
//   0x00 - 0x0F : instruction region (loaded from program.hex, read-only)
//   0x10 - 0x1F : data region        (data word stored in bits [7:0])
//
// Timing (slow memory model):
//   A request must be held for WAIT_CYCLES clock cycles before the access
//   completes. `ready` is asserted in the cycle the access completes; in that
//   cycle `rdata` holds the read data and, for a write, the word is written on
//   the rising clock edge at the end of the cycle.
//     WAIT_CYCLES = 0 : completes in the request cycle (single-cycle memory)
//     WAIT_CYCLES = 2 : request cycle + 2 wait cycles = 3-cycle access
//   The wait counter restarts after every completed access, so two back-to-
//   back requests are served one after the other (one access in flight).
//
// Reset: active-high synchronous; clears the data region (instructions kept).
module shared_memory #(
    parameter WAIT_CYCLES = 2
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        req,         // access request (held until ready)
    input  wire        we,          // 1 = write, 0 = read
    input  wire [4:0]  addr,
    input  wire [15:0] wdata,
    output wire        ready,       // access completes this cycle
    output wire [15:0] rdata
);

    reg [15:0] mem [0:31];
    reg [3:0]  wait_cnt;
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            mem[i] = 16'h0000;
        $readmemh("program.hex", mem, 0, 15);
    end

    assign ready = req && (wait_cnt == WAIT_CYCLES);
    assign rdata = mem[addr];

    // Data-region word select (instruction region is write-protected)
    wire [15:0] write_select;

    address_decoder addr_dec (
        .enable       (ready & we & addr[4]),
        .addr         (addr[3:0]),
        .select_lines (write_select)
    );

    always @(posedge clk) begin
        if (reset) begin
            wait_cnt <= 4'd0;
            for (i = 16; i < 32; i = i + 1)
                mem[i] <= 16'h0000;
        end
        else begin
            // Count wait cycles of the current access; restart after it completes
            if (!req || ready)
                wait_cnt <= 4'd0;
            else
                wait_cnt <= wait_cnt + 4'd1;

            for (i = 0; i < 16; i = i + 1) begin
                if (write_select[i])
                    mem[16 + i] <= wdata;
            end
        end
    end

endmodule
