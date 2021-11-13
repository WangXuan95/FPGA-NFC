`timescale 1ns/1ns

module nfca_tx_modulate (
    input  wire       rstn,       // 0:reset, 1:work
    input  wire       clk,        // require 81.36MHz
    // tx bit modulate interface
    output reg        tx_req,
    input  wire       tx_en,
    input  wire       tx_bit,
    // RFID carrier output, connect to a NMOS transistor to drive the antenna coil
    output reg        carrier_out,
    // 1:in RX window,  0:out of RX window
    output reg        rx_rstn
);

localparam    CARRIER_SETUP = 2048;
localparam    CARRIER_HOLD  = 131072;

initial tx_req  = 1'b0;
initial carrier_out = 1'b0;
initial rx_rstn = 1'b0;

reg [ 1:0] clkcnt = '0;
reg [ 7:0] ccnt = '0;
reg [31:0] wcnt = '1;
reg [ 1:0] bdata = '0;   // {1 bits for future, 1 bit for current, 1 bit for past}


always @ (posedge clk)
    if(~rstn) begin
        clkcnt <= '0;
        ccnt <= '0;
    end else if(clkcnt >= 2'd2) begin
        clkcnt <= '0;
        ccnt <= ccnt + 8'h01;
    end else begin
        clkcnt <= clkcnt + 2'd1;
    end


always @ (posedge clk)
    if(~rstn)
        tx_req <= 1'b0;
    else
        tx_req <= clkcnt == 2'h0 && ccnt == 8'hff && (wcnt == CARRIER_SETUP || wcnt >= CARRIER_SETUP*2 && wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD || wcnt > CARRIER_SETUP*2 + CARRIER_HOLD + 16);


always @ (posedge clk)
    if(~rstn) begin
        wcnt <= '1;
        bdata <= '0;
    end else if(clkcnt >= 2'd2 && ccnt == 8'hff) begin
        if         (wcnt <  CARRIER_SETUP) begin
            wcnt <= wcnt + 1;
        end else if(wcnt == CARRIER_SETUP) begin
            if(tx_en) begin
                bdata <= {tx_bit, bdata[1]};
                //$write("%d", tx_bit);           // only for simulation
            end else begin
                wcnt <= wcnt + 1;
                //$write("\n");                   // only for simulation
            end
        end else if(wcnt <  CARRIER_SETUP*2) begin
            wcnt <= wcnt + 1;
        end else if(wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD) begin
            if(tx_en) begin
                wcnt <= CARRIER_SETUP;
                bdata <= {tx_bit, 1'b0};
                //$write("%d", tx_bit);           // only for simulation
            end else
                wcnt <= wcnt + 1;
        end else if(wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD + 16) begin
            wcnt <= wcnt + 1;
        end else if(tx_en) begin
            wcnt <= 0;
            bdata <= {tx_bit, 1'b0};
            //$write("%d", tx_bit);               // only for simulation
        end
    end


always @ (posedge clk)
    if(~rstn)
        carrier_out <= 1'b0;
    else if(wcnt == CARRIER_SETUP && ~ccnt[6])
        if(ccnt[7])
            carrier_out <= ~ccnt[0] && bdata[1] == 1'b0;
        else
            carrier_out <= ~ccnt[0] && bdata[1:0] != 2'b00;
    else if(wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD)
        carrier_out <= ~ccnt[0];
    else
        carrier_out <= 1'b0;


always @ (posedge clk)
    if(~rstn)
        rx_rstn <= 1'b0;
    else
        rx_rstn <= wcnt >= CARRIER_SETUP + 7 && wcnt < CARRIER_SETUP*2 - 128;

endmodule

