`timescale 1ns/1ps

module apb_uart_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    // Global Signals
    input  wire                   pclk,
    input  wire                   presetn,

    // APB Interface Signals
    input  wire [ADDR_WIDTH-1:0]  paddr,
    input  wire                   psel,
    input  wire                   penable,
    input  wire                   pwrite,
    input  wire [DATA_WIDTH-1:0]  pwdata,
    output reg                    pready,
    output reg  [DATA_WIDTH-1:0]  prdata,

    // Internal Peripheral Control Signals
    output reg  [7:0]             tx_byte,
    output reg                    tx_start,
    input  wire                   tx_busy,
    output reg  [15:0]            baud_div
);

    // Address Definitions
    localparam ADDR_TXDATA  = 8'h00;
    localparam ADDR_RXDATA  = 8'h04;
    localparam ADDR_STATUS  = 8'h08;
    localparam ADDR_BAUDDIV = 8'h0C;

    // APB Protocol Condition: Transfer is active in ACCESS phase
    wire apb_write_enable = psel && penable && pwrite;
    wire apb_read_enable  = psel && penable && !pwrite;

    // 1. Ready signal generation
    // For this design, all register accesses complete in 1 cycle without wait states
    always @(*) begin
        pready = psel && penable;
    end

    // 2. APB Write Logic (Registers & Pulse generation)
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_byte   <= 8'h00;
            tx_start  <= 1'b0;
            baud_div  <= 16'd54; // Default to standard divisor
        end else begin
            // tx_start must be a 1-cycle strobe
            tx_start <= 1'b0;

            if (apb_write_enable) begin
                case (paddr)
                    ADDR_TXDATA: begin
                        tx_byte  <= pwdata[7:0];
                        tx_start <= 1'b1; // Trigger transmission
                    end
                    ADDR_BAUDDIV: begin
                        baud_div <= pwdata[15:0];
                    end
                    default: ; // Ignore undefined addresses
                endcase
            end
        end
    end

    // 3. APB Read Logic (Combinational)
    always @(*) begin
        prdata = 32'h0;
        if (apb_read_enable) begin
            case (paddr)
                ADDR_STATUS:  prdata = {31'b0, tx_busy};
                ADDR_BAUDDIV: prdata = {16'b0, baud_div};
                default:      prdata = 32'h0;
            endcase
        end
    end

endmodule
