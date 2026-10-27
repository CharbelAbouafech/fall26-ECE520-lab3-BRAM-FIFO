//------------------------------------------------------------------------------
// File        : tb_sc_fifo.v
// Module      : tb_sc_fifo
// Author      : Charbel Abou Afech
// Class       : ECE 520/L
// Lab         : Lab 3 - BRAM FIFO
// Date        : 10/05/2026
// Self-checking testbench, 50 MHz clock, active-high reset
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_sc_fifo;
 
    reg         clk   = 0;
    reg         srst  = 0;
    reg         wr_en = 0;
    reg         rd_en = 0;
    reg  [15:0] din   = 0;
    wire [15:0] dout;
    wire        valid, full, empty, almost_full, almost_empty;
    wire [5:0]  data_count;
 
    reg [15:0] input_data [0:63];   // loaded from input_data.txt
    integer errors = 0;
    integer i;
 
    sc_fifo dut (
        .clk(clk), .srst(srst),
        .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .valid(valid),
        .full(full), .empty(empty),
        .almost_full(almost_full), .almost_empty(almost_empty),
        .data_count(data_count)
    );
 
    always #10 clk = ~clk;          // 50 MHz clock (20 ns period)
 
    // Inputs change on the falling edge, the FIFO samples on the rising edge.
 
    task do_reset;
    begin
        @(negedge clk); srst = 1;
        @(negedge clk);
        @(negedge clk); srst = 0;
    end
    endtask
 
    task write_word(input [15:0] d);
    begin
        @(negedge clk); wr_en = 1; din = d;
        @(negedge clk); wr_en = 0;
    end
    endtask
 
    task read_word(input [15:0] expected);
    begin
        @(negedge clk); rd_en = 1;
        @(negedge clk); rd_en = 0;
        if (valid !== 1 || dout !== expected) begin
            errors = errors + 1;
            $display("  FAIL: read %h (valid=%b), expected %h", dout, valid, expected);
        end
    end
    endtask
 
    // n = number of words that should be in the FIFO
    task check_flags(input integer n);
    begin
        if (data_count   !== n        ||
            empty        !== (n == 0) ||
            full         !== (n == 32)||
            almost_empty !== (n <= 1) ||
            almost_full  !== (n >= 31)) begin
            errors = errors + 1;
            $display("  FAIL: expected %0d words, got data_count=%0d empty=%b full=%b almost_empty=%b almost_full=%b",
                     n, data_count, empty, full, almost_empty, almost_full);
        end
    end
    endtask
 
    initial begin
        $readmemh("input_data.txt", input_data);
        $display("input_data.txt: first word = %h, last word = %h", input_data[0], input_data[63]);
        if (input_data[0] === 16'hxxxx || input_data[63] === 16'hxxxx) begin
            errors = errors + 1;
            $display("  FAIL: input_data.txt was not loaded (expected 64 words)");
        end
 
    
        $display("Test 1: output returns to 0 after reset");
        do_reset;
        write_word(16'hBEEF);
        write_word(16'h1234);
        read_word(16'hBEEF);            // dout is now BEEF (not 0)
        do_reset;                       // reset with 1234 still inside
        if (dout !== 0 || valid !== 0) begin
            errors = errors + 1;
            $display("  FAIL: dout=%h valid=%b after reset, expected 0", dout, valid);
        end
        check_flags(0);                 // FIFO is empty again
 
   
        $display("Test 2: write/read all 1s, then all 0s");
        for (i = 0; i < 32; i = i + 1) write_word(16'hFFFF);
        for (i = 0; i < 32; i = i + 1) read_word(16'hFFFF);
        for (i = 0; i < 32; i = i + 1) write_word(16'h0000);
        for (i = 0; i < 32; i = i + 1) read_word(16'h0000);
 
  
        $display("Test 3: alternating bit patterns 0xAAAA / 0x5555");
        for (i = 0; i < 16; i = i + 1) begin
            write_word(16'hAAAA);
            write_word(16'h5555);
        end
        for (i = 0; i < 16; i = i + 1) begin
            read_word(16'hAAAA);
            read_word(16'h5555);
        end
 
        
        $display("Test 4: write and read every memory location (input_data.txt)");
        for (i = 0;  i < 32; i = i + 1) write_word(input_data[i]);
        for (i = 0;  i < 32; i = i + 1) read_word(input_data[i]);
        for (i = 32; i < 64; i = i + 1) write_word(input_data[i]);
        for (i = 32; i < 64; i = i + 1) read_word(input_data[i]);
 
      
        $display("Test 5: status flags (empty, full, almost_empty, almost_full)");
        check_flags(0);
        for (i = 1; i <= 32; i = i + 1) begin
            write_word(i);
            check_flags(i);             // checked after every write
        end
        for (i = 1; i <= 32; i = i + 1) begin
            read_word(i);
            check_flags(32 - i);        // checked after every read
        end
 
     
        $display("Test 6: read_enable and write_enable");
 
        // write while full -> ignored
        for (i = 0; i < 32; i = i + 1) write_word(16'hC000 + i);
        write_word(16'hDEAD);
        check_flags(32);
 
        // read and write together while full -> only the read happens
        @(negedge clk); wr_en = 1; rd_en = 1; din = 16'hFFFF;
        @(negedge clk); wr_en = 0; rd_en = 0;
        if (valid !== 1 || dout !== 16'hC000) begin
            errors = errors + 1;
            $display("  FAIL: read %h, expected C000", dout);
        end
        check_flags(31);
        for (i = 1; i < 32; i = i + 1) read_word(16'hC000 + i);   // DEAD/FFFF never come out
        check_flags(0);
 
        // read while empty, ignored
        @(negedge clk); rd_en = 1;
        @(negedge clk); rd_en = 0;
        if (valid !== 0) begin
            errors = errors + 1;
            $display("  FAIL: valid went high on a read while empty");
        end
        check_flags(0);
 
        // read and write together while empty, only the write happens
        @(negedge clk); wr_en = 1; rd_en = 1; din = 16'h4321;
        @(negedge clk); wr_en = 0; rd_en = 0;
        if (valid !== 0) begin
            errors = errors + 1;
            $display("  FAIL: valid went high on a read while empty");
        end
        check_flags(1);
 
        // read and write together with data inside, both happen
        @(negedge clk); wr_en = 1; rd_en = 1; din = 16'h1111;
        @(negedge clk); wr_en = 0; rd_en = 0;
        if (valid !== 1 || dout !== 16'h4321) begin
            errors = errors + 1;
            $display("  FAIL: read %h, expected 4321", dout);
        end
        check_flags(1);                 // count stays the same
        read_word(16'h1111);
        check_flags(0);
 
       
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
 
endmodule
 