//------------------------------------------------------------------------------
// File        : sc_fifo.v
// Module      : sc_fifo
// Author      : Charbel Abou Afech
// Class       : ECE 520/L
// Lab         : Lab 3 - BRAM FIFO
// Date        : 10/05/2026
//------------------------------------------------------------------------------
module sc_fifo #(
    parameter WIDTH                  = 16,
    parameter DEPTH                  = 32,  // must be a power of two
    parameter ADDR_WIDTH             = 5,   // log2(DEPTH)
    parameter ALMOST_EMPTY_THRESHOLD = 1,
    parameter ALMOST_FULL_THRESHOLD  = 31,
    parameter READ_LATENCY           = 1    // 1..8
)(
    input  wire                  clk,
    input  wire                  srst,
 
    input  wire                  wr_en,
    input  wire [WIDTH-1:0]      din,
 
    input  wire                  rd_en,
    output wire [WIDTH-1:0]      dout,
    output wire                  valid,
 
    output wire                  full,
    output wire                  empty,
    output wire                  almost_full,
    output wire                  almost_empty,
    output wire [ADDR_WIDTH:0]   data_count     // 0..DEPTH
);
 
    // Memory: inferred block RAM
    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];
 
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;
 
    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;
 
    // Write port
    always @(posedge clk) begin
        if (do_wr)
            mem[wr_ptr] <= din;
    end
 
    // Read port: registered output (first output stage)
    reg [WIDTH-1:0] ram_q;
    reg             ram_q_valid;
 
    always @(posedge clk) begin
        if (srst)
            ram_q <= {WIDTH{1'b0}};
        else if (do_rd)
            ram_q <= mem[rd_ptr];
    end
 
    always @(posedge clk) begin
        if (srst)
            ram_q_valid <= 1'b0;
        else
            ram_q_valid <= do_rd;
    end
 
    // Pointers and count
    always @(posedge clk) begin
        if (srst) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
            rd_ptr <= {ADDR_WIDTH{1'b0}};
            count  <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            if (do_wr)
                wr_ptr <= wr_ptr + 1'b1;
            if (do_rd)
                rd_ptr <= rd_ptr + 1'b1;
 
            case ({do_wr, do_rd})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;      // idle, or read+write together
            endcase
        end
    end
 
    // Status flags
    assign full         = (count == DEPTH);
    assign empty        = (count == 0);
    assign almost_full  = (count >= ALMOST_FULL_THRESHOLD);
    assign almost_empty = (count <= ALMOST_EMPTY_THRESHOLD);
    assign data_count   = count;
 
    // Extra output stages for READ_LATENCY > 1.
    // Stage 0 is ram_q; each later stage copies the one before it every clock.
    wire [WIDTH*READ_LATENCY-1:0] stage_data;
    wire [READ_LATENCY-1:0]       stage_valid;
 
    assign stage_data[WIDTH-1:0] = ram_q;
    assign stage_valid[0]        = ram_q_valid;
 
    genvar g;
    generate
        for (g = 1; g < READ_LATENCY; g = g + 1) begin : g_out_pipe
            reg [WIDTH-1:0] data_q;
            reg             valid_q;
 
            always @(posedge clk) begin
                if (srst) begin
                    data_q  <= {WIDTH{1'b0}};
                    valid_q <= 1'b0;
                end else begin
                    data_q  <= stage_data[(g-1)*WIDTH +: WIDTH];
                    valid_q <= stage_valid[g-1];
                end
            end
 
            assign stage_data[g*WIDTH +: WIDTH] = data_q;
            assign stage_valid[g]               = valid_q;
        end
    endgenerate
 
    assign dout  = stage_data[(READ_LATENCY-1)*WIDTH +: WIDTH];
    assign valid = stage_valid[READ_LATENCY-1];
 
endmodule
 