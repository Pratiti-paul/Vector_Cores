// L1 Data Cache
// Direct-mapped, one 8-bit data word per line, write-through, write-allocate.
//
//   INDEX_BITS = 2  ->  4 lines (a quarter of the 16-word data space)
//   index = addr[INDEX_BITS-1:0],  tag = addr[3:INDEX_BITS]
//
// LOAD  hit : data returned combinationally (no stall).
// LOAD  miss: the word is read from the shared memory; the core stalls until
//             mem_ready, the data is forwarded in that cycle and the line is
//             filled.
// STORE     : write-through - every store is written to the shared memory
//             (the core stalls until the write completes) and the line is
//             updated/allocated, so a later LOAD of the same address hits.
//             The shared memory therefore always holds the current data.
//
// ENABLE = 0 turns the cache off (every LOAD goes to the shared memory).
module dcache #(
    parameter INDEX_BITS = 2,
    parameter ENABLE     = 1
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        rd,          // LOAD in progress (instruction valid)
    input  wire        wr,          // STORE in progress (instruction valid)
    input  wire [3:0]  addr,
    input  wire [7:0]  wdata,
    output wire [7:0]  rdata,
    output wire        done,        // the data access completes this cycle
    output wire        hit,         // LOAD hit

    // Port to mem_arbiter
    output wire        mem_req,
    output wire        mem_we,
    output wire [4:0]  mem_addr,
    output wire [15:0] mem_wdata,
    input  wire        mem_ready,
    input  wire [15:0] mem_rdata
);

    localparam LINES    = 1 << INDEX_BITS;
    localparam TAG_BITS = 4 - INDEX_BITS;

    reg [7:0]          line_data [0:LINES-1];
    reg [TAG_BITS-1:0] line_tag  [0:LINES-1];
    reg [LINES-1:0]    line_valid;

    wire [INDEX_BITS-1:0] index = addr[INDEX_BITS-1:0];
    wire [TAG_BITS-1:0]   tag   = addr[3:INDEX_BITS];
    wire lookup_hit = (ENABLE != 0) && line_valid[index] && (line_tag[index] == tag);

    assign hit       = rd & lookup_hit;
    assign mem_req   = (rd & ~lookup_hit) | wr;
    assign mem_we    = wr;
    assign mem_addr  = {1'b1, addr};              // data region
    assign mem_wdata = {8'h00, wdata};
    assign rdata     = lookup_hit ? line_data[index] : mem_rdata[7:0];

    assign done = rd ? (lookup_hit | mem_ready) :
                  wr ? mem_ready :
                       1'b1;                      // no data access

    always @(posedge clk) begin
        if (reset)
            line_valid <= {LINES{1'b0}};
        else if (mem_ready && (wr || (rd && ~lookup_hit))) begin
            line_data[index]  <= wr ? wdata : mem_rdata[7:0];
            line_tag[index]   <= tag;
            line_valid[index] <= 1'b1;
        end
    end

endmodule
