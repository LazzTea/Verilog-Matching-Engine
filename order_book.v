module order_book $(parameter DEPTH = 16;) (
  input wire clk,
  input wire rst,

  // Port A

  input wire [3:0] step,

  input wire [3:0] symbol,
  input wire buy,

  input wire [9:0] price,
  input wire [8:0] qty,

  output wire [3:0] step_out,
  output reg [19:0] transaction, // Side, Price, Quantity, (does not include adding new orders)

  // Port B

  input wire [3:0] request_symbol
  input wire request_buy,
  input wire [11:0] request_num,

  output reg [31:0] req_out
);

// level_table[ticker[4] + buy[1]] = { head_addr[12] }
// Number of Entries: 4 + 1 = 5 bits -> 32
reg [11:0] level_table [0:32];
// order_book = { valid[1], price[10], quantity[9], next[12] }
(* ram_style = "block" *)
// All 1s not availible, Reserved for clean
reg [31:0] order_book [0:4095];

// Clean Cache : Must Load to be all 1s
reg [11:0] clean [0:10];

// Register to Save Current Order
reg r_symbol,
reg r_buy,
reg r_price,
reg r_qty

reg [11:0] order_addr;
reg [31:0] order;

reg [11:0] last_order_addr;
reg [31:0] last_order;

reg [11:0] clean_addr = 0;

reg next_step;

// Port A
always @(posedge clk) begin
  case (step)
    // Base Case New Order Inputed
    3'b000: begin
      // Get the Opposite Nearest Opposite Order
      order_addr = level_table[{symbol, ~buy}];
      order = order_book[order_addr];

      // Save Current Order Values
      r_symbol = symbol;
      r_buy = buy;
      r_price = price;
      r_qty = qty;

      // Compare New Order & opp order
      if ((buy && price >= order[1:10]) || (!buy && price <= order[1:10])) begin
        // Get difference in Quantities
        r_qty = r_qty - order[11:19];

        // If 0: Both are Satisified, remove the Opp Order
        if (r_qty == 0) begin
          order[0] = 0;

          clean = {order_addr, clean[1:10]};

          level_table[{symbol, ~buy}] = order[20:31];
          order_addr = order[20:31];

          next_step = 3'b001;

        end
        // If >: New Order is Not Satisified, Remove Opp Order & Compare Next Opp Order
        else if (r_qty > 0) begin
          order[0] = 0;

          clean = {order_addr, clean[1:10]};

          level_table[{symbol, ~buy}] = order[20:31];
          order_addr = order[20:31];

          next_step = 3'b010;

        end
        // If <: Opp Order is Not Satisified, Change to its New Quantity & New Order Satisified
        else if (r_qty < 0) begin
          order[11:19] = -r_qty;

          next_step = 3'b001;

        end
      // end else if (!buy && price <= order[1:10]) begin
      // New Order cannot be Satisified by Opp Orders, Add New Order to Book
      end else begin
        last_order_addr = order_addr;
        last_order = order;

        order_addr = level_table[{symbol, buy}];

        next_step = 3'b100;
      end
    end

    // Edit Current Order : End
    3'b001: begin
      order_book[order_addr] = order;

      next_step = 3'b000;
    end

    // Edit Current Order : Next
    3'b010: begin
      order_book[order_addr] = order;

      order_addr = order[20:31];

      // if statement to compare to input

      next_step = 3'b011;

    end

    // Match Order : Next WIP
    3'b011: begin
      order = order_book[order_addr];

      // Compare New Order & opp order
      if ((buy && r_price >= order[1:10]) || (!buy && r_price <= order[1:10])) begin
        // Get difference in Quantities
        r_qty = r_qty - order[11:19];

        // If 0: Both are Satisified, remove the Opp Order
        if (r_qty == 0) begin
          order[0] = 0;

          clean = {order_addr, clean[1:10]};

          level_table[{symbol, ~buy}] = order[20:31];

          next_step = 3'b001;

        end
        // If >: New Order is Not Satisified, Remove Opp Order & Compare Next Opp Order
        else if (r_qty > 0) begin
          order[0] = 0;

          clean = {order_addr, clean[1:10]};

          level_table[{symbol, ~buy}] = order[20:31];

          next_step = 3'b010;

        end
        // If <: Opp Order is Not Satisified, Change to its New Quantity & New Order Satisified
        else if (r_qty < 0) begin
          order[11:19] = -r_qty;

          next_step = 3'b001;

        end
      // end else if (!buy && price <= order[1:10]) begin
      // New Order cannot be Satisified by Opp Orders, Add New Order to Book
      end else begin
        last_order_addr = order_addr;
        last_order = order;

        order_addr = level_table[{symbol, buy}];

        next_step = 3'b100;
      end


    end

    // Add to Order Book : Initial
    3'b100: begin
      order = order_book[order_addr];

      if (r_price >= order[10:1]) begin
        order_addr = order[31:20];
      end
      else if (r_price < order[1:10]) begin
        order = {1, r_price, r_qty, order_addr};

        // Get Order From Clean
        if (clean[0] != 12'd4096) begin
          order_addr = clean[0]; 
          clean = {clean[1:10], 12'd4096};

          last_order[20:31] = order_addr;
          next_step = 3'b101;
        end 
        // No Clean Availible, Must Search Order Book (SLOW)
        else begin
          next_step = 3'b111;
        end
      end
    end

    // Add to Order Book : End : Last Order
    3'b101: begin
      order_book[last_order_addr] = last_order;

      next_step = 3'b110;

    end

    // Add to Order Book : End : New Order
    3'b110: begin
      order_book[order_addr] = order;

      next_step = 3'b000;

    end

    // Find Clean Entry : Initial : WIP Does Not Account for Overflow
    3'b111: begin
      if (order_book[clean_addr][0] == 0) begin
        clean[0] = clean_addr;
        clean_addr = 0;

        next_step = 3'b100;

      end else begin
        clean_addr = clean_addr + 1;
      end
    end
  endcase
end

assign step_out = next_step;

// Port B

reg busy = 0;
reg [3:0] req_symbol;
reg req_buy;
reg [11:0] req_num;

reg [11:0] display_addr;
reg display_next;

always @(posedge clk) begin
  if (!busy) begin
    // Continous Output : WIP
    if (request_num == 12'd4096) begin
    // Request Set Number
    end 
    
    else if (request_num > 0) begin
      req_symbol <= request_symbol;
      req_buy <= request_buy;
      req_num <= request_num;

      display_addr <= level_table[{req_symbol, req_buy}];

      busy <= 1;
      req_out <= 0; 

    end 
    else begin
      busy <= 0;
      req_out <= 0;
    end

  end else begin
    if (req_num == 12'd4096) begin
      if (display_next) begin
        display_addr <= req_out[31:20];
      end

      req_out <= order_book[display_addr];

    end 
    else if (req_num > 0) begin
      display_addr <= req_out[31:20];
      req_out <= order_book[display_addr];
      req_num <= req_num - 1;

    end 
    else begin
      busy = 0;
    end
  end
end

