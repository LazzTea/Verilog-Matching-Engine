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
    // Display and graph dimensions. The order book uses one 4-bit symbol ID
    // for each stock shown by the selector.
    localparam integer STOCK_COUNT = 16;
    localparam integer GRAPH_POINTS = 32;

    // Controller phases for seeding a demo book, then reading its ask and bid
    // sides into registers consumed by graphics.
    localparam [3:0] ST_IDLE       = 4'd0,
                     ST_SEED_READY = 4'd1,
                     ST_SEED_SEND  = 4'd2,
                     ST_SEED_BUSY  = 4'd3,
                     ST_SEED_WAIT  = 4'd4,
                     ST_ASK_START  = 4'd5,
                     ST_ASK_WAIT   = 4'd6,
                     ST_BID_START  = 4'd7,
                     ST_BID_WAIT   = 4'd8;

    // selected_stock follows button presses; display_stock changes only after
    // the corresponding book rows have been collected.
    reg [3:0] selected_stock;
    reg [3:0] display_stock;
    reg [3:0] active_stock;
    reg [3:0] controller_state;
    reg [2:0] seed_index;
    reg [1:0] row_index;
    reg [3:0] read_timer;
    reg [STOCK_COUNT-1:0] stock_seeded;

    // Order-book write and read-port signals.
    wire next_stock_pressed;
    reg [GRAPH_POINTS * STOCK_COUNT * 10 - 1:0] graph_history;
    wire [31:0] ticker_symbol;

    wire order_in_ready;
    wire order_in_valid = (controller_state == ST_SEED_SEND);
    wire [3:0] order_symbol = active_stock;
    wire order_buy = (seed_index >= 3);
    wire [9:0] order_price = seed_price(active_stock, seed_index);
    wire [8:0] order_qty = seed_quantity(active_stock, seed_index);

    // Port B reads one side of the selected stock. Each returned order is
    // packed as {next pointer, quantity, price, valid}.
    reg [3:0] request_symbol;
    reg request_buy;
    reg [11:0] request_num;
    wire [31:0] request_order;
    wire request_order_valid;
    wire [19:0] transaction;
    wire transaction_valid;
    reg [3:0] trade_symbol;

    // Graphics expects six rows (three asks, then three bids), with price and
    // quantity in packed BCD rather than the order book's binary fields.
    reg [5:0] display_valid;
    reg [95:0] display_price_bcd;
    reg [71:0] display_quantity_bcd;
    wire [2:0] display_row = request_buy ?
                             (row_index + 3'd3) : {1'b0, row_index};

    // Keep the displayed ticker names aligned with the symbol IDs used by the
    // selector and order book.
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

    // Generate a demo spread for each stock: the first three orders are asks
    // and the remaining three are bids.
    function [9:0] seed_price;
        input [3:0] stock;
        input [2:0] index;
        integer midpoint;
        begin
            midpoint = 500 + stock * 12;
            if (index < 3)
                seed_price = midpoint + 4 + index * 2;
            else
                seed_price = midpoint - 4 - (index - 3) * 2;
        end
    endfunction

    // Deterministic demo quantities make it possible to exercise the book and
    // display without an external order-entry interface.
    function [8:0] seed_quantity;
        input [3:0] stock;
        input [2:0] index;
        begin
            seed_quantity = 80 + ((stock * 7 + index * 23) % 300);
        end
    endfunction

    // Convert a 10-bit binary value (0-1023) to four decimal BCD digits using
    // the shift-and-add-3 (double-dabble) algorithm.
    function [15:0] binary_to_bcd;
        input [9:0] binary_value;
        reg [19:0] digits;
        integer bit_index;
        begin
            digits = 20'd0;
            for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
                if (digits[3:0] >= 5)
                    digits[3:0] = digits[3:0] + 4'd3;
                if (digits[7:4] >= 5)
                    digits[7:4] = digits[7:4] + 4'd3;
                if (digits[11:8] >= 5)
                    digits[11:8] = digits[11:8] + 4'd3;
                if (digits[15:12] >= 5)
                    digits[15:12] = digits[15:12] + 4'd3;
                if (digits[19:16] >= 5)
                    digits[19:16] = digits[19:16] + 4'd3;
                digits = {digits[18:0], binary_value[9-bit_index]};
            end
            binary_to_bcd = digits[15:0];
        end
    endfunction

    // Initial graph curve shown until actual trades arrive for a stock.
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

    // Debounce the stock-advance button and wrap naturally through all 16 IDs.
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

    // Remember the symbol of the submitted order so its resulting trade can
    // be appended to the correct per-stock graph history.
    always @(posedge clk) begin
        if (reset_button)
            trade_symbol <= 4'd0;
        else if (order_in_valid && order_in_ready)
            trade_symbol <= order_symbol;
    end

    // The top-level demo only sends its generated seed orders; display reads
    // share the order book's independent Port B.
    order_book book (
        .clk(clk),
        .rst(reset_button),
        .in_valid(order_in_valid),
        .in_ready(order_in_ready),
        .symbol(order_symbol),
        .buy(order_buy),
        .price(order_price),
        .qty(order_qty),
        .transaction(transaction),
        .trans_valid(transaction_valid),
        .rest_id(),
        .rest_valid(),
        .full(),
        .request_symbol(request_symbol),
        .request_buy(request_buy),
        .request_num(request_num),
        .req_out(request_order),
        .req_out_valid(request_order_valid)
    );

    // Coordinate order insertion and display reads. The short timeout handles
    // empty sides because Port B does not signal completion for an empty list.
    always @(posedge clk) begin
        if (reset_button) begin
            display_stock <= 4'hf;
            active_stock <= 4'd0;
            controller_state <= ST_IDLE;
            seed_index <= 3'd0;
            row_index <= 2'd0;
            read_timer <= 4'd0;
            stock_seeded <= {STOCK_COUNT{1'b0}};
            request_symbol <= 4'd0;
            request_buy <= 1'b0;
            request_num <= 12'd0;
            display_valid <= 6'd0;
            display_price_bcd <= 96'd0;
            display_quantity_bcd <= 72'd0;
        end else begin
            case (controller_state)
                ST_IDLE: begin
                    if (display_stock != selected_stock) begin
                        // Clear old rows immediately so a stock never briefly
                        // appears with another stock's prices.
                        active_stock <= selected_stock;
                        display_valid <= 6'd0;
                        display_price_bcd <= 96'd0;
                        display_quantity_bcd <= 72'd0;
                        seed_index <= 3'd0;
                        row_index <= 2'd0;
                        if (stock_seeded[selected_stock])
                            controller_state <= ST_ASK_START;
                        else
                            controller_state <= ST_SEED_READY;
                    end
                end

                ST_SEED_READY: begin
                    // Wait for the order book to accept each demo order.
                    if (order_in_ready)
                        controller_state <= ST_SEED_SEND;
                end

                ST_SEED_SEND: begin
                    // Keep in_valid asserted for one clock edge, then wait
                    // until the book has completed matching/insertion.
                    controller_state <= ST_SEED_BUSY;
                end

                ST_SEED_BUSY: begin
                    if (!order_in_ready)
                        controller_state <= ST_SEED_WAIT;
                end

                ST_SEED_WAIT: begin
                    if (order_in_ready) begin
                        if (seed_index == 3'd5) begin
                            stock_seeded[active_stock] <= 1'b1;
                            controller_state <= ST_ASK_START;
                        end else begin
                            seed_index <= seed_index + 1'b1;
                            controller_state <= ST_SEED_READY;
                        end
                    end
                end

                ST_ASK_START: begin
                    // Read up to three sell orders into display rows 0-2.
                    request_symbol <= active_stock;
                    request_buy <= 1'b0;
                    request_num <= 12'd3;
                    row_index <= 2'd0;
                    read_timer <= 4'd0;
                    controller_state <= ST_ASK_WAIT;
                end

                ST_ASK_WAIT: begin
                    request_num <= 12'd0;
                    if (request_order_valid) begin
                        if (row_index < 3) begin
                            // Convert and store the returned binary values.
                            display_valid[display_row] <= request_order[0];
                            display_price_bcd[display_row * 16 +: 16] <=
                                binary_to_bcd({1'b0, request_order[10:1]});
                            display_quantity_bcd[display_row * 12 +: 12] <=
                                binary_to_bcd({1'b0, request_order[19:11]});
                        end
                        if (row_index == 2 ||
                            request_order[31:20] == 12'hfff) begin
                            request_buy <= 1'b1;
                            row_index <= 2'd0;
                            read_timer <= 4'd0;
                            controller_state <= ST_BID_START;
                        end else begin
                            row_index <= row_index + 1'b1;
                        end
                    end else if (read_timer == 4'd8) begin
                        request_buy <= 1'b1;
                        row_index <= 2'd0;
                        read_timer <= 4'd0;
                        controller_state <= ST_BID_START;
                    end else begin
                        read_timer <= read_timer + 1'b1;
                    end
                end

                ST_BID_START: begin
                    // Read up to three buy orders into display rows 3-5.
                    request_symbol <= active_stock;
                    request_buy <= 1'b1;
                    request_num <= 12'd3;
                    row_index <= 2'd0;
                    read_timer <= 4'd0;
                    controller_state <= ST_BID_WAIT;
                end

                ST_BID_WAIT: begin
                    request_num <= 12'd0;
                    if (request_order_valid) begin
                        if (row_index < 3) begin
                            display_valid[display_row] <= request_order[0];
                            display_price_bcd[display_row * 16 +: 16] <=
                                binary_to_bcd({1'b0, request_order[10:1]});
                            display_quantity_bcd[display_row * 12 +: 12] <=
                                binary_to_bcd({1'b0, request_order[19:11]});
                        end
                        if (row_index == 2 ||
                            request_order[31:20] == 12'hfff) begin
                            display_stock <= active_stock;
                            controller_state <= ST_IDLE;
                        end else begin
                            row_index <= row_index + 1'b1;
                        end
                    end else if (read_timer == 4'd8) begin
                        display_stock <= active_stock;
                        controller_state <= ST_IDLE;
                    end else begin
                        read_timer <= read_timer + 1'b1;
                    end
                end

                default: controller_state <= ST_IDLE;
            endcase
        end
    end

    assign ticker_symbol = ticker_for_stock(display_stock);

    // Seed every graph with a visible demo trace on reset. Each accepted
    // transaction shifts that stock's trace left and appends the trade price.
    genvar stock_index;
    generate
        for (stock_index = 0; stock_index < STOCK_COUNT;
             stock_index = stock_index + 1) begin : stock_history
            integer history_sample;
            always @(posedge clk) begin
                if (reset_button) begin
                    for (history_sample = 0;
                         history_sample < GRAPH_POINTS;
                         history_sample = history_sample + 1) begin
                        graph_history[
                            (stock_index * GRAPH_POINTS + history_sample) * 10
                            +: 10
                        ] <= demo_price(stock_index, history_sample);
                    end
                end else if (transaction_valid &&
                             trade_symbol == stock_index) begin
                    for (history_sample = 0;
                         history_sample < GRAPH_POINTS - 1;
                         history_sample = history_sample + 1) begin
                        graph_history[
                            (stock_index * GRAPH_POINTS + history_sample) * 10
                            +: 10
                        ] <= graph_history[
                            (stock_index * GRAPH_POINTS + history_sample + 1) * 10
                            +: 10
                        ];
                    end
                    graph_history[
                        (stock_index * GRAPH_POINTS + GRAPH_POINTS - 1) * 10
                        +: 10
                    ] <= transaction[10:1];
                end
            end
        end
    endgenerate

    wire [GRAPH_POINTS * STOCK_COUNT * 10 - 1:0] graph_history_data;
    assign graph_history_data = graph_history;

    // The VGA counters are internal to graphics; only sync and color outputs
    // leave this top-level module.
    wire [9:0] x_unused;
    wire [9:0] y_unused;
    wire video_on_unused;

    graphics #(
        .GRAPH_POINTS(GRAPH_POINTS),
        .GRAPH_STOCKS(STOCK_COUNT)
    ) display (
        .clk(clk),
        .rst(reset_button),
        .mock_valid(display_valid),
        .mock_is_bid(6'b111000),
        .mock_price_bcd(display_price_bcd),
        .mock_quantity_bcd(display_quantity_bcd),
        .mock_symbol(ticker_symbol),
        .selected_stock(display_stock),
        .mock_graph_price_history(graph_history_data),
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
