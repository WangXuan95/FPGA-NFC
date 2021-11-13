FPGA NFC (RFID)
===========================
用 FPGA 从底层开始搭建一个 NFC PCD (读卡器)，支持 ISO14443A 标准。



## 为什么要做本项目？

本人想玩玩射频，又想展示一些和其它玩 SDR 的人不一样的东西。然后发现 NFC 的载波频率只有 13.56MHz，且调制方式为调幅（ASK） ，可以用很低的成本（最廉价的 FPGA + 1个3Msps 的ADC + 几个分立器件）实现一个读卡器。FPGA内既进行数字信号处理，又进行协议处理，是一个完整的~~可以装X的~~小系统。于是就有了本项目，目前已经能在 PC 端串口命令控制下，完整地支持 ISO14443A 。并成功地与 M1卡 交互。



## 名词释义

| 名词                      | 简称 | 直观名称               | 释义                                                         |
| ------------------------- | ---- | ---------------------- | ------------------------------------------------------------ |
| Proximity Coupling Device | PCD  | 读卡器、读写器、Reader | 给卡片提供能量，并作为通讯主机的设备，其实就是读卡器，也就是本项目要实现的东西。 |
| Proximity Card            | PICC | 标签、卡片、TAG        | M1卡、UID卡、电子标签这些卡片。不同类的卡片可能满足不同标准。 |
| PCD-to-PICC               | TX   | 发送                   | PCD 对载波进行调制，传输信息到 PICC                          |
| PICC-to-PCD               | RX   | 接收                   | PICC 改变自身阻抗，使得 PCD 探测到载波幅度发生变化，从而传输信息到 PCD 。 |
| NXP MIFARE Classic 1K     | M1卡 |                        | 一种满足 ISO14443A 的卡片，日常生活很常见，比如门禁卡。      |
| ISO14443A                 | NFCA |                        | 一种 NFC 标准，用于个人卡片。本项目从硬件到协议完全支持。详见 [1,2] |
| ISO14443B                 | NFCB |                        | 一种 NFC 标准，用于个人卡片。本项目硬件不支持。详见 [1,2]    |
| ISO15693                  | NFCV |                        | 一种 NFC 标准，用于工业电子标签。本项目硬件支持，但 FPGA 尚未编写其协议。详见 [1] |
| Carrier、载波             | fc   | 13.56MHz 载波          | FPGA 发射引脚需要产生的频率，驱动线圈在这个频率下谐振。      |
| Subcarrier、副载波        | fs   | 847.5 kHz 副载波       | 调制的最小单位（PCD和PICC会以这个频率改变调制幅度），是载波频率的 1/16 |
| 位频率                    |      | 105.9375 kHz           | 8个副载波周期可能携带一位 (bit) 数据信息                     |

更多简称详见引用 [1,2]



## 项目思路

对于发送，13.56MHz 载波发送可以让 FPGA 驱动一个 MOS 管 (FDV301N) + 一个谐振电路来让天线(线圈)谐振。对于 ISO14443A，PCD-to-PICC 的调制方式是 100% ASK （即在一个副载波周期内，要么满幅度发送载波，要么完全不发送载波），这对 FPGA 也是很容易实现的。

对于 ISO14443A 接收，PICC-to-PCD 的调制方式是 2%~10% 的 ASK （即在一个副载波周期内，要么让载波减弱一点，要么不减弱）。我用二极管(1N4148)+电容电阻来做包络检波，该包络线的频率=副载波频率=847.5kHz。这样避免我们用几十Msps的ADC来直接采样载波，而是只用一个 3Msps 的 ADC (AD7276B) 来采样副载波即可。

在 FPGA 内，需要用一个数字信号处理算法来检测 ADC 信号的幅度的微小变化，需要一定的抗噪声能力（我用的是中值滤波减去原始信号，再做阈值检测，效果不错）。

至于发送协议的 CRC 校验生成、封包；接收协议的解包 [2]，这是 FPGA 的强项，不必多说。

我还在 FPGA 中实现了串口控制逻辑，用户可以在 PC 端的”串口调试工具“中发送你要发送给卡片的数据，然后收到卡片返回的数据。

下图是系统框图，其中 FPGA 中的模块下方逐个标注了 Verilog 代码文件名。

    ____________    __________________________________________________________________________________________________
    |          |    |                      _________________________________________________________                 |
    |          |    |         ___________  |    ____________          _____________                |                 |   ____________    ____________
    |          |    |         | UART RX |  |    |  frame   |          | RFID TX   |                |                 |   | FDV301N  |    | Resonant |     ___________
    |  uart_tx |--->| uart_rx |  logic  |--|--->|  pack    |--------->| modulate  |--------------->|---------------->|-->| N-MOSFET |--->| circuit  |     |         |
    |          |    |         -----------  |    ------------          -------------                |   carrier_out   |   |          |    |          |---->| Antenna |
    |          |    |  uart_rx.sv          | nfca_tx_frame.sv           | nfca_tx_modulate.sv      |                 |   ------------    ------------  |  |  Coil   |
    |          |    |  uart_rx_parser.sv   |                    rx_rstn |                          |                 |                                 |  |         |
    |      GND |----|  stream_sync_fifo.sv |                            |                          |                 |                                 |  -----------
    |          |    |         ___________  |  ___________         ______V____        ____________  |  _____________  |     ___________   ____________  |
    |          |    |         | UART TX |  |  | bytes   |         | bits    |        | ADC data |  |  | AD7276B   |  |     |         |   | envelop  |  |
    |  uart_rx |<---| uart_tx |  logic  |<-|--| rebuild |<--------| rebuild |<-------| process  |<-|--| ADC reader|<-|<----| AD7276B |<--|detection |<--
    |          |    |         -----------  |  -----------         -----------        ------------  |  -------------  | SPI |   ADC   |   |          |
    |          |    |        uart_tx.sv    |nfca_rx_tobytes.sv   nfca_rx_tobits.sv  nfca_rx_dsp.sv |  ad7276_read.sv |     -----------   ------------
    |          |    |                      --------------------------------------------------------|                 |
    |          |    |                                      nfca_controller.sv                                        |
    ------------    --------------------------------------------------------------------------------------------------
       Host PC                          FPGA (fpga_top.sv)                                                                       Analog Circuit
       



# 硬件

需要一个很简单的 PCB，上面包括发送电路的 N-MOSFET、电感等。接收电路的 1N4148 二极管、以及 AD7276B ADC。

我在立创 EDA 开源，详见 https://oshwhub.com/wangxuan/rfid_nfc_iso14443a_iso15693_breakoutboard 。你可以拿他来打样。

如果你只看原理图 ，见 NFC_RFID_BreakoutBoard_sch.pdf 。一些原理和焊接的注意事项我已经写在原理图中。

该电路方案参考自 THM3060 原理图 [3] 。



# FPGA 部署

部署到 FPGA 时，所有 ./RTL/ 目录 和 ./RTL/nfca_controller/ 目录 中的 .sv 文件都需要加入工程。FPGA 顶层为 fpga_top.sv 。它的每个引脚的连接方式见代码注释，如下：

    module fpga_top(
        input  wire        rstn_btn,        // press button to reset, pressed=0, unpressed=1
        input  wire        clk50m,          // a 50MHz Crystal oscillator
        
        // AD7276 ADC SPI interface
        output wire        ad7276_csn,      // connect to AD7276's CSN   (RFID_NFC_Breakboard 的 ADC_CSN)
        output wire        ad7276_sclk,     // connect to AD7276's SCLK  (RFID_NFC_Breakboard 的 ADC_SCK)
        input  wire        ad7276_sdata,    // connect to AD7276's SDATA (RFID_NFC_Breakboard 的 ADC_DAT)
        
        // NFC carrier generation signal
        output wire        carrier_out,     // connect to FDV301N(N-MOSFET)'s gate （栅极）  (RFID_NFC_Breakboard 的 CARRIER_OUT)
        
        // connect to Host-PC (typically via a USB-to-UART chip on FPGA board, such as CP2102 or CH340)
        input  wire        uart_rx,         // connect to USB-to-UART chip's UART-TX
        output wire        uart_tx,         // connect to USB-to-UART chip's UART-RX
        
        // connect to on-board LED's (optional)
        output wire        led0, led1, led2
    );

* 所有代码都是 SystemVerilog 行为级实现，支持任意 FPGA 平台。
* 除了 fpga_top.sv 里的 altpll module 是仅限于 Cyclone IV E 的原语，它用来生成 81.36MHz 时钟，用来驱动 NFC 控制器。如果你用的不是 Altera Cyclone IV E，请使用其它的 IP 核（例如Xilinx 的 clock wizard）或原语来替换。



# 串口控制

通过串口进行通信，串口格式为 115200,8,n,1 (即波特率=115200，8个数据位，无校验位，1个停止位)。串口通信是“一问一答”的形式，发送你要发给卡片的数据，然后卡片返回数据。每个命令和响应都以 \r 或 \n 或 \r\n 结尾（也就是一行一个命令/响应）

首先，建议在 PC 上使用“串口调试助手”，而不是 putty 等软件。因为我设计的逻辑是： FPGA 会在收到串口命令时打开载波，如果1.2秒内没有下一个命令到来，就自动关闭载波。这对于一个控制串口的应用程序是足够的时间。但1.2秒的时间内，是不够人是打出下一条命令的，会导致载波关闭，卡片下电，卡片之前获得的状态都消失了。“串口调试助手”可以一次发送多行命令，而 Putty 则一次只能打一条命令。

> 注意：“串口调试助手” 往往有“16进制显示”和“16进制发送”选项，不需要勾选。本项目里 FPGA 会把收到的 ASCII 的十六进制形式处理成数字，也会把发出的 数字转成 ASCII 十六进制形式。

## 与 M1 卡通信

我用自己的门禁卡，和几个在 taobao 上买了的 M1 白卡试了试，因为都是 M1 卡，行为类似。以一个卡举例：

在 “串口调试助手” 中输入（注意末尾要加回车，这样才会被当成一条完整的命令）：

    26
    
命令 FPGA 发送 0x26 (ISO14443 规定的 REQA [2]) 给卡片。然后串口收到如下，这是 ISO14443 规定的 ATQA，含义是 Bit frame anticollision 。

    04 00
    

> 注：如果没检测到卡，串口会收到字符 n。表示： FPGA正常工作，但没检测到卡。

然后我们在“发送框”里下一行附加一个  ISO14443 规定的 anticollision 命令，用来获得卡的 UID （因为很可能1.2秒已经过去了，卡片已经丢失了上次上电的信息，需要重新发送 REQA 0x26）。

    26
    93 20
    

卡片响应（第一行是响应 REQA 的 ATQA，第二行是 响应 anticollision 的 UID）：

    04 00
    4B BE DE 79 52
    

然后我们在“发送框”里下一行附加一个 ISO14443 规定的 SELECT 命令，用刚刚获取到的 UID 选中该卡：

    26
    93 20
    93 70 4B BE DE 79 52
    

卡响应 ISO14443 规定的 SAK：

    04 00
    4B BE DE 79 52
    08 B6 DD
    
可以看出，这个卡的 SAK=0x08，代表它是 M1 卡。后面的 0xB6 0xDD 则是 CRC 校验码。

> 发送时不需要用户附加 CRC 校验码， FPGA 会在协议规定的需要加校验码的地方自动计算并追加 CRC。
>
> 接收时，CRC吗不会被 FPGA 检查和删掉，会从串口展示出来。

根据卡片返回的 SAK ，知道这是 M1 卡后，我们可以发送 M1 卡的 Key 认证命令的 Phase1 （第一阶段），从卡片获取随机数（注意，该命令不是 ISO14443 规定的，而是 M1 卡独有的，其它卡不会响应这个命令）。我们在“发送框”里下一行附加：

    26
    93 20
    93 70 4B BE DE 79 52
    60 07
    

卡片响应 4 字节随机数：

    04 00
    4B BE DE 79 52
    08 B6 DD
    EF 9B B6 5A
    



在 anticollision 这一步，本项目也支持发送不完整的字节（bit-oriented frame）来进行多卡片冲突检测。留待后续完善文档。



> 关于 M1 卡的后续认证、读写步骤，不是本工程关注的范围。
>
> 本工程仅关注 ISO14443A PCD 与 PICC 交互的底层实现。
>
> 你可以用上层应用程序（C, Python, C# 编程），控制串口来进行 M1 卡的进一步操作。



# 引用

* [1] ST TN1216 Technical note, ST NFC guide, https://www.st.com/resource/en/technical_note/dm00190233-st25-nfc-guide-stmicroelectronics.pdf
* [2] ISO/IEC STANDARD 14443-3, http://emutag.com/iso/14443-3.pdf
* [3] THM3060 读卡器 原理图（好像没有官方公开，~~国内公司老毛病了~~。可以上 baidu 搜，或 taobao 买个模块，商家就给你原理图了）

