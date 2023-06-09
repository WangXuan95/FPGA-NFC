
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_tx_frame
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: called by nfca_controller
//--------------------------------------------------------------------------------------------------------

module nfca_tx_frame (
    input  wire       rstn,           // 0:reset, 1:work
    input  wire       clk,            // require 81.36MHz
    // TX byte stream interface (axis sink liked)
    input  wire       tx_tvalid,
    output reg        tx_tready,
    input  wire [7:0] tx_tdata,
    input  wire [3:0] tx_tdatab,      // indicate how many bits are valid in the last byte. range=[1,8]. for the last byte of bit-oriented frame
    input  wire       tx_tlast,
    // tx bit modulate interface
    input  wire       tx_req,
    output reg        tx_en,
    output reg        tx_bit,
    // indicate how many bits remain for an incomplete byte for PICC to send, for nfca_rx_tobytes to reconstruct the bytes
    output reg  [2:0] remainb
);


function  [15:0] CRC16;
    input [15:0] crc;
    input [ 7:0] inbyte;
//function automatic logic [15:0] CRC16(input logic [15:0] crc, input logic [7:0] inbyte);
    reg   [ 7:0] tmp;
begin
    tmp = inbyte ^ crc[7:0];
    tmp = tmp ^ {tmp[3:0], 4'h0};
    CRC16 = ( {8'h0, crc[15:8]} ^ {tmp, 8'h0} ^ {5'h0, tmp, 3'h0} ^ {12'h0, tmp[7:4]} );
end
endfunction


initial tx_tready = 1'b0;
initial {tx_en, tx_bit} = 0;
initial remainb = 0;

reg [ 7:0] buffer [0:4095];   // will synthesis to BRAM
reg [ 7:0] rdata = 0;
reg [11:0] wptr = 0;
reg [11:0] rptr = 0;
reg [ 3:0] lastb = 0;
reg [17:0] txshift = 0;
reg [ 4:0] txcount = 0;
reg        end_of = 1'b0;
reg        has_crc = 1'b0;
reg [15:0] crc = 16'h6363;
reg        incomplete = 1'b0;

wire short_frame = (rdata == 8'h26 || rdata == 8'h52 || rdata == 8'h35 || rdata[7:4] == 4'h4 || rdata[7:3] == 5'h0F);


always @ (posedge clk)
    rdata <= buffer[rptr];


always @ (posedge clk)
    if(tx_tready & tx_tvalid)
        buffer[wptr] <= tx_tdata;


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        tx_tready <= 0;
        {tx_bit, tx_en} <= 0;
        {wptr, rptr} <= 0;
        lastb <= 0;
        txshift <= 0;
        txcount <= 0;
        end_of <= 1'b0;
        has_crc <= 1'b0;
        crc <= 16'h6363;
        incomplete <= 1'b0;
        remainb <= 0;
    end else begin
        if(tx_tready) begin
            if(tx_tvalid) begin
                crc <= CRC16(crc, tx_tdata);
                if (wptr != 12'hFFF) wptr <= wptr + 12'd1;
                lastb <= tx_tdatab==4'd0 ? 4'd1 : tx_tdatab>4'd8 ? 4'd8 : tx_tdatab;
                if(tx_tlast) begin                   // end of a frame input
                    if (wptr != 12'hFFF) begin       // not overflow
                        txshift <= 0;                //
                        txcount <= 5'd1;             //     send the S bit (start of communication)
                        tx_tready <= 1'b0;           //     start to send a frame
                    end else begin                   // overflow!
                        wptr <= 0;                   //     reset wptr
                        crc <= 16'h6363;             //     reset CRC
                    end
                end
            end
        end else if(txcount != 0) begin
            if(tx_req) begin
                {txshift, tx_bit, tx_en} <= {1'b0, txshift, 1'b1};
                txcount <= txcount - 5'd1;
            end
        end else if(rptr == wptr) begin
            if(has_crc) begin
                txshift <= {~(^crc[15:8]), crc[15:8], ~(^crc[7:0]), crc[7:0]};     // append CRC (16bit + 2bit parity) 
                txcount <= 5'd18;
            end else if(end_of) begin
                txshift <= 0;
                txcount <= 5'd1;              //     send the E bit (end of communication)
                end_of <= 1'b0;
                remainb <= incomplete ? lastb[2:0] : 3'd0;
            end else if(tx_req) begin
                tx_tready <= 1'b1;
                {tx_bit, tx_en} <= 0;
                {wptr, rptr} <= 0;
            end
            has_crc <= 1'b0;
            crc <= 16'h6363;
        end else begin
            incomplete <= 1'b0;
            end_of <= 1'b1;
            rptr <= rptr + 12'd1;
            txshift <= {9'd0, ~(^rdata), rdata};
            if         (rptr == 12'h0) begin                                                                           // the 1st byte
                has_crc <= ~(rdata == 8'h93 || rdata == 8'h95 || rdata == 8'h97 || short_frame);
                txcount <= short_frame ? 4'd7 : 4'd9;
            end else if(rptr == 12'h1) begin                                                                           // the 2nd byte
                has_crc <= has_crc | (rdata == 8'h70);
                txcount <= 4'd9;
            end else if(rptr+12'd1 < wptr) begin                                                                       // inner bytes
                txcount <= 4'd9;
            end else if(lastb < 4'd8) begin                                                                            // last byte (incomplete)
                incomplete <= 1'b1;
                has_crc <= 1'b0;
                txcount <= {1'h0,lastb};
            end else begin                                                                                             // last byte (complete)
                txcount <= 5'd9;
            end
        end
    end

endmodule 
