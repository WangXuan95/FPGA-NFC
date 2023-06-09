
module ad7276_read (
    input  wire       rstn, 
    input  wire       clk,      // require 81.36MHz
    // connect to AD7276
    output reg        ad7276_csn,
    output reg        ad7276_sclk,
    input  wire       ad7276_sdata,
    // 12bit ADC data output
    output reg        adc_data_en,
    output reg [11:0] adc_data
);


initial {ad7276_csn, ad7276_sclk} = 2'b11;
initial {adc_data_en, adc_data} = 0;

reg [ 4:0] cnt = 0;
reg        data_en = 0;
reg [11:0] data = 0;

// cnt runs from 0~31 cyclic
always @ (posedge clk or negedge rstn)
    if(~rstn)
        cnt <= 0;
    else
        cnt <= cnt + 5'd1;


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {ad7276_csn, ad7276_sclk} <= 2'b11;
    end else begin
        if(cnt >= 5'd29 || cnt == 5'd0)
            {ad7276_csn, ad7276_sclk} <= 2'b11;
        else
            {ad7276_csn, ad7276_sclk} <= {1'b0, cnt[0]};
    end


always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        data_en <= 1'b0;
        data <= 0;
        adc_data_en <= 1'b0;
        adc_data <= 0;
    end else begin
        if(ad7276_csn) begin                     // submit result
            data_en <= 1'b0;
            adc_data_en <= data_en;
            if(data_en) adc_data <= data;
        end else if(ad7276_sclk) begin           // sample at negedge of ad7276_sclk
            data_en <= 1'b1;
            data <= {data[10:0], ad7276_sdata};
            adc_data_en <= 1'b0;
        end
    end


endmodule
