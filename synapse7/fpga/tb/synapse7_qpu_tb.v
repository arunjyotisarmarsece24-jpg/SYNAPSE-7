// ============================================================================
// Module Name:  synapse7_qpu_tb
// Project:      SYNAPSE-7 Testbench
// Description:  Verification testbench for synapse7_qpu_core and NTT unit
// ============================================================================

`timescale 1ns / 1ps

module synapse7_qpu_tb;

    reg clk;
    reg rst_btn;
    reg uart_rx;
    wire uart_tx;
    wire [3:0] leds;
    wire rgb0_red, rgb0_green, rgb0_blue;

    // Instantiate DUT
    synapse7_qpu_core dut (
        .clk(clk),
        .rst_btn(rst_btn),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .leds(leds),
        .rgb0_red(rgb0_red),
        .rgb0_green(rgb0_green),
        .rgb0_blue(rgb0_blue)
    );

    // 100MHz clock generation (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Testbench stimulation
    initial begin
        $display("[SYNAPSE-7 TESTBENCH] Starting Hardware Simulation...");
        rst_btn = 0; // Assert reset
        uart_rx = 1; // Idle line
        #100;
        
        rst_btn = 1; // De-assert reset
        #200;
        $display("[SYNAPSE-7 TESTBENCH] Core exited reset successfully.");

        // Simulate UART reception of 'Q' (0x51) -> 8'b01010001
        send_uart_byte(8'h51);
        #100000;

        // Simulate UART reception of 'S' (0x53) -> Steane Parity Check
        send_uart_byte(8'h53);
        #100000;

        // Simulate UART reception of 'N' (0x4E) -> NTT Calculation
        send_uart_byte(8'h4E);
        #100000;

        $display("[SYNAPSE-7 TESTBENCH] All stimuli completed successfully.");
        $finish;
    end

    // Task to serialize byte over UART @ 115200 baud (8.68 us per bit)
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            uart_rx = 0; // Start bit
            #8680;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #8680;
            end
            uart_rx = 1; // Stop bit
            #8680;
        end
    endtask

endmodule
