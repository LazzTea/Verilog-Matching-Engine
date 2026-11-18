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
    parameter LIST_ROWS = 6,
    parameter GRAPH_POINTS = 32,
    parameter GRAPH_STOCKS = 16,
    parameter GRAPH_PRICE_MIN = 0,
    parameter GRAPH_PRICE_MAX = 1023
)(
    // 100 MHz board clock and active-high reset.
    input wire clk,
    input wire rst,


    // Packed mock rows: row 0 occupies the least-significant bits.
    input wire [LIST_ROWS-1:0] mock_valid,
    input wire [LIST_ROWS-1:0] mock_is_bid,
    input wire [LIST_ROWS*16-1:0] mock_price_bcd,
    input wire [LIST_ROWS*12-1:0] mock_quantity_bcd,
    input wire [31:0] mock_symbol,
    input wire [3:0] selected_stock,
    input wire [LIST_ROWS*10-1:0] depth_prices,
    input wire [LIST_ROWS*9-1:0] depth_quantities,
    // Each stock has GRAPH_POINTS packed 10-bit samples; sample 0 is oldest.
    input wire [GRAPH_STOCKS*GRAPH_POINTS*10-1:0] mock_graph_price_history,


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
    parameter ORDER_LIST_WIDTH = (H_DISPLAY * 5) / 16;
    parameter GRAPH_HEIGHT = V_DISPLAY / 2;
    parameter SEPARATOR_WIDTH = 2;
    
    parameter PRICE_LABEL_X = 16;
    parameter QUANTITY_LABEL_X = 112;
    parameter LABEL_Y = 32;
    parameter HEADER_LABEL_X = 16;
    parameter HEADER_SYMBOL_X = 88;
    parameter HEADER_Y = 8;
    parameter ASK_LABEL_Y = 52;
    parameter BID_LABEL_Y = 192;
    parameter LIST_TOP = 68;
    parameter BID_TOP = 208;
    parameter LIST_ROW_HEIGHT = 40;
    parameter ASK_ROWS = LIST_ROWS / 2;
    parameter PRICE_VALUE_X = 16;
    parameter QUANTITY_VALUE_X = 112;
    parameter VALUE_TOP = 10;
    parameter TEXT_SCALE = 2;
    parameter GRAPH_AXIS_LEFT = ORDER_LIST_WIDTH + 52;
    parameter GRAPH_AXIS_RIGHT = H_DISPLAY - 20;
    parameter GRAPH_AXIS_TOP = GRAPH_HEIGHT + 32;
    parameter GRAPH_AXIS_BOTTOM = V_DISPLAY - 12;
    parameter GRAPH_AXIS_WIDTH = 2;
    parameter DEPTH_AXIS_LEFT = ORDER_LIST_WIDTH + 56;
    parameter DEPTH_AXIS_RIGHT = H_DISPLAY - 12;
    parameter DEPTH_AXIS_TOP = 40;
    parameter DEPTH_AXIS_BOTTOM = GRAPH_HEIGHT - 26;
    parameter DEPTH_PLOT_LEFT = DEPTH_AXIS_LEFT + GRAPH_AXIS_WIDTH;
    parameter DEPTH_PLOT_RIGHT = DEPTH_AXIS_RIGHT - 1;
    parameter DEPTH_PLOT_TOP = DEPTH_AXIS_TOP + GRAPH_AXIS_WIDTH;
    parameter DEPTH_PLOT_BOTTOM = DEPTH_AXIS_BOTTOM - GRAPH_AXIS_WIDTH;

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

    wire in_ask_rows = y >= LIST_TOP &&
                       y < LIST_TOP + ASK_ROWS * LIST_ROW_HEIGHT;
    wire in_bid_rows = y >= BID_TOP &&
                       y < BID_TOP + (LIST_ROWS - ASK_ROWS) * LIST_ROW_HEIGHT;
    wire in_list_rows = in_ask_rows || in_bid_rows;
    wire [9:0] list_y = in_ask_rows ? y - LIST_TOP : y - BID_TOP;
    wire [2:0] selected_row = in_ask_rows ?
                              list_y / LIST_ROW_HEIGHT :
                              ASK_ROWS + list_y / LIST_ROW_HEIGHT;
    wire [5:0] row_y = list_y % LIST_ROW_HEIGHT;
    wire row_valid = in_list_rows ? mock_valid[selected_row] : 1'b0;
    wire [15:0] selected_price_bcd = mock_price_bcd >> (selected_row * 16);
    wire [11:0] selected_quantity_bcd = mock_quantity_bcd >> (selected_row * 12);
    wire [GRAPH_POINTS*10-1:0] selected_graph_prices =
        mock_graph_price_history[
            selected_stock * GRAPH_POINTS * 10 +: GRAPH_POINTS * 10
        ];

    wire [2:0] price_digit_index = (x - PRICE_VALUE_X) / (6 * TEXT_SCALE);
    wire [2:0] quantity_digit_index = (x - QUANTITY_VALUE_X) / (6 * TEXT_SCALE);
    wire [2:0] header_symbol_character_index =
        (x - HEADER_SYMBOL_X) / (6 * TEXT_SCALE);
    wire [2:0] header_symbol_column =
        ((x - HEADER_SYMBOL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] price_column = ((x - PRICE_VALUE_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] quantity_column = ((x - QUANTITY_VALUE_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] digit_row = (row_y - VALUE_TOP) / TEXT_SCALE;
    wire [3:0] price_digit = selected_price_bcd >> ((3 - price_digit_index) * 4);
    wire [3:0] quantity_digit = selected_quantity_bcd >> ((2 - quantity_digit_index) * 4);
    wire [7:0] header_symbol_character =
        mock_symbol >> ((3 - header_symbol_character_index) * 8);
    wire [4:0] price_bitmap = glyph_row(8'h30 + price_digit, digit_row);
    wire [4:0] quantity_bitmap = glyph_row(8'h30 + quantity_digit, digit_row);
    wire [2:0] header_symbol_row = (y - HEADER_Y) / TEXT_SCALE;
    wire [4:0] header_symbol_bitmap =
        glyph_row(header_symbol_character, header_symbol_row);
    wire header_symbol_pixel = x >= HEADER_SYMBOL_X &&
                               x < HEADER_SYMBOL_X + 4 * 6 * TEXT_SCALE &&
                               y >= HEADER_Y &&
                               y < HEADER_Y + 7 * TEXT_SCALE &&
                               header_symbol_character_index < 4 &&
                               header_symbol_column < 5 &&
                               glyph_pixel(header_symbol_bitmap,
                                           header_symbol_column);
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
    reg [7:0] label_character;
    reg [2:0] label_column;
    reg [2:0] label_row;
    always @(*) begin
        label_character = 8'h00;
        label_column = 3'd0;
        label_row = 3'd0;
        if (y >= HEADER_Y && y < HEADER_Y + 7 * TEXT_SCALE &&
            x >= HEADER_LABEL_X &&
            x < HEADER_LABEL_X + 5 * 6 * TEXT_SCALE) begin
            label_row = (y - HEADER_Y) / TEXT_SCALE;
            label_column =
                ((x - HEADER_LABEL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
            case ((x - HEADER_LABEL_X) / (6 * TEXT_SCALE))
                0: label_character = 8'h53;
                1: label_character = 8'h54;
                2: label_character = 8'h4f;
                3: label_character = 8'h43;
                4: label_character = 8'h4b;
                default: label_character = 8'h00;
            endcase
        end else if (y >= LABEL_Y && y < LABEL_Y + 7 * TEXT_SCALE) begin
            label_row = (y - LABEL_Y) / TEXT_SCALE;
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
            end
        end else if ((y >= ASK_LABEL_Y &&
                      y < ASK_LABEL_Y + 7 * TEXT_SCALE) ||
                     (y >= BID_LABEL_Y &&
                      y < BID_LABEL_Y + 7 * TEXT_SCALE)) begin
            label_row = y >= BID_LABEL_Y ?
                        (y - BID_LABEL_Y) / TEXT_SCALE :
                        (y - ASK_LABEL_Y) / TEXT_SCALE;
            if (x >= PRICE_LABEL_X &&
                x < PRICE_LABEL_X + 4 * 6 * TEXT_SCALE) begin
                label_column =
                    ((x - PRICE_LABEL_X) % (6 * TEXT_SCALE)) / TEXT_SCALE;
                case ((x - PRICE_LABEL_X) / (6 * TEXT_SCALE))
                    0: label_character = y >= BID_LABEL_Y ? 8'h42 : 8'h41;
                    1: label_character = y >= BID_LABEL_Y ? 8'h49 : 8'h53;
                    2: label_character = y >= BID_LABEL_Y ? 8'h44 : 8'h4b;
                    3: label_character = y >= BID_LABEL_Y ? 8'h53 : 8'h53;
                    default: label_character = 8'h00;
                endcase
            end
        end
    end

    wire [4:0] label_bitmap = glyph_row(label_character, label_row);
    wire label_pixel = glyph_pixel(label_bitmap, label_column);

    function [7:0] chart_title_character;
        input depth_chart;
        input [4:0] character_index;
        begin
            chart_title_character = 8'h20;
            if (depth_chart) begin
                case (character_index)
                    0: chart_title_character = 8'h4f;
                    1: chart_title_character = 8'h52;
                    2: chart_title_character = 8'h44;
                    3: chart_title_character = 8'h45;
                    4: chart_title_character = 8'h52;
                    6: chart_title_character = 8'h42;
                    7: chart_title_character = 8'h4f;
                    8: chart_title_character = 8'h4f;
                    9: chart_title_character = 8'h4b;
                    11: chart_title_character = 8'h44;
                    12: chart_title_character = 8'h45;
                    13: chart_title_character = 8'h50;
                    14: chart_title_character = 8'h54;
                    15: chart_title_character = 8'h48;
                    default: chart_title_character = 8'h20;
                endcase
            end else begin
                case (character_index)
                    0: chart_title_character = 8'h4c;
                    1: chart_title_character = 8'h41;
                    2: chart_title_character = 8'h53;
                    3: chart_title_character = 8'h54;
                    5: chart_title_character = 8'h42;
                    6: chart_title_character = 8'h55;
                    7: chart_title_character = 8'h59;
                    9: chart_title_character = 8'h4f;
                    10: chart_title_character = 8'h52;
                    11: chart_title_character = 8'h44;
                    12: chart_title_character = 8'h45;
                    13: chart_title_character = 8'h52;
                    14: chart_title_character = 8'h53;
                    default: chart_title_character = 8'h20;
                endcase
            end
        end
    endfunction

    function [7:0] graph_time_character;
        input newest;
        input [1:0] character_index;
        begin
            if (newest) begin
                case (character_index)
                    0: graph_time_character = 8'h4e;
                    1: graph_time_character = 8'h45;
                    2: graph_time_character = 8'h57;
                    default: graph_time_character = 8'h20;
                endcase
            end else begin
                case (character_index)
                    0: graph_time_character = 8'h4f;
                    1: graph_time_character = 8'h4c;
                    2: graph_time_character = 8'h44;
                    default: graph_time_character = 8'h20;
                endcase
            end
        end
    endfunction

    wire in_depth_chart = y < GRAPH_HEIGHT;
    wire [9:0] chart_title_y = in_depth_chart ? 10'd8 : GRAPH_HEIGHT + 10'd8;
    wire [9:0] chart_title_x = GRAPH_AXIS_LEFT;
    wire [4:0] chart_title_index =
        (x - chart_title_x) / (6 * TEXT_SCALE);
    wire [2:0] chart_title_column =
        ((x - chart_title_x) % (6 * TEXT_SCALE)) / TEXT_SCALE;
    wire [2:0] chart_title_row =
        (y - chart_title_y) / TEXT_SCALE;
    wire [4:0] chart_title_bitmap =
        glyph_row(chart_title_character(in_depth_chart, chart_title_index),
                  chart_title_row);
    wire chart_title_pixel =
        x >= chart_title_x &&
        x < chart_title_x + 16 * 6 * TEXT_SCALE &&
        y >= chart_title_y &&
        y < chart_title_y + 7 * TEXT_SCALE &&
        chart_title_index < (in_depth_chart ? 16 : 15) &&
        chart_title_column < 5 &&
        glyph_pixel(chart_title_bitmap, chart_title_column);

    wire depth_axis_pixel =
        ((x >= DEPTH_AXIS_LEFT && x < DEPTH_AXIS_LEFT + GRAPH_AXIS_WIDTH) &&
         (y >= DEPTH_AXIS_TOP && y < DEPTH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH)) ||
        ((y >= DEPTH_AXIS_BOTTOM &&
          y < DEPTH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH) &&
         (x >= DEPTH_AXIS_LEFT && x < DEPTH_AXIS_RIGHT));

    function [9:0] depth_price_x;
        input [9:0] price;
        input [9:0] min_price;
        input [9:0] max_price;
        integer price_range;
        integer plot_span;
        begin
           price_range = max_price - min_price;
           plot_span = DEPTH_PLOT_RIGHT - DEPTH_PLOT_LEFT;
           if (price_range == 0)
               depth_price_x = DEPTH_PLOT_LEFT + plot_span / 2;
           else
               depth_price_x = DEPTH_PLOT_LEFT +
                   ((price - min_price) * plot_span) / price_range;
        end
    endfunction

    function [9:0] depth_quantity_y;
        input [12:0] quantity;
        input [12:0] max_quantity;
        integer plot_height;
        begin
           plot_height = DEPTH_PLOT_BOTTOM - DEPTH_PLOT_TOP;
           if (max_quantity == 0)
               depth_quantity_y = DEPTH_PLOT_BOTTOM;
           else
               depth_quantity_y = DEPTH_PLOT_BOTTOM -
                   (quantity * plot_height) / max_quantity;
        end
    endfunction

    function [15:0] depth_to_bcd;
        input [12:0] value;
        reg [19:0] digits;
        integer bit_index;
        begin
            digits = 20'd0;
            for (bit_index = 0; bit_index < 13;
                 bit_index = bit_index + 1) begin
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
                digits = {digits[18:0], value[12-bit_index]};
            end
            depth_to_bcd = digits[15:0];
        end
    endfunction

    reg [9:0] depth_min_price;
    reg [9:0] depth_max_price;
    reg [12:0] depth_total_quantity;
    reg [12:0] depth_bid_quantity;
    reg [12:0] depth_ask_quantity;
    reg [12:0] depth_max_quantity;
    reg [12:0] depth_ask_cumulative;
    reg [12:0] depth_bid_cumulative;
    reg [12:0] depth_row_quantity;
    reg [9:0] depth_row_price;
    reg [9:0] depth_previous_x;
    reg [9:0] depth_current_x;
    reg [9:0] depth_previous_y;
    reg [9:0] depth_current_y;
    reg [9:0] depth_line_low;
    reg [9:0] depth_line_high;
    reg depth_has_data;
    reg depth_bid_started;
    reg depth_ask_curve_pixel;
    reg depth_bid_curve_pixel;
    reg depth_axis_label_pixel;
    reg [9:0] depth_price_tick_value;
    reg [12:0] depth_quantity_tick_value;
    reg [15:0] depth_label_bcd;
    reg [9:0] depth_label_tick_x;
    reg [9:0] depth_label_tick_y;
    reg [9:0] depth_label_left;
    reg [4:0] depth_label_character_index;
    reg [2:0] depth_label_column;
    reg [2:0] depth_label_row;
    reg [3:0] depth_label_digit;
    reg [4:0] depth_label_bitmap;
    integer depth_label_index;
    integer depth_index;

    // Plot cumulative ask and bid quantities against the prices from the
    // currently displayed order rows. The order book supplies asks ascending
    // and bids descending, so the bid side is traversed in reverse here.
    always @(*) begin
        depth_min_price = 10'h3ff;
        depth_max_price = 10'd0;
        depth_total_quantity = 13'd0;
        depth_bid_quantity = 13'd0;
        depth_ask_quantity = 13'd0;
        depth_max_quantity = 13'd0;
        depth_ask_cumulative = 13'd0;
        depth_bid_cumulative = 13'd0;
        depth_row_quantity = 13'd0;
        depth_row_price = 10'd0;
        depth_previous_x = DEPTH_PLOT_LEFT;
        depth_current_x = DEPTH_PLOT_LEFT;
        depth_previous_y = DEPTH_PLOT_BOTTOM;
        depth_current_y = DEPTH_PLOT_BOTTOM;
        depth_line_low = DEPTH_PLOT_BOTTOM;
        depth_line_high = DEPTH_PLOT_BOTTOM;
        depth_has_data = 1'b0;
        depth_bid_started = 1'b0;
        depth_ask_curve_pixel = 1'b0;
        depth_bid_curve_pixel = 1'b0;
        depth_axis_label_pixel = 1'b0;
        depth_price_tick_value = 10'd0;
        depth_quantity_tick_value = 13'd0;
        depth_label_bcd = 16'd0;
        depth_label_tick_x = 10'd0;
        depth_label_tick_y = 10'd0;
        depth_label_left = 10'd0;
        depth_label_character_index = 5'd0;
        depth_label_column = 3'd0;
        depth_label_row = 3'd0;
        depth_label_digit = 4'd0;
        depth_label_bitmap = 5'd0;

        for (depth_index = 0; depth_index < LIST_ROWS;
            depth_index = depth_index + 1) begin
           if (mock_valid[depth_index]) begin
               depth_row_price = depth_prices >> (depth_index * 10);
               depth_row_quantity =
                   (depth_quantities >> (depth_index * 9)) & 9'h1ff;
               if (!depth_has_data || depth_row_price < depth_min_price)
                   depth_min_price = depth_row_price;
               if (!depth_has_data || depth_row_price > depth_max_price)
                   depth_max_price = depth_row_price;
               depth_has_data = 1'b1;
               depth_total_quantity =
                   depth_total_quantity + depth_row_quantity;
               if (mock_is_bid[depth_index])
                   depth_bid_quantity =
                       depth_bid_quantity + depth_row_quantity;
               else
                   depth_ask_quantity =
                       depth_ask_quantity + depth_row_quantity;
           end
        end
        if (depth_has_data) begin
           if (depth_min_price >= 10'd5)
               depth_min_price = depth_min_price - 10'd5;
           if (depth_max_price <= 10'd1018)
               depth_max_price = depth_max_price + 10'd5;
        end
        depth_max_quantity = depth_bid_quantity > depth_ask_quantity ?
                             depth_bid_quantity : depth_ask_quantity;

        if (depth_has_data && depth_max_quantity != 0) begin
           // Ask depth grows as price rises: draw from best ask outward.
           depth_previous_x = DEPTH_PLOT_LEFT;
           depth_previous_y = DEPTH_PLOT_BOTTOM;
           for (depth_index = 0; depth_index < ASK_ROWS;
                depth_index = depth_index + 1) begin
               if (mock_valid[depth_index] &&
                   !mock_is_bid[depth_index]) begin
                   depth_row_price = depth_prices >> (depth_index * 10);
                   depth_row_quantity =
                       (depth_quantities >> (depth_index * 9)) & 9'h1ff;
                   depth_ask_cumulative =
                       depth_ask_cumulative + depth_row_quantity;
                   depth_current_x = depth_price_x(
                       depth_row_price, depth_min_price, depth_max_price);
                   depth_current_y = depth_quantity_y(
                       depth_ask_cumulative, depth_max_quantity);

                   depth_line_low = depth_previous_x < depth_current_x ?
                                    depth_previous_x : depth_current_x;
                   depth_line_high = depth_previous_x < depth_current_x ?
                                     depth_current_x : depth_previous_x;
                   if (y == depth_previous_y &&
                       x >= depth_line_low && x <= depth_line_high)
                       depth_ask_curve_pixel = 1'b1;

                   depth_line_low = depth_previous_y < depth_current_y ?
                                    depth_previous_y : depth_current_y;
                   depth_line_high = depth_previous_y < depth_current_y ?
                                     depth_current_y : depth_previous_y;
                   if (x == depth_current_x &&
                       y >= depth_line_low && y <= depth_line_high)
                       depth_ask_curve_pixel = 1'b1;

                   depth_previous_x = depth_current_x;
                   depth_previous_y = depth_current_y;
               end
           end
           if (depth_ask_cumulative != 0 &&
               y == depth_previous_y &&
               x >= depth_previous_x && x <= DEPTH_PLOT_RIGHT)
               depth_ask_curve_pixel = 1'b1;

           // Bid depth is largest at the lowest bid and falls toward the
           // best bid as price increases.
           depth_bid_cumulative = depth_bid_quantity;
           depth_previous_y = depth_quantity_y(
               depth_bid_cumulative, depth_max_quantity);
           for (depth_index = LIST_ROWS - 1;
                depth_index >= ASK_ROWS;
                depth_index = depth_index - 1) begin
               if (mock_valid[depth_index] &&
                   mock_is_bid[depth_index]) begin
                   depth_row_price = depth_prices >> (depth_index * 10);
                   depth_current_x = depth_price_x(
                       depth_row_price, depth_min_price, depth_max_price);

                   if (!depth_bid_started) begin
                       depth_line_low = DEPTH_PLOT_LEFT < depth_current_x ?
                                        DEPTH_PLOT_LEFT : depth_current_x;
                       depth_line_high = DEPTH_PLOT_LEFT < depth_current_x ?
                                         depth_current_x : DEPTH_PLOT_LEFT;
                       if (y == depth_previous_y &&
                           x >= depth_line_low && x <= depth_line_high)
                           depth_bid_curve_pixel = 1'b1;
                       depth_previous_x = depth_current_x;
                       depth_bid_started = 1'b1;
                   end else begin
                       depth_line_low = depth_previous_x < depth_current_x ?
                                        depth_previous_x : depth_current_x;
                       depth_line_high = depth_previous_x < depth_current_x ?
                                         depth_current_x : depth_previous_x;
                       if (y == depth_previous_y &&
                           x >= depth_line_low && x <= depth_line_high)
                           depth_bid_curve_pixel = 1'b1;
                   end

                   if (depth_index < LIST_ROWS - 1)
                       depth_bid_cumulative = depth_bid_cumulative -
                           ((depth_quantities >>
                             ((depth_index + 1) * 9)) & 9'h1ff);
                   depth_current_y = depth_quantity_y(
                       depth_bid_cumulative, depth_max_quantity);
                   depth_line_low = depth_previous_y < depth_current_y ?
                                    depth_previous_y : depth_current_y;
                   depth_line_high = depth_previous_y < depth_current_y ?
                                     depth_current_y : depth_previous_y;
                   if (x == depth_current_x &&
                       y >= depth_line_low && y <= depth_line_high)
                       depth_bid_curve_pixel = 1'b1;

                   depth_previous_x = depth_current_x;
                   depth_previous_y = depth_current_y;
               end
           end
           // Stop the bid curve at the best bid, then drop to zero depth.
           if (depth_bid_quantity != 0) begin
               depth_line_low = depth_previous_y < DEPTH_PLOT_BOTTOM ?
                                depth_previous_y : DEPTH_PLOT_BOTTOM;
               depth_line_high = depth_previous_y < DEPTH_PLOT_BOTTOM ?
                                 DEPTH_PLOT_BOTTOM : depth_previous_y;
               if (x == depth_previous_x &&
                   y >= depth_line_low && y <= depth_line_high)
                   depth_bid_curve_pixel = 1'b1;
           end

           // Five evenly spaced price and cumulative-quantity tick labels.
           for (depth_label_index = 0; depth_label_index < 5;
                depth_label_index = depth_label_index + 1) begin
               depth_quantity_tick_value =
                   (depth_max_quantity * depth_label_index) / 4;
               depth_label_tick_y = depth_quantity_y(
                   depth_quantity_tick_value, depth_max_quantity);
               depth_label_left = DEPTH_AXIS_LEFT - 30;
               if (depth_min_price == depth_max_price)
                   depth_price_tick_value = depth_min_price;
               else
                   depth_price_tick_value = depth_min_price +
                       ((depth_max_price - depth_min_price) *
                        depth_label_index) / 4;

               if (depth_min_price != depth_max_price ||
                   depth_label_index == 2) begin
                   depth_label_bcd = depth_to_bcd(
                       {3'b000, depth_price_tick_value});
                   depth_label_tick_x = depth_price_x(
                       depth_price_tick_value,
                       depth_min_price,
                       depth_max_price);
                   depth_label_left = depth_label_tick_x - 12;
                   if (x >= depth_label_left &&
                       x < depth_label_left + 24 &&
                       y >= DEPTH_AXIS_BOTTOM + 5 &&
                       y < DEPTH_AXIS_BOTTOM + 12) begin
                       depth_label_character_index =
                           (x - depth_label_left) / 6;
                       depth_label_column =
                           (x - depth_label_left) % 6;
                       depth_label_row = y - DEPTH_AXIS_BOTTOM - 5;
                       depth_label_digit = depth_label_bcd >>
                           ((3 - depth_label_character_index) * 4);
                       depth_label_bitmap =
                           glyph_row(8'h30 + depth_label_digit,
                                     depth_label_row);
                       if (depth_label_character_index < 4 &&
                           depth_label_column < 5 &&
                           glyph_pixel(depth_label_bitmap,
                                       depth_label_column))
                           depth_axis_label_pixel = 1'b1;
                   end
               end

               depth_label_bcd = depth_to_bcd(
                   depth_quantity_tick_value);
               depth_label_tick_y = depth_quantity_y(
                   depth_quantity_tick_value, depth_max_quantity);
               depth_label_left = DEPTH_AXIS_LEFT - 30;
               if (x >= depth_label_left &&
                   x < depth_label_left + 24 &&
                   y >= depth_label_tick_y - 3 &&
                   y < depth_label_tick_y + 4) begin
                   depth_label_character_index = (x - depth_label_left) / 6;
                   depth_label_column = (x - depth_label_left) % 6;
                   depth_label_row = y - depth_label_tick_y + 3;
                   depth_label_digit = depth_label_bcd >>
                       ((3 - depth_label_character_index) * 4);
                   depth_label_bitmap =
                       glyph_row(8'h30 + depth_label_digit,
                                 depth_label_row);
                   if (depth_label_character_index < 4 &&
                       depth_label_column < 5 &&
                       glyph_pixel(depth_label_bitmap,
                                   depth_label_column))
                       depth_axis_label_pixel = 1'b1;
               end
           end
        end
    end

    // Two-pixel L-shaped axes inside the lower, buy-history chart.
    wire graph_axis_pixel =
        ((x >= GRAPH_AXIS_LEFT && x < GRAPH_AXIS_LEFT + GRAPH_AXIS_WIDTH) &&
         (y >= GRAPH_AXIS_TOP && y < GRAPH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH)) ||
        ((y >= GRAPH_AXIS_BOTTOM && y < GRAPH_AXIS_BOTTOM + GRAPH_AXIS_WIDTH) &&
         (x >= GRAPH_AXIS_LEFT && x < GRAPH_AXIS_RIGHT));
    wire order_heading_background_pixel =
        x < ORDER_LIST_WIDTH &&
        ((y >= ASK_LABEL_Y &&
          y < ASK_LABEL_Y + 7 * TEXT_SCALE) ||
         (y >= BID_LABEL_Y &&
          y < BID_LABEL_Y + 7 * TEXT_SCALE));

    localparam GRAPH_SPAN = GRAPH_AXIS_RIGHT - GRAPH_AXIS_LEFT -
                            GRAPH_AXIS_WIDTH - 1;
    localparam GRAPH_PLOT_HEIGHT = GRAPH_AXIS_BOTTOM - GRAPH_AXIS_TOP -
                                   GRAPH_AXIS_WIDTH - 1;
    localparam GRAPH_X_OFFSET_BITS =
        (GRAPH_SPAN > 0) ? $clog2(GRAPH_SPAN + 1) : 1;
    localparam GRAPH_SEGMENT_BITS =
        (GRAPH_POINTS > 1) ? $clog2(GRAPH_POINTS) : 1;
    localparam GRAPH_SCALED_X_BITS =
        (GRAPH_SPAN > 0 && GRAPH_POINTS > 1) ?
        $clog2(GRAPH_SPAN * (GRAPH_POINTS - 1) + 1) : 1;

    reg [GRAPH_X_OFFSET_BITS-1:0] graph_x_offset;
    reg [GRAPH_SCALED_X_BITS-1:0] graph_scaled_x;
    reg [GRAPH_SEGMENT_BITS-1:0] graph_segment_index;
    reg [GRAPH_X_OFFSET_BITS-1:0] graph_segment_progress;
    reg [10:0] graph_price_0;
    reg [10:0] graph_price_1;
    reg [10:0] graph_clamped_price_0;
    reg [10:0] graph_clamped_price_1;
    reg [10:0] graph_price_delta_0;
    reg [10:0] graph_price_delta_1;
    reg [20:0] graph_price_product_0;
    reg [20:0] graph_price_product_1;
    reg [9:0] graph_y_0;
    reg [9:0] graph_y_1;
    reg [9:0] graph_line_y;
    reg [10:0] graph_next_progress;
    reg [9:0] graph_next_y;
    reg [9:0] graph_low_y;
    reg [9:0] graph_high_y;
    reg [9:0] graph_y_delta;
    reg [20:0] graph_y_product;
    reg [20:0] graph_next_y_product;
    reg [9:0] graph_y_step;
    reg [9:0] graph_next_y_step;
    reg [9:0] graph_plot_height;
    reg graph_line_pixel;

    reg graph_axis_label_pixel;
    reg graph_time_label_pixel;
    reg [9:0] graph_tick_price;
    reg [9:0] graph_tick_y;
    reg [9:0] graph_tick_left;
    reg [15:0] graph_tick_bcd;
    reg [4:0] graph_tick_character_index;
    reg [2:0] graph_tick_column;
    reg [2:0] graph_tick_row;
    reg [3:0] graph_tick_digit;
    reg [4:0] graph_tick_bitmap;
    reg [1:0] graph_time_character_index;
    reg [2:0] graph_time_column;
    reg [2:0] graph_time_row;
    reg [4:0] graph_time_bitmap;
    integer graph_tick_index;

    // Interpolate between adjacent historical samples and map prices to the
    // configured vertical range. Narrow intermediates avoid 32-bit datapaths.
    always @(*) begin
        graph_x_offset = 0;
        graph_scaled_x = 0;
        graph_segment_index = 0;
        graph_segment_progress = 0;
        graph_price_0 = 0;
        graph_price_1 = 0;
        graph_clamped_price_0 = 0;
        graph_clamped_price_1 = 0;
        graph_price_delta_0 = 0;
        graph_price_delta_1 = 0;
        graph_price_product_0 = 0;
        graph_price_product_1 = 0;
        graph_y_0 = 0;
        graph_y_1 = 0;
        graph_line_y = 0;
        graph_next_progress = 0;
        graph_next_y = 0;
        graph_low_y = 0;
        graph_high_y = 0;
        graph_y_delta = 0;
        graph_y_product = 0;
        graph_next_y_product = 0;
        graph_y_step = 0;
        graph_next_y_step = 0;
        graph_plot_height = GRAPH_PLOT_HEIGHT;
        graph_line_pixel = 1'b0;

        if (GRAPH_POINTS >= 2 &&
            GRAPH_PRICE_MAX > GRAPH_PRICE_MIN &&
            GRAPH_SPAN > 0 &&
            x >= GRAPH_AXIS_LEFT + GRAPH_AXIS_WIDTH &&
            x < GRAPH_AXIS_RIGHT) begin
            graph_x_offset = x - GRAPH_AXIS_LEFT - GRAPH_AXIS_WIDTH;
            graph_scaled_x = graph_x_offset * (GRAPH_POINTS - 1);
            graph_segment_index = graph_scaled_x / GRAPH_SPAN;
            graph_segment_progress = graph_scaled_x % GRAPH_SPAN;
            if (graph_segment_index >= GRAPH_POINTS - 1) begin
                graph_segment_index = GRAPH_POINTS - 2;
                graph_segment_progress = GRAPH_SPAN;
            end

            graph_price_0 =
                selected_graph_prices[graph_segment_index * 10 +: 10];
            graph_price_1 =
                selected_graph_prices[(graph_segment_index + 1) * 10 +: 10];

            graph_clamped_price_0 = graph_price_0;
            graph_clamped_price_1 = graph_price_1;
            if (graph_clamped_price_0 < GRAPH_PRICE_MIN)
                graph_clamped_price_0 = GRAPH_PRICE_MIN;
            else if (graph_clamped_price_0 > GRAPH_PRICE_MAX)
                graph_clamped_price_0 = GRAPH_PRICE_MAX;
            if (graph_clamped_price_1 < GRAPH_PRICE_MIN)
                graph_clamped_price_1 = GRAPH_PRICE_MIN;
            else if (graph_clamped_price_1 > GRAPH_PRICE_MAX)
                graph_clamped_price_1 = GRAPH_PRICE_MAX;

            graph_price_delta_0 = graph_clamped_price_0 - GRAPH_PRICE_MIN;
            graph_price_delta_1 = graph_clamped_price_1 - GRAPH_PRICE_MIN;
            graph_price_product_0 = graph_price_delta_0 * graph_plot_height;
            graph_price_product_1 = graph_price_delta_1 * graph_plot_height;
            graph_y_0 = GRAPH_AXIS_BOTTOM - 1 -
                graph_price_product_0 / (GRAPH_PRICE_MAX - GRAPH_PRICE_MIN);
            graph_y_1 = GRAPH_AXIS_BOTTOM - 1 -
                graph_price_product_1 / (GRAPH_PRICE_MAX - GRAPH_PRICE_MIN);

            if (graph_y_1 >= graph_y_0)
                graph_y_delta = graph_y_1 - graph_y_0;
            else
                graph_y_delta = graph_y_0 - graph_y_1;
            graph_y_product = graph_y_delta * graph_segment_progress;
            graph_y_step = graph_y_product / GRAPH_SPAN;
            if (graph_y_1 >= graph_y_0)
                graph_line_y = graph_y_0 + graph_y_step;
            else
                graph_line_y = graph_y_0 - graph_y_step;

            graph_next_progress = graph_segment_progress + GRAPH_POINTS - 1;
            if (graph_next_progress > GRAPH_SPAN)
                graph_next_progress = GRAPH_SPAN;
            graph_next_y_product = graph_y_delta * graph_next_progress;
            graph_next_y_step = graph_next_y_product / GRAPH_SPAN;
            if (graph_y_1 >= graph_y_0)
                graph_next_y = graph_y_0 + graph_next_y_step;
            else
                graph_next_y = graph_y_0 - graph_next_y_step;
            if (graph_line_y < graph_next_y) begin
                graph_low_y = graph_line_y;
                graph_high_y = graph_next_y;
            end else begin
                graph_low_y = graph_next_y;
                graph_high_y = graph_line_y;
            end
            graph_line_pixel = y >= graph_low_y && y <= graph_high_y;
        end
    end

    // Label the price scale and show the sample direction along the time axis.
    always @(*) begin
        graph_axis_label_pixel = 1'b0;
        graph_time_label_pixel = 1'b0;
        graph_tick_price = GRAPH_PRICE_MIN;
        graph_tick_y = GRAPH_AXIS_BOTTOM - 1;
        graph_tick_left = GRAPH_AXIS_LEFT - 30;
        graph_tick_bcd = 16'd0;
        graph_tick_character_index = 5'd0;
        graph_tick_column = 3'd0;
        graph_tick_row = 3'd0;
        graph_tick_digit = 4'd0;
        graph_tick_bitmap = 5'd0;
        graph_time_character_index = 2'd0;
        graph_time_column = 3'd0;
        graph_time_row = 3'd0;
        graph_time_bitmap = 5'd0;

        if (GRAPH_PRICE_MAX > GRAPH_PRICE_MIN) begin
            for (graph_tick_index = 0; graph_tick_index < 5;
                 graph_tick_index = graph_tick_index + 1) begin
                graph_tick_price = GRAPH_PRICE_MIN +
                    ((GRAPH_PRICE_MAX - GRAPH_PRICE_MIN) *
                     graph_tick_index) / 4;
                graph_tick_y = GRAPH_AXIS_BOTTOM - 1 -
                    (GRAPH_PLOT_HEIGHT * graph_tick_index) / 4;
                graph_tick_bcd = depth_to_bcd(
                    {3'b000, graph_tick_price});
                graph_tick_left = GRAPH_AXIS_LEFT - 30;

                if (y >= graph_tick_y - 3 && y < graph_tick_y + 4 &&
                    x >= graph_tick_left && x < graph_tick_left + 24) begin
                    graph_tick_character_index =
                        (x - graph_tick_left) / 6;
                    graph_tick_column = (x - graph_tick_left) % 6;
                    graph_tick_row = y - graph_tick_y + 3;
                    graph_tick_digit = graph_tick_bcd >>
                        ((3 - graph_tick_character_index) * 4);
                    graph_tick_bitmap = glyph_row(
                        8'h30 + graph_tick_digit, graph_tick_row);
                    if (graph_tick_character_index < 4 &&
                        graph_tick_column < 5 &&
                        glyph_pixel(graph_tick_bitmap,
                                    graph_tick_column))
                        graph_axis_label_pixel = 1'b1;
                end
            end
        end

        if (y >= GRAPH_AXIS_BOTTOM + 4 &&
            y < GRAPH_AXIS_BOTTOM + 11) begin
            graph_time_row = y - GRAPH_AXIS_BOTTOM - 4;

            if (x >= GRAPH_AXIS_LEFT + 4 &&
                x < GRAPH_AXIS_LEFT + 22) begin
                graph_time_character_index =
                    (x - GRAPH_AXIS_LEFT - 4) / 6;
                graph_time_column =
                    (x - GRAPH_AXIS_LEFT - 4) % 6;
                graph_time_bitmap = glyph_row(
                    graph_time_character(1'b0, graph_time_character_index),
                    graph_time_row);
                if (graph_time_character_index < 3 &&
                    graph_time_column < 5 &&
                    glyph_pixel(graph_time_bitmap, graph_time_column))
                    graph_time_label_pixel = 1'b1;
            end

            if (x >= GRAPH_AXIS_RIGHT - 20 &&
                x < GRAPH_AXIS_RIGHT - 2) begin
                graph_time_character_index =
                    (x - (GRAPH_AXIS_RIGHT - 20)) / 6;
                graph_time_column =
                    (x - (GRAPH_AXIS_RIGHT - 20)) % 6;
                graph_time_bitmap = glyph_row(
                    graph_time_character(1'b1, graph_time_character_index),
                    graph_time_row);
                if (graph_time_character_index < 3 &&
                    graph_time_column < 5 &&
                    glyph_pixel(graph_time_bitmap, graph_time_column))
                    graph_time_label_pixel = 1'b1;
            end
        end
    end

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

    // Draw the order list and two stacked chart panels.
    always @(*) begin
        // Pixels outside the active 640x480 area are black.
        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (video_on) begin
            // Divider lines separate the order list and the two charts.
            if ((x >= ORDER_LIST_WIDTH &&
                 x < ORDER_LIST_WIDTH + SEPARATOR_WIDTH) ||
                (x >= ORDER_LIST_WIDTH &&
                 y >= GRAPH_HEIGHT - SEPARATOR_WIDTH &&
                 y < GRAPH_HEIGHT + SEPARATOR_WIDTH)) begin
                red = 4'h5;
                green = 4'h7;
                blue = 4'h9;
            end else if (x < ORDER_LIST_WIDTH) begin
                // Selected ticker, two-sided market depth, and row values.
                red = order_heading_background_pixel ? 4'h5 : 4'h1;
                green = order_heading_background_pixel ? 4'h7 : 4'h2;
                blue = order_heading_background_pixel ? 4'h9 : 4'h4;
                if (label_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (header_symbol_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (price_pixel && mock_is_bid[selected_row]) begin
                    red = 4'hf;
                    green = 4'h5;
                    blue = 4'h5;
                end else if (price_pixel) begin
                    red = 4'h3;
                    green = 4'hf;
                    blue = 4'h8;
                end else if (quantity_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end
            end else if (y < GRAPH_HEIGHT) begin
                // Upper-right panel is reserved for the future depth chart.
                red = 4'h1;
                green = 4'h2;
                blue = 4'h3;
                if (chart_title_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (depth_axis_label_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (depth_axis_pixel) begin
                    red = 4'h8;
                    green = 4'ha;
                    blue = 4'hc;
                end else if (depth_ask_curve_pixel) begin
                    red = 4'h3;
                    green = 4'hf;
                    blue = 4'h8;
                end else if (depth_bid_curve_pixel) begin
                    red = 4'hf;
                    green = 4'h5;
                    blue = 4'h5;
                end
            end else begin
                // Lower-right panel plots the selected stock's buy history.
                red = 4'h1;
                green = 4'h2;
                blue = 4'h3;
                if (chart_title_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;

                end else if (graph_axis_label_pixel ||
                             graph_time_label_pixel) begin
                    red = 4'hb;
                    green = 4'hd;
                    blue = 4'hf;
                end else if (graph_axis_pixel) begin
                    red = 4'h8;
                    green = 4'ha;
                    blue = 4'hc;
                end else if (graph_line_pixel) begin
                    red = 4'h3;
                    green = 4'hf;
                    blue = 4'h8;
                end
            end
        end
    end










endmodule


//Bids and asks row title should be same color (currently bids is one color)
