module symConv #(
  parameter [3:0] NUM_TICKERS = 1,
  parameter PTICKERS = "AAPL"
) (
  input wire [3:0] symbol_in,
  input wire [39:0] string_in,

  output reg [3:0] symbol_out,
  output wire [39:0] string_out
);

// Verilog is Trash so we need this instead of just setting the param
wire [39:0] TICKERS [0:NUM_TICKERS-1];

genvar n;
generate
  for (n = 0; n < NUM_TICKERS; n = n + 1) begin : gen_unpack
    assign TICKERS[n] = PTICKERS[n*40 +: 40];
  end
endgenerate


// Convert String -> Symbol ID
integer i;
always @* begin
  symbol_out = 4'hF; // Default/invalid ID if no match is found
  for (i = 0; i < NUM_TICKERS; i = i + 1) begin
    if (string_in == TICKERS[i]) begin
      symbol_out = i[3:0];
    end
  end
end

// Convert Symbol ID -> String (Direct Array Lookup)
assign string_out = (symbol_in < NUM_TICKERS) ? TICKERS[symbol_in] : 40'h2020202020;

endmodule