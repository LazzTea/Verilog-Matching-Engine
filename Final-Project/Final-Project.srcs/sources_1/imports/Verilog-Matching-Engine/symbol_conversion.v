module symbol_conversion #(
    parameter NUM_TICKERS = 1,
    parameter [32*NUM_TICKERS-1:0] PTICKERS = "AAPL"
) (
    input wire [31:0] ticker,

    output reg [3:0] symbol,
    output reg       valid
);

// Verilog is Trash so we need this instead of just setting the param
wire [31:0] TICKERS [0:NUM_TICKERS-1];

genvar n;
generate
    for (n = 0; n < NUM_TICKERS; n = n + 1) begin : gen_unpack
        assign TICKERS[n] = PTICKERS[(NUM_TICKERS-1-n)*32 +: 32];
    end
endgenerate


// Convert Ticker -> Symbol ID
integer i;
always @* begin
    symbol = 0;
    valid  = 0;
    for (i = 0; i < NUM_TICKERS; i = i + 1) begin
        if (ticker == TICKERS[i]) begin
            symbol = i[3:0];
            valid  = 1;
        end
    end
end

endmodule