`timescale 1ns / 1ps

module tb;
    reg         clk = 0;
    reg         rst = 1;
    reg  [7:0]  ch = 0;
    reg         valid_ch = 0;

    wire [31:0] symbol;
    wire        buy;
    wire [9:0]  price;
    wire [8:0]  qty;
    wire        valid;
    wire        valid_i;

    user_ctrls dut (
        .clk(clk), .rst(rst),
        .ch(ch), .valid_ch(valid_ch),
        .symbol(symbol), .buy(buy), .price(price), .qty(qty),
        .valid(valid), .valid_i(valid_i)
    );

    always #5 clk = ~clk;

    // Idle cycles between characters.
    localparam GAP = 20;

    localparam [7:0] CR = 8'h0D;
    localparam [7:0] LF = 8'h0A;

    // Output monitor: count pulses and capture outputs
    integer     n_order = 0;
    integer     n_info  = 0;
    reg [31:0]  cap_symbol;
    reg         cap_buy;
    reg [9:0]   cap_price;
    reg [8:0]   cap_qty;

    integer     pass_cnt = 0;
    integer     fail_cnt = 0;

    always @(posedge clk) begin
        if (valid && valid_i) begin
            $display("  FAIL: valid and valid_i high in the same cycle at %0t", $time);
            fail_cnt = fail_cnt + 1;
        end
        if (valid) begin
            n_order    = n_order + 1;
            cap_symbol = symbol;
            cap_buy    = buy;
            cap_price  = price;
            cap_qty    = qty;
        end
        if (valid_i) begin
            n_info     = n_info + 1;
            cap_symbol = symbol;
        end
    end

    // ---------------------------------------------------------------
    // Stimulus tasks
    // ---------------------------------------------------------------

    // Send one byte as a single-cycle valid_ch pulse (like a UART RX)
    task send_byte(input [7:0] b);
        begin
            @(negedge clk);
            ch       = b;
            valid_ch = 1;
            @(negedge clk);
            valid_ch = 0;
            repeat (GAP) @(negedge clk);
        end
    endtask

    // Send a string (no terminator). Length is found automatically:
    // Verilog string literals are right-aligned with zero padding.
    task send_str(input [8*32-1:0] s);
        integer k, len;
        begin
            len = 0;
            for (k = 0; k < 32; k = k + 1)
                if (s[k*8 +: 8] != 8'h00) len = k + 1;
            for (k = len - 1; k >= 0; k = k - 1)
                send_byte(s[k*8 +: 8]);
        end
    endtask

    // Send a string followed by a line ending
    // ending: 0 = CR, 1 = LF, 2 = CR+LF
    task send_line(input [8*32-1:0] s, input integer ending);
        begin
            send_str(s);
            if (ending == 0 || ending == 2) send_byte(CR);
            if (ending == 1 || ending == 2) send_byte(LF);
            repeat (GAP) @(negedge clk);
        end
    endtask

    task clear_counts;
        begin
            n_order = 0;
            n_info  = 0;
        end
    endtask

    // ---------------------------------------------------------------
    // Check tasks
    // ---------------------------------------------------------------
    task expect_order(input [8*32-1:0] name,
                    input [31:0] e_sym, input e_buy,
                    input [9:0] e_price, input [8:0] e_qty);
        begin
            if (n_order == 1 && n_info == 0 &&
                cap_symbol == e_sym && cap_buy == e_buy &&
                cap_price == e_price && cap_qty == e_qty) begin
                $display("  PASS: %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL: %0s", name);
                $display("        expected 1 order %s buy=%0d price=%0d qty=%0d, 0 info",
                        e_sym, e_buy, e_price, e_qty);
                $display("        got %0d order(s), %0d info; last %s buy=%0d price=%0d qty=%0d",
                        n_order, n_info, cap_symbol, cap_buy, cap_price, cap_qty);
                fail_cnt = fail_cnt + 1;
            end
            clear_counts;
        end
    endtask

    task expect_info(input [8*32-1:0] name, input [31:0] e_sym);
        begin
            if (n_info == 1 && n_order == 0 && cap_symbol == e_sym) begin
                $display("  PASS: %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL: %0s", name);
                $display("        expected 1 info %s, 0 orders", e_sym);
                $display("        got %0d info, %0d order(s); last symbol %s",
                        n_info, n_order, cap_symbol);
                fail_cnt = fail_cnt + 1;
            end
            clear_counts;
        end
    endtask

    task expect_none(input [8*32-1:0] name);
        begin
            if (n_order == 0 && n_info == 0) begin
                $display("  PASS: %0s", name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL: %0s", name);
                $display("        expected no pulses, got %0d order(s), %0d info",
                        n_order, n_info);
                fail_cnt = fail_cnt + 1;
            end
            clear_counts;
        end
    endtask

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------
    initial begin
        // Reset
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (3) @(negedge clk);
        clear_counts;

        $display("\n--- Valid orders ---");
        send_line("buy ABCD 1 1", 0);
        expect_order("shortest buy", "ABCD", 1, 1, 1);

        send_line("sell WXYZ 999 511", 0);
        expect_order("longest sell", "WXYZ", 0, 999, 511);

        send_line("buy ABCD 123 5", 0);
        expect_order("3-digit price", "ABCD", 1, 123, 5);

        send_line("sell QQQQ 7 42", 0);
        expect_order("2-digit qty", "QQQQ", 0, 7, 42);

        send_line("buy ABCD 10 50", 0);
        expect_order("zeros in digits", "ABCD", 1, 10, 50);

        send_line("buy ABCD 0 0", 0);
        expect_order("zero price and qty", "ABCD", 1, 0, 0);

        $display("\n--- Quantity clamping ---");
        send_line("buy ABCD 5 512", 0);
        expect_order("qty 512 clamps to 511", "ABCD", 1, 5, 511);

        send_line("sell ABCD 999 999", 0);
        expect_order("qty 999 clamps to 511", "ABCD", 0, 999, 511);

        $display("\n--- Line endings ---");
        send_line("buy ABCD 12 34", 1);
        expect_order("LF only", "ABCD", 1, 12, 34);

        send_line("buy ABCD 12 34", 2);
        expect_order("CR+LF gives one pulse", "ABCD", 1, 12, 34);

        send_byte(CR); send_byte(LF); send_byte(CR);
        repeat (GAP) @(negedge clk);
        expect_none("blank lines ignored");

        send_line("buy ABCD 21 43", 2);
        expect_order("order after blank lines", "ABCD", 1, 21, 43);

        $display("\n--- Info command ---");
        send_line("info WXYZ", 0);
        expect_info("info WXYZ", "WXYZ");

        send_line("info ABCD", 2);
        expect_info("info with CR+LF", "ABCD");

        send_line("info WXY", 0);
        expect_none("info 3-char symbol");

        send_line("info WXYZ1", 0);
        expect_none("info 5-char symbol");

        send_line("infoXWXYZ", 0);
        expect_none("info missing space");

        send_line("inf WXYZ", 0);
        expect_none("misspelled info");

        $display("\n--- Malformed orders ---");
        send_line("buy ABCD 12", 0);
        expect_none("too short / missing qty");

        send_line("buy ABCD 12 ", 0);
        expect_none("missing qty after space");

        send_line("buy ABCD 1 1234", 0);
        expect_none("4-digit qty");

        send_line("buy ABCD 1234 1", 0);
        expect_none("4-digit price");

        send_line("buy ABCD 1x 1", 0);
        expect_none("non-digit in price");

        send_line("buy ABCD 1 1x", 0);
        expect_none("non-digit in qty");

        send_line("buy ABCD  1 1", 0);
        expect_none("double space before price");

        send_line("buy ABCD 1  1", 0);
        expect_none("double space before qty");

        send_line("buyXABCD 1 1", 0);
        expect_none("missing space after command");

        send_line("buy ABCDE 1 1", 0);
        expect_none("5-char symbol");

        send_line("buy ABCD 1 1 ", 0);
        expect_none("trailing space");

        send_line("bye ABCD 1 1", 0);
        expect_none("bad command starting with b");

        send_line("sel ABCD 1 1", 0);
        expect_none("bad command starting with s");

        send_line("xbuy ABCD 1 1", 0);
        expect_none("bad first character");

        send_line("sell ABCD 999 9999", 0);
        expect_none("overflow past buffer");

        send_line("sell ABCD 999 999 99999", 0);
        expect_none("long overflow past buffer");

        $display("\n--- Recovery ---");
        send_line("buy ABCD 5 6", 0);
        expect_order("order after bad lines", "ABCD", 1, 5, 6);

        send_str("buy AB");
        @(negedge clk); rst = 1;
        repeat (2) @(negedge clk); rst = 0;
        repeat (2) @(negedge clk);
        clear_counts;
        send_line("sell WXYZ 8 9", 0);
        expect_order("reset mid-line", "WXYZ", 0, 8, 9);

        send_line("info ABCD", 0);
        send_line("buy WXYZ 3 4", 0);
        if (n_info == 1 && n_order == 1 && cap_symbol == "WXYZ" && cap_buy == 1 &&
            cap_price == 3 && cap_qty == 4) begin
            $display("  PASS: info then order back to back");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL: info then order back to back (%0d info, %0d orders)",
                    n_info, n_order);
            fail_cnt = fail_cnt + 1;
        end
        clear_counts;

        // Summary
        $display("\n=======================================");
        $display("  %0d passed, %0d failed", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  SOME TESTS FAILED");
        $display("=======================================\n");
        $finish;
    end

    // Safety timeout
    initial begin
        #50_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule