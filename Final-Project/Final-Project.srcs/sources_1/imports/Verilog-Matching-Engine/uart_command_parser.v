module uart_command_parser (
    input wire clk,
    input wire rst,
    input wire [7:0] byte_data,
    input wire byte_valid,
    output reg order_valid,
    input wire order_ready,
    output reg [3:0] order_symbol,
    output reg order_buy,
    output reg [9:0] order_price,
    output reg [8:0] order_qty,
    output reg command_error
);
    localparam [2:0] STATE_SIDE        = 3'd0,
                     STATE_SIDE_COMMA  = 3'd1,
                     STATE_SYMBOL      = 3'd2,
                     STATE_PRICE       = 3'd3,
                     STATE_QUANTITY    = 3'd4,
                     STATE_DISCARD_LINE = 3'd5;

    reg [2:0] state;
    reg command_buy;
    reg [31:0] symbol_token;
    reg [2:0] symbol_length;
    reg [15:0] number_value;
    reg [3:0] number_digits;
    reg [3:0] command_symbol;
    reg [9:0] command_price;
    wire line_ending = byte_data == 8'h0a || byte_data == 8'h0d;

    function [4:0] decode_symbol;
        input [31:0] token;
        input [2:0] length;
        begin
            decode_symbol = 5'b00000;
            case (length)
                2: begin
                    case (token[15:0])
                        16'h4241: decode_symbol = {1'b1, 4'd14}; // BA
                        16'h4b4f: decode_symbol = {1'b1, 4'd15}; // KO
                        default: decode_symbol = 5'b00000;
                    endcase
                end
                3: begin
                    case (token[23:0])
                        24'h414d44: decode_symbol = {1'b1, 4'd9};  // AMD
                        24'h49424d: decode_symbol = {1'b1, 4'd11}; // IBM
                        24'h4a504d: decode_symbol = {1'b1, 4'd12}; // JPM
                        24'h444953: decode_symbol = {1'b1, 4'd13}; // DIS
                        default: decode_symbol = 5'b00000;
                    endcase
                end
                4: begin
                    case (token)
                        32'h4141504c: decode_symbol = {1'b1, 4'd0}; // AAPL
                        32'h4d534654: decode_symbol = {1'b1, 4'd1}; // MSFT
                        32'h474f4f47: decode_symbol = {1'b1, 4'd2}; // GOOG
                        32'h414d5a4e: decode_symbol = {1'b1, 4'd3}; // AMZN
                        32'h4e564441: decode_symbol = {1'b1, 4'd4}; // NVDA
                        32'h54534c41: decode_symbol = {1'b1, 4'd5}; // TSLA
                        32'h4d455441: decode_symbol = {1'b1, 4'd6}; // META
                        32'h4e464c58: decode_symbol = {1'b1, 4'd7}; // NFLX
                        32'h494e5443: decode_symbol = {1'b1, 4'd8}; // INTC
                        32'h4f52434c: decode_symbol = {1'b1, 4'd10}; // ORCL
                        default: decode_symbol = 5'b00000;
                    endcase
                end
                default: decode_symbol = 5'b00000;
            endcase
        end
    endfunction

    reg [4:0] decoded_symbol;

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_SIDE;
            command_buy <= 1'b0;
            symbol_token <= 32'd0;
            symbol_length <= 3'd0;
            number_value <= 16'd0;
            number_digits <= 4'd0;
            command_symbol <= 4'd0;
            command_price <= 10'd0;
            order_valid <= 1'b0;
            order_symbol <= 4'd0;
            order_buy <= 1'b0;
            order_price <= 10'd0;
            order_qty <= 9'd0;
            command_error <= 1'b0;
        end else begin
            command_error <= 1'b0;

            if (order_valid && order_ready)
                order_valid <= 1'b0;

            if (byte_valid) begin
                if (order_valid && !order_ready) begin
                    if (line_ending)
                        state <= STATE_SIDE;
                    else begin
                        command_error <= 1'b1;
                        state <= STATE_DISCARD_LINE;
                    end
                end else begin
                    case (state)
                        STATE_SIDE: begin
                            if (line_ending) begin
                                state <= STATE_SIDE;
                            end else if (byte_data == 8'h42) begin
                                command_buy <= 1'b1;
                                state <= STATE_SIDE_COMMA;
                            end else if (byte_data == 8'h53) begin
                                command_buy <= 1'b0;
                                state <= STATE_SIDE_COMMA;
                            end else begin
                                command_error <= 1'b1;
                                state <= STATE_DISCARD_LINE;
                            end
                        end

                        STATE_SIDE_COMMA: begin
                            if (byte_data == 8'h2c) begin
                                symbol_token <= 32'd0;
                                symbol_length <= 3'd0;
                                state <= STATE_SYMBOL;
                            end else begin
                                command_error <= 1'b1;
                                if (line_ending)
                                    state <= STATE_SIDE;
                                else
                                    state <= STATE_DISCARD_LINE;
                            end
                        end

                        STATE_SYMBOL: begin
                            if (byte_data == 8'h2c) begin
                                decoded_symbol =
                                    decode_symbol(symbol_token, symbol_length);
                                if (decoded_symbol[4]) begin
                                    command_symbol <= decoded_symbol[3:0];
                                    number_value <= 16'd0;
                                    number_digits <= 4'd0;
                                    state <= STATE_PRICE;
                                end else begin
                                    command_error <= 1'b1;
                                    state <= STATE_DISCARD_LINE;
                                end
                            end else if (byte_data >= 8'h41 &&
                                         byte_data <= 8'h5a &&
                                         symbol_length < 4) begin
                                symbol_token <= {symbol_token[23:0],
                                                 byte_data};
                                symbol_length <= symbol_length + 1'b1;
                            end else begin
                                command_error <= 1'b1;
                                if (line_ending)
                                    state <= STATE_SIDE;
                                else
                                    state <= STATE_DISCARD_LINE;
                            end
                        end

                        STATE_PRICE: begin
                            if (byte_data == 8'h2c) begin
                                if (number_digits != 0 &&
                                    number_value != 0 &&
                                    number_value <= 16'd1023) begin
                                    command_price <= number_value[9:0];
                                    number_value <= 16'd0;
                                    number_digits <= 4'd0;
                                    state <= STATE_QUANTITY;
                                end else begin
                                    command_error <= 1'b1;
                                    state <= STATE_DISCARD_LINE;
                                end
                            end else if (byte_data >= 8'h30 &&
                                         byte_data <= 8'h39 &&
                                         number_digits < 4) begin
                                number_value <= number_value * 10 +
                                                (byte_data - 8'h30);
                                number_digits <= number_digits + 1'b1;
                            end else begin
                                command_error <= 1'b1;
                                if (line_ending)
                                    state <= STATE_SIDE;
                                else
                                    state <= STATE_DISCARD_LINE;
                            end
                        end

                        STATE_QUANTITY: begin
                            if (line_ending) begin
                                if (number_digits != 0 &&
                                    number_value != 0 &&
                                    number_value <= 16'd511) begin
                                    order_symbol <= command_symbol;
                                    order_buy <= command_buy;
                                    order_price <= command_price;
                                    order_qty <= number_value[8:0];
                                    order_valid <= 1'b1;
                                    state <= STATE_SIDE;
                                end else begin
                                    command_error <= 1'b1;
                                    state <= STATE_SIDE;
                                end
                            end else if (byte_data >= 8'h30 &&
                                         byte_data <= 8'h39 &&
                                         number_digits < 3) begin
                                number_value <= number_value * 10 +
                                                (byte_data - 8'h30);
                                number_digits <= number_digits + 1'b1;
                            end else begin
                                command_error <= 1'b1;
                                state <= STATE_DISCARD_LINE;
                            end
                        end

                        STATE_DISCARD_LINE: begin
                            if (line_ending)
                                state <= STATE_SIDE;
                        end

                        default: begin
                            state <= STATE_SIDE;
                        end
                    endcase
                end
            end
        end
    end
endmodule
