`timescale 1ns/1ns

module nfca_controller (
    input  wire       rstn,           // 0:reset, 1:work
    input  wire       clk,            // require 81.36MHz,  (81.36 = 13.56*6)
    // TX byte stream interface for NFC PCD-to-PICC (axis sink liked)
    input  wire       tx_tvalid,
    output wire       tx_tready,
    input  wire [7:0] tx_tdata,
    input  wire       tx_tlast,
    input  wire [2:0] tx_tlastb,      // indicate how many bits are valid in the last byte. 0:1bit, 1:2bits, 2:3bits, ..., 7:8bits.
    // RX byte stream interface for NFC PICC-to-PCD (axis source liked, without tready)
    output wire       rx_tvalid,
    output wire [7:0] rx_tdata,
    output wire       rx_tlast,
    output wire [3:0] rx_tlastb,
    output wire       rx_tlast_err,
    output wire       rx_tlast_col,
    output wire       no_card,
    // 12bit ADC data interface, the ADC is to sample the envelope detection signal of RFID RX. Required sample rate = 2.5425Msa/s = 81.36/32, that is, transmit 12bit on adc_data every 32 clk cycles.
    input  wire       adc_data_en,    // After starting to work, adc_data_en=1 pulse needs to be generated every 32 clk cycles, and adc_data_en=0 in the rest of the cycles. adc_data_en=1 means adc_data is valid.
    input  wire[11:0] adc_data,       // adc_data should valid when adc_data_en=1
    // RFID carrier output, connect to a NMOS transistor to drive the antenna coil
    output wire       carrier_out,
    // for debug external trigger (optional)
    output wire       rx_rstn
);

wire [2:0] remainb;

wire       tx_req;
wire       tx_en;
wire       tx_bit;

wire       rx_ask_en;
wire       rx_ask;

// RX bit parsed (105.9375 kbps base-band)
wire       rx_bit_en;     // when rx_bit_en=1 pulses, a received bit is valid on rx_bit
wire       rx_bit;        // exclude S (start of communication) and E (end of communication)
wire       rx_end;        // end of a communication pulse, because of detect E, or detect a bit collision, or detect an error.
wire       rx_end_err;    // indicate an unknown error, such a PICC (card) do not match ISO14443A, or noise, only valid when rx_end=1
wire       rx_end_col;    // indicate a bit collision, only valid when rx_end=1


nfca_tx_frame nfca_tx_frame_i (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .tx_tvalid     ( tx_tvalid         ),
    .tx_tready     ( tx_tready         ),
    .tx_tdata      ( tx_tdata          ),
    .tx_tlast      ( tx_tlast          ),
    .tx_tlastb     ( tx_tlastb         ),
    .tx_req        ( tx_req            ),
    .tx_en         ( tx_en             ),
    .tx_bit        ( tx_bit            ),
    .remainb       ( remainb           )
);


nfca_tx_modulate nfca_tx_modulate_i (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .tx_req        ( tx_req            ),
    .tx_en         ( tx_en             ),
    .tx_bit        ( tx_bit            ),
    .carrier_out   ( carrier_out       ),
    .rx_rstn       ( rx_rstn           )
);


nfca_rx_dsp nfca_rx_dsp_i (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .adc_data_en   ( adc_data_en       ),
    .adc_data      ( adc_data          ),
    .rx_ask_en     ( rx_ask_en         ),
    .rx_ask        ( rx_ask            ),
    .rx_lpf_data   (                   ),
    .rx_raw_data   (                   )
);


nfca_rx_tobits nfca_rx_tobits_i (
    .rstn          ( rx_rstn           ),
    .clk           ( clk               ),
    .rx_ask_en     ( rx_ask_en         ),
    .rx_ask        ( rx_ask            ),
    .rx_bit_en     ( rx_bit_en         ),
    .rx_bit        ( rx_bit            ),
    .rx_end        ( rx_end            ),
    .rx_end_err    ( rx_end_err        ),
    .rx_end_col    ( rx_end_col        )
);


nfca_rx_tobytes nfca_rx_tobytes_i (
    .rstn          ( rx_rstn           ),
    .clk           ( clk               ),
    .remainb       ( remainb           ),
    .rx_bit_en     ( rx_bit_en         ),
    .rx_bit        ( rx_bit            ),
    .rx_end        ( rx_end            ),
    .rx_end_err    ( rx_end_err        ),
    .rx_end_col    ( rx_end_col        ),
    .rx_tvalid     ( rx_tvalid         ),
    .rx_tdata      ( rx_tdata          ),
    .rx_tlast      ( rx_tlast          ),
    .rx_tlastb     ( rx_tlastb         ),
    .rx_tlast_err  ( rx_tlast_err      ),
    .rx_tlast_col  ( rx_tlast_col      ),
    .no_card       ( no_card           )
);

endmodule
