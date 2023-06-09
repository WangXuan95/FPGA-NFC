
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_rx_tobytes
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: called by nfca_controller
//--------------------------------------------------------------------------------------------------------

module nfca_rx_tobytes (
    input  wire       rstn,          // 0:reset, 1:work
    input  wire       clk,           // require 81.36MHz
    // RX on/off control
    input  wire       rx_on,         // 0:off, 1:on
    // indicate how many bits remain for an incomplete byte for PICC to send
    input  wire [2:0] remainb,
    // RX bit parsed (105.9375 kbps base-band)
    input  wire       rx_bit_en,     // when rx_bit_en=1 pulses, a received bit is valid on rx_bit
    input  wire       rx_bit,        // exclude S (start of communication) and E (end of communication)
    input  wire       rx_end,        // end of a communication pulse, because of detect E, or detect a bit collision, or detect an error.
    input  wire       rx_end_col,    // indicate a bit collision, only valid when rx_end=1
    input  wire       rx_end_err,    // indicate an unknown error, such a PICC (card) do not match ISO14443A, or noise, or PICC's frame is too long. Only valid when rx_end=1
    // RX byte parsed
    output reg        rx_tvalid,
    output reg  [7:0] rx_tdata,
    output reg  [3:0] rx_tdatab,
    output reg        rx_tend,
    output reg        rx_terr
);

initial {rx_tvalid, rx_tdata, rx_tend, rx_tdatab, rx_terr} = 0;

reg [3:0] cnt = 0;
reg [7:0] byte_saved = 0;

localparam [2:0] IDLE   = 3'd0,
                 START  = 3'd1,
                 PARSE  = 3'd2,
                 CSTOP  = 3'd3,
                 STOP   = 3'd4;
reg        [2:0] status = IDLE;

wire      error_parity = (status==PARSE) & ~(^{rx_bit,byte_saved});

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= 0;
        cnt <= 0;
        byte_saved <= 0;
        status <= IDLE;
    end else begin
        {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= 0;
        if(status == CSTOP) begin
            {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= {1'b1,      8'h00, 4'd0, 1'b1, 1'b0};   // end with collision (step2)
            status <= STOP;
        end else if(~rx_on) begin
            cnt <= {1'b0, remainb};
            byte_saved <= 0;
            status <= IDLE;
            if(status == START || status == PARSE)
                {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr}     <= {1'b1, byte_saved, cnt, 1'b1, 1'b1};
        end else if(status == IDLE) begin
            status <= START;
        end else if(status != STOP) begin
            if(rx_bit_en) begin
                if(cnt < 4'd8) begin
                    cnt <= cnt + 4'd1;
                    byte_saved[cnt] <= rx_bit;
                end else begin
                    {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= {1'b1, byte_saved,4'd8, error_parity, error_parity};
                    cnt <= 0;
                    byte_saved <= 0;
                    status <= error_parity ? STOP : PARSE;
                end
            end else if(rx_end) begin
                status <= rx_end_col ? CSTOP : STOP;
                if(rx_end_col)
                    {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= {1'b1, byte_saved, cnt, 1'b0, 1'b0};   // end with collision
                else if(rx_end_err | (|cnt) )
                    {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= {1'b1, byte_saved, cnt, 1'b1, 1'b1};   // end with error
                else
                    {rx_tvalid, rx_tdata, rx_tdatab, rx_tend, rx_terr} <= {1'b1,      8'h00,4'd0, 1'b1, 1'b0};   // end normally
            end
        end
    end

endmodule
