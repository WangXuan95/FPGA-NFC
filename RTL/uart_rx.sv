`timescale 1ns/1ns

module uart_rx #(
    parameter CLK_DIV = 108  // UART baud rate = clk freq/(4*CLK_DIV), modify CLK_DIV to change the UART baud
                             // for example, when clk=125MHz, CLK_DIV=271, then baud=125MHz/(4*271)=115200, 115200 is a typical baud rate for UART
) (
    input  wire      rstn,
    input  wire      clk,
    // UART RX input
    input  wire      uart_rx,
    // UART RX bytes
    output reg       uart_rx_byte_en,
    output reg [7:0] uart_rx_byte
);

initial {uart_rx_byte_en, uart_rx_byte} = '0;

reg        rxr = 1'b1;
reg [31:0] ccnt = 0;
reg [31:0] bcnt = 0;
reg [ 5:0] rxshift = '0;
wire       rxbit = rxshift[2:0] != 3'h0 && rxshift[3:1] != 3'h0;
reg [ 8:0] databuf = '0;


always @ (posedge clk)
    if(~rstn)
        rxr <= 1'b0;
    else
        rxr <= uart_rx;


always @ (posedge clk) begin
    uart_rx_byte_en <= 1'b0;
    if(~rstn) begin
        uart_rx_byte <= '0;
        ccnt <= 0;
        bcnt <= 0;
        rxshift <= '0;
        databuf <= '0;
    end else if( ccnt < CLK_DIV-1 ) begin
        ccnt <= ccnt + 1;
    end else begin
        ccnt <= 0;
        rxshift <= {rxshift[4:0], rxr};
        if         (bcnt <  1000) begin
            bcnt <= (&rxshift) ? bcnt + 1 : 0;
        end else if(bcnt == 1000) begin
            if(rxshift == 6'b111_000) bcnt <= 1001;
        end else if(bcnt <  1037) begin
            if(bcnt[1:0] == 2'b01) databuf <= {rxbit, databuf[8:1]};
            bcnt <= bcnt + 1;
        end else if(~rxbit | databuf[0]) begin
            bcnt <= 0;
        end else begin
            bcnt <= 1000;
            uart_rx_byte_en <= 1'b1;
            uart_rx_byte <= databuf[8:1];
        end
    end
end

endmodule
