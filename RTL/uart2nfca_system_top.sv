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
    output wire       rf_rx_rstn
);

wire       adc_data_en;
wire[11:0] adc_data;

wire       uart_rx_byte_en;
wire [7:0] uart_rx_byte;

wire       tvalid;
wire [7:0] tdata;
wire       tlast;
wire [2:0] tlastb;

wire       tx_tvalid;
wire       tx_tready;
wire [7:0] tx_tdata;
wire       tx_tlast;
wire [2:0] tx_tlastb;

wire       rx_tvalid;
wire [7:0] rx_tdata;
wire       rx_tlast;
wire [3:0] rx_tlastb;
wire       rx_tlast_err;
wire       rx_tlast_col;
wire       no_card;


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
    .CLK_DIV          ( 177                             )
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
    .tlast            ( tlast                           ),
    .tlastb           ( tlastb                          )
);


stream_sync_fifo #(
    .DSIZE            ( 8 + 1 + 3                       ),
    .ASIZE            ( 12                              )
) uart_rx_fifo_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .itvalid          ( tvalid                          ),
    .itready          (                                 ),
    .itdata           ( {tdata   , tlast   , tlastb   } ),
    .otvalid          ( tx_tvalid                       ),
    .otready          ( tx_tready                       ),
    .otdata           ( {tx_tdata, tx_tlast, tx_tlastb} )
);


nfca_controller nfca_controller_i (
    .rstn             ( rstn                            ),
    .clk              ( clk                             ),
    .tx_tvalid        ( tx_tvalid                       ),
    .tx_tready        ( tx_tready                       ),
    .tx_tdata         ( tx_tdata                        ),
    .tx_tlast         ( tx_tlast                        ),
    .tx_tlastb        ( tx_tlastb                       ),
    .rx_tvalid        ( rx_tvalid                       ),
    .rx_tdata         ( rx_tdata                        ),
    .rx_tlast         ( rx_tlast                        ),
    .rx_tlastb        ( rx_tlastb                       ),
    .rx_tlast_err     ( rx_tlast_err                    ),
    .rx_tlast_col     ( rx_tlast_col                    ),
    .no_card          ( no_card                         ),
    .adc_data_en      ( adc_data_en                     ),
    .adc_data         ( adc_data                        ),
    .carrier_out      ( carrier_out                     ),
    .rx_rstn          ( rf_rx_rstn                      )
);


function automatic logic [7:0] hex2ascii(input [3:0] hex);
    return (hex<4'hA) ? (hex+"0") : (hex+("A"-8'hA)) ;
endfunction


uart_tx #(
    .UART_CLK_DIV     ( 707                             ),  // 81.428571MHz / 707 = 115175 ~ 115200
    .MODE             ( 1                               ),  // ASCII printable mode
    .FIFO_ASIZE       ( 11                              ),
    .BYTE_WIDTH       ( 5                               ),
    .BIG_ENDIAN       ( 0                               )
) uart_tx_i (
    .rst_n            ( rstn                            ),
    .clk              ( clk                             ),
    .wreq             ( rx_tvalid | no_card             ),
    .wgnt             (                                 ),
    .wdata            ( no_card ? {"n", "\n", 8'h00, 8'h00, 8'h00} : 
                        { hex2ascii(rx_tdata[7:4]), 
                          hex2ascii(rx_tdata[3:0]), 
                          rx_tlast_err ? "e" : rx_tlast_col ? "c" : ~rx_tlastb[3] ? ":"    : 8'h00, 
                          (rx_tlast_err|rx_tlast_col|~rx_tlastb[3]) ? hex2ascii(rx_tlastb) : 8'h00, 
                          rx_tlast ? "\n" : " "} 
                                                        ),
    .o_uart_tx        ( uart_tx                         )
);

endmodule
