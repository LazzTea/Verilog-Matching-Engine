module graphics #(
    // VGA 640x480 timing intervals, measured in pixel clocks.
    parameter H_DISPLAY = 640,
    parameter H_FRONT = 16,
    parameter H_SYNC = 96,
    parameter H_BACK = 48,
    parameter V_DISPLAY = 480,
    parameter V_FRONT = 10,
    parameter V_SYNC = 2,
    parameter V_BACK = 33,
    parameter LIST_ROWS = 6
)(
    // 100 MHz board clock and active-high reset.
    input wire clk,
    input wire rst,


    // Packed mock rows: row 0 occupies the least-significant bits.
    input wire [LIST_ROWS-1:0] mock_valid,
    input wire [LIST_ROWS-1:0] mock_is_bid,
    input wire [LIST_ROWS*16-1:0] mock_price_bcd,
    input wire [LIST_ROWS*12-1:0] mock_quantity_bcd,
    input wire [LIST_ROWS*5-1:0] mock_symbol,


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
    
    parameter PRICE_LABEL_X = 52;
    parameter QUANTITY_LABEL_X = 120;
    parameter SYMBOL_LABEL_X = 8;
    parameter LABEL_Y = 16;
    parameter LIST_TOP = 48;
    parameter LIST_ROW_HEIGHT = 64;
    parameter PRICE_VALUE_X = 52;
    parameter QUANTITY_VALUE_X = 120;
    parameter SYMBOL_VALUE_X = 8;
    parameter VALUE_TOP = 24;
    parameter TEXT_SCALE = 2;
    parameter GRAPH_AXIS_LEFT = ORDER_LIST_WIDTH + 20;
    parameter GRAPH_AXIS_RIGHT = H_DISPLAY - 20;
    parameter GRAPH_AXIS_TOP = 20;
    parameter GRAPH_AXIS_BOTTOM = GRAPH_HEIGHT - 20;
    parameter GRAPH_AXIS_WIDTH = 2;

    // Five-by-seven glyphs: each inner row case selects a scanline, MSB first.
    function [4:0] glyph_row;
        input [7:0] character;
        input [2:0] row;
        begin
            case (character)
                // ASCII '0'.
                8'h30: case (row)
                    0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10011; 3: glyph_row = 5'b10101;
                    4: glyph_row = 5'b11001; 5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '1'.
                8'h31: case (row)
                    0: glyph_row = 5'b00100; 1: glyph_row = 5'b01100;
                    2: glyph_row = 5'b00100; 3: glyph_row = 5'b00100;
                    4: glyph_row = 5'b00100; 5: glyph_row = 5'b00100;
                    6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '2'.
                8'h32: case (row)
                    0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b00001; 3: glyph_row = 5'b00010;
                    4: glyph_row = 5'b00100; 5: glyph_row = 5'b01000;
                    6: glyph_row = 5'b11111; default: glyph_row = 5'b00000;
                endcase
                // ASCII '3'.
                8'h33: case (row)
                    0: glyph_row = 5'b11110; 1: glyph_row = 5'b00001;
                    2: glyph_row = 5'b00001; 3: glyph_row = 5'b01110;
                    4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                    6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '4'.
                8'h34: case (row)
                    0: glyph_row = 5'b00010; 1: glyph_row = 5'b00110;
                    2: glyph_row = 5'b01010; 3: glyph_row = 5'b10010;
                    4: glyph_row = 5'b11111; 5: glyph_row = 5'b00010;
                    6: glyph_row = 5'b00010; default: glyph_row = 5'b00000;
                endcase
                // ASCII '5'.
                8'h35: case (row)
                    0: glyph_row = 5'b11111; 1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000; 3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                    6: glyph_row = 5'b11110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '6'.
                8'h36: case (row)
                    0: glyph_row = 5'b01110; 1: glyph_row = 5'b10000;
                    2: glyph_row = 5'b10000; 3: glyph_row = 5'b11110;
                    4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '7'.
                8'h37: case (row)
                    0: glyph_row = 5'b11111; 1: glyph_row = 5'b00001;
                    2: glyph_row = 5'b00010; 3: glyph_row = 5'b00100;
                    4: glyph_row = 5'b01000; 5: glyph_row = 5'b01000;
                    6: glyph_row = 5'b01000; default: glyph_row = 5'b00000;
                endcase
                // ASCII '8'.
                8'h38: case (row)
                    0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001; 3: glyph_row = 5'b01110;
                    4: glyph_row = 5'b10001; 5: glyph_row = 5'b10001;
                    6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII '9'.
                8'h39: case (row)
                    0: glyph_row = 5'b01110; 1: glyph_row = 5'b10001;
                    2: glyph_row = 5'b10001; 3: glyph_row = 5'b01111;
                    4: glyph_row = 5'b00001; 5: glyph_row = 5'b00001;
                    6: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII 'A'.
                8'h41: case (row)
                    0: glyph_row = 5'b01110; 1, 2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11111; default: glyph_row = 5'b10001;
                endcase
                // ASCII 'B'.
                8'h42: case (row)
                    0, 3, 6: glyph_row = 5'b11110; 1, 2, 4, 5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // ASCII 'C'.
                8'h43: case (row)
                    0, 6: glyph_row = 5'b01111; default: glyph_row = 5'b10000;
                endcase
                // ASCII 'D'.
                8'h44: case (row)
                    0, 6: glyph_row = 5'b11110; 1, 2, 3, 4, 5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // ASCII 'E'.
                8'h45: case (row)
                    0, 3, 6: glyph_row = 5'b11111; default: glyph_row = 5'b10000;
                endcase
                // ASCII 'F'.
                8'h46: case (row)
                    0: glyph_row = 5'b11111; 1, 2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b11110; default: glyph_row = 5'b10000;
                endcase
                // ASCII 'G'.
                8'h47: case (row)
                    0: glyph_row = 5'b01111; 1, 2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b10111; 4, 5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01111;
                endcase
                // ASCII 'H'.
                8'h48: case (row)
                    0, 1, 2, 4, 5, 6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b11111;
                endcase
                // ASCII 'I'.
                8'h49: case (row)
                    0, 6: glyph_row = 5'b01110; default: glyph_row = 5'b00100;
                endcase
                // ASCII 'J'.
                8'h4a: case (row)
                    0: glyph_row = 5'b00111; 1, 2, 3: glyph_row = 5'b00010;
                    4, 5: glyph_row = 5'b10010; default: glyph_row = 5'b01100;
                endcase
                // ASCII 'K'.
                8'h4b: case (row)
                    0, 6: glyph_row = 5'b10001; 1, 5: glyph_row = 5'b10010;
                    2, 4: glyph_row = 5'b10100; default: glyph_row = 5'b11000;
                endcase
                // ASCII 'L'.
                8'h4c: case (row)
                    0, 1, 2, 3, 4, 5: glyph_row = 5'b10000;
                    default: glyph_row = 5'b11111;
                endcase
                // ASCII 'M'.
                8'h4d: case (row)
                    0: glyph_row = 5'b10001; 1: glyph_row = 5'b11011;
                    2: glyph_row = 5'b10101; default: glyph_row = 5'b10001;
                endcase
                // ASCII 'N'.
                8'h4e: case (row)
                    0: glyph_row = 5'b10001; 1: glyph_row = 5'b11001;
                    2: glyph_row = 5'b10101; 3: glyph_row = 5'b10011;
                    default: glyph_row = 5'b10001;
                endcase
                // ASCII 'O'.
                8'h4f: case (row)
                    0, 6: glyph_row = 5'b01110; 1, 2, 3, 4, 5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // ASCII 'P'.
                8'h50: case (row)
                    0: glyph_row = 5'b11110; 1, 2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11110; default: glyph_row = 5'b10000;
                endcase
                // ASCII 'Q'.
                8'h51: case (row)
                    0, 6: glyph_row = 5'b01110; 1, 2, 3: glyph_row = 5'b10001;
                    4: glyph_row = 5'b10101; 5: glyph_row = 5'b10010;
                    default: glyph_row = 5'b01101;
                endcase
                // ASCII 'R'.
                8'h52: case (row)
                    0: glyph_row = 5'b11110; 1, 2: glyph_row = 5'b10001;
                    3: glyph_row = 5'b11110; 4: glyph_row = 5'b10100;
                    5: glyph_row = 5'b10010; default: glyph_row = 5'b10001;
                endcase
                // ASCII 'S'.
                8'h53: case (row)
                    0: glyph_row = 5'b01111; 1, 2: glyph_row = 5'b10000;
                    3: glyph_row = 5'b01110; 4, 5: glyph_row = 5'b00001;
                    default: glyph_row = 5'b11110;
                endcase
                // ASCII 'T'.
                8'h54: case (row)
                    0: glyph_row = 5'b11111; default: glyph_row = 5'b00100;
                endcase
                // ASCII 'U'.
                8'h55: case (row)
                    0, 1, 2, 3, 4, 5: glyph_row = 5'b10001;
                    default: glyph_row = 5'b01110;
                endcase
                // ASCII 'V'.
                8'h56: case (row)
                    0, 1, 2, 3: glyph_row = 5'b10001; 4, 5: glyph_row = 5'b01010;
                    default: glyph_row = 5'b00100;
                endcase
                // ASCII 'W'.
                8'h57: case (row)
                    0, 1, 2: glyph_row = 5'b10001; 3, 4, 5: glyph_row = 5'b10101;
                    default: glyph_row = 5'b01010;
                endcase
                // ASCII 'X'.
                8'h58: case (row)
                    0, 1: glyph_row = 5'b10001; 2: glyph_row = 5'b01010;
                    3: glyph_row = 5'b00100; 4: glyph_row = 5'b01010;
                    default: glyph_row = 5'b10001;
                endcase
                // ASCII 'Y'.
                8'h59: case (row)
                    0, 1: glyph_row = 5'b10001; 2: glyph_row = 5'b01010;
                    default: glyph_row = 5'b00100;
                endcase
                // ASCII 'Z'.
                8'h5a: case (row)
                    0: glyph_row = 5'b11111; 1: glyph_row = 5'b00001;
                    2: glyph_row = 5'b00010; 3: glyph_row = 5'b00100;
                    4: glyph_row = 5'b01000; 5: glyph_row = 5'b10000;
                    default: glyph_row = 5'b11111;
                endcase
                // ASCII space: blank scanlines.
                8'h20: glyph_row = 5'b00000;
                // ASCII hyphen.
                8'h2d: case (row)
                    3: glyph_row = 5'b01110; default: glyph_row = 5'b00000;
                endcase
                // ASCII period.
                8'h2e: case (row)
                    6: glyph_row = 5'b00100; default: glyph_row = 5'b00000;
                endcase
                default: glyph_row = 5'b00000;
            endcase
        end
    endfunction

    function glyph_pixel;
        input [4:0] row_bits;
        input [2:0] column;
        begin
            case (column)
                0: glyph_pixel = row_bits[4];
                1: glyph_pixel = row_bits[3];
                2: glyph_pixel = row_bits[2];
                3: glyph_pixel = row_bits[1];
                4: glyph_pixel = row_bits[0];
                default: glyph_pixel = 1'b0;
            endcase
        end
    endfunction

    wire [9:0] list_y = y - LIST_TOP;
    wire [2:0] selected_row = list_y / LIST_ROW_HEIGHT;
    wire [5:0] row_y = list_y % LIST_ROW_HEIGHT;
    wire in_list_rows = y >= LIST_TOP &&
                        y < LIST_TOP + LIST_ROWS * LIST_ROW_HEIGHT;
    wire row_valid = in_list_rows ? mock_valid[selected_row] : 1'b0;
    wire [15:0] selected_price_bcd = mock_price_bcd >> (selected_row * 16);
    wire [11:0] selected_quantity_bcd = mock_quantity_bcd >> (selected_row * 12);
    wire [4:0] selected_symbol = mock_symbol >> (selected_row * 5);

    wire [2:0] price_digit_index = (x - PRICE_VALUE_X) / (6 * TEXT_SCALE);
    wire [2:0] quantity_digit_index = (x - QUANTITY_VALUE_X) / (6 * TEXT_SCALE);
    wire [2:0] symbol_column = ((x - SYMBOL_VALUE_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] price_column = ((x - PRICE_VALUE_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] quantity_column = ((x - QUANTITY_VALUE_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] digit_row = (row_y - VALUE_TOP) / TEXT_SCALE;
    wire [3:0] price_digit = selected_price_bcd >> ((3 - price_digit_index) * 4);
    wire [3:0] quantity_digit = selected_quantity_bcd >> ((2 - quantity_digit_index) * 4);
    wire [7:0] symbol_character = selected_symbol <= 5'd25 ?
                                  8'h41 + {3'b000, selected_symbol} : 8'h00;
    wire [4:0] price_bitmap = glyph_row(8'h30 + price_digit, digit_row);
    wire [4:0] quantity_bitmap = glyph_row(8'h30 + quantity_digit, digit_row);
    wire [4:0] symbol_bitmap = glyph_row(symbol_character, digit_row);
    wire price_pixel = row_valid && x >= PRICE_VALUE_X &&
                       x < PRICE_VALUE_X + 4 * 6 * TEXT_SCALE &&
                       row_y >= VALUE_TOP && row_y < VALUE_TOP + 7 * TEXT_SCALE &&
                       price_digit_index < 4 && price_column < 5 &&
                       glyph_pixel(price_bitmap, price_column);
    wire quantity_pixel = row_valid && x >= QUANTITY_VALUE_X &&
                          x < QUANTITY_VALUE_X + 3 * 6 * TEXT_SCALE &&
                          row_y >= VALUE_TOP && row_y < VALUE_TOP + 7 * TEXT_SCALE &&
                          quantity_digit_index < 3 && quantity_column < 5 &&
                          glyph_pixel(quantity_bitmap, quantity_column);
    wire symbol_pixel = row_valid && x >= SYMBOL_VALUE_X &&
                        x < SYMBOL_VALUE_X + 6 * TEXT_SCALE &&
                        row_y >= VALUE_TOP && row_y < VALUE_TOP + 7 * TEXT_SCALE &&
                        symbol_column < 5 && glyph_pixel(symbol_bitmap, symbol_column);

    reg [7:0] label_character;
    reg [2:0] label_column;
    always @(*) begin
        label_character = 8'h00;
        label_column = 3'd0;
        if (y >= LABEL_Y && y < LABEL_Y + 7 * TEXT_SCALE) begin
            if (x >= PRICE_LABEL_X &&
                x < PRICE_LABEL_X + 5 * 6 * TEXT_SCALE) begin
                label_column = ((x - PRICE_LABEL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
                case ((x - PRICE_LABEL_X) / (6 * TEXT_SCALE))
                    // Character positions 0 through 4 spell PRICE.
                    0: label_character = 8'h50;
                    1: label_character = 8'h52;
                    2: label_character = 8'h49;
                    3: label_character = 8'h43;
                    4: label_character = 8'h45;
                    default: label_character = 8'h00;
                endcase
            end else if (x >= QUANTITY_LABEL_X &&
                         x < QUANTITY_LABEL_X + 3 * 6 * TEXT_SCALE) begin
                label_column = ((x - QUANTITY_LABEL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
                case ((x - QUANTITY_LABEL_X) / (6 * TEXT_SCALE))
                    // Character positions 0 through 2 spell QTY.
                    0: label_character = 8'h51;
                    1: label_character = 8'h54;
                    2: label_character = 8'h59;
                    default: label_character = 8'h00;
                endcase
            end else if (x >= SYMBOL_LABEL_X &&
                         x < SYMBOL_LABEL_X + 3 * 6 * TEXT_SCALE) begin
                label_column = ((x - SYMBOL_LABEL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
                case ((x - SYMBOL_LABEL_X) / (6 * TEXT_SCALE))
                    0: label_character = 8'h53;
                    1: label_character = 8'h59;
                    2: label_character = 8'h4d;
                    default: label_character = 8'h00;
                endcase
            end
        end
    end

    wire [2:0] label_row = (y - LABEL_Y) / TEXT_SCALE;
    wire [4:0] label_bitmap = glyph_row(label_character, label_row);
    wire label_pixel = glyph_pixel(label_bitmap, label_column);

    // Two-pixel L-shaped axes inside the graph panel.
    wire graph_axis_pixel =
        ((x >= GRAPH_AXIS_LEFT && x < GRAPH_AXIS_LEFT + GRAPH_AXIS_WIDTH) &&
         (y >= GRAPH_AXIS_TOP && y < GRAPH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH)) ||
        ((y >= GRAPH_AXIS_BOTTOM && y < GRAPH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH) &&
         (x >= GRAPH_AXIS_LEFT && x < GRAPH_AXIS_RIGHT));

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
        // Pixels outside the active 640x480 area are black.
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (video_on) begin
            // Divider lines separating the three display panels.
            if ((x >= ORDER_LIST_WIDTH &&
                 x < ORDER_LIST_WIDTH + SEPARATOR_WIDTH) ||
                (x >= ORDER_LIST_WIDTH &&
                 y >= GRAPH_HEIGHT &&
                 y < GRAPH_HEIGHT + SEPARATOR_WIDTH)) begin
                red = 4'h5;
                green = 4'h7;
                blue = 4'h9;
            end else if (x < ORDER_LIST_WIDTH) begin
                // Left panel: order-list background, labels, and mock values.
                red = 4'h1;
                green = 4'h2;
                blue = 4'h4;
                if (label_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (price_pixel && mock_is_bid[selected_row]) begin
                    red = 4'h3;
                    green = 4'hf;
                    blue = 4'h8;
                end else if (price_pixel) begin
                    red = 4'hf;
                    green = 4'h5;
                    blue = 4'h5;
                end else if (quantity_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (symbol_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (in_list_rows && row_y == 0) begin
                    red = 4'h3;
                    green = 4'h5;
                    blue = 4'h8;
                end
            end else if (y < GRAPH_HEIGHT) begin
                // Upper-right panel: graph background and its L-shaped axes.
                if (graph_axis_pixel) begin
                    red = 4'h8;
                    green = 4'ha;
                    blue = 4'hc;
                end else begin
                    red = 4'h1;
                    green = 4'h2;
                    blue = 4'h3;
                end
            end else begin
                // Lower-right panel: order-entry background.
                red = 4'h2;
                green = 4'h3;
                blue = 4'h5;
            end
        end
    end










endmodule