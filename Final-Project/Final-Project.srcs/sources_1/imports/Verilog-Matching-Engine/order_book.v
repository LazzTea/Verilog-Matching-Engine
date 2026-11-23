module order_book 
#(
  parameter BOOK_FILE     = "",
  parameter HEAD_FILE    = "",
  parameter PRELOAD_COUNT = 0
)
(
  input wire clk,
  input wire rst,

  // Port A : New Orders
  input  wire        in_valid, 
  output wire        in_ready,

  input  wire [3:0]  symbol,
  input  wire        buy,
  input  wire [9:0]  price,
  input  wire [8:0]  qty,

  output reg  [19:0] transaction,
  output reg         trans_valid,

  output reg         full,

  // Port B : Display
  input  wire [3:0]  request_symbol,
  input  wire        request_buy,
  input  wire [11:0] request_num,

  output reg  [31:0] req_out,
  output reg         req_out_valid
);

// NULL: 12 bits can only count to 4095, so 12'd4096 wraps to 0
// Slot 4095 is reserved instead and never handed out.
localparam [11:0] NULL = 12'hFFF;

/*
struct level_table [ticker[4] + buy[1]]
{ LSB
  head_addr[12]
} MSB
*/
reg [11:0] head_table [0:31];

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
// Slot 4095 (NULL) is never used
reg [31:0] order_book [0:4095];

integer i;
initial begin
  for (i = 0; i < 4096; i = i + 1) order_book[i] = 32'd0;
  for (i = 0; i < 32;   i = i + 1) head_table[i] = NULL;

  if (BOOK_FILE  != "") $readmemh(BOOK_FILE,  order_book);
  if (HEAD_FILE != "") $readmemh(HEAD_FILE, head_table);
end

// Register to Save Current Order
reg [3:0] r_symbol;
reg       r_buy;
reg [9:0] r_price;
reg [8:0] r_qty;

reg  [11:0] order_addr;
reg  [31:0] order;

wire        or_valid = order[0];
wire [9:0]  or_price = order[10:1];
wire [8:0]  or_qty   = order[19:11];
wire [11:0] or_next  = order[31:20];

// Matching
wire crosses    = or_valid && (r_buy ? (r_price >= or_price) : (r_price <= or_price));
wire [9:0] diff = {1'b0, r_qty} - {1'b0, or_qty};
wire equal      = (diff == 10'd0);
wire or_more    = diff[9];
wire new_more   = !or_more && !equal;
wire [8:0] or_left  = or_qty - r_qty;
wire [8:0] fill_qty = or_more ? r_qty : or_qty;

// Adding: does the new order go in front of the order just read?
wire goes_before = r_buy ? (r_price > or_price) : (r_price < or_price);

reg [11:0] last_order_addr;
reg [31:0] last_order;

// Head lookups
wire [11:0] opp_head_in = head_table[{symbol, ~buy}];
wire [11:0] own_head    = head_table[{r_symbol, r_buy}];

// Clean slots: never-used slots come from clean_fresh, freed slots go on a stack
(* ram_style = "distributed" *)
reg  [11:0] clean [0:4095];
reg  [12:0] clean_sp = 0;
reg  [11:0] clean_fresh = PRELOAD_COUNT;
wire        have_clean = (clean_sp != 0);
wire [11:0] new_slot   = have_clean ? clean[clean_sp - 1'b1] : clean_fresh;
wire        slot_ok    = have_clean || (clean_fresh != NULL);
reg  [11:0] r_new_slot;

// States
localparam [2:0]  S_IDLE   = 3'd0,   // wait for an order, read opposite head
                  S_MATCH  = 3'd1,   // compare against opposite order
                  S_ADD_RD = 3'd2,   // read own side head
                  S_ADD    = 3'd3,   // walk own side to find the spot
                  S_ADD_WR = 3'd4,   // write the new order
                  S_LINK   = 3'd5;   // point the previous order at the new one

reg [2:0] step = S_IDLE;

assign in_ready = (step == S_IDLE);

wire port_a_read_enable =
    !rst &&
    ((step == S_IDLE && in_valid && opp_head_in != NULL) ||
     (step == S_MATCH && crosses && !or_more && !equal &&
      or_next != NULL) ||
     (step == S_ADD_RD && own_head != NULL) ||
     (step == S_ADD && !goes_before && or_next != NULL));
wire [11:0] port_a_read_address =
    step == S_IDLE ? opp_head_in :
    step == S_ADD_RD ? own_head : or_next;

wire port_a_write_enable =
    !rst &&
    ((step == S_MATCH && crosses && or_more) ||
     (step == S_ADD_WR && slot_ok) ||
     (step == S_LINK));
wire [11:0] port_a_write_address =
    step == S_MATCH ? order_addr :
    step == S_ADD_WR ? new_slot : last_order_addr;
wire [31:0] port_a_write_data =
    step == S_MATCH ? {or_next, or_left, or_price, 1'b1} :
    step == S_ADD_WR ? {order_addr, r_qty, r_price, 1'b1} :
                       {r_new_slot, last_order[19:0]};

// Keep all matching/insertion accesses on one synchronous BRAM port.
always @(posedge clk) begin
  if (port_a_read_enable)
    order <= order_book[port_a_read_address];
  if (port_a_write_enable)
    order_book[port_a_write_address] <= port_a_write_data;
end


// Port A
always @(posedge clk) begin
  trans_valid <= 0;
  full        <= 0;

  if (rst) begin
    order_addr  <= NULL;

    r_symbol  <= 0;
    r_buy     <= 0;
    r_price   <= 0;
    r_qty     <= 0;

    step <= S_IDLE;
  end

  else begin
    case (step)
      // Load Inputs & Opposite Head
      S_IDLE: begin
        if (in_valid) begin
          // Save Current Order Values
          r_symbol  <= symbol;
          r_buy     <= buy;
          r_price   <= price;
          r_qty     <= qty;

          // Get the Nearest Opposite Order (ready next cycle)
          order_addr <= opp_head_in;

          // Opposite side empty -> nothing to match, go add
          if (opp_head_in == NULL) step <= S_ADD_RD;
          else                     step <= S_MATCH;
        end
      end

      // Compare New Order & Opposite Order (order holds the opp order now)
      S_MATCH: begin
        if (crosses) begin
          transaction <= {fill_qty, or_price, r_buy};
          trans_valid <= 1;

          // Equal or New Bigger: remove the Opp Order (it is always the head)
          if (!or_more) begin
            clean[clean_sp] <= order_addr;
            clean_sp <= clean_sp + 1'b1;
            head_table[{r_symbol, ~r_buy}] <= or_next;
            order_addr <= or_next;
            r_qty      <= diff[8:0];

            if (equal)                step <= S_IDLE;
            else if (or_next == NULL) step <= S_ADD_RD;
            else begin
              step  <= S_MATCH;
            end
          end

          // Opp Bigger: change it to its new quantity, new order satisfied
          else begin
            step <= S_IDLE;
          end
        end

        // New Order cannot be Satisfied by Opp Orders, Add New Order to Book
        else begin
          step <= S_ADD_RD;
        end
      end

      // Read own side head
      S_ADD_RD: begin
        last_order_addr <= NULL;
        order_addr      <= own_head;

        if (own_head == NULL) step <= S_ADD_WR;
        else begin
          step  <= S_ADD;
        end
      end

      // Walk own side (order holds the order at order_addr)
      S_ADD: begin
        if (goes_before) begin
          step <= S_ADD_WR;
        end else begin
          last_order_addr <= order_addr;
          last_order      <= order;
          order_addr      <= or_next;
          if (or_next == NULL) step <= S_ADD_WR;
        end
      end

      // Write new order, fix head if needed
      S_ADD_WR: begin
        if (slot_ok) begin
          r_new_slot <= new_slot;

          if (have_clean) clean_sp  <= clean_sp - 1'b1;
          else            clean_fresh <= clean_fresh + 1'b1;

          if (last_order_addr == NULL) begin
            head_table[{r_symbol, r_buy}] <= new_slot;
            step <= S_IDLE;
          end else begin
            step <= S_LINK;
          end
        end else begin
          full <= 1;
          step <= S_IDLE;
        end
      end

      // Previous order's next = new order
      S_LINK: begin
        step <= S_IDLE;
      end

      default: step <= S_IDLE;
    endcase
  end
end


// Port B 
reg         busy;
reg  [11:0] req_num;
reg  [31:0] b_order;
wire        b_valid  = b_order[0];
wire [11:0] b_next   = b_order[31:20];
wire [11:0] req_head = head_table[{request_symbol, request_buy}];
wire port_b_read_enable =
    !rst &&
    ((!busy && request_num != 0 && req_head != NULL) ||
     (busy && b_valid && req_num > 1 && b_next != NULL));
wire [11:0] port_b_read_address = busy ? b_next : req_head;

always @(posedge clk) begin
  if (port_b_read_enable)
    b_order <= order_book[port_b_read_address];
end

always @(posedge clk) begin
  req_out_valid <= 0;

  if (rst) begin
    busy <= 0;
  end

  else if (!busy) begin
    if (request_num != 0 && req_head != NULL) begin
      req_num <= request_num;
      busy    <= 1;
    end
  end

  else begin
    if (b_valid) begin
      req_out       <= b_order;
      req_out_valid <= 1;
    end
    req_num <= req_num - 1'b1;

    // Stop at the count, the end of the list, or a bad entry
    if (!b_valid || req_num == 1 || b_next == NULL)
      busy <= 0;
  end
end

endmodule

