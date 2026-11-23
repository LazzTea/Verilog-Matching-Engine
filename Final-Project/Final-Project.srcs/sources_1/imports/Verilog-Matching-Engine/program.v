module program();

// Takes in User Input
user_ctrls uc (
    .clk(clk), .rst(rst),

    .ch(), .valid_ch(),

    .symbol(), .buy(),
    .price(), .qty(),

    .valid(), .valid_i()
);

// Converts String to Symbol
symbol_conversion #(
    .NUM_TICKERS(5),
    .PTICKERS("AAPLMSFTGOOGAMZNNVDA")
) sc (
    .ticker(),
    .symbol(), .valid()
);

// Order Book Data Structure
order_book #(
    .BOOK_FILE("tables/order_book.mem"),
    .HEAD_FILE("tables/head_table.mem"),
    .PRELOAD_COUNT(5)
) ob (
    .clk(clk), .rst(rst),
    .in_valid(), .in_ready(),

    .symbol(), .buy(), 
    .price(), .qty(),

    .transaction(), .trans_valid(),
    .full(),

    .request_symbol(), request_buy(),
    .request_num(),

    .req_out(), .req_out_valid()
);

endmodule