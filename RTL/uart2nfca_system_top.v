
module uart2nfca_system_top (
    input  wire       rstn,           // 0:reset, 1:work
    input  wire       clk,            // require 81.36MHz,  (81.36 = 13.56*6)
    // connect to AD7276, which is a 12bit 3Msps ADC to sample the envelope detection result of RFID RX. Actually work at 2.5456 Msa/s in this system
    output wire       ad7276_csn,
    output wire       ad7276_sclk,
    input  wire       ad7276_sdata,
    // RFID carrier output, connect to a NMOS transistor to drive the antenna coil
    output wire       carrier_out,
    // UART interface, typically connect to host-PC or MCU, and run NFC user applications on host-PC or MCU.
    input  wire       uart_rx,
    output wire       uart_tx,
    // for debug external trigger (optional)
    output wire       rx_on
);

wire       adc_data_en;
wire[11:0] adc_data;

wire       uart_rx_byte_en;
wire [7:0] uart_rx_byte;

wire       tvalid;
wire [7:0] tdata;
wire [3:0] tdatab;
wire       tlast;

wire       tx_tvalid;
wire       tx_tready;
wire [7:0] tx_tdata;
wire [3:0] tx_tdatab;
wire       tx_tlast;

wire       rx_tvalid;
wire [7:0] rx_tdata;
wire [3:0] rx_tdatab;
wire       rx_tend;
wire       rx_terr;


ad7276_read u_ad7276_read (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .ad7276_csn       ( ad7276_csn                      ),
    .ad7276_sclk      ( ad7276_sclk                     ),
    .ad7276_sdata     ( ad7276_sdata                    ),
    .adc_data_en      ( adc_data_en                     ),
    .adc_data         ( adc_data                        )
);


uart_rx #(
    .CLK_FREQ         ( 81360000                        ),  // 81.36 MHz
    .BAUD_RATE        ( 9600                            ),
    .PARITY           ( "NONE"                          ),
    .FIFO_EA          ( 0                               )
) u_uart_rx (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .i_uart_rx        ( uart_rx                         ),
    .o_tready         ( 1'b1                            ),
    .o_tvalid         ( uart_rx_byte_en                 ),
    .o_tdata          ( uart_rx_byte                    ),
    .o_overflow       (                                 )
);


uart_rx_parser u_uart_rx_parser (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .uart_rx_byte_en  ( uart_rx_byte_en                 ),
    .uart_rx_byte     ( uart_rx_byte                    ),
    .tvalid           ( tvalid                          ),
    .tdata            ( tdata                           ),
    .tdatab           ( tdatab                          ),
    .tlast            ( tlast                           )
);


fifo_sync #(
    .DW               ( 8 + 4 + 1                       ),
    .EA               ( 12                              )
) u_fifo_sync (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .i_rdy            (                                 ),
    .i_en             ( tvalid                          ),
    .i_data           ( {   tdata,    tdatab,    tlast} ),
    .o_rdy            ( tx_tready                       ),
    .o_en             ( tx_tvalid                       ),
    .o_data           ( {tx_tdata, tx_tdatab, tx_tlast} )
);


nfca_controller u_nfca_controller (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .tx_tvalid        ( tx_tvalid                       ),
    .tx_tready        ( tx_tready                       ),
    .tx_tdata         ( tx_tdata                        ),
    .tx_tdatab        ( tx_tdatab                       ),
    .tx_tlast         ( tx_tlast                        ),
    .rx_on            ( rx_on                           ),
    .rx_tvalid        ( rx_tvalid                       ),
    .rx_tdata         ( rx_tdata                        ),
    .rx_tdatab        ( rx_tdatab                       ),
    .rx_tend          ( rx_tend                         ),
    .rx_terr          ( rx_terr                         ),
    .adc_data_en      ( adc_data_en                     ),
    .adc_data         ( adc_data                        ),
    .carrier_out      ( carrier_out                     )
);


function  [7:0] hex2ascii;
    input [3:0] hex;
begin
    hex2ascii = (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
end
endfunction


uart_tx #(
    .CLK_FREQ         ( 81360000                        ),
    .BAUD_RATE        ( 9600                            ),
    .PARITY           ( "NONE"                          ),
    .STOP_BITS        ( 4                               ),
    .BYTE_WIDTH       ( 4                               ),
    .FIFO_EA          ( 12                              ),
    .EXTRA_BYTE_AFTER_TRANSFER ( ""                     ),
    .EXTRA_BYTE_AFTER_PACKET   ( ""                     )
) u_uart_tx (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .i_tready         (                                 ),
    .i_tvalid         ( rx_tvalid                       ),
    .i_tdata          ( rx_tend ? {8'h00, 8'h00, "\n", (rx_terr ? "n" : 8'h00)} : { ((rx_tdatab<4'd8) ? hex2ascii(rx_tdatab) : 8'h00), ((rx_tdatab<4'd8) ? ":" : " "), hex2ascii(rx_tdata[3:0]), hex2ascii(rx_tdata[7:4]) } ),
    .i_tkeep          ( rx_tend ? {1'b0 , 1'b0 , 1'b1, (rx_terr ? 1'b1 : 1'b0)} : { ((rx_tdatab<4'd8) ? 1'b1                 : 1'b0 ),  3'b111                                                                            } ),
    .i_tlast          ( 1'b0                            ),
    .o_uart_tx        ( uart_tx                         )
);


endmodule
