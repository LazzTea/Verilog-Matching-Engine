module order_book $(parameter DEPTH = 16;) (
  input wire clk,
  input wire rst,

  // Port A
  input wire [3:0]  symbol,
  input wire        buy,

  input wire [9:0]  price,
  input wire [8:0]  qty,

  output reg [19:0] transaction, // Side, Price, Quantity, (does not include adding new orders)

  // Port B

  input wire [3:0] request_symbol
  input wire request_buy,
  input wire [11:0] request_num,

  output reg [31:0] req_out
);

/*
struct level_table [ticker[4] + buy[1]]
{ LSB
  head_addr[12]
} MSB
*/
reg [11:0] level_table [0:32];

/*
struct order_book
{ LSB
  valid[1]
  price[10]
  quantity[9]
  next[12]
} MSB
*/
(* ram_style = "block" *)
// 4096 Index Reserved for No Clean Index
reg [31:0] order_book [0:4095];

// Register to Save Current Order
reg [4:0] r_symbol,
reg       r_buy,
reg [9:0] r_price,
reg [8:0] r_qty

reg [11:0] order_addr;
reg [31:0] order;

wire        or_valid = order[0];
wire [9:0]  or_price = order[10:1];
wire [8:0]  or_qty   = order[19:11];
wire [11:0] or_next  = order[31:20];

wire crosses    = r_buy ? (r_price >= or_price) : (r_price <= or_price);
wire [9:0] diff = r_qty - or_qty;
wire equal      = diff == 0;
wire new_more   = diff > 0;
wire or_more    = diff < 0;


reg [11:0] last_order_addr;
reg [31:0] last_order;

// Clean Cache : Must Load to be all 1s
reg [11:0]  clean [0:10];
reg [11:0]  clean_addr  = 0;
reg         clean_bit   = 0;

reg [1:0] step = 0;

// Initalize the Tables
initial begin
  $readmemh("level_table", level_table);
  $readmemh("order_book", order_book);
  $readmemh("clean", clean);
end

// Port A
always @(posedge clk || posedge rst) begin
  // Reset is WIP
  if (rst) begin
    $readmemh("level_table", level_table);
    $readmemh("order_book", order_book);
    $readmemh("clean", clean);

    order_addr  <= 0;
    order       <= 0;

    r_symbol  <= 0;
    r_buy     <= 0;
    r_price   <= 0;
    r_qty     <= 0;

    step = 0;
  end 
  
  else begin
    case (step)
      // Load Inputs & Order 
      2'b00: begin
        // Get the Opposite Nearest Opposite Order
        order_addr  <= level_table[{symbol, ~buy}];
        order       <= order_book[level_table[{symbol, ~buy}]];

        // Save Current Order Values
        r_symbol  <= symbol;
        r_buy     <= buy;
        r_price   <= price;
        r_qty     <= qty;

        step <= 2'b01;
      
      // Compare New Order & Opposite Order
      2'b01:
        if (crosses) begin
          // Get difference in Quantities
          r_qty <= r_qty - order[11:19];

          // If 0: Both are Satisified, remove the Opp Order
          if (equal || new_more) begin
            clean <= {order_addr, clean[9:0]};

            level_table[{r_symbol, ~r_buy}] <= order[31:20];
            order_addr <= order[31:20];

            order_book[order[31:20]] <= 0;

            if (equal) step <= 2'b00 else step <= 2'b01;
          end

          // If <: Opp Order is Not Satisified, Change to its New Quantity & New Order Satisified
          else begin
            order_book[order_addr] <= {order[31:20], (-diff)[8:0], order[10:0]}

            step <= 2'b00;
          end

        // New Order cannot be Satisified by Opp Orders, Add New Order to Book
        end else begin
          last_order_addr <= order_addr;
          last_order <= order;

          order_addr <= level_table[{r_symbol, r_buy}];

          step <= 2'b10;
        end
      end

      // Add to Order Book
      2'b10: begin
        if (r_price >= order[10:1]) begin
          order <= order_book[order[31:20]];
          order_addr <= order[31:20];
        end

        else if (r_price < order[1:10]) begin
          order <= {order_addr, r_qty, r_price, 1};

          // Get Order From Clean
          if (clean[0] != 12'd4096) begin
            order_addr <= clean[0]; 
            clean <= {12'd4096, clean[10:0]};

            order_book[clean[0]] <= {order_addr, r_qty, r_price, 1};
            if (order_addr == level_table[{r_symbol, r_buy}]) begin
              level_table[{r_symbol, r_buy}] <= clean[0];
            end else begin
              order_book[last_order_addr] <= {clean[0], last_order[20:0]};
            end

            step <= 2'b00;
          end 

          // No Clean Availible, Must Search Order Book (SLOW)
          else begin
            clean_addr <= 0;
            clean_bit <= order_book[0][0];

            step <= 2'b11;
          end
        end
      end

      // Find Clean Entry : WIP Overflow Just Crashes
      2'b11: begin
        if (clean_bit == 0) begin
          clean[0] <= clean_addr;

          step <= 2'b10;
        end

        else if (clean_addr + 1 == 12'd4096) begin
          // Crash the System, We've Run Out of Storage
        end 
        
        else begin
          clean_addr <= clean_addr + 1;
          clean_bit <= order_book[clean_addr + 1][0]
        end
      end
    endcase
  end
end

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
      req_symbol  <= request_symbol;
      req_buy     <= request_buy;
      req_num     <= request_num;

      display_addr <= level_table[{request_symbol, request_buy}];

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

