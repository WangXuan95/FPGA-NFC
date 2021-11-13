`timescale 1ns/1ns

module nfca_rx_tobytes (
    input  wire       rstn,          // 0:reset, 1:work
    input  wire       clk,           // require 81.36MHz
    // indicate how many bits remain for an incomplete byte for PICC to send
    input  wire [2:0] remainb,
    // RX bit parsed (105.9375 kbps base-band)
    input  wire       rx_bit_en,     // when rx_bit_en=1 pulses, a received bit is valid on rx_bit
    input  wire       rx_bit,        // exclude S (start of communication) and E (end of communication)
    input  wire       rx_end,        // end of a communication pulse, because of detect E, or detect a bit collision, or detect an error.
    input  wire       rx_end_err,    // indicate an unknown error, such a PICC (card) do not match ISO14443A, or noise, or PICC's frame is too long. Only valid when rx_end=1
    input  wire       rx_end_col,    // indicate a bit collision, only valid when rx_end=1
    // RX byte parsed
    output reg        rx_tvalid,
    output reg  [7:0] rx_tdata,
    output reg        rx_tlast,
    output reg  [3:0] rx_tlastb,
    output reg        rx_tlast_err,
    output reg        rx_tlast_col,
    output reg        no_card
);

initial {rx_tvalid, rx_tdata, rx_tlast, rx_tlastb, rx_tlast_err, rx_tlast_col} = '0;

reg [3:0] cnt = '0;
reg [7:0] byte_saved = '0;
enum logic [1:0] {IDLE, START, PARSE, STOP} status = IDLE;
wire      error_parity = (status==PARSE) & ~(^{rx_bit,byte_saved});

always @ (posedge clk) begin
    {rx_tvalid, rx_tdata, rx_tlast, rx_tlastb, rx_tlast_err, rx_tlast_col} <= '0;
    no_card <= '0;
    if(~rstn) begin
        cnt <= {1'b0, remainb};
        byte_saved <= '0;
        status <= IDLE;
        no_card <= status == START;
        if(status == PARSE)
            {rx_tvalid, rx_tdata, rx_tlast, rx_tlastb, rx_tlast_err} <= {1'b1, byte_saved, 1'b1, cnt, 1'b1};
    end else if(status == IDLE) begin
        status <= START;
    end else if(status != STOP) begin
        if(rx_bit_en) begin
            if(cnt < 4'd8) begin
                cnt <= cnt + 4'd1;
                byte_saved[cnt] <= rx_bit;
            end else begin
                {rx_tvalid, rx_tdata, rx_tlast, rx_tlastb, rx_tlast_err} <= {1'b1, byte_saved, error_parity, cnt, error_parity};
                cnt <= '0;
                byte_saved <= '0;
                status <= error_parity ? STOP : PARSE;
            end
        end else if(rx_end) begin
            {rx_tvalid, rx_tdata, rx_tlast, rx_tlastb, rx_tlast_err, rx_tlast_col} <= {1'b1, byte_saved, 1'b1, cnt, rx_end_err, rx_end_col};
            status <= STOP;
        end
    end
end

endmodule
