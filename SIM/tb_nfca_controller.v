
//--------------------------------------------------------------------------------------------------------
// Module  : tb_nfca_controller
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for nfca_controller
//           only a simulation for PCD-to-PICC,
//           because there is no PICC model, it can not simulate PICC-to-PCD
//--------------------------------------------------------------------------------------------------------

`timescale 1ps/1ps

module tb_nfca_controller ();

initial $dumpvars(0, tb_nfca_controller);


reg clk = 1'b0;
always #6000 clk = ~clk;   // 81.36MHz approx.


reg        tx_tvalid = 1'b0;
wire       tx_tready;
reg  [7:0] tx_tdata  = 0;
reg  [3:0] tx_tdatab = 0;
reg        tx_tlast  = 0;

wire       carrier_out;


nfca_controller nfca_controller_i (
    .rstn          ( 1'b1              ),
    .clk           ( clk               ),
    .tx_tvalid     ( tx_tvalid         ),
    .tx_tready     ( tx_tready         ),
    .tx_tdata      ( tx_tdata          ),
    .tx_tdatab     ( tx_tdatab         ),
    .tx_tlast      ( tx_tlast          ),
    .rx_on         (                   ),
    .rx_tvalid     (                   ),
    .rx_tdata      (                   ),
    .rx_tdatab     (                   ),
    .rx_tend       (                   ),
    .rx_terr       (                   ),
    .adc_data_en   ( 1'b0              ),
    .adc_data      ( 12'h0             ),
    .carrier_out   ( carrier_out       )
);


task tx_frame;
    input [255:0] data_array;
    input integer byte_len;
    input [  3:0] datab;
    integer ii;
begin
    $display("PCD-to-PICC: %d Bytes", byte_len);
    {tx_tvalid, tx_tdata, tx_tdatab, tx_tlast} <= 0;
    @ (posedge clk);
    for (ii=0; ii<byte_len; ii=ii+1) begin
        tx_tvalid <= 1'b1;
        tx_tdata  <= data_array[8*ii+:8];
        tx_tdatab <= ii+1 == byte_len ? datab : 4'd8;
        tx_tlast  <= ii+1 == byte_len;
        @ (posedge clk);
        while(~tx_tready) @ (posedge clk);
    end
    {tx_tvalid, tx_tdata, tx_tdatab, tx_tlast} <= 0;
end
endtask


initial begin
    tx_frame(256'h00_00_00_26, 1, 4'd8);
    tx_frame(256'h00_00_34_12, 2, 4'd8);
    tx_frame(256'h00_12_34_12, 3, 4'd6);
    tx_frame(256'h00_12_56_93, 3, 4'd7);
    tx_frame(256'h34_12_56_93, 4, 4'd1);
    tx_frame(256'h34_12_70_95, 4, 4'd8);
    tx_frame(256'h34_12_6f_95, 4, 4'd8);
    
    @ (posedge clk);
    while(~tx_tready) @ (posedge clk);
    repeat(10000) @ (posedge clk);
    $finish;
end


endmodule

