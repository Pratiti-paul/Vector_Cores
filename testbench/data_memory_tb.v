`timescale 1ns/1ps

module data_memory_tb;

    reg        clk;
    reg        reset;
    reg        mem_read;
    reg        mem_write;
    reg  [3:0] addr;
    reg  [7:0] write_data;
    wire [7:0] read_data;

    integer i, errors;

    // Instantiate Data Memory (which internally instantiates address_decoder)
    data_memory uut (
        .clk        (clk),
        .reset      (reset),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (read_data)
    );

    // Generate clock: period = 10 ns
    always #5 clk = ~clk;

    initial begin
        $dumpfile("data_memory.vcd");
        $dumpvars(0, data_memory_tb);

        clk        = 0;
        reset      = 0;
        mem_read   = 0;
        mem_write  = 0;
        addr       = 0;
        write_data = 0;
        errors     = 0;

        $display("=== Starting Data Memory Read/Write Tests ===");

        // ---------------------------------------------------------------
        // Test 1: Reset verification
        //   Assert reset for one cycle, then check all 16 locations are 0.
        // ---------------------------------------------------------------
        $display("--- Test 1: Reset verification ---");
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        mem_read = 1;
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            if (read_data !== 8'h00) begin
                $display("FAIL reset addr=%0d read_data=%h expected=00", i, read_data);
                errors = errors + 1;
            end else
                $display("PASS reset addr=%0d read_data=%h", i, read_data);
        end
        mem_read = 0;

        // ---------------------------------------------------------------
        // Test 2: Basic write and read back
        //   Write 0xAA to addr 0, 0x55 to addr 1; read both back.
        // ---------------------------------------------------------------
        $display("--- Test 2: Basic write and read back ---");

        // Write 0xAA to addr 0
        mem_write  = 1;
        addr       = 4'd0;
        write_data = 8'hAA;
        @(posedge clk); #1;
        mem_write  = 0;

        // Write 0x55 to addr 1
        mem_write  = 1;
        addr       = 4'd1;
        write_data = 8'h55;
        @(posedge clk); #1;
        mem_write  = 0;

        // Read back addr 0
        mem_read = 1;
        addr     = 4'd0; #1;
        if (read_data !== 8'hAA) begin
            $display("FAIL basic write addr=0 read_data=%h expected=AA", read_data);
            errors = errors + 1;
        end else
            $display("PASS basic write addr=0 read_data=%h", read_data);

        // Read back addr 1
        addr = 4'd1; #1;
        if (read_data !== 8'h55) begin
            $display("FAIL basic write addr=1 read_data=%h expected=55", read_data);
            errors = errors + 1;
        end else
            $display("PASS basic write addr=1 read_data=%h", read_data);
        mem_read = 0;

        // ---------------------------------------------------------------
        // Test 3: Exhaustive 16-location write and read
        //   Write a unique pattern to each location, then read all back.
        //   Pattern: data = (addr * 11 + 5) & 0xFF
        // ---------------------------------------------------------------
        $display("--- Test 3: Exhaustive 16-location write and read ---");

        // Reset first to clear previous data
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        // Write unique values
        for (i = 0; i < 16; i = i + 1) begin
            mem_write  = 1;
            addr       = i;
            write_data = (i * 11 + 5) & 8'hFF;
            @(posedge clk); #1;
        end
        mem_write = 0;

        // Read back and verify
        mem_read = 1;
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            if (read_data !== ((i * 11 + 5) & 8'hFF)) begin
                $display("FAIL exhaustive addr=%0d read_data=%h expected=%h",
                          i, read_data, (i * 11 + 5) & 8'hFF);
                errors = errors + 1;
            end else
                $display("PASS exhaustive addr=%0d read_data=%h", i, read_data);
        end
        mem_read = 0;

        // ---------------------------------------------------------------
        // Test 4: Write inhibit
        //   With mem_write = 0, attempt to change data — verify no update.
        // ---------------------------------------------------------------
        $display("--- Test 4: Write inhibit ---");

        // addr 0 should still hold (0*11+5) = 0x05 from Test 3
        mem_write  = 0;
        addr       = 4'd0;
        write_data = 8'hFF;
        @(posedge clk); #1;

        mem_read = 1;
        addr     = 4'd0; #1;
        if (read_data !== 8'h05) begin
            $display("FAIL write inhibit addr=0 read_data=%h expected=05", read_data);
            errors = errors + 1;
        end else
            $display("PASS write inhibit addr=0 read_data=%h", read_data);
        mem_read = 0;

        // ---------------------------------------------------------------
        // Test 5: Read inhibit
        //   With mem_read = 0, read_data should output 8'h00.
        // ---------------------------------------------------------------
        $display("--- Test 5: Read inhibit ---");

        mem_read = 0;
        addr     = 4'd0; #1;
        if (read_data !== 8'h00) begin
            $display("FAIL read inhibit read_data=%h expected=00", read_data);
            errors = errors + 1;
        end else
            $display("PASS read inhibit read_data=%h", read_data);

        // ---------------------------------------------------------------
        // Test 6: Program compatibility (program.hex scenario)
        //   STORE R1, [2]  -> write 8 to addr 2
        //   LOAD  R3, [2]  -> read addr 2 and expect 8
        // ---------------------------------------------------------------
        $display("--- Test 6: Program compatibility (STORE/LOAD to addr 2) ---");

        // Reset
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        // STORE: write value 8 to addr 2
        mem_write  = 1;
        addr       = 4'd2;
        write_data = 8'd8;
        @(posedge clk); #1;
        mem_write  = 0;

        // LOAD: read addr 2
        mem_read = 1;
        addr     = 4'd2; #1;
        if (read_data !== 8'd8) begin
            $display("FAIL program compat STORE/LOAD addr=2 read_data=%0d expected=8", read_data);
            errors = errors + 1;
        end else
            $display("PASS program compat STORE/LOAD addr=2 read_data=%0d", read_data);
        mem_read = 0;

        // ---------------------------------------------------------------
        // Test 7: Overwrite
        //   Write a value, then overwrite with a new value at the same addr.
        // ---------------------------------------------------------------
        $display("--- Test 7: Overwrite ---");

        // Write 0x42 to addr 5
        mem_write  = 1;
        addr       = 4'd5;
        write_data = 8'h42;
        @(posedge clk); #1;

        // Overwrite with 0xBE
        write_data = 8'hBE;
        @(posedge clk); #1;
        mem_write  = 0;

        // Read back
        mem_read = 1;
        addr     = 4'd5; #1;
        if (read_data !== 8'hBE) begin
            $display("FAIL overwrite addr=5 read_data=%h expected=BE", read_data);
            errors = errors + 1;
        end else
            $display("PASS overwrite addr=5 read_data=%h", read_data);
        mem_read = 0;

        // ---------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------
        $display("=== Data Memory Tests Complete ===");
        if (errors == 0)
            $display("ALL DATA MEMORY READ/WRITE TESTS PASSED");
        else
            $display("%0d DATA MEMORY TEST(S) FAILED", errors);

        $finish;
    end

endmodule
