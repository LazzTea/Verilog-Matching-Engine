module debouncer #(
    parameter integer CLK_HZ = 100000000,
    parameter integer DEBOUNCE_MS = 20
)(
    input wire clk,
    input wire rst,
    input wire button_async,
    output reg button_state,
    output reg button_pressed
);
    localparam integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNTER_WIDTH =
        (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;

    (* ASYNC_REG = "TRUE" *) reg button_sync_1;
    (* ASYNC_REG = "TRUE" *) reg button_sync_2;
    reg [COUNTER_WIDTH-1:0] debounce_count;

    always @(posedge clk) begin
        if (rst) begin
            button_sync_1 <= 1'b0;
            button_sync_2 <= 1'b0;
            button_state <= 1'b0;
            button_pressed <= 1'b0;
            debounce_count <= 0;
        end else begin
            button_sync_1 <= button_async;
            button_sync_2 <= button_sync_1;
            button_pressed <= 1'b0;

            if (button_sync_2 == button_state) begin
                debounce_count <= 0;
            end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
                button_state <= button_sync_2;
                debounce_count <= 0;
                if (button_sync_2)
                    button_pressed <= 1'b1;
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end
        end
    end
endmodule
