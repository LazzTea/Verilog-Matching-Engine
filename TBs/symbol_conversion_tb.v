`timescale 1ns / 1ps

module tb;

reg  [31:0] ticker;
wire [3:0]  symbol;
wire        valid;

// Input List: APPL = 0, GOOG = 1 (first in the list is symbol 0)
symbol_conversion #(
    .NUM_TICKERS(2),
    .PTICKERS({"APPL", "GOOG"})
)
dut (
    .ticker(ticker),
    .symbol(symbol), .valid(valid)
);

task test (input [31:0] str, input [3:0] exp_sym, input exp_valid);
begin
    ticker = str;

    #1;

if (symbol != exp_sym) begin
    $display("Inputing %s, Becomes %b, Instead of Expected %b\n", str, symbol, exp_sym);
end

if (valid != exp_valid) begin
    $display("Inputing %s, Valid %b, Instead of Expected %b\n", str, valid, exp_valid);
end

  // Change Later to Count Errors or something
    if ((symbol == exp_sym) && (valid == exp_valid)) begin
        $display("Correct");
    end
end
endtask


initial begin
    $display("Begin Testing Symbol Conversion");
    test("APPL", 0, 1);
    test("GOOG", 1, 1);
    test("TSLA", 0, 0);   // not in the list
end
endmodule