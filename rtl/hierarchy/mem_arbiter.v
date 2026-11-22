// Memory Arbiter for the shared lower-level memory
//
// Connects the L1 instruction cache and the L1 data cache to the single port
// of shared_memory. Only one access can be in flight at a time.
//
// Priority: instruction cache first.
//   In this single-cycle core an instruction must be fetched (I-cache hit)
//   before its data access is known, and the core only issues a data request
//   while the current instruction hits in the I-cache. While a data access is
//   in progress the PC is held, so the instruction cache does not request.
//   The two caches therefore take turns on the shared port: an instruction
//   refill and a data access for the same instruction are serialized, which
//   is the structural cost of sharing the lower-level memory. The fixed
//   priority keeps the port behaviour well defined in any case.
//
//   The port address is selected by grant_d, which depends only on the
//   I-cache hit status and the decoded (cached) instruction, never on the
//   memory's read data, so there is no combinational loop through the port.
module mem_arbiter (
    // Instruction cache side (read only)
    input  wire        i_req,
    input  wire [4:0]  i_addr,
    output wire        i_ready,

    // Data cache side
    input  wire        d_req,
    input  wire        d_we,
    input  wire [4:0]  d_addr,
    input  wire [15:0] d_wdata,
    output wire        d_ready,

    // Shared memory port
    output wire        mem_req,
    output wire        mem_we,
    output wire [4:0]  mem_addr,
    output wire [15:0] mem_wdata,
    input  wire        mem_ready,

    output wire        grant_d       // 1 = data cache owns the port
);

    assign grant_d   = ~i_req & d_req;

    assign mem_req   = i_req | d_req;
    assign mem_we    = grant_d & d_we;
    assign mem_addr  = grant_d ? d_addr : i_addr;
    assign mem_wdata = d_wdata;

    assign i_ready   = i_req   & mem_ready;
    assign d_ready   = grant_d & mem_ready;

endmodule
