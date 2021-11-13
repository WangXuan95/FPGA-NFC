`timescale 1ns/1ns

module stream_sync_fifo #(
    parameter   DSIZE = 8,
    parameter   ASIZE = 10
)(
    input  wire             rstn,
    input  wire             clk,
    input  wire             itvalid,
    output wire             itready,
    input  wire [DSIZE-1:0] itdata,
    output reg              otvalid,
    input  wire             otready,
    output wire [DSIZE-1:0] otdata
);

reg  [DSIZE-1:0] buffer [1<<ASIZE];  // may automatically synthesize to BRAM

logic [ASIZE:0] wptr, rptr;

wire full  = wptr == {~rptr[ASIZE], rptr[ASIZE-1:0]};
wire empty = wptr == rptr;

assign itready = rstn & ~full;

always @ (posedge clk)
    if(~rstn) begin
        wptr <= '0;
    end else begin
        if(itvalid & ~full)
            wptr <= wptr + (1+ASIZE)'(1);
    end

always @ (posedge clk)
    if(itvalid & ~full)
        buffer[wptr[ASIZE-1:0]] <= itdata;

wire            rdready = ~otvalid | otready;
reg             rdack;
reg [DSIZE-1:0] rddata;
reg [DSIZE-1:0] keepdata;
assign otdata = rdack ? rddata : keepdata;

always @ (posedge clk)
    if(~rstn) begin
        otvalid <= 1'b0;
        rdack <= 1'b0;
        rptr <= '0;
        keepdata <= '0;
    end else begin
        otvalid <= ~empty | ~rdready;
        rdack <= ~empty & rdready;
        if(~empty & rdready)
            rptr <= rptr + (1+ASIZE)'(1);
        if(rdack)
            keepdata <= rddata;
    end

always @ (posedge clk)
    rddata <= buffer[rptr[ASIZE-1:0]];

endmodule
