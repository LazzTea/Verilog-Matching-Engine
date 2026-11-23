module uart_rx #(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer BAUD_RATE = 115_200
) (
    input wire clk,
    input wire rst,
    input wire rx_serial,
    output reg [7:0] data,
    output reg data_valid,
    output reg framing_error
);
    localparam integer CLKS_PER_BIT =
        (CLK_FREQ + BAUD_RATE / 2) / BAUD_RATE;
    localparam integer HALF_BIT_CYCLES = CLKS_PER_BIT / 2;
    localparam integer START_SAMPLE_COUNT =
        (HALF_BIT_CYCLES > 0) ? HALF_BIT_CYCLES - 1 : 0;
    localparam integer COUNTER_WIDTH =
        (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

    localparam [1:0] STATE_IDLE  = 2'd0,
                     STATE_START = 2'd1,
                     STATE_DATA  = 2'd2,
                     STATE_STOP  = 2'd3;

    reg rx_meta;
    reg rx_sync;
    reg [1:0] state;
    reg [COUNTER_WIDTH-1:0] clock_count;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_serial;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_IDLE;
            clock_count <= 0;
            bit_index <= 0;
            data <= 8'd0;
            data_valid <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            framing_error <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    clock_count <= 0;
                    bit_index <= 0;
                    if (!rx_sync)
                        state <= STATE_START;
                end

                STATE_START: begin
                    if (clock_count == START_SAMPLE_COUNT) begin
                        clock_count <= 0;
                        if (!rx_sync)
                            state <= STATE_DATA;
                        else
                            state <= STATE_IDLE;
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STATE_DATA: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        data[bit_index] <= rx_sync;
                        if (bit_index == 3'd7)
                            state <= STATE_STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STATE_STOP: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        state <= STATE_IDLE;
                        if (rx_sync)
                            data_valid <= 1'b1;
                        else
                            framing_error <= 1'b1;
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    clock_count <= 0;
                    bit_index <= 0;
                end
            endcase
        end
    end
endmodule
