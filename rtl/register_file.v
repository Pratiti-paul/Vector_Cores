module register_file (
    input wire clk,
    input wire reset,
    input wire reg_write,

    input wire [1:0] read_reg1,
    input wire [1:0] read_reg2,
    input wire [1:0] write_reg,

    input wire [7:0] write_data,

    output wire [7:0] read_data1,
    output wire [7:0] read_data2
);

    reg [7:0] registers [0:3];

    // Synchronous reset and write
    always @(posedge clk) begin
        if (reset) begin
            registers[0] <= 8'b00000000;
            registers[1] <= 8'b00000000;
            registers[2] <= 8'b00000000;
            registers[3] <= 8'b00000000;
        end
        else if (reg_write && write_reg != 2'b00) begin
            registers[write_reg] <= write_data;
        end
    end

    // Asynchronous dual read
    assign read_data1 = (read_reg1 == 2'b00) ? 8'b00000000 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 2'b00) ? 8'b00000000 : registers[read_reg2];

endmodule
