`timescale 1ns / 1ps

module tb;

reg [3:0] symbol_in;
wire [3:0] symbol_out;

reg [39:0] string_in;
wire [39:0] string_out;

// Input List: APPL = 0,
symConv #(
  .NUM_TICKERS(2),
  .PTICKERS({"GOOG ", "AAPL "})
) dut (
  .symbol_in(symbol_in), .symbol_out(symbol_out),
  .string_in(string_in), .string_out(string_out)
);

task test (reg [3:0] sym, reg [39:0] exp_str,
    reg [39:0] str, reg [3:0] exp_sym);

symbol_in = sym;
string_in = str;

#1;

if (string_out != exp_str) begin
  $display("Inputing %b, Becomes %s, Instead of Expected %s\n", sym, string_out, exp_str);
end

if (symbol_out != exp_sym) begin
  $display("Inputing %s, Becomes %b, Instead of Expected %b\n", str, symbol_out, exp_sym);
end

// Change Later to Count Errors or something
if ((string_out == exp_str) && (symbol_out == exp_sym)) begin
  $display("Correct");
end

endtask


initial begin
  $display("Begin Testing Symbol Conversion");
  test(0, "AAPL ", "AAPL ", 0);
  test(1, "GOOG ", "GOOG ", 1);
end
  
endmodule