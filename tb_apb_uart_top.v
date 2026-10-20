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
        .tx_serial(tx_serial)
    );

    // 100 MHz Clock Generation
    always #5 pclk = ~pclk;

    // APB Master Write Task (Simulating the CPU)
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

    initial begin
        // Generate the VCD file for GTKWave
        $dumpfile("uart_waves.vcd");
        $dumpvars(0, tb_apb_uart_top);

        // Initialize signals
        pclk    = 0;
        presetn = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;

        // Apply Reset
        #20 presetn = 1;
        #20;

        $display("Configuring Baud Rate Divisor...");
        // Write to ADDR_BAUDDIV (0x0C)
        apb_write(8'h0C, 32'd10); // Small divisor so simulation runs quickly

        #20;
        
        $display("Writing Character 'A' (0x41) to TX Data Register...");
        // Write to ADDR_TXDATA (0x00)
        apb_write(8'h00, 32'h00000041); 

        // Wait enough time for the serial transmission to finish shifting bits
        #2500;
        
        $display("Simulation Complete.");
        $finish;
    end

endmodule
