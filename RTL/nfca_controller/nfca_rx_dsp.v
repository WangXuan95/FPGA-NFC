
//--------------------------------------------------------------------------------------------------------
// Module  : nfca_rx_dsp
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: called by nfca_controller
//--------------------------------------------------------------------------------------------------------

module nfca_rx_dsp (
    input  wire       rstn,              // 0:reset, 1:work
    input  wire       clk,               // require 81.36MHz
    // 12bit ADC data input (2.5425 Msa/s)
    input  wire       adc_data_en,
    input  wire[11:0] adc_data,
    // RX DSP result (2.5425 Mbps)
    output reg        rx_ask_en,         // rx_ask_en=1 will pulses every 32 clk cycles. When rx_ask_en=1, rx_ask, rx_lpf_data and rx_raw_data is valid.
    output reg        rx_ask,            // ASK demodulated signal. 1 means detected rx_raw_data is significantly less than rx_lpf_data, that is, the PICC (TAG) is sending a ASK signal.
    output reg [11:0] rx_lpf_data,       // low-frequency baseline, only for debug
    output reg [11:0] rx_raw_data        // rx_raw_data, which is to compare with rx_lpf_data, only for debug
);


initial {rx_ask_en, rx_ask, rx_lpf_data, rx_raw_data} = 0;

localparam       N           = 21;
localparam [5:0] SORT_CYCLES = 6'd24;

reg [ 5:0] ccnt = 0;
reg [ 5:0] acnt = 0;
reg [11:0] array  [0:(N-1)];
reg [11:0] sorted [0:(N-1)];

wire [11:0] lpf = sorted[12];              // sorted 是 排序后的过去21个样点，lpf 取其中第12个（中间偏大一点的一个），可以将 lpf 看作中值滤波的结果。
wire [11:0] raw = array [10];              // array  是 未排序的过去21个样点，raw 取其中第10个（最中间那个），即 raw 是观察窗内最中心的数据。

integer ii;

// ASK 解调的 DSP 算法的思路： 用中值滤波获取 ADC 数据的基线(baseline)， ADC 数据小于 baseline 一定的值，认为检测到 ASK 调制的 '1'
// 中值滤波： 用 array 存储过去 21 个 ADC 样点，每获取一个新样点，就用把 array 赋值给 sorted，并用排序网络（冒泡排序）花费 22 个周期对 sorted 排序。最终得到的 sorted 的中间数就是中值滤波结果。
always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        rx_ask_en <= 1'b0;
        {rx_ask, rx_lpf_data, rx_raw_data} <= 0;
        ccnt <= 0;
        acnt <= 0;
        for (ii=0; ii<N; ii=ii+1) begin
            array[ii]  <= 0;
            sorted[ii] <= 0;
        end
    end else begin
        rx_ask_en <= 1'b0;
        if(adc_data_en) begin
            ccnt <= 0;
            array[0] <= adc_data;
            for(ii=0; ii<N-1; ii=ii+1) array[ii+1] <= array[ii];
        end else if(ccnt <= 6'd0) begin 
            ccnt <= ccnt + 6'd1;
            for(ii=0; ii<N; ii=ii+1) sorted[ii] <= array[ii];
        end else if(ccnt <= SORT_CYCLES) begin                        // 花费 SORT_CYCLES 周期运行冒泡排序网络（实际上考虑到 array len=N，只要 N+1 个周期就够，更多无害）
            ccnt <= ccnt + 6'd1;
            if(ccnt[0]) begin
                for(ii=0; ii<N-1; ii=ii+2) begin                      // 排序网络在 ccnt=奇数 时的行为： 0和1尝试交换，2和3尝试交换，4和5尝试交换，……以此类推
                    if( sorted[ii] > sorted[ii+1] ) begin
                        sorted[ii] <= sorted[ii+1];
                        sorted[ii+1] <= sorted[ii];
                    end
                end
            end else begin
                for(ii=1; ii<N  ; ii=ii+2) begin                      // 排序网络在 ccnt=偶数 时的行为： 1和2尝试交换，3和4尝试交换，5和6尝试交换，……以此类推
                    if( sorted[ii] > sorted[ii+1] ) begin
                        sorted[ii] <= sorted[ii+1];
                        sorted[ii+1] <= sorted[ii];
                    end
                end
            end
        end else if(ccnt == SORT_CYCLES + 6'd1) begin
            ccnt <= ccnt + 6'd1;
            if(acnt[5]) begin
                rx_ask_en <= 1'b1;
                rx_ask <= ( lpf - {7'h0,lpf[11:7]} - {8'h0,lpf[11:8]} > raw );               // 若 raw < 0.988*lpf , 认为 PICC 在发送 ASK 。
                rx_lpf_data <= lpf;
                rx_raw_data <= raw;
            end else
                acnt <= acnt + 6'd1;
        end
    end

endmodule
