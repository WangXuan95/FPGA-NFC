
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_rx_tobits
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: called by nfca_controller
//--------------------------------------------------------------------------------------------------------

module nfca_rx_tobits (
    input  wire       rstn,          // 0:reset, 1:work
    input  wire       clk,           // require 81.36MHz
    // RX on/off control
    input  wire       rx_on,         // 0:off, 1:on
    // RX DSP result input  (2.5425 Mbps)
    input  wire       rx_ask_en,
    input  wire       rx_ask,
    // RX bit parsed (105.9375 kbps base-band)
    output reg        rx_bit_en,     // when rx_bit_en=1 pulses, a received bit is valid on rx_bit
    output reg        rx_bit,        // exclude S (start of communication) and E (end of communication)
    output reg        rx_end,        // end of a communication pulse, because of detect E, or detect a bit collision, or detect an error.
    output reg        rx_end_col,    // indicate a bit collision, only valid when rx_end=1
    output reg        rx_end_err     // indicate an unknown error, such a PICC (card) do not match ISO14443A, or noise, or PICC's frame is too long. Only valid when rx_end=1
);

initial {rx_bit_en, rx_bit, rx_end, rx_end_err, rx_end_col} = 0;


reg [ 3:0] detect_zeros = 0;
reg [ 3:0] detect_ones = 0;
reg [11:0] shift0 = 0;
reg [11:0] shift1 = 0;
reg [11:0] shift2 = 0;
reg [11:0] shift3 = 0;
reg [ 4:0] cnt = 0;

localparam [1:0] IDLE  = 2'd0,
                 PARSE = 2'd1,
                 STOP  = 2'd2;

reg        [1:0] status = IDLE;

reg  [3:0] sum [0:3];                 // not real register

integer ii, jj;                       // not real register, just loop variable

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        detect_zeros <= 0;
        detect_ones <= 0;
        {shift3, shift2, shift1, shift0} <= 0;
    end else begin
        if(~rx_on) begin
            detect_zeros <= 0;
            detect_ones <= 0;
            {shift3, shift2, shift1, shift0} <= 0;
        end else if(rx_ask_en) begin
            for(ii=0; ii<4; ii=ii+1) sum[ii] = 0;
            for(ii=0; ii<12; ii=ii+1) begin
                sum[0] = sum[0] + {3'h0, shift0[ii]};
                sum[1] = sum[1] + {3'h0, shift1[ii]};
                sum[2] = sum[2] + {3'h0, shift2[ii]};
                sum[3] = sum[3] + {3'h0, shift3[ii]};
            end
            for(jj=0; jj<4; jj=jj+1) begin
                detect_ones[jj]  <= sum[jj] >= 4'd3;
                detect_zeros[jj] <= sum[jj] <= 4'd1;
            end
            {shift3, shift2, shift1, shift0} <= {shift3[10:0], shift2, shift1, shift0, rx_ask};
        end
    end


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {rx_bit_en, rx_bit, rx_end, rx_end_err, rx_end_col} <= 0;
        cnt <= 0;
        status <= IDLE;
    end else begin
        {rx_bit_en, rx_bit, rx_end, rx_end_err, rx_end_col} <= 0;
        if(~rx_on) begin
            cnt <= 0;
            status <= IDLE;
        end else if(rx_ask_en) begin
            if(status == IDLE) begin
                cnt <= 0;
                if(detect_ones == 4'b0010 && detect_zeros == 4'b1101)
                    status <= PARSE;
            end else if(status == PARSE) begin
                if(cnt < 5'd23) begin
                    cnt <= cnt + 5'd1;
                end else begin
                    cnt <= 0;
                    if(~(&(detect_ones^detect_zeros))) begin               // noise
                        {rx_end, rx_end_err} <= 2'b11;
                        status <= STOP;
                    end else if(detect_ones[1:0] == 2'b00) begin           // end of communication
                        rx_end <= 1'b1;
                        status <= STOP;
                    end else if(detect_ones[1:0] == 2'b11) begin           // collision
                        {rx_end, rx_end_col} <= 2'b11;
                        status <= STOP;
                    end else if(detect_ones[1:0] == 2'b10) begin           // logic '1'
                        {rx_bit_en, rx_bit} <= 2'b11;
                    end else if(detect_ones[1:0] == 2'b01) begin           // logic '0'
                        rx_bit_en <= 1'b1;
                    end else begin                                         // undefined error
                        {rx_end, rx_end_err} <= 2'b11;
                        status <= STOP;
                    end
                end
            end
        end
    end

endmodule
