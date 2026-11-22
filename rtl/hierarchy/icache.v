// L1 Instruction Cache
// Direct-mapped, one 16-bit instruction per line, read-only.
//
//   INDEX_BITS = 3  ->  8 lines (half of the 16-word instruction space)
//   index = PC[INDEX_BITS-1:0],  tag = PC[3:INDEX_BITS]
//
// Hit : the instruction is returned combinationally (no stall).
// Miss: the cache requests the word from the shared memory and the core
//       stalls. When the memory completes (mem_ready) the word is written
//       into the line; the instruction then hits and executes in the next
//       cycle. Instructions are always delivered from the cache lines (never
//       forwarded straight from memory), so the shared-memory address never
//       depends combinationally on the memory's own read data.
//
// ENABLE = 0 turns the cache off: the line is invalidated as soon as its
// instruction retires, so every fetch goes to the shared memory. Used to
// measure the benefit of the cache.
module icache #(
    parameter INDEX_BITS = 3,
    parameter ENABLE     = 1
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [3:0]  pc,
    input  wire        retire,      // current instruction completes this cycle
    output wire [15:0] instr,       // instruction for the core
    output wire        valid,       // instr is valid (cache hit) this cycle
    output wire        hit,

    // Refill port (to mem_arbiter)
    output wire        mem_req,
    output wire [4:0]  mem_addr,
    input  wire        mem_ready,
    input  wire [15:0] mem_rdata
);

    localparam LINES    = 1 << INDEX_BITS;
    localparam TAG_BITS = 4 - INDEX_BITS;

    reg [15:0]         line_data [0:LINES-1];
    reg [TAG_BITS-1:0] line_tag  [0:LINES-1];
    reg [LINES-1:0]    line_valid;

    wire [INDEX_BITS-1:0] index = pc[INDEX_BITS-1:0];
    wire [TAG_BITS-1:0]   tag   = pc[3:INDEX_BITS];

    assign hit      = line_valid[index] && (line_tag[index] == tag);
    assign valid    = hit;
    assign instr    = line_data[index];
    assign mem_req  = ~hit;
    assign mem_addr = {1'b0, pc};                 // instruction region

    always @(posedge clk) begin
        if (reset)
            line_valid <= {LINES{1'b0}};
        else if (~hit && mem_ready) begin
            line_data[index]  <= mem_rdata;
            line_tag[index]   <= tag;
            line_valid[index] <= 1'b1;
        end
        else if ((ENABLE == 0) && retire)
            line_valid <= {LINES{1'b0}};          // cache disabled: no reuse
    end

endmodule
