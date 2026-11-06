module graphics #(
    // VGA 640x480 timing intervals, measured in pixel clocks.
    parameter H_DISPLAY = 640,
    parameter H_FRONT = 16,
    parameter H_SYNC = 96,
    parameter H_BACK = 48,
    parameter V_DISPLAY = 480,
    parameter V_FRONT = 10,
    parameter V_SYNC = 2,
    parameter V_BACK = 33
)(
    // 100 MHz board clock and active-high reset.
    input wire clk,
    input wire rst,


    //Mock List
    input reg [7:0] order_list [0:ORDER_LIST_WIDTH-1],


    // VGA synchronization, current pixel coordinates, and active-video flag.
    output reg hsync,
    output reg vsync,
    output reg [9:0] x,
    output reg [9:0] y,
    output reg video_on,
    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue
);

    // Full scan dimensions and procedural layout sizes.
    parameter H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;
    parameter V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;
    parameter ORDER_LIST_WIDTH = H_DISPLAY / 4;
    parameter GRAPH_HEIGHT = (V_DISPLAY * 3) / 4;
    parameter SEPARATOR_WIDTH = 2;

    // Divide the board clock by four to advance one pixel at 25 MHz.
    reg [1:0] pixel_divider;
    wire pixel_tick = (pixel_divider == 2'b11);

    // Scan across each row, then advance to the next row at the line boundary.
    always @(posedge clk) begin
        if (rst) begin
            pixel_divider <= 2'b00;
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            pixel_divider <= pixel_divider + 1'b1;

            if (pixel_tick) begin
                if (x == H_TOTAL - 1) begin
                    x <= 10'd0;
                    if (y == V_TOTAL - 1)
                        y <= 10'd0;
                    else
                        y <= y + 1'b1;
                end else begin
                    x <= x + 1'b1;
                end
            end
        end
    end

    // Generate active-low sync pulses and mark visible display coordinates.
    always @(*) begin
        hsync = ~((x >= H_DISPLAY + H_FRONT) &&
                  (x < H_DISPLAY + H_FRONT + H_SYNC));
        vsync = ~((y >= V_DISPLAY + V_FRONT) &&
                  (y < V_DISPLAY + V_FRONT + V_SYNC));
        video_on = (x < H_DISPLAY) && (y < V_DISPLAY);
    end

    // Draw the order list, graph, and order-entry panels with separator lines.
    always @(*) begin
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (video_on) begin
            if ((x >= ORDER_LIST_WIDTH &&
                 x < ORDER_LIST_WIDTH + SEPARATOR_WIDTH) ||
                (x >= ORDER_LIST_WIDTH &&
                 y >= GRAPH_HEIGHT &&
                 y < GRAPH_HEIGHT + SEPARATOR_WIDTH)) begin
                red = 4'h5;
                green = 4'h7;
                blue = 4'h9;
            end else if (x < ORDER_LIST_WIDTH) begin
                red = 4'h1;
                green = 4'h2;
                blue = 4'h4;
            end else if (y < GRAPH_HEIGHT) begin
                red = 4'h1;
                green = 4'h2;
                blue = 4'h3;
            end else begin
                red = 4'h2;
                green = 4'h3;
                blue = 4'h5;
            end
        end
    end







endmodule