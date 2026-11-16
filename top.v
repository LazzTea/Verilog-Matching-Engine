module top (
    input wire clk,
    input wire reset_button,
    input wire next_button,
    output wire vga_hsync,
    output wire vga_vsync,
    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue
);
    localparam integer STOCK_COUNT = 16;
    localparam integer GRAPH_POINTS = 32;

    reg [3:0] selected_stock;
    wire next_stock_pressed;
    wire [GRAPH_POINTS * STOCK_COUNT * 10 - 1:0] demo_graph_history;

    debouncer next_stock_debouncer (
        .clk(clk),
        .rst(reset_button),
        .button_async(next_button),
        .button_state(),
        .button_pressed(next_stock_pressed)
    );

    always @(posedge clk) begin
        if (reset_button)
            selected_stock <= 4'd0;
        else if (next_stock_pressed)
            selected_stock <= selected_stock + 1'b1;
    end

    function [31:0] ticker_for_stock;
        input [3:0] stock;
        begin
            case (stock)
                4'd0: ticker_for_stock = "AAPL";
                4'd1: ticker_for_stock = "MSFT";
                4'd2: ticker_for_stock = "GOOG";
                4'd3: ticker_for_stock = "AMZN";
                4'd4: ticker_for_stock = "NVDA";
                4'd5: ticker_for_stock = "TSLA";
                4'd6: ticker_for_stock = "META";
                4'd7: ticker_for_stock = "NFLX";
                4'd8: ticker_for_stock = "INTC";
                4'd9: ticker_for_stock = "AMD ";
                4'd10: ticker_for_stock = "ORCL";
                4'd11: ticker_for_stock = "IBM ";
                4'd12: ticker_for_stock = "JPM ";
                4'd13: ticker_for_stock = "DIS ";
                4'd14: ticker_for_stock = "BA  ";
                default: ticker_for_stock = "KO  ";
            endcase
        end
    endfunction

    function [9:0] demo_price;
        input integer stock;
        input integer sample;
        integer triangle;
        begin
            if ((sample % 16) < 8)
                triangle = sample % 16;
            else
                triangle = 15 - (sample % 16);
            demo_price = 250 + stock * 20 + triangle * 35 + sample * 2;
        end
    endfunction

    genvar stock_index;
    genvar sample_index;
    generate
        for (stock_index = 0; stock_index < STOCK_COUNT;
             stock_index = stock_index + 1) begin : stock_history
            for (sample_index = 0; sample_index < GRAPH_POINTS;
                 sample_index = sample_index + 1) begin : sample_history
                assign demo_graph_history[
                    (stock_index * GRAPH_POINTS + sample_index) * 10 +: 10
                ] = demo_price(stock_index, sample_index);
            end
        end
    endgenerate

    wire [9:0] x_unused;
    wire [9:0] y_unused;
    wire video_on_unused;

    graphics #(
        .GRAPH_POINTS(GRAPH_POINTS),
        .GRAPH_STOCKS(STOCK_COUNT)
    ) display (
        .clk(clk),
        .rst(reset_button),
        .mock_valid(6'b111111),
        .mock_is_bid(6'b111000),
        .mock_price_bcd({
            16'h0995, 16'h0998, 16'h1005,
            16'h1012, 16'h1010, 16'h1008
        }),
        .mock_quantity_bcd({
            12'h075, 12'h150, 12'h042,
            12'h200, 12'h085, 12'h120
        }),
        .mock_symbol(ticker_for_stock(selected_stock)),
        .selected_stock(selected_stock),
        .mock_graph_price_history(demo_graph_history),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .x(x_unused),
        .y(y_unused),
        .video_on(video_on_unused),
        .red(vga_red),
        .green(vga_green),
        .blue(vga_blue)
    );
endmodule
