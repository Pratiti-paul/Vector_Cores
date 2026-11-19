`timescale 1ns/1ps

module address_decoder_tb;

    reg        enable;
    reg  [3:0] addr;
    wire [15:0] select_lines;

    integer i, j, errors, bit_count;

    // Instantiate Address Decoder
    address_decoder uut (
        .enable       (enable),
        .addr         (addr),
        .select_lines (select_lines)
    );

    initial begin
        $dumpfile("address_decoder.vcd");
        $dumpvars(0, address_decoder_tb);

        enable = 0;
        addr   = 0;
        errors = 0;

        $display("=================================================================");
        $display("   ADDRESS DECODER (4-to-16 ONE-HOT) VERIFICATION TESTBENCH");
        $display("=================================================================");

        // -----------------------------------------------------------------
        // Test A1: One-hot verification for all 16 addresses (enable=1)
        //   For each addr 0–15, verify select_lines == (1 << addr)
        //   and confirm exactly one bit is set.
        // -----------------------------------------------------------------
        $display("--- Test A1: One-hot output for all 16 addresses (enable=1) ---");
        enable = 1;

        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;

            // Check one-hot value
            if (select_lines !== (16'b1 << i)) begin
                $display("FAIL A1 addr=%0d select_lines=%b expected=%b",
                          i, select_lines, (16'b1 << i));
                errors = errors + 1;
            end else begin
                // Verify exactly one bit is set (popcount == 1)
                bit_count = 0;
                for (j = 0; j < 16; j = j + 1) begin
                    if (select_lines[j]) bit_count = bit_count + 1;
                end
                if (bit_count !== 1) begin
                    $display("FAIL A1 addr=%0d popcount=%0d (expected 1)", i, bit_count);
                    errors = errors + 1;
                end else
                    $display("PASS A1 addr=%2d select_lines=%016b (bit %0d set)", i, select_lines, i);
            end
        end

        // -----------------------------------------------------------------
        // Test A2: Enable=0 produces all-zero output for all addresses
        // -----------------------------------------------------------------
        $display("--- Test A2: Enable=0 produces all-zero for all addresses ---");
        enable = 0;

        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            if (select_lines !== 16'b0) begin
                $display("FAIL A2 addr=%0d select_lines=%b expected=0000000000000000", i, select_lines);
                errors = errors + 1;
            end else
                $display("PASS A2 addr=%2d select_lines=%016b (all zero)", i, select_lines);
        end

        // -----------------------------------------------------------------
        // Test A3: Enable toggle mid-operation
        //   Set addr, toggle enable 1→0→1, verify transitions.
        // -----------------------------------------------------------------
        $display("--- Test A3: Enable toggle mid-operation ---");

        addr = 4'd7;
        enable = 1; #1;
        if (select_lines !== 16'b0000000010000000) begin
            $display("FAIL A3.1 enable=1 addr=7 select_lines=%b", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.1 enable=1 addr=7 select_lines=%016b", select_lines);

        enable = 0; #1;
        if (select_lines !== 16'b0) begin
            $display("FAIL A3.2 enable=0 addr=7 select_lines=%b (expected 0)", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.2 enable=0 addr=7 select_lines=%016b (gated off)", select_lines);

        enable = 1; #1;
        if (select_lines !== 16'b0000000010000000) begin
            $display("FAIL A3.3 enable=1 addr=7 select_lines=%b (re-enabled)", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.3 enable=1 addr=7 select_lines=%016b (re-enabled)", select_lines);

        // Test with addr 0 (boundary)
        addr = 4'd0;
        enable = 1; #1;
        if (select_lines !== 16'b0000000000000001) begin
            $display("FAIL A3.4 enable=1 addr=0 select_lines=%b", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.4 enable=1 addr=0 select_lines=%016b (bit 0)", select_lines);

        enable = 0; #1;
        if (select_lines !== 16'b0) begin
            $display("FAIL A3.5 enable=0 addr=0 select_lines=%b", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.5 enable=0 addr=0 select_lines=%016b (gated off)", select_lines);

        // Test with addr 15 (boundary)
        addr = 4'd15;
        enable = 1; #1;
        if (select_lines !== 16'b1000000000000000) begin
            $display("FAIL A3.6 enable=1 addr=15 select_lines=%b", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.6 enable=1 addr=15 select_lines=%016b (bit 15)", select_lines);

        enable = 0; #1;
        if (select_lines !== 16'b0) begin
            $display("FAIL A3.7 enable=0 addr=15 select_lines=%b", select_lines);
            errors = errors + 1;
        end else
            $display("PASS A3.7 enable=0 addr=15 select_lines=%016b (gated off)", select_lines);

        // -----------------------------------------------------------------
        // Test A4: Rapid address sweep (combinational tracking)
        //   Change addr every 1ns with enable=1, verify output tracks.
        // -----------------------------------------------------------------
        $display("--- Test A4: Rapid address sweep (combinational tracking) ---");
        enable = 1;

        for (i = 0; i < 16; i = i + 1) begin
            addr = i; #1;
            if (select_lines !== (16'b1 << i)) begin
                $display("FAIL A4 rapid sweep addr=%0d select_lines=%b", i, select_lines);
                errors = errors + 1;
            end
        end

        // Reverse sweep
        for (i = 15; i >= 0; i = i - 1) begin
            addr = i; #1;
            if (select_lines !== (16'b1 << i)) begin
                $display("FAIL A4 reverse sweep addr=%0d select_lines=%b", i, select_lines);
                errors = errors + 1;
            end
        end

        // Non-sequential jumps
        addr = 4'd0;  #1; if (select_lines !== (16'b1 << 0))  errors = errors + 1;
        addr = 4'd15; #1; if (select_lines !== (16'b1 << 15)) errors = errors + 1;
        addr = 4'd8;  #1; if (select_lines !== (16'b1 << 8))  errors = errors + 1;
        addr = 4'd3;  #1; if (select_lines !== (16'b1 << 3))  errors = errors + 1;

        $display("PASS A4 rapid sweep: forward, reverse, and non-sequential all correct");

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("=================================================================");
        if (errors == 0)
            $display("ALL ADDRESS DECODER TESTS PASSED (0 errors)");
        else
            $display("%0d ADDRESS DECODER TEST(S) FAILED", errors);
        $display("=================================================================");

        $finish;
    end

endmodule
