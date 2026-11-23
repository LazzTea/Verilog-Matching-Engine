`timescale 1ns / 1ps

module tb;

reg clk;
reg rst;

// New Orders
reg in_valid;
wire in_ready;

reg [3:0] symbol;
reg buy;
reg [9:0] price;
reg [8:0] qty;

wire [19:0] transaction;
wire trans_valid;

wire full;

// Note: Consider removing the rest, we dont need to edit orders

// Display Orders
reg [3:0] request_symbol;
reg request_buy;
reg [11:0] request_num;

wire [31:0] req_out;
wire req_out_valid;

// Testing Variables
reg [7:0] e;

order_book dut (
  .clk(clk), .rst(rst),
  .in_valid(in_valid), .in_ready(in_ready),
  .symbol(symbol), .buy(buy), .price(price), .qty(qty),
  .transaction(transaction), .trans_valid(trans_valid),
  .full(full),

  .request_symbol(request_symbol),
  .request_buy(request_buy), .request_num(request_num),
  .req_out(req_out), .req_out_valid(req_out_valid)
);

task new_order(
  reg [3:0]  p_symbol,
  reg        p_buy,
  reg [9:0]  p_price,
  reg [8:0]  p_qty,

  reg  [19:0] exp_transaction,
  reg         exp_trans_valid,

  reg         exp_full
);

@(negedge clk);

in_valid = 1;
symbol = p_symbol;
buy = p_buy;
price = p_price;
qty = p_qty;

wait(!in_ready);

in_valid = 0;

wait (in_ready);

e = 0;

if (transaction != exp_transaction) begin
  $display("Expected Transaction %b, Got %b", exp_transaction, transaction);
  e = e + 1;
end

if (full != exp_full) begin
  $display("Expected Is Full %b, Got %b", exp_full, full);
  e = e + 1;
end

if (e > 0)  $display("Failed %d Test Cases", e);
else        $display("Passed");

endtask

initial begin
  clk = 0;
  rst = 0;
  
  in_valid = 0;

  request_num = 0;
end

always #5 clk = ~clk;

initial begin
  new_order(
    1,
    0,
    10,
    5,
    0,
    0,
    0
  );

  new_order(
    1,
    1,
    10,
    5,
    99, // WIP
    1,
    0
  );

  $finish;
end

endmodule