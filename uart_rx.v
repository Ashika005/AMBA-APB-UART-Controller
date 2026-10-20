`timescale 1ns/1ps

module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div,
    input  wire        rx_serial,
    output reg  [7:0]  rx_data,
    output reg         rx_done
);

    // States for UART RX FSM
    localparam S_IDLE  = 2'b00;
    localparam S_START = 2'b01;
    localparam S_DATA  = 2'b10;
    localparam S_STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shifter;

    // 1. Double-Flop Synchronizer to prevent Metastability
    reg rx_sync_1;
    reg rx_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync   <= 1'b1;
        end else begin
            rx_sync_1 <= rx_serial;
            rx_sync   <= rx_sync_1; // Safe synchronized signal
        end
    end

    // 2. UART Receiving State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            baud_cnt <= 16'd0;
            bit_idx  <= 3'd0;
            shifter  <= 8'h00;
            rx_data  <= 8'h00;
            rx_done  <= 1'b0;
        end else begin
            rx_done <= 1'b0; // Default: 1-cycle pulse when data is ready

            case (state)
                S_IDLE: begin
                    baud_cnt <= 16'd0;
                    if (rx_sync == 1'b0) begin // Start bit falling edge detected
                        state <= S_START;
                    end
                end

                S_START: begin
                    // Wait HALF a baud period to sample exactly in the middle of the start bit
                    if (baud_cnt == (baud_div >> 1)) begin
                        if (rx_sync == 1'b0) begin // Glitch filter: confirm it is still LOW
                            baud_cnt <= 16'd0;
                            state    <= S_DATA;
                            bit_idx  <= 3'd0;
                        end else begin
                            state <= S_IDLE; // It was a noise glitch, ignore it
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    // Wait a FULL baud period to sample the middle of the next data bits
                    if (baud_cnt == baud_div - 1) begin
                        baud_cnt <= 16'd0;
                        shifter[bit_idx] <= rx_sync; // Sample and shift in the bit
                        
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    // Wait a FULL baud period for the stop bit
                    if (baud_cnt == baud_div - 1) begin
                        baud_cnt <= 16'd0;
                        if (rx_sync == 1'b1) begin // Confirm valid stop bit (HIGH)
                            rx_data <= shifter;    // Push out the assembled byte
                            rx_done <= 1'b1;       // Flag CPU that data is ready
                        end
                        state <= S_IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
