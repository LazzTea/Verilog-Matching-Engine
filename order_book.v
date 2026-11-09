module order_book $(parameter DEPTH = 16;) (
  input clk,
  input rst,

  // Port A

  input [3:0] step,

  input [4:0] symbol,
  input buy,

  input [9:0] price,
  input [8:0] qty,

  output [3:0] step_out,
  output [19:0] transaction, // Side, Price, Quantity, (does not include adding new orders)

  // Port B

  input [4:0] req_symbol
  input req_buy,
  input req_num,
  output [31:0] req_out
);

// level_table[ticker[4] + buy[1]] = { head_addr[12] }
// Number of Entries: 4 + 1 = 5 bits -> 32
reg [11:0] level_table [0:32];
// order_book = { valid[1], price[10], quantity[9], next[12] }
(* ram_style = "block" *)
reg [31:0] order_book [0:4096];

// Register to Save Current Order
reg r_symbol,
reg r_buy,
reg r_price,
reg r_qty

reg [11:0] lvl_addr;
reg [31:0] order;
reg next_step;

// Port A
always @(posedge clk) begin
  case (step)
    // Base Case New Order Inputed
    3'b000: begin
      // Get the Opposite Nearest Opposite Order
      lvl_addr = level_table[{symbol, ~buy}];
      order = order_book[lvl_addr];

      // Save Current Order Values
      r_symbol = symbol;
      r_buy = buy;
      r_price = price;
      r_qty = qty;

      // Compare New Order & opp order
      if (buy && price >= order[1:10]) begin
        r_qty = r_qty - order[11:19];

        // r_qty pos or neg
        if (r_qty == 0) begin
          next_step = 1;
          order[0] = 1;
        end
        if (r_qty > 0)
        if (r_qty < 0)
      end else if (!buy && price <= order[1:10]) begin
      end else begin
      end
    end

    // Edit Current Order
    3'b001: order_book[lvl_addr] = order; // Need to add next step calcs

    // Move to Next In List
    3'b010:

    // Add to Order Book : Initial
    3'b011:

    // Add to Order Book : Next 
    3'b100
  endcase

end

assign step_out = next_step;

// Port B

