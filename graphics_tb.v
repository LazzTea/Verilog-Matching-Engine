`timescale 1ns/1ps

module graphics_tb;
    reg clk;
    reg rst;
    reg [5:0] mock_valid;
    reg [5:0] mock_is_bid;
    reg [95:0] mock_price_bcd;
    reg [71:0] mock_quantity_bcd;
    reg [31:0] mock_symbol;
    reg [3:0] selected_stock;
    reg [1599:0] mock_graph_price_history;

    wire hsync;
    wire vsync;
    wire [9:0] x;
    wire [9:0] y;
    wire video_on;
    wire [3:0] red;
    wire [3:0] green;
    wire [3:0] blue;

    integer failures;
    integer image_file;
    integer pixel_count;
    reg image_done;
    reg [9:0] last_x;
    reg [9:0] last_y;

    graphics #(
        .GRAPH_POINTS(10),
        .GRAPH_STOCKS(16),
        .GRAPH_PRICE_MIN(0),
        .GRAPH_PRICE_MAX(1000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .mock_valid(mock_valid),
        .mock_is_bid(mock_is_bid),
        .mock_price_bcd(mock_price_bcd),
        .mock_quantity_bcd(mock_quantity_bcd),
        .mock_symbol(mock_symbol),
        .selected_stock(selected_stock),
        .mock_graph_price_history(mock_graph_price_history),
        .hsync(hsync),
        .vsync(vsync),
        .x(x),
        .y(y),
        .video_on(video_on),
        .red(red),
        .green(green),
        .blue(blue)
    );

    always #5 clk = ~clk;

    // Save one RGB sample whenever the scan advances to a new visible pixel.
    always @(negedge clk) begin
        if (!rst && !image_done && video_on &&
            ((x !== last_x) || (y !== last_y))) begin
            $fwrite(image_file, "%0d %0d %0d\n",
                    red * 17, green * 17, blue * 17);
            last_x = x;
            last_y = y;
            pixel_count = pixel_count + 1;

            if (pixel_count == 640 * 480) begin
                $fclose(image_file);
                image_done = 1'b1;
                $display("Wrote graphics.ppm (640x480)");
            end
        end
    end

    task check_hsync;
        input [9:0] target_x;
        input expected_hsync;
        begin
            while ((x !== target_x) || (y !== 10'd0))
                @(negedge clk);
            #1;
            if (hsync !== expected_hsync) begin
                $display("FAIL hsync at x=%0d: got %b expected %b",
                         target_x, hsync, expected_hsync);
                failures = failures + 1;
            end else begin
                $display("PASS hsync at x=%0d: %b", target_x, hsync);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        failures = 0;
        pixel_count = 0;
        image_done = 1'b0;
        last_x = 10'h3ff;
        last_y = 10'h3ff;

        image_file = $fopen("graphics.ppm", "w");
        if (image_file == 0)
            $fatal(1, "could not open graphics.ppm for writing");
        $fwrite(image_file, "P3\n640 480\n255\n");

        mock_valid = 6'b111111;
        mock_is_bid = 6'b111000;
        mock_price_bcd = {
            16'h0995, 16'h0998, 16'h1005,
            16'h1012, 16'h1010, 16'h1008
        };
        mock_quantity_bcd = {
            12'h075, 12'h150, 12'h042,
            12'h200, 12'h085, 12'h120
        };
        mock_symbol = "AAPL";
        selected_stock = 4'd0;
        mock_graph_price_history = 1600'd0;
        mock_graph_price_history[0 +: 100] = {
            10'd600, 10'd250, 10'd750, 10'd500, 10'd250,
            10'd1000, 10'd0, 10'd100, 10'd900, 10'd400
        };
        mock_graph_price_history[100 +: 100] = {
            10'd900, 10'd800, 10'd700, 10'd600, 10'd500,
            10'd400, 10'd300, 10'd200, 10'd100, 10'd0
        };

        repeat (4) @(posedge clk);
        #1;
        if ((x !== 10'd0) || (y !== 10'd0)) begin
            $display("FAIL reset coordinates: x=%0d y=%0d", x, y);
            failures = failures + 1;
        end else begin
            $display("PASS reset coordinates");
        end

        rst = 1'b0;

        check_hsync(10'd656, 1'b0);
        check_hsync(10'd752, 1'b1);

        if (failures == 0)
            $display("VGA timing checks passed; generated graphics.ppm");
        else begin
            $display("GRAPHICS TESTS FAILED: %0d failure(s)", failures);
            $fatal(1, "graphics testbench failed");
        end

        while (!image_done)
            @(negedge clk);

        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "graphics testbench timeout");
    end
endmodule
