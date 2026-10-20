
`timescale 1ns/1ps

module tb_apb_uart_top;

    reg         pclk;
    reg         presetn;
    reg  [7:0]  paddr;
    reg         psel;
    reg         penable;
    reg         pwrite;
    reg  [31:0] pwdata;
    
    wire        pready;
    wire [31:0] prdata;
    wire        tx_serial;
    reg         rx_serial; // New RX input wire

    // Instantiate the Top-Level Design
    apb_uart_top uut (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .pready(pready),
        .prdata(prdata),
        .tx_serial(tx_serial),
        .rx_serial(rx_serial) // Connect RX
    );

    // 100 MHz Clock Generation
    always #5 pclk = ~pclk;

    // APB Master Write Task
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            psel    <= 1;
            pwrite  <= 1;
            paddr   <= addr;
            pwdata  <= data;
            penable <= 0;
            
            @(posedge pclk);
            penable <= 1;
            
            wait(pready);
            @(posedge pclk);
            psel    <= 0;
            penable <= 0;
            pwrite  <= 0;
        end
    endtask

    // APB Master Read Task
    task apb_read(input [7:0] addr);
        begin
            @(posedge pclk);
            psel    <= 1;
            pwrite  <= 0;
            paddr   <= addr;
            penable <= 0;
            
            @(posedge pclk);
            penable <= 1;
            
            wait(pready);
            @(posedge pclk);
            $display("APB READ: Address 0x%02X = 0x%08X", addr, prdata);
            psel    <= 0;
            penable <= 0;
        end
    endtask

    // Task to simulate an external device sending serial data
    task send_serial_byte(input [7:0] data, input integer baud_div);
        integer i;
        integer baud_delay;
        begin
            baud_delay = baud_div * 10; // 10ns per clock cycle
            
            // Start bit
            rx_serial = 0;
            #(baud_delay);
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx_serial = data[i];
                #(baud_delay);
            end
            
            // Stop bit
            rx_serial = 1;
            #(baud_delay);
        end
    endtask

    initial begin
        $dumpfile("uart_waves.vcd");
        $dumpvars(0, tb_apb_uart_top);

        pclk      = 0;
        presetn   = 0;
        psel      = 0;
        penable   = 0;
        pwrite    = 0;
        paddr     = 0;
        pwdata    = 0;
        rx_serial = 1; // Idle line is HIGH

        #20 presetn = 1;
        #20;

        $display("1. Configuring Baud Rate Divisor to 10...");
        apb_write(8'h0C, 32'd10);
        #20;
        
        $display("2. CPU Transmitting 'A' (0x41) out of TX...");
        apb_write(8'h00, 32'h00000041); 
        #1500;

        $display("3. Simulating External Device Sending 'Z' (0x5A) into RX...");
        send_serial_byte(8'h5A, 10);
        #200;

        $display("4. CPU Reading RX Data Register...");
        apb_read(8'h04);

        #100;
        $display("Simulation Complete.");
        $finish;
    end

endmodule