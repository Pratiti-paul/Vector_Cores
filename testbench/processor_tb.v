`timescale 1ns / 1ps

module processor_tb;

    // Clock and reset
    reg clk;
    reg reset;

    // Processor outputs
    wire [3:0]  pc_out;
    wire [15:0] instr;
    wire [7:0]  alu_out;
    wire [7:0]  write_data;
    wire        zero;
    wire        halted;

    integer errors;
    integer cycles;
    integer i;

    // Instantiate the processor
    top_module uut (
        .clk       (clk),
        .reset     (reset),
        .pc_out    (pc_out),
        .instr     (instr),
        .alu_out   (alu_out),
        .write_data(write_data),
        .zero      (zero),
        .halted    (halted)
    );

    // Generate a 10 ns clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Main processor verification
    initial begin

        errors = 0;
        cycles = 0;
        reset = 1'b1;

        // Generate waveform
        $dumpfile("processor_wave.vcd");
        $dumpvars(0, processor_tb);

        $display("----------------------------------------");
        $display(" PROCESSOR-LEVEL SELF-CHECKING TESTBENCH");
        $display("----------------------------------------");

        // Hold reset across two rising edges
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display("Reset released. Starting execution...");

        // Wait until HALT or timeout
        while ((halted !== 1'b1) && (cycles < 30)) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;

            $display(
                "Cycle %0d | PC=%0d | Instruction=%h | ALU=%h | HALT=%b",
                cycles, pc_out, instr, alu_out, halted
            );
        end

        // Allow combinational signals to settle
        #1;

        $display("----------------------------------------");
        $display(" FINAL PROCESSOR STATE");
        $display("----------------------------------------");

        // Check R0
        if (uut.rf_inst.registers[0] === 8'd0)
            $display("PASS: R0 = 0");
        else begin
            $display("FAIL: R0 expected 0, got %h",
                     uut.rf_inst.registers[0]);
            errors = errors + 1;
        end

        // Check R1
        if (uut.rf_inst.registers[1] === 8'd5)
            $display("PASS: R1 = 5");
        else begin
            $display("FAIL: R1 expected 5, got %h",
                     uut.rf_inst.registers[1]);
            errors = errors + 1;
        end

        // Check R2
        if (uut.rf_inst.registers[2] === 8'd3)
            $display("PASS: R2 = 3");
        else begin
            $display("FAIL: R2 expected 3, got %h",
                     uut.rf_inst.registers[2]);
            errors = errors + 1;
        end

        // Check R3
        if (uut.rf_inst.registers[3] === 8'd9)
            $display("PASS: R3 = 9");
        else begin
            $display("FAIL: R3 expected 9, got %h",
                     uut.rf_inst.registers[3]);
            errors = errors + 1;
        end

        // Check Data Memory location 2
        if (uut.dmem_inst.mem[2] === 8'd8)
            $display("PASS: DMEM[2] = 8");
        else begin
            $display("FAIL: DMEM[2] expected 8, got %h",
                     uut.dmem_inst.mem[2]);
            errors = errors + 1;
        end

        // Check Program Counter
        if (pc_out === 4'd7)
            $display("PASS: PC = 7");
        else begin
            $display("FAIL: PC expected 7, got %h", pc_out);
            errors = errors + 1;
        end

        // Check HALT
        if (halted === 1'b1)
            $display("PASS: HALT asserted");
        else begin
            $display("FAIL: HALT was not asserted");
            errors = errors + 1;
        end

        // Verify that PC stays frozen after HALT
        $display("----------------------------------------");
        $display(" VERIFYING HALT HOLD BEHAVIOR");
        $display("----------------------------------------");

        repeat (3) begin
            @(posedge clk);
            #1;

            if (pc_out === 4'd7 && halted === 1'b1)
                $display("PASS: PC remains at 7 after HALT");
            else begin
                $display("FAIL: PC changed after HALT");
                errors = errors + 1;
            end
        end

        // Final result
        $display("----------------------------------------");
        $display(" TOTAL ERRORS: %0d", errors);
        $display("----------------------------------------");

        if (cycles >= 30 && halted !== 1'b1) begin
            $display("FAIL: Processor timed out before HALT");
            $finish;
        end

        if (errors == 0)
            $display("ALL PROCESSOR TESTS PASSED!");
        else
            $display("PROCESSOR TEST FAILED!");

        $finish;
    end

endmodule