
module uart_rx_parser #(
    parameter CLK_DIV = 108  // UART baud rate = clk freq/(4*CLK_DIV), modify CLK_DIV to change the UART baud
                             // for example, when clk=125MHz, CLK_DIV=271, then baud=125MHz/(4*271)=115200, 115200 is a typical baud rate for UART
) (
    input  wire       rstn,
    input  wire       clk,
    // uart RX bytes input
    input  wire       uart_rx_byte_en,
    input  wire [7:0] uart_rx_byte,
    // parsed byte stream
    output reg        tvalid,
    output reg  [7:0] tdata,
    output reg  [3:0] tdatab,
    output reg        tlast
);


initial {tvalid, tdata, tlast, tdatab} = 0;

localparam [7:0] CHAR_0  = 8'h30,  // "0"
                 CHAR_9  = 8'h39,  // "9"
                 CHAR_A  = 8'h41,  // "A"
                 CHAR_F  = 8'h46,  // "F"
                 CHAR_a  = 8'h61,  // "a"
                 CHAR_f  = 8'h66,  // "f"
                 CHAR_ht = 8'h09,  // "\t"
                 CHAR_sp = 8'h20,  // " "
                 CHAR_cr = 8'h0D,  // "\r"
                 CHAR_lf = 8'h0A,  // "\n"
                 CHAR_cl = 8'h3A;  // ":"


function  [4:0] ascii2hex;
    input [7:0] ascii;
    reg   [7:0] tmp;
begin
    if         ( ascii >= CHAR_0 && ascii <= CHAR_9 ) begin
        tmp = ascii - CHAR_0;
        ascii2hex = {1'b1, tmp[3:0]};
    end else if( ascii >= CHAR_A && ascii <= CHAR_F ) begin
        tmp = ascii - CHAR_A + 8'd10;
        ascii2hex = {1'b1, tmp[3:0]};
    end else if( ascii >= CHAR_a && ascii <= CHAR_f ) begin
        tmp = ascii - CHAR_a + 8'd10;
        ascii2hex = {1'b1, tmp[3:0]};
    end else begin
        tmp = ascii;
        ascii2hex = {1'b0, 4'h0};
    end
end
endfunction


wire       isspace = (uart_rx_byte == CHAR_sp) || (uart_rx_byte == CHAR_ht);
wire       iscrlf  = (uart_rx_byte == CHAR_cr) || (uart_rx_byte == CHAR_lf);
wire       iscolon = (uart_rx_byte == CHAR_cl);
wire       ishex;
wire [3:0] hexvalue;

assign {ishex, hexvalue} = ascii2hex(uart_rx_byte);

localparam [2:0] INIT   = 3'd0,
                 HEXH   = 3'd1,
                 HEXL   = 3'd2,
                 LASTB  = 3'd3,
                 INVALID= 3'd4;
reg [2:0] fsm = INIT;

reg [7:0] savedata = 0;

always @ (posedge clk or negedge rstn)
    if(~rstn) begin
        {tvalid, tdata, tlast, tdatab} <= 0;
        fsm <= INIT;
        savedata <= 0;
    end else begin
        {tvalid, tdata, tlast} <= 0;
        tdatab <= 4'd8;
        if(uart_rx_byte_en) begin        
            if         (fsm == INIT) begin
                if(ishex) begin
                    savedata <= {4'h0, hexvalue};
                    fsm <= HEXH;
                end else if(~iscrlf & ~isspace) begin
                    fsm <= INVALID;
                end
            end else if(fsm == HEXH || fsm==HEXL) begin
                if(ishex) begin
                    if(fsm == HEXH) begin
                        savedata <= {savedata[3:0], hexvalue};
                        fsm <= HEXL;
                    end else begin
                        {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b0};
                        savedata <= {4'h0, hexvalue};
                        fsm <= HEXH;
                    end
                end else if(iscolon) begin
                    fsm <= LASTB;
                end else if(isspace) begin
                    fsm <= HEXL;
                end else if(iscrlf) begin
                    {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b1};
                    fsm <= INIT;
                end else begin
                    {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b1};
                    fsm <= INVALID;
                end
            end else if(fsm == LASTB) begin
                if(ishex) begin
                    {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b1};
                    if     (hexvalue == 4'd0)
                        tdatab <= 4'd1;
                    else if(hexvalue <= 4'd7)
                        tdatab <= hexvalue;
                    fsm <= INVALID;
                end else if(iscrlf) begin
                    {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b1};
                    fsm <= INIT;
                end else begin
                    {tvalid, tdata, tlast} <= {1'b1, savedata, 1'b1};
                    fsm <= INVALID;
                end
            end else if(iscrlf) begin
                fsm <= INIT;
            end
        end
    end

endmodule
