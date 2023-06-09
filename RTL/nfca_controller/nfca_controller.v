
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_controller
// Type    : synthesizable, IP's top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: NFC-A (ISO14443A) controller
//--------------------------------------------------------------------------------------------------------

module nfca_controller (
    input  wire       rstn,           // 0:reset, 1:work
    input  wire       clk,            // require 81.36MHz,  (81.36 = 13.56*6)
    // TX byte stream interface for NFC PCD-to-PICC (axis sink liked)
    input  wire       tx_tvalid,
    output wire       tx_tready,
    input  wire [7:0] tx_tdata,
    input  wire [3:0] tx_tdatab,      // indicate how many bits are valid in the last byte. range=[1,8]. for the last byte of bit-oriented frame
    input  wire       tx_tlast,
    // RX status
    output wire       rx_on,
    // RX byte stream interface for NFC PICC-to-PCD (axis source liked, without tready)
    output wire       rx_tvalid,
    output wire [7:0] rx_tdata,
    output wire [3:0] rx_tdatab,
    output wire       rx_tend,
    output wire       rx_terr,
    // 12bit ADC data interface, the ADC is to sample the envelope detection signal of RFID RX. Required sample rate = 2.5425Msa/s = 81.36/32, that is, transmit 12bit on adc_data every 32 clk cycles.
    input  wire       adc_data_en,    // After starting to work, adc_data_en=1 pulse needs to be generated every 32 clk cycles, and adc_data_en=0 in the rest of the cycles. adc_data_en=1 means adc_data is valid.
    input  wire[11:0] adc_data,       // adc_data should valid when adc_data_en=1
    // RFID carrier output, connect to a NMOS transistor to drive the antenna coil
    output wire       carrier_out
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
wire       rx_end_col;    // indicate a bit collision, only valid when rx_end=1
wire       rx_end_err;    // indicate an unknown error, such a PICC (card) do not match ISO14443A, or noise, only valid when rx_end=1


nfca_tx_frame u_nfca_tx_frame (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .tx_tvalid     ( tx_tvalid         ),
    .tx_tready     ( tx_tready         ),
    .tx_tdata      ( tx_tdata          ),
    .tx_tdatab     ( tx_tdatab         ),
    .tx_tlast      ( tx_tlast          ),
    .tx_req        ( tx_req            ),
    .tx_en         ( tx_en             ),
    .tx_bit        ( tx_bit            ),
    .remainb       ( remainb           )
);


nfca_tx_modulate u_nfca_tx_modulate (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .tx_req        ( tx_req            ),
    .tx_en         ( tx_en             ),
    .tx_bit        ( tx_bit            ),
    .carrier_out   ( carrier_out       ),
    .rx_on         ( rx_on             )
);


nfca_rx_dsp u_nfca_rx_dsp (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .adc_data_en   ( adc_data_en       ),
    .adc_data      ( adc_data          ),
    .rx_ask_en     ( rx_ask_en         ),
    .rx_ask        ( rx_ask            ),
    .rx_lpf_data   (                   ),
    .rx_raw_data   (                   )
);


nfca_rx_tobits u_nfca_rx_tobits (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .rx_on         ( rx_on             ),
    .rx_ask_en     ( rx_ask_en         ),
    .rx_ask        ( rx_ask            ),
    .rx_bit_en     ( rx_bit_en         ),
    .rx_bit        ( rx_bit            ),
    .rx_end        ( rx_end            ),
    .rx_end_col    ( rx_end_col        ),
    .rx_end_err    ( rx_end_err        )
);


nfca_rx_tobytes u_nfca_rx_tobytes (
    .rstn          ( rstn              ),
    .clk           ( clk               ),
    .rx_on         ( rx_on             ),
    .remainb       ( remainb           ),
    .rx_bit_en     ( rx_bit_en         ),
    .rx_bit        ( rx_bit            ),
    .rx_end        ( rx_end            ),
    .rx_end_col    ( rx_end_col        ),
    .rx_end_err    ( rx_end_err        ),
    .rx_tvalid     ( rx_tvalid         ),
    .rx_tdata      ( rx_tdata          ),
    .rx_tdatab     ( rx_tdatab         ),
    .rx_tend       ( rx_tend           ),
    .rx_terr       ( rx_terr           )
);

endmodule
