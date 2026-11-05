`timescale 1ns/1ps

module program_counter_tb;

    reg clk;
    reg reset;
    reg pc_enable;
    reg [3:0] pc_next;

    wire [3:0] pc_out;

    // Instantiate Program Counter
    program_counter uut (
        .clk(clk),
        .reset(reset),
        .pc_enable(pc_enable),
        .pc_next(pc_next),
        .pc_out(pc_out)
    );

    // Generate clock
    always #5 clk = ~clk;

    initial begin

        clk = 0;
        reset = 1;
        pc_enable = 0;
        pc_next = 0;

        // Test reset
        #10;
        $display("After reset: PC = %d", pc_out);

        // Test sequential update
        reset = 0;
        pc_enable = 1;
        pc_next = 1;

        #10;
        $display("After increment: PC = %d", pc_out);

        // Test another address
        pc_next = 2;

        #10;
        $display("Next address: PC = %d", pc_out);

        // Test jump
        pc_next = 10;

        #10;
        $display("After jump: PC = %d", pc_out);

        // Test hold
        pc_enable = 0;

        #10;
        $display("After hold: PC = %d", pc_out);

        // Finish simulation
        $finish;

    end

endmodule
