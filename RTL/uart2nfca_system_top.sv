`timescale 1ns/1ns

module uart2nfca_system_top (
    input  wire       rstn,           // 0:reset, 1:work
    input  wire       clk,            // require 81.36MHz,  (81.36 = 13.56*6)
    // connect to AD7276, which is a 12bit 3Msps ADC to sample the envelope detection result of RFID RX. Actually work at 2.5456 Msa/s in this system
    output wire       ad7276_csn,
    output wire       ad7276_sclk,
    input  wire       ad7276_sdata,
    // RFID carrier output, connect to a NMOS transistor to drive the antenna coil
    output reg        carrier_out,
    // UART interface, typically connect to host-PC or MCU, and run NFC user applications on host-PC or MCU.
    input  wire       uart_rx,
    output wire       uart_tx,
    // for debug external trigger (optional)
    output wire       rx_rstn
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


ad7276_read ad7276_read_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .ad7276_csn       ( ad7276_csn                      ),
    .ad7276_sclk      ( ad7276_sclk                     ),
    .ad7276_sdata     ( ad7276_sdata                    ),
    .adc_data_en      ( adc_data_en                     ),
    .adc_data         ( adc_data                        )
);


uart_rx #(
    .CLK_DIV          ( 2120                            )   // 81.36MHz / 8482 / ~ 9600 * 4
) uart_rx_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .uart_rx          ( uart_rx                         ),
    .uart_rx_byte_en  ( uart_rx_byte_en                 ),
    .uart_rx_byte     ( uart_rx_byte                    )
);


uart_rx_parser uart_rx_parser_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .uart_rx_byte_en  ( uart_rx_byte_en                 ),
    .uart_rx_byte     ( uart_rx_byte                    ),
    .tvalid           ( tvalid                          ),
    .tdata            ( tdata                           ),
    .tdatab           ( tdatab                          ),
    .tlast            ( tlast                           )
);


stream_sync_fifo #(
    .DSIZE            ( 8 + 4 + 1                       ),
    .ASIZE            ( 12                              )
) uart_rx_fifo_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .itvalid          ( tvalid                          ),
    .itready          (                                 ),
    .itdata           ( {   tdata,    tdatab,    tlast} ),
    .otvalid          ( tx_tvalid                       ),
    .otready          ( tx_tready                       ),
    .otdata           ( {tx_tdata, tx_tdatab, tx_tlast} )
);


nfca_controller nfca_controller_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .tx_tvalid        ( tx_tvalid                       ),
    .tx_tready        ( tx_tready                       ),
    .tx_tdata         ( tx_tdata                        ),
    .tx_tdatab        ( tx_tdatab                       ),
    .tx_tlast         ( tx_tlast                        ),
    .rx_rstn          ( rx_rstn                         ),
    .rx_tvalid        ( rx_tvalid                       ),
    .rx_tdata         ( rx_tdata                        ),
    .rx_tdatab        ( rx_tdatab                       ),
    .rx_tend          ( rx_tend                         ),
    .rx_terr          ( rx_terr                         ),
    .adc_data_en      ( adc_data_en                     ),
    .adc_data         ( adc_data                        ),
    .carrier_out      ( carrier_out                     )
);


function automatic logic [7:0] hex2ascii(input [3:0] hex);
    return (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
endfunction


uart_tx #(
    .UART_CLK_DIV     ( 8482                            ),  // 81.36MHz / 8482 ~ 9600
    .MODE             ( 1                               ),  // ASCII printable mode
    .FIFO_ASIZE       ( 12                              ),
    .BYTE_WIDTH       ( 4                               ),
    .BIG_ENDIAN       ( 0                               )
) uart_tx_i (
    .rst_n            ( rstn                            ),
    .clk              ( clk                             ),
    .wgnt             (                                 ),
    .wreq             ( rx_tvalid                       ),
    .wdata            ( rx_tend ? {(rx_terr ? "n" : 8'h00), "\n", 8'h00, 8'h00} : 
                        { hex2ascii(rx_tdata[7:4]), hex2ascii(rx_tdata[3:0]), 
                          rx_tdatab<4'd8 ? ":" : " ", 
                          rx_tdatab<4'd8 ? hex2ascii(rx_tdatab) : 8'h00 }
                                                        ),
    .o_uart_tx        ( uart_tx                         )
);

endmodule
