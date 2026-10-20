`timescale 1ns/1ps

module apb_uart_top (
    input  wire        pclk,
    input  wire        presetn,
    input  wire [7:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire        pready,
    output wire [31:0] prdata,
    output wire        tx_serial
);

    // Internal wires connecting the Slave to the TX Core
    wire [7:0]  tx_byte;
    wire        tx_start;
    wire        tx_busy;
    wire [15:0] baud_div;

    // Instantiate the APB Slave Controller
    apb_uart_slave u_slave (
        .pclk     (pclk),
        .presetn  (presetn),
        .paddr    (paddr),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .pwdata   (pwdata),
        .pready   (pready),
        .prdata   (prdata),
        .tx_byte  (tx_byte),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .baud_div (baud_div)
    );

    // Instantiate the Core UART TX
    uart_tx u_tx (
        .clk       (pclk),
        .rst_n     (presetn),
        .baud_div  (baud_div),
        .tx_data   (tx_byte),
        .tx_start  (tx_start),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy)
    );

endmodule
