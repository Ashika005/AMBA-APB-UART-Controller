`timescale 1ns/1ps

module apb_uart_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  wire                   pclk,
    input  wire                   presetn,

    input  wire [ADDR_WIDTH-1:0]  paddr,
    input  wire                   psel,
    input  wire                   penable,
    input  wire                   pwrite,
    input  wire [DATA_WIDTH-1:0]  pwdata,
    output reg                    pready,
    output reg  [DATA_WIDTH-1:0]  prdata,

    output reg  [7:0]             tx_byte,
    output reg                    tx_start,
    input  wire                   tx_busy,
    output reg  [15:0]            baud_div,
    
    // New RX interface signals
    input  wire [7:0]             rx_data,
    input  wire                   rx_done
);

    localparam ADDR_TXDATA  = 8'h00;
    localparam ADDR_RXDATA  = 8'h04;
    localparam ADDR_STATUS  = 8'h08;
    localparam ADDR_BAUDDIV = 8'h0C;

    wire apb_write_enable = psel && penable && pwrite;
    wire apb_read_enable  = psel && penable && !pwrite;

    reg [7:0] rx_buffer;
    reg       rx_valid;

    always @(*) begin
        pready = psel && penable;
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_byte   <= 8'h00;
            tx_start  <= 1'b0;
            baud_div  <= 16'd54;
            rx_buffer <= 8'h00;
            rx_valid  <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            // Capture incoming data from RX core
            if (rx_done) begin
                rx_buffer <= rx_data;
                rx_valid  <= 1'b1; // Set flag indicating unread data is present
            end

            // Clear the valid flag automatically when the CPU reads the RX register
            if (apb_read_enable && paddr == ADDR_RXDATA) begin
                rx_valid <= 1'b0;
            end

            // APB Write logic
            if (apb_write_enable) begin
                case (paddr)
                    ADDR_TXDATA: begin
                        tx_byte  <= pwdata[7:0];
                        tx_start <= 1'b1;
                    end
                    ADDR_BAUDDIV: baud_div <= pwdata[15:0];
                    default: ;
                endcase
            end
        end
    end

    // APB Read Logic
    always @(*) begin
        prdata = 32'h0;
        if (apb_read_enable) begin
            case (paddr)
                ADDR_RXDATA:  prdata = {24'h0, rx_buffer};
                ADDR_STATUS:  prdata = {30'b0, rx_valid, tx_busy}; // bit 1: rx_valid, bit 0: tx_busy
                ADDR_BAUDDIV: prdata = {16'h0, baud_div};
                default:      prdata = 32'h0;
            endcase
        end
    end

endmodule
