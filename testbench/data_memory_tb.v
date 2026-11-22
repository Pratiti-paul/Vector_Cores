`timescale 1ns/1ps

module data_memory_tb;

    reg        clk;
    reg        reset;
    reg        mem_read;
    reg        mem_write;
    reg  [3:0] addr;
    reg  [7:0] write_data;
    wire [7:0] read_data;

    integer i, errors, total_pass;

    // Instantiate Data Memory (internally instantiates address_decoder)
    data_memory uut (
        .clk        (clk),
        .reset      (reset),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (read_data)
    );

    // Clock generation: period = 10 ns
    always #5 clk = ~clk;

    // Helper task: check and report
    task check;
        input [7:0] actual;
        input [7:0] expected;
        input [8*80-1:0] label;
        begin
            if (actual === expected) begin
                $display("PASS %0s actual=%h", label, actual);
                total_pass = total_pass + 1;
            end else begin
                $display("FAIL %0s actual=%h expected=%h", label, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("data_memory_phase2.vcd");
        $dumpvars(0, data_memory_tb);

        clk        = 0;
        reset      = 0;
        mem_read   = 0;
        mem_write  = 0;
        addr       = 0;
        write_data = 0;
        errors     = 0;
        total_pass = 0;

        $display("===================================================================");
        $display("  DATA MEMORY PHASE II — COMPREHENSIVE VERIFICATION TESTBENCH");
        $display("===================================================================");

        // =================================================================
        // Test D1: Reset verification (all 16 locations)
        // =================================================================
        $display("--- Test D1: Reset verification (all 16 locations) ---");
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        mem_read = 1;
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            check(read_data, 8'h00, "D1 reset");
        end
        mem_read = 0;

        // =================================================================
        // Test D2: Individual write and read to all 16 addresses
        //   Write unique value to each addr, read back one at a time.
        // =================================================================
        $display("--- Test D2: Individual write/read all 16 addresses ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        for (i = 0; i < 16; i = i + 1) begin
            // Write
            mem_write  = 1;
            addr       = i;
            write_data = (i * 17 + 3) & 8'hFF;
            @(posedge clk); #1;
            mem_write  = 0;

            // Read back same address
            mem_read = 1;
            addr     = i; #1;
            check(read_data, (i * 17 + 3) & 8'hFF, "D2 addr");
            mem_read = 0;
        end

        // =================================================================
        // Test D3: Independent read operation
        //   Read from address that was never written (after fresh reset).
        //   Must return 0x00, not X or Z.
        // =================================================================
        $display("--- Test D3: Independent read (never-written address) ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        mem_read = 1;
        addr = 4'd7; #1;
        check(read_data, 8'h00, "D3 never-written addr=7");
        addr = 4'd0; #1;
        check(read_data, 8'h00, "D3 never-written addr=0");
        addr = 4'd15; #1;
        check(read_data, 8'h00, "D3 never-written addr=15");
        mem_read = 0;

        // =================================================================
        // Test D4: Independent write operation
        //   Write to two addresses without reading between.
        //   Only then read both — proves writes are independent of reads.
        // =================================================================
        $display("--- Test D4: Independent write (deferred read) ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Write 0xAB to addr 3 (no read)
        mem_write = 1; addr = 4'd3; write_data = 8'hAB;
        @(posedge clk); #1;

        // Write 0xCD to addr 10 (no read)
        addr = 4'd10; write_data = 8'hCD;
        @(posedge clk); #1;
        mem_write = 0;

        // Now read both
        mem_read = 1;
        addr = 4'd3; #1;
        check(read_data, 8'hAB, "D4 deferred read addr=3");
        addr = 4'd10; #1;
        check(read_data, 8'hCD, "D4 deferred read addr=10");
        mem_read = 0;

        // =================================================================
        // Test D5: Disabled write verification (multiple addresses)
        //   Write known values, then attempt writes with mem_write=0.
        // =================================================================
        $display("--- Test D5: Disabled write (multiple addresses) ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Write known values
        mem_write = 1;
        addr = 4'd0;  write_data = 8'h11; @(posedge clk); #1;
        addr = 4'd5;  write_data = 8'h55; @(posedge clk); #1;
        addr = 4'd15; write_data = 8'hFF; @(posedge clk); #1;
        mem_write = 0;

        // Attempt writes with mem_write=0
        addr = 4'd0;  write_data = 8'hEE; @(posedge clk); #1;
        addr = 4'd5;  write_data = 8'hDD; @(posedge clk); #1;
        addr = 4'd15; write_data = 8'hCC; @(posedge clk); #1;

        // Read back — must have original values
        mem_read = 1;
        addr = 4'd0;  #1; check(read_data, 8'h11, "D5 write-inhibit addr=0");
        addr = 4'd5;  #1; check(read_data, 8'h55, "D5 write-inhibit addr=5");
        addr = 4'd15; #1; check(read_data, 8'hFF, "D5 write-inhibit addr=15");
        mem_read = 0;

        // =================================================================
        // Test D6: Read control gating (multiple addresses)
        //   mem_read=0 must output 0x00 regardless of stored content.
        // =================================================================
        $display("--- Test D6: Read control gating ---");
        // Memory still has values from D5

        mem_read = 0;
        addr = 4'd0; #1;
        check(read_data, 8'h00, "D6 mem_read=0 addr=0");
        addr = 4'd5; #1;
        check(read_data, 8'h00, "D6 mem_read=0 addr=5");
        addr = 4'd15; #1;
        check(read_data, 8'h00, "D6 mem_read=0 addr=15");

        // Now enable — verify correct data appears
        mem_read = 1;
        addr = 4'd0;  #1; check(read_data, 8'h11, "D6 mem_read=1 addr=0");
        addr = 4'd5;  #1; check(read_data, 8'h55, "D6 mem_read=1 addr=5");
        addr = 4'd15; #1; check(read_data, 8'hFF, "D6 mem_read=1 addr=15");
        mem_read = 0;

        // =================================================================
        // Test D7: Consecutive back-to-back operations
        //   No idle cycles between operations.
        // =================================================================
        $display("--- Test D7: Consecutive back-to-back operations ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Write-Write: consecutive writes to addr 0 and addr 1
        mem_write = 1;
        addr = 4'd0; write_data = 8'hA0;
        @(posedge clk); #1;
        addr = 4'd1; write_data = 8'hB1;
        @(posedge clk); #1;
        mem_write = 0;

        // Verify both writes landed correctly
        mem_read = 1;
        addr = 4'd0; #1; check(read_data, 8'hA0, "D7 write-write addr=0");
        addr = 4'd1; #1; check(read_data, 8'hB1, "D7 write-write addr=1");

        // Write-Read: write to addr 2, immediately read addr 2 next cycle
        mem_write = 1; mem_read = 0;
        addr = 4'd2; write_data = 8'hC2;
        @(posedge clk); #1;
        mem_write = 0; mem_read = 1;
        addr = 4'd2; #1;
        check(read_data, 8'hC2, "D7 write-then-read addr=2");

        // Read-Read: consecutive reads
        addr = 4'd0; #1; check(read_data, 8'hA0, "D7 read-read addr=0");
        addr = 4'd1; #1; check(read_data, 8'hB1, "D7 read-read addr=1");
        addr = 4'd2; #1; check(read_data, 8'hC2, "D7 read-read addr=2");
        mem_read = 0;

        // =================================================================
        // Test D8: Simultaneous mem_read=1 and mem_write=1
        //   Write new data while reading same address.
        //   Async read sees OLD value; new value appears after clock edge.
        // =================================================================
        $display("--- Test D8: Simultaneous mem_read and mem_write ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Write initial value 0x10 to addr 4
        mem_write = 1; mem_read = 0;
        addr = 4'd4; write_data = 8'h10;
        @(posedge clk); #1;
        mem_write = 0;

        // Simultaneously assert both: write 0x20, read addr 4
        mem_write = 1; mem_read = 1;
        addr = 4'd4; write_data = 8'h20;
        // Before clock edge: combinational read should still see old value (0x10)
        #1;
        check(read_data, 8'h10, "D8 simultaneous pre-clk (old value)");

        @(posedge clk); #1;
        mem_write = 0;
        // After clock edge: new value should be written
        addr = 4'd4; #1;
        check(read_data, 8'h20, "D8 simultaneous post-clk (new value)");
        mem_read = 0;

        // =================================================================
        // Test D9: Mid-operation reset
        //   Write data, then assert reset while memory is populated.
        // =================================================================
        $display("--- Test D9: Mid-operation reset ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Populate several addresses
        mem_write = 1;
        addr = 4'd0;  write_data = 8'hDE; @(posedge clk); #1;
        addr = 4'd7;  write_data = 8'hAD; @(posedge clk); #1;
        addr = 4'd15; write_data = 8'hBE; @(posedge clk); #1;
        mem_write = 0;

        // Verify they are populated
        mem_read = 1;
        addr = 4'd0; #1;
        if (read_data !== 8'hDE) begin
            $display("FAIL D9 pre-reset addr=0 not populated"); errors = errors + 1;
        end
        mem_read = 0;

        // Assert reset mid-operation
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        // Verify ALL 16 locations are cleared
        mem_read = 1;
        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            check(read_data, 8'h00, "D9 mid-reset");
        end
        mem_read = 0;

        // =================================================================
        // Test D10: Write timing verification
        //   Data must NOT appear before posedge clk, MUST appear after.
        // =================================================================
        $display("--- Test D10: Write timing verification ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // Set up write
        mem_write = 1;
        addr = 4'd6;
        write_data = 8'h77;

        // Check BEFORE clock edge — read should still see old value (0x00)
        mem_read = 1;
        #1;
        check(read_data, 8'h00, "D10 before posedge (not yet written)");

        // Clock edge
        @(posedge clk); #1;
        mem_write = 0;

        // Check AFTER clock edge — new value available
        addr = 4'd6; #1;
        check(read_data, 8'h77, "D10 after posedge (written)");
        mem_read = 0;

        // =================================================================
        // Test D11: Read timing verification (combinational)
        //   Address change must immediately update read_data, no clock.
        // =================================================================
        $display("--- Test D11: Read timing (combinational) ---");
        // Write distinct values to addr 4 and addr 6
        mem_write = 1; mem_read = 0;
        addr = 4'd4; write_data = 8'h44; @(posedge clk); #1;
        addr = 4'd9; write_data = 8'h99; @(posedge clk); #1;
        mem_write = 0;

        // Now read: change addr without clock edge, verify instant update
        mem_read = 1;
        addr = 4'd4; #1;
        check(read_data, 8'h44, "D11 combinational read addr=4");

        // Switch to addr 9 — no clock edge, just address change
        addr = 4'd9; #1;
        check(read_data, 8'h99, "D11 combinational read addr=9 (no clk)");

        // Switch to addr 6 (still has 0x77 from D10)
        addr = 4'd6; #1;
        check(read_data, 8'h77, "D11 combinational read addr=6 (no clk)");
        mem_read = 0;

        // =================================================================
        // Test D12: LOAD/STORE processor compatibility
        //   Simulate program.hex STORE R1,[2] -> LOAD R3,[2] sequence
        //   plus boundary address tests (addr 0 and addr 15).
        // =================================================================
        $display("--- Test D12: LOAD/STORE processor compatibility ---");
        reset = 1; @(posedge clk); #1; reset = 0;

        // STORE R1, [2]: write value 8 to addr 2 (from program.hex)
        mem_write = 1;
        addr       = 4'd2;
        write_data = 8'd8;
        @(posedge clk); #1;
        mem_write = 0;

        // LOAD R3, [2]: read addr 2
        mem_read = 1;
        addr = 4'd2; #1;
        check(read_data, 8'd8, "D12 STORE/LOAD addr=2 (program.hex)");
        mem_read = 0;

        // Boundary: STORE to addr 0
        mem_write = 1;
        addr = 4'd0; write_data = 8'hA5;
        @(posedge clk); #1;
        mem_write = 0;

        mem_read = 1;
        addr = 4'd0; #1;
        check(read_data, 8'hA5, "D12 boundary STORE/LOAD addr=0");

        // Boundary: STORE to addr 15
        mem_write = 1;
        addr = 4'd15; write_data = 8'h5A;
        @(posedge clk); #1;
        mem_write = 0;

        addr = 4'd15; #1;
        check(read_data, 8'h5A, "D12 boundary STORE/LOAD addr=15");

        // Cross-verify: addr 2 still holds value 8
        addr = 4'd2; #1;
        check(read_data, 8'd8, "D12 cross-verify addr=2 unchanged");
        mem_read = 0;

        // =================================================================
        // Final Summary
        // =================================================================
        $display("===================================================================");
        $display("Total Checks Passed: %0d", total_pass);
        $display("Total Checks Failed: %0d", errors);
        $display("===================================================================");
        if (errors == 0)
            $display("ALL DATA MEMORY PHASE II TESTS PASSED");
        else
            $display("%0d DATA MEMORY TEST(S) FAILED", errors);
        $display("===================================================================");

        $finish;
    end

endmodule
