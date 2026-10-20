`timescale 1ns/1ps

module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div,   // Number of system clocks per baud tick
    input  wire [7:0]  tx_data,
    input  wire        tx_start,
    output reg         tx_serial,
    output wire        tx_busy
);

    // States for UART TX FSM
    localparam S_IDLE  = 2'b00;
    localparam S_START = 2'b01;
    localparam S_DATA  = 2'b10;
    localparam S_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shifter;

    assign tx_busy = (state != S_IDLE);

    // Baud Clock Pulse Generation
    wire baud_tick = (baud_cnt == baud_div - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= 16'd0;
        else if (state != S_IDLE) begin
            if (baud_tick)
                baud_cnt <= 16'd0;
            else
                baud_cnt <= baud_cnt + 1'b1;
        end else
            baud_cnt <= 16'd0;
    end

    // UART Transmission State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            tx_serial <= 1'b1; // Idle line is HIGH
            bit_idx   <= 3'd0;
            shifter   <= 8'h00;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_serial <= 1'b1;
                    if (tx_start) begin
                        shifter <= tx_data;
                        state   <= S_START;
                    end
                end

                S_START: begin
                    tx_serial <= 1'b0; // Start bit is LOW
                    if (baud_tick) begin
                        state   <= S_DATA;
                        bit_idx <= 3'd0;
                    end
                end

                S_DATA: begin
                    tx_serial <= shifter[bit_idx];
                    if (baud_tick) begin
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end

                S_STOP: begin
                    tx_serial <= 1'b1; // Stop bit is HIGH
                    if (baud_tick)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
