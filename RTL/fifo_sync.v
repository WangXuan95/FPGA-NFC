
//--------------------------------------------------------------------------------------------------------
// Module  : fifo_sync
// Type    : synthesizable, IP's sub-module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: synchronous fifo
//--------------------------------------------------------------------------------------------------------

module fifo_sync #(
    parameter            DW = 8,     // bit width
    parameter            EA = 10     // 9:depth=512   10:depth=1024   11:depth=2048   12:depth=4096
) (
    input  wire          rstn,
    input  wire          clk,
    // input interface
    output wire          i_rdy,
    input  wire          i_en,
    input  wire [DW-1:0] i_data,
    // output interface
    input  wire          o_rdy,
    output reg           o_en,
    output reg  [DW-1:0] o_data
);



reg  [DW-1:0] buffer [ ((1<<EA)-1) : 0 ];

localparam [EA:0] A_ZERO = {{EA{1'b0}}, 1'b0};
localparam [EA:0] A_ONE  = {{EA{1'b0}}, 1'b1};

reg  [EA:0] wptr      = A_ZERO;
reg  [EA:0] wptr_d1   = A_ZERO;
reg  [EA:0] wptr_d2   = A_ZERO;
reg  [EA:0] rptr      = A_ZERO;
wire [EA:0] rptr_next = (o_en & o_rdy) ? (rptr+A_ONE) : rptr;



assign i_rdy = ( wptr != {~rptr[EA], rptr[EA-1:0]} );

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        wptr    <= A_ZERO;
        wptr_d1 <= A_ZERO;
        wptr_d2 <= A_ZERO;
    end else begin
        if (i_en & i_rdy)
            wptr <= wptr + A_ONE;
        wptr_d1 <= wptr;
        wptr_d2 <= wptr_d1;
    end

always @ (posedge clk)
    if (i_en & i_rdy)
        buffer[wptr[EA-1:0]] <= i_data;



always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        rptr <= A_ZERO;
        o_en <= 1'b0;
    end else begin
        rptr <= rptr_next;
        o_en <= (rptr_next != wptr_d2);
    end

always @ (posedge clk)
    o_data <= buffer[rptr_next[EA-1:0]];


endmodule
