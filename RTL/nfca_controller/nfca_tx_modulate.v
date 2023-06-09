
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_tx_modulate
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: called by nfca_controller
//--------------------------------------------------------------------------------------------------------

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
    output reg        rx_on
);


localparam    CARRIER_SETUP = 2048;
localparam    CARRIER_HOLD  = 131072;

initial tx_req  = 1'b0;
initial carrier_out = 1'b0;
initial rx_on = 1'b0;

reg [ 1:0] clkcnt = 2'd0;
reg [ 7:0] ccnt = 8'd0;
reg [31:0] wcnt = 32'hFFFFFFFF;
reg [ 1:0] bdata = 2'd0;            // {1 bits for future, 1 bit for current, 1 bit for past}


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        clkcnt <= 2'd0;
        ccnt <= 8'd0;
    end else begin
        if(clkcnt >= 2'd2) begin
            clkcnt <= 2'd0;
            ccnt <= ccnt + 8'h01;
        end else begin
            clkcnt <= clkcnt + 2'd1;
        end
    end


always @ (posedge clk or negedge rstn)
    if(~rstn)
        tx_req <= 1'b0;
    else
        tx_req <= clkcnt == 2'h0 && ccnt == 8'hff && (wcnt == CARRIER_SETUP || wcnt >= CARRIER_SETUP*2 && wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD || wcnt > CARRIER_SETUP*2 + CARRIER_HOLD + 16);


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        wcnt <= 32'hFFFFFFFF;
        bdata <= 2'd0;
    end else begin
        if(clkcnt >= 2'd2 && ccnt == 8'hff) begin
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
    end


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        carrier_out <= 1'b0;
    end else begin
        if(wcnt == CARRIER_SETUP && ~ccnt[6]) begin
            if(ccnt[7])
                carrier_out <= ~ccnt[0] && bdata[1] == 1'b0;
            else
                carrier_out <= ~ccnt[0] && bdata[1:0] != 2'b00;
        end else if(wcnt <= CARRIER_SETUP*2 + CARRIER_HOLD) begin
            carrier_out <= ~ccnt[0];
        end else begin
            carrier_out <= 1'b0;
        end
    end


always @ (posedge clk or negedge rstn)
    if(~rstn)
        rx_on <= 1'b0;
    else
        rx_on <= wcnt >= CARRIER_SETUP + 7 && wcnt < CARRIER_SETUP*2 - 128;

endmodule

