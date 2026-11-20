`timescale 1ns/1ps

module uart_command_parser_tb;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [7:0] byte_data = 8'd0;
    reg byte_valid = 1'b0;
    reg order_ready = 1'b0;
    wire order_valid;
    wire [3:0] order_symbol;
    wire order_buy;
    wire [9:0] order_price;
    wire [8:0] order_qty;
    wire command_error;
    integer error_count = 0;

    uart_command_parser dut (
        .clk(clk),
        .rst(rst),
        .byte_data(byte_data),
        .byte_valid(byte_valid),
        .order_valid(order_valid),
        .order_ready(order_ready),
        .order_symbol(order_symbol),
        .order_buy(order_buy),
        .order_price(order_price),
        .order_qty(order_qty),
        .command_error(command_error)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst && command_error)
            error_count = error_count + 1;
    end

    task send_char;
        input [7:0] character;
        begin
            @(negedge clk);
            byte_data = character;
            byte_valid = 1'b1;
            @(negedge clk);
            byte_valid = 1'b0;
        end
    endtask

    task send_line;
        input [255:0] characters;
        input integer length;
        integer character_index;
        begin
            for (character_index = 0; character_index < length;
                 character_index = character_index + 1)
                send_char(characters[8 * (length - character_index - 1) +: 8]);
        end
    endtask

    task accept_order;
        begin
            @(negedge clk);
            order_ready = 1'b1;
            @(negedge clk);
            order_ready = 1'b0;
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_line("B,AAPL,1005,42\n", 15);
        while (!order_valid)
            @(negedge clk);
        #1;
        if (order_symbol !== 4'd0 || order_buy !== 1'b1 ||
            order_price !== 10'd1005 || order_qty !== 9'd42)
            $fatal(1, "Parser decoded the AAPL buy command incorrectly");
        repeat (3) @(negedge clk);
        if (!order_valid || order_price !== 10'd1005 || order_qty !== 9'd42)
            $fatal(1, "Parser did not hold the order until accepted");
        accept_order();

        send_line("S,AMD,999,511", 13);
        send_char(8'h0d);
        send_char(8'h0a);
        while (!order_valid)
            @(negedge clk);
        #1;
        if (order_symbol !== 4'd9 || order_buy !== 1'b0 ||
            order_price !== 10'd999 || order_qty !== 9'd511)
            $fatal(1, "Parser decoded the AMD sell command incorrectly");
        accept_order();

        send_line("B,NOPE,100,1\n", 13);
        repeat (2) @(negedge clk);
        if (order_valid || error_count != 1)
            $fatal(1, "Parser did not reject an unknown ticker");

        send_line("B,KO,1024,1\n", 12);
        repeat (2) @(negedge clk);
        if (order_valid || error_count != 2)
            $fatal(1, "Parser did not reject an out-of-range price");

        $display("PASS: command parser decodes orders, holds them for handshake, and rejects invalid input");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Command parser testbench timeout");
    end
endmodule
