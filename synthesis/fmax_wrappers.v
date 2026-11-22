// Fmax measurement wrappers (synthesis / place-and-route only, not simulation)
//
// Each wrapper instantiates one processor and registers every output port.
// Without this, the timing analyser would time paths from internal flip-flops
// straight to unconstrained FPGA output pins, so the reported Fmax would
// include pin routing instead of the processor's own register-to-register
// logic. With registered outputs, every timed path starts and ends at a
// flip-flop, which is the clock-period limit of the core itself.
//
// Used by synthesis/run_ice40.sh.

module harvard_fmax_top (
    input  wire        clk,
    input  wire        reset,
    output reg  [3:0]  pc_out,
    output reg  [15:0] instr,
    output reg  [7:0]  alu_out,
    output reg  [7:0]  write_data,
    output reg         zero,
    output reg         halted
);
    wire [3:0]  pc_w;
    wire [15:0] instr_w;
    wire [7:0]  alu_w, wdata_w;
    wire        zero_w, halted_w;

    top_module core (
        .clk(clk), .reset(reset),
        .pc_out(pc_w), .instr(instr_w), .alu_out(alu_w),
        .write_data(wdata_w), .zero(zero_w), .halted(halted_w)
    );

    always @(posedge clk) begin
        pc_out     <= pc_w;
        instr      <= instr_w;
        alu_out    <= alu_w;
        write_data <= wdata_w;
        zero       <= zero_w;
        halted     <= halted_w;
    end
endmodule

module vn_fmax_top (
    input  wire        clk,
    input  wire        reset,
    output reg  [3:0]  pc_out,
    output reg  [15:0] instr,
    output reg  [7:0]  alu_out,
    output reg  [7:0]  write_data,
    output reg         zero,
    output reg  [4:0]  mem_addr,
    output reg         mem_phase,
    output reg         stall,
    output reg         retire,
    output reg         halted
);
    wire [3:0]  pc_w;
    wire [15:0] instr_w;
    wire [7:0]  alu_w, wdata_w;
    wire        zero_w, halted_w;
    wire [4:0]  maddr_w;
    wire        phase_w, stall_w, retire_w;

    vn_top_module core (
        .clk(clk), .reset(reset),
        .pc_out(pc_w), .instr(instr_w), .alu_out(alu_w),
        .write_data(wdata_w), .zero(zero_w),
        .mem_addr(maddr_w), .mem_phase(phase_w),
        .stall(stall_w), .retire(retire_w), .halted(halted_w)
    );

    always @(posedge clk) begin
        pc_out     <= pc_w;
        instr      <= instr_w;
        alu_out    <= alu_w;
        write_data <= wdata_w;
        zero       <= zero_w;
        mem_addr   <= maddr_w;
        mem_phase  <= phase_w;
        stall      <= stall_w;
        retire     <= retire_w;
        halted     <= halted_w;
    end
endmodule
