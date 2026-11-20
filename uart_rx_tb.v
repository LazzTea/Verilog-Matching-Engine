`timescale 1ns/1ps

module uart_rx_tb;
    localparam integer CLKS_PER_BIT = 10;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx_serial = 1'b1;
    wire [7:0] data;
    wire data_valid;
    wire framing_error;
    integer valid_count = 0;
    integer error_count = 0;
    reg [7:0] last_data = 8'd0;
    integer bit_number;

    uart_rx #(
        .CLK_FREQ(1000),
        .BAUD_RATE(100)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx_serial(rx_serial),
        .data(data),
        .data_valid(data_valid),
        .framing_error(framing_error)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst) begin
            if (data_valid) begin
                valid_count = valid_count + 1;
                last_data = data;
            end
            if (framing_error)
                error_count = error_count + 1;
        end
    end

    task send_frame;
        input [7:0] value;
        input stop_bit;
        begin
            @(negedge clk);
            rx_serial = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge clk);
            for (bit_number = 0; bit_number < 8;
                 bit_number = bit_number + 1) begin
                rx_serial = value[bit_number];
                repeat (CLKS_PER_BIT) @(negedge clk);
            end
            rx_serial = stop_bit;
            repeat (CLKS_PER_BIT) @(negedge clk);
            rx_serial = 1'b1;
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        send_frame(8'hA5, 1'b1);
        repeat (2) @(posedge clk);
        #1;
        if (valid_count != 1 || last_data !== 8'hA5)
            $fatal(1, "UART receiver decoded A5 incorrectly");

        send_frame(8'h3C, 1'b0);
        repeat (2) @(posedge clk);
        #1;
        if (error_count != 1 || valid_count != 1)
            $fatal(1, "UART receiver did not flag the invalid stop bit");

        repeat (12) @(negedge clk);
        send_frame(8'h96, 1'b1);
        repeat (2) @(posedge clk);
        #1;
        if (valid_count != 2 || last_data !== 8'h96 || error_count != 1)
            $fatal(1, "UART receiver did not recover after a framing error");

        $display("PASS: UART RX decodes bytes, flags framing errors, and recovers");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "UART RX testbench timeout");
    end
endmodule
