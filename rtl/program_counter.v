
module program_counter (
    input wire clk,
    input wire reset,
    input wire pc_enable,
    input wire [3:0] pc_next,

    output reg [3:0] pc_out
);

    always @(posedge clk) begin

        if (reset) begin
            pc_out <= 4'b0000;
        end

        else if (pc_enable) begin
            pc_out <= pc_next;
        end

    end

endmodule
