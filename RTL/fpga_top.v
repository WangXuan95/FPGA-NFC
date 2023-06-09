
module fpga_top (

    input  wire        rstn_btn,        // press button to reset, pressed=0, unpressed=1
    input  wire        clk50m,          // a 50MHz Crystal oscillator
    
    // AD7276 ADC SPI interface
    output wire        ad7276_csn,      // connect to AD7276's CSN   (NFC_Breakboard's AD7276_CSN)
    output wire        ad7276_sclk,     // connect to AD7276's SCLK  (NFC_Breakboard's AD7276_SCLK)
    input  wire        ad7276_sdata,    // connect to AD7276's SDATA (NFC_Breakboard's AD7276_SDATA)
    
    // NFC carrier generation signal
    output wire        carrier_out,     // connect to FDV301N(N-MOSFET)'s gate （栅极）  (NFC_Breakboard's CARRIER_OUT)
    
    // connect to Host-PC (typically via a USB-to-UART chip on FPGA board, such as FT232, CP2102 or CH340)
    input  wire        uart_rx,         // connect to USB-to-UART chip's UART-TX
    output wire        uart_tx,         // connect to USB-to-UART chip's UART-RX
    
    // connect to on-board LED's (optional)
    output wire        led0,            // led0=1 indicates PLL is normally run
    output wire        led1,            // led1=1 indicates carrier is on
    output wire        led2             // led2=1 indicates PCD-to-PICC communication is done, and PCD is waiting for PICC-to-PCD
);


//-------------------------------------------------------------------------------------------------------------------------------------
// The NFC controller core needs a 81.36MHz clock, this PLL module is to convert clk50m to clk81m36
// This PLL module is only available on Altera Cyclone IV E.
// If you use other FPGA families, please use their compatible primitives or IP-cores to generate clk81m36
//-------------------------------------------------------------------------------------------------------------------------------------
wire [3:0] subwire0;
wire       clk81m36;
wire       clk_locked;
altpll pll_i ( .areset (~rstn_btn), .inclk ({1'b0,clk50m}), .clk ({subwire0,clk81m36}), .locked (clk_locked), .activeclock (), .clkbad (), .clkena ({6{1'b1}}), .clkloss (), .clkswitch (1'b0), .configupdate (1'b0), .enable0 (), .enable1 (), .extclk (), .extclkena ({4{1'b1}}), .fbin (1'b1), .fbmimicbidir (), .fbout (), .fref (), .icdrclk (), .pfdena (1'b1), .phasecounterselect ({4{1'b1}}), .phasedone (), .phasestep (1'b1), .phaseupdown (1'b1), .pllena (1'b1), .scanaclr (1'b0), .scanclk (1'b0), .scanclkena (1'b1), .scandata (1'b0), .scandataout (), .scandone (), .scanread (1'b0), .scanwrite (1'b0), .sclkout0 (), .sclkout1 (), .vcooverrange (), .vcounderrange ()); defparam pll_i.bandwidth_type = "AUTO", pll_i.clk0_divide_by = 625, pll_i.clk0_duty_cycle = 50, pll_i.clk0_multiply_by = 1017, pll_i.clk0_phase_shift = "0", pll_i.compensate_clock = "CLK0", pll_i.inclk0_input_frequency = 20000, pll_i.intended_device_family = "Cyclone IV E", pll_i.lpm_hint = "CBX_MODULE_PREFIX=pll", pll_i.lpm_type = "altpll", pll_i.operation_mode = "NORMAL", pll_i.pll_type = "AUTO", pll_i.port_activeclock = "PORT_UNUSED", pll_i.port_areset = "PORT_USED", pll_i.port_clkbad0 = "PORT_UNUSED", pll_i.port_clkbad1 = "PORT_UNUSED", pll_i.port_clkloss = "PORT_UNUSED", pll_i.port_clkswitch = "PORT_UNUSED", pll_i.port_configupdate = "PORT_UNUSED", pll_i.port_fbin = "PORT_UNUSED", pll_i.port_inclk0 = "PORT_USED", pll_i.port_inclk1 = "PORT_UNUSED", pll_i.port_locked = "PORT_USED", pll_i.port_pfdena = "PORT_UNUSED", pll_i.port_phasecounterselect = "PORT_UNUSED", pll_i.port_phasedone = "PORT_UNUSED", pll_i.port_phasestep = "PORT_UNUSED", pll_i.port_phaseupdown = "PORT_UNUSED", pll_i.port_pllena = "PORT_UNUSED", pll_i.port_scanaclr = "PORT_UNUSED", pll_i.port_scanclk = "PORT_UNUSED", pll_i.port_scanclkena = "PORT_UNUSED", pll_i.port_scandata = "PORT_UNUSED", pll_i.port_scandataout = "PORT_UNUSED", pll_i.port_scandone = "PORT_UNUSED", pll_i.port_scanread = "PORT_UNUSED", pll_i.port_scanwrite = "PORT_UNUSED", pll_i.port_clk0 = "PORT_USED", pll_i.port_clk1 = "PORT_UNUSED", pll_i.port_clk2 = "PORT_UNUSED", pll_i.port_clk3 = "PORT_UNUSED", pll_i.port_clk4 = "PORT_UNUSED", pll_i.port_clk5 = "PORT_UNUSED", pll_i.port_clkena0 = "PORT_UNUSED", pll_i.port_clkena1 = "PORT_UNUSED", pll_i.port_clkena2 = "PORT_UNUSED", pll_i.port_clkena3 = "PORT_UNUSED", pll_i.port_clkena4 = "PORT_UNUSED", pll_i.port_clkena5 = "PORT_UNUSED", pll_i.port_extclk0 = "PORT_UNUSED", pll_i.port_extclk1 = "PORT_UNUSED", pll_i.port_extclk2 = "PORT_UNUSED", pll_i.port_extclk3 = "PORT_UNUSED", pll_i.self_reset_on_loss_lock = "OFF", pll_i.width_clock = 5;


//-------------------------------------------------------------------------------------------------------------------------------------
// UART-to-NFCA system
//-------------------------------------------------------------------------------------------------------------------------------------
uart2nfca_system_top u_uart2nfca_system (
    .rstn          ( clk_locked        ),
    .clk           ( clk81m36          ),
    .ad7276_csn    ( ad7276_csn        ),
    .ad7276_sclk   ( ad7276_sclk       ),
    .ad7276_sdata  ( ad7276_sdata      ),
    .carrier_out   ( carrier_out       ),
    .uart_rx       ( uart_rx           ),
    .uart_tx       ( uart_tx           ),
    .rx_on         ( led2              )
);


//-------------------------------------------------------------------------------------------------------------------------------------
// LEDs' assignment
//-------------------------------------------------------------------------------------------------------------------------------------
assign led0 = clk_locked;
assign led1 = carrier_out;


endmodule
