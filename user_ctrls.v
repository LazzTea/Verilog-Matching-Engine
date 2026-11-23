module userCtrls (
    input wire clk,
    input wire rst,

    input wire [7:0]    ch,
    input wire          valid_ch,

    // Creating a new order
    output reg [31:0]   symbol,
    output reg          buy,
    output reg [9:0]    price,
    output reg [8:0]    qty,

    output wire         valid,
    output wire         valid_i
);

// buy [String Symbol] [Price] [Quantity]
// sell [String Symbol] [Price] [Quantity]
// 4 + 1 + 4 + 1 + 3 + 1 + 3
// User Input
reg [7:0] uin [0:17];
reg [4:0] indx = 0;

reg [9:0] r_price;
reg [9:0] r_qty;

reg valid_order = 0;
reg valid_info = 0;

reg [5:0] ptr;
reg next;

integer i;

// Parse Steps
localparam S_IDLE  = 4'd0;  // Store chars / wait for terminator
localparam S_BUY   = 4'd1;  // Buy or Sell
localparam S_SP1   = 4'd2;  // Space after command
localparam S_SYM   = 4'd3;  // Ticker Symbol
localparam S_SP2   = 4'd4;  // OOB check + space after symbol
localparam S_PRICE = 4'd5;  // Price, one digit per step
localparam S_SP3   = 4'd6;  // OOB check + space after price
localparam S_QTY   = 4'd7;  // Quantity, one digit per step
localparam S_END   = 4'd8;  // Trailing input check
localparam S_DONE  = 4'd9;  // Present result for one cycle
localparam S_INFO  = 4'd10; // Shows graph info for a stock

reg [3:0] step = S_IDLE;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        indx        <= 0;
        valid_order <= 0;
        valid_info  <= 0;
        step        <= S_IDLE;
    end else begin
        case (step)

        S_IDLE: begin
            if (!valid_ch)
                // Do nothing if Valid Char is not true
                valid_order <= 0;
            else if ((ch == 8'h0D || ch == 8'h0A) && (uin[0] == "b" || uin[0] == "s") && indx != 0) begin
                ptr <= 0;

                // Parse Input
                if (indx < 12) valid_order <= 0;
                else           valid_order <= 1;

                step <= S_BUY;
            end else if ((ch == 8'h0D || ch == 8'h0A) && uin[0] == "i" && indx != 0) begin
                // View stock info
                step <= S_INFO;
            end else if ((ch == 8'h0D || ch == 8'h0A) && indx != 0) begin
                // Invalid First Character, Can't Be correct
                valid_order <= 0;
                indx        <= 0;
            end else begin
                // Store Char
                if (indx < 18 && !(ch == 8'h0D || ch == 8'h0A)) begin
                    uin[indx] <= ch;
                    indx      <= indx + 1;
                end

                valid_order <= 0;
            end
        end

        S_BUY: begin
            // Buy or Sell
            if (valid_order && {uin[ptr], uin[ptr+1], uin[ptr+2]} == "buy") begin
                buy <= 1;
                ptr <= ptr + 3;
            end else if (valid_order && {uin[ptr], uin[ptr+1], uin[ptr+2], uin[ptr+3]} == "sell") begin
                buy <= 0;
                ptr <= ptr + 4;
            end else begin
                valid_order <= 0;
            end

            step <= S_SP1;
        end

        S_SP1: begin
            // Check for space
            if (uin[ptr] != " ") valid_order <= 0;
            ptr <= ptr + 1;

            step <= S_SYM;
        end

        S_SYM: begin
            // Ticker Symbol
            if (valid_order) begin
                symbol <= {uin[ptr], uin[ptr+1], uin[ptr+2], uin[ptr+3]};
                ptr    <= ptr + 4;
            end

            step <= S_SP2;
        end

        S_SP2: begin
            // Ensure ptr is not OOB
            if (ptr >= indx) valid_order <= 0;
            next <= 0;

            // Check for space
            if (uin[ptr] != " ") valid_order <= 0;
            ptr <= ptr + 1;

            i    <= 0;
            step <= S_PRICE;
        end

        S_PRICE: begin
            // Price (one loop iteration per step)
            if (!next && valid_order && ptr < indx) begin
                // Back to Back spaces are errors
                if (uin[ptr] == " " && i == 0) begin
                    valid_order <= 0;
                end
                // Space after the first input moves on to next parse
                else if (uin[ptr] == " ") begin
                    next <= 1;
                end
                // Ensure input is a digit
                else if (uin[ptr] >= 8'h30 && uin[ptr] <= 8'h39) begin
                    if (i == 0) r_price <= uin[ptr] - 8'h30;
                    else        r_price <= r_price * 10 + uin[ptr] - 8'h30;
                    ptr <= ptr + 1;
                end
                // Invalid if input is not a digit
                else if (uin[ptr] < 8'h30 || uin[ptr] > 8'h39) begin
                    valid_order <= 0;
                end
            end

            if (i == 2) step <= S_SP3;
            else        i    <= i + 1;
        end

        S_SP3: begin
            // Ensure ptr is not OOB
            if (ptr >= indx) valid_order <= 0;
            next <= 0;

            // Check for space
            if (uin[ptr] != " ") valid_order <= 0;
            ptr <= ptr + 1;

            i    <= 0;
            step <= S_QTY;
        end

        S_QTY: begin
            // Quantity (one loop iteration per step)
            if (!next && valid_order && ptr < indx) begin
                // Ensure input is a digit
                if (uin[ptr] >= 8'h30 && uin[ptr] <= 8'h39) begin
                    if (i == 0) r_qty <= uin[ptr] - 8'h30;
                    else        r_qty <= r_qty * 10 + uin[ptr] - 8'h30;
                    ptr <= ptr + 1;
                end
                // Invalid if input is not a digit
                else if (uin[ptr] < 8'h30 || uin[ptr] > 8'h39) begin
                    valid_order <= 0;
                end
            end else if (i == 0) valid_order <= 0;

            if (i == 2) step <= S_END;
            else        i    <= i + 1;
        end

        S_END: begin
            // Trailing Inputs is an Error
            if (ptr != indx) valid_order <= 0;

            // Store price & quantity
            price <= r_price;

            if (r_qty < 512)    qty <= r_qty;
            else                qty <= 9'd511;

            // Clear Index
            indx <= 0;

            step <= S_DONE;
        end

        S_DONE: begin
            // valid is high for this one cycle if the order passed
            valid_order <= 0;
            valid_info <= 0;
            step        <= S_IDLE;
        end

        S_INFO: begin
            if (indx == 9 && {uin[0], uin[1], uin[2], uin[3], uin[4]} == "info ") begin
                symbol <= {uin[5], uin[6], uin[7], uin[8]};
                valid_info <= 1;
            end

            indx <= 0;
            step <= S_DONE;
        end

        default: step <= S_IDLE;

        endcase
    end
end

// Only valid when parsing is complete
assign valid    = valid_order && (step == S_DONE);
assign valid_i  = valid_info  && (step == S_DONE);

endmodule