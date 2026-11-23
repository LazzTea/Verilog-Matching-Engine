module userCtrls (
    input wire clk,
    input wire rst,

    input wire [7:0]    ch,
    input wire          valid_ch,

    output reg [31:0]   symbol,
    output reg          buy,
    output reg [9:0]    price,
    output reg [8:0]    qty,
    output wire         valid
);

// buy [String Symbol] [Price] [Quantity]
// sell [String Symbol] [Price] [Quantity]
// 4 + 1 + 4 + 1 + 3 + 1 + 3
// User Input
reg [7:0] uin [0:17];
reg [4:0] indx = 0;

reg valid_order = 0;

reg [5:0] ptr;
reg next;

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        indx = 0;
        valid_order = 0;
    end else if (!valid_ch)
        // Do nothing if Valid Char is not true
        valid_order = 0;
    else if ((ch == 8'h0D || ch == 8'h0A) && (uin[0] == "b" || uin[0] == "s") && indx != 0) begin
        valid_order = 1;
        ptr = 0;

        // Parse Input
        if (indx < 12) valid_order = 0;

        // Buy or Sell
        if (valid_order && {uin[ptr], uin[ptr+1], uin[ptr+2]} == "buy") begin
            buy = 1;
            ptr = ptr + 3;
        end else if (valid_order && {uin[ptr], uin[ptr+1], uin[ptr+2],  uin[ptr+3]} == "sell") begin
            buy = 0;
            ptr = ptr + 4;
        end else begin 
            valid_order = 0;
        end

        // Check for space
        if (uin[ptr] != " ") valid_order = 0;
        ptr = ptr + 1;

        // Ticker Symbol
        if (valid_order) begin
            symbol = {uin[ptr], uin[ptr+1], uin[ptr+2],  uin[ptr+3]};
            ptr = ptr + 4;
        end

        // Ensure ptr is not OOB
        if (ptr >= indx) valid_order = 0;
        next = 0;

        // Check for space
        if (uin[ptr] != " ") valid_order = 0;
        ptr = ptr + 1;

        // Price
        for (i = 0; i < 3; i = i + 1) begin
            if (!next && valid_order && ptr < indx) begin
                // Back to Back spaces are errors
                if (uin[ptr] == " " && i == 0) begin
                    valid_order = 0;
                end 
                // Space after the first input moves on to next parse
                else if (uin[ptr] == " ") begin
                    next = 1;
                end 
                // Ensure input is a digit
                else if (uin[ptr] >= 8'h30 && uin[ptr] <= 8'h39) begin
                    if (i == 0) price = uin[ptr] - 8'h30;
                    else price = price * 10 + uin[ptr] - 8'h30;
                    ptr = ptr + 1;
                end
                // Invalid if input is not a digit
                else if (uin[ptr] < 8'h30 || uin[ptr] > 8'h39) begin
                    valid_order = 0;
                end
            end
        end

        // Ensure ptr is not OOB
        if (ptr >= indx) valid_order = 0;
        next = 0;

        // Check for space
        if (uin[ptr] != " ") valid_order = 0;
        ptr = ptr + 1;

        // Quantity
        for (i = 0; i < 3; i = i + 1) begin
            if (!next && valid_order && ptr < indx) begin
                // Ensure input is a digit
                if (uin[ptr] >= 8'h30 && uin[ptr] <= 8'h39) begin
                    if (i == 0) qty = uin[ptr] - 8'h30;
                    else qty = qty * 10 + uin[ptr] - 8'h30;
                    ptr = ptr + 1;
                end 
                // Invalid if input is not a digit
                else if (uin[ptr] < 8'h30 || uin[ptr] > 8'h39) begin
                    valid_order = 0;
                end
            end else if (i == 0) valid_order = 0;
        end

        // Trailing Inputs is an Error
        if (ptr != indx) valid_order = 0;

        // Clear Index
        indx = 0;

    end else if ((ch == 8'h0D || ch == 8'h0A) && indx != 0) begin
        // Invalid First Character, Can't Be correct
        valid_order = 0;
        indx = 0;
    end

    else begin
        // Store Char
        if (indx < 18 && !(ch == 8'h0D || ch == 8'h0A)) begin
            uin[indx] = ch;
            indx = indx + 1;
        end

        valid_order = 0;
    end
end

assign valid = valid_order;

endmodule