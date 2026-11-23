`timescale 1ns/1ps

module top_tb;
    reg clk = 1'b0;
    reg reset_button = 1'b1;
    reg next_button = 1'b0;
    reg uart_rxd = 1'b1;
    wire uart_txd;
    wire vga_hsync;
    wire vga_vsync;
    wire [3:0] vga_red;
    wire [3:0] vga_green;
    wire [3:0] vga_blue;
    integer cycles;
    integer bit_index;

    top dut (
        .clk(clk),
        .reset_button(reset_button),
        .next_button(next_button),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

    always #5 clk = ~clk;

    task send_uart_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            uart_rxd = 1'b0;
            repeat (868) @(negedge clk);
            for (bit_index = 0; bit_index < 8;
                 bit_index = bit_index + 1) begin
                uart_rxd = value[bit_index];
                repeat (868) @(negedge clk);
            end
            uart_rxd = 1'b1;
            repeat (868) @(negedge clk);
        end
    endtask

    task send_test_order;
        begin
            send_uart_byte(8'h42); // B
            send_uart_byte(8'h2c); // ,
            send_uart_byte(8'h41); // A
            send_uart_byte(8'h41); // A
            send_uart_byte(8'h50); // P
            send_uart_byte(8'h4c); // L
            send_uart_byte(8'h2c); // ,
            send_uart_byte(8'h35); // 5
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h30); // 0
            send_uart_byte(8'h2c); // ,
            send_uart_byte(8'h34); // 4
            send_uart_byte(8'h32); // 2
            send_uart_byte(8'h0d); // CR, as sent by PuTTY's Enter key
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        reset_button = 1'b0;

        cycles = 0;
        while (!(dut.display_stock == 4'd0 &&
                 dut.display_valid == 6'b111111) && cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (cycles == 1000)
            $fatal(1, "Timed out waiting for order-book rows");

        if (dut.display_price_bcd[15:0] !== 16'h0504 ||
            dut.display_price_bcd[31:16] !== 16'h0506 ||
            dut.display_price_bcd[47:32] !== 16'h0508 ||
            dut.display_price_bcd[63:48] !== 16'h0496 ||
            dut.display_price_bcd[79:64] !== 16'h0494 ||
            dut.display_price_bcd[95:80] !== 16'h0492)
            $fatal(1, "Unexpected BCD prices: %h", dut.display_price_bcd);

        if (dut.display_quantity_bcd[11:0] !== 12'h080 ||
            dut.display_quantity_bcd[23:12] !== 12'h103 ||
            dut.display_quantity_bcd[35:24] !== 12'h126 ||
            dut.display_quantity_bcd[47:36] !== 12'h149 ||
            dut.display_quantity_bcd[59:48] !== 12'h172 ||
            dut.display_quantity_bcd[71:60] !== 12'h195)
            $fatal(1, "Unexpected BCD quantities: %h",
                   dut.display_quantity_bcd);

        if (dut.display_depth_prices[9:0] !== 10'd504 ||
            dut.display_depth_prices[19:10] !== 10'd506 ||
            dut.display_depth_prices[29:20] !== 10'd508 ||
            dut.display_depth_prices[39:30] !== 10'd496 ||
            dut.display_depth_prices[49:40] !== 10'd494 ||
            dut.display_depth_prices[59:50] !== 10'd492)
            $fatal(1, "Unexpected raw prices passed to the depth chart");

        if (dut.display_depth_quantities[8:0] !== 9'd80 ||
            dut.display_depth_quantities[17:9] !== 9'd103 ||
            dut.display_depth_quantities[26:18] !== 9'd126 ||
            dut.display_depth_quantities[35:27] !== 9'd149 ||
            dut.display_depth_quantities[44:36] !== 9'd172 ||
            dut.display_depth_quantities[53:45] !== 9'd195)
            $fatal(1, "Unexpected raw quantities passed to the depth chart");

        send_test_order();
        cycles = 0;
        while (dut.display_price_bcd[63:48] !== 16'h0500 &&
               cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 1000)
            $fatal(1, "Displayed order book did not refresh after UART order");
        if (dut.display_price_bcd[79:64] !== 16'h0496 ||
            dut.display_price_bcd[95:80] !== 16'h0494)
            $fatal(1, "UART order did not shift the displayed bid levels");

        if (vga_hsync === 1'bx || vga_vsync === 1'bx)
            $fatal(1, "VGA sync outputs contain unknown values");
        if (uart_txd !== 1'b1)
            $fatal(1, "UART transmit line should idle high before UART TX is added");

        force dut.transaction = {9'd1, 10'd777, 1'b0};
        force dut.transaction_valid = 1'b1;
        force dut.trade_symbol = 4'd0;
        @(posedge clk);
        #1;
        if (dut.graph_history[190 +: 10] !== 10'd777)
            $fatal(1, "Trade price was not appended to the selected stock graph");
        release dut.transaction;
        release dut.transaction_valid;
        release dut.trade_symbol;

        force dut.selected_stock = 4'd1;
        @(posedge clk);
        #1;
        release dut.selected_stock;

        cycles = 0;
        while (!(dut.display_stock == 4'd1 &&
                 dut.display_valid == 6'b111111) && cycles < 1000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        if (cycles == 1000)
            $fatal(1, "Timed out waiting for the second stock's order-book rows");
        if (dut.ticker_symbol !== "MSFT" ||
            dut.display_price_bcd[15:0] !== 16'h0516 ||
            dut.display_price_bcd[63:48] !== 16'h0508)
            $fatal(1, "Second stock selection did not load matching book data");

        $display("PASS: top loads book rows, converts BCD, selects stocks, and appends trades to graph history.");
        $finish;
    end
endmodule
