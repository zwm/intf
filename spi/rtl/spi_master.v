

module spi_master (
    // sys
    input                           rstn,
    input                           clk,
    // byte intf
    input                           tx_buf_vld, // one data byte valid to be transmitted
    input       [7:0]               tx_buf_byte,
    output                          tx_buf_req,
    output                          rx_buf_req,
    output      [7:0]               rx_buf_byte,
    input                           rx_buf_vld, // rx buffer is empty to receive one byte
    // reg
    input                           spi_en,
    input                           spi_start_pulse,
    input                           tx_rx_seq,
    input       [19:0]              tx_len,
    input       [19:0]              rx_len,
    input       [3 :0]              clk_div,
    input                           cpha,
    input                           cpol,
    input                           rx_adj_en,
    input       [3 :0]              rx_adj_clk,
    input       [2 :0]              ncs_dly,
    // spi pin
    output                          ncs,
    output                          sck,
    output                          mosi,
    input                           miso,
    // status
    output      [7:0]               spi_status
);

// macro
localparam IDLE                 = 3'd0;
localparam NCS_LOW              = 3'd1;
localparam DATA_BYTE            = 3'd2;
localparam TX_RX_DELAY          = 3'd2;
localparam WAIT_BUF             = 3'd3;
localparam NCS_HIGH             = 3'd4;
// const
localparam SPI_TX               = 3'd0;
localparam SPI_RX               = 3'd1;
localparam SPI_TRANS            = 3'd2;
// signals
reg [2:0] st_curr, st_next; reg [1:0] trans_state; reg [2:0] bit_cnt; reg [19:0] byte_cnt; reg [3:0] clk_cnt;
wire [2:0] bit_cnt_max; wire [19:0] byte_cnt_max;
wire bit_cnt_end, bit_end, byte_cnt_end, clk_cnt_end;
wire buf_valid, ncs_dly_end, rx_data_en, tx_data_en, tx_edge, rx_edge;
reg sck_raw; reg [7:0] tx_shift; reg [6:0] rx_shift;

//---------------------------------------------------------------------------
// Assignment
//---------------------------------------------------------------------------
// en & start
assign tx_data_en                   = tx_len != 0;
assign rx_data_en                   = rx_len != 0;
assign spi_start                    = spi_start_pulse & (tx_data_en | rx_data_en);
// clk
assign clk_cnt_end                  = clk_cnt == clk_div;
assign tx_edge                      = (cpol ? ( sck_raw) : (~sck_raw)) & clk_cnt_end;
assign rx_edge                      = rx_adj_en ? 
                                        ((cpol ? ( sck_raw) : (~sck_raw)) & (clk_cnt == rx_adj_clk)) :
                                        ((cpol ? (~sck_raw) : ( sck_raw)) & clk_cnt_end);
assign buf_valid                    = trans_state == SPI_TX ? tx_buf_vld :          // tx only
                                      trans_state == SPI_RX ? rx_buf_vld :          // rx only
                                      (tx_buf_vld & rx_buf_vld);                    // tx & rx
// bit cnt
assign bit_cnt_max                  = (st_curr == NCS_LOW || st_curr == NCS_HIGH) ? ncs_dly : 3'h7;
assign bit_cnt_end                  = (bit_cnt == bit_cnt_max);
assign bit_end                      = tx_edge & bit_cnt_end;
assign ncs_dly_end                  = bit_cnt_end;
// byte cnt
assign byte_cnt_max                 = trans_state == SPI_TX ? tx_len :
                                      trans_state == SPI_RX ? rx_len : tx_len; // default, tx_len ???
assign byte_cnt_end                 = (byte_cnt == byte_cnt_max);
// buf
assign tx_buf_req                   = (st_curr == DATA_BYTE) && (bit_cnt == 0) && tx_edge;
assign rx_buf_req                   = (st_curr == DATA_BYTE) && bit_cnt_end && rx_edge;
assign rx_buf_byte                  = {rx_shift[6:0], miso};
//---------------------------------------------------------------------------
// Syn
//---------------------------------------------------------------------------
// clk_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        clk_cnt <= 0;
    else if (st_curr == IDLE && spi_start)
        clk_cnt <= 0;
    else if (st_curr != DATA_BYTE && st_next == DATA_BYTE)
        clk_cnt <= 0;
    //else if (st_curr == DATA_BYTE && st_next == DATA_BYTE) begin
    else if (st_curr == DATA_BYTE) begin
        if (clk_cnt_end)
            clk_cnt <= 0;
        else
            clk_cnt <= clk_cnt + 1;
    end
// sck_raw
always @(posedge clk or negedge rstn)
    if (~rstn)
        sck_raw <= 0;
    else if (st_curr == IDLE)
        sck_raw <= cpol;
    else if (st_curr != DATA_BYTE && st_next == DATA_BYTE)
        sck_raw <= ~cpol;
    else if (st_curr == DATA_BYTE && st_next == DATA_BYTE && clk_cnt_end)
        sck_raw <= ~ sck_raw;
// sck_shift
always @(posedge clk or negedge rstn)
    if (~rstn)
        sck_shift <= 0;
    else if (st_curr == IDLE)
        sck_shift <= cpol;
    else if (clk_cnt_end)
        sck_shift <= sck_raw;
// bit_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        bit_cnt <= 0;
    else if ((st_curr != NCS_LOW && st_next == NCS_LOW) || (st_curr != NCS_HIGH && st_next == NCS_HIGH) || (st_curr != DATA_BYTE && st_next == DATA_BYTE))
        bit_cnt <= 0;
    else if ((st_curr == NCS_LOW) || (st_curr == NCS_HIGH) || (st_curr == DATA_BYTE && tx_edge == 1)) begin
        if (bit_cnt_end)
            bit_cnt <= 0;
        else
            bit_cnt <= bit_cnt + 1;
    end
// byte_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        byte_cnt <= 0;
    else if (~spi_en)
        byte_cnt <= 0;
    else if (st_curr == IDLE && spi_start)
        byte_cnt <= 0;
    else if (st_curr == DATA_BYTE && bit_end) begin
        if (byte_cnt_end)
            byte_cnt <= 0;
        else
            byte_cnt <= byte_cnt + 1;
    end
// tx_shift, shift dir ???
always @(posedge clk)
    if (trans_state == SPI_TX || trans_state == SPI_TRANS) begin
        if (st_curr != DATA_BYTE && st_next == DATA_BYTE) begin
            tx_shift <= tx_buf_byte;
        end
        else if (st_curr == DATA_BYTE && tx_edge) begin
            if (~bit_end)
                tx_shift <= {tx_shift[6:0], 1'b0};
            else if (~byte_end & buf_valid)
                tx_shift <= tx_buf_byte;
        end
    end
    else begin // default ???
        tx_shift <= tx_shift;
    end
// rx_shift, shift dir ???
always @(posedge clk)
    if (st_curr == DATA_BYTE) begin
        rx_shift <= {rx_shift[5:0], miso};
    end
// trans_state
always @(posedge clk or negedge rstn)
    if (~rstn)
        trans_state <= 0;
    else if (st_curr == IDLE && spi_start) begin
        if (tx_rx_seq) begin
            if (tx_data_en)
                trans_state <= SPI_TX;
            else
                trans_state <= SPI_RX;
        end
        else begin
            trans_state <= SPI_TRANS;
        end
    end
    else if (st_curr == DATA_BYTE && trans_state == SPI_TX && byte_cnt_end && bit_end && rx_data_en) begin
        trans_state <= SPI_RX;
    end
//---------------------------------------------------------------------------
// FSM
//---------------------------------------------------------------------------
// fsm_sync
always @(posedge clk or negedge rstn)
    if (~rstn)
        st_curr <= IDLE;
    else if (~spi_en)
        st_curr <= IDLE;
    else
        st_curr <= st_next;
// fsm_comb
always @(*) begin
    // init
    st_next = st_curr;
    // trans
    case (st_curr)
        IDLE: begin
            if (spi_start)
                st_next = NCS_LOW;
        end
        NCS_LOW: begin // ncs low delay & check buffer
            if (ncs_dly_end) begin
                if (buf_valid)
                    st_next = DATA_BYTE;
                else
                    st_next = WAIT_BUF;
            end
        end
        DATA_BYTE: begin // data byte trans & check buffer
            if (bit_end) begin
                if (byte_cnt_end) begin
                    if (trans_state == SPI_TX && rx_data_en != 0)
                        st_next = TX_RX_DELAY;
                    else
                        st_next = NCS_HIGH;
                end
                else if (~buf_valid)
                    st_next = WAIT_BUF;
            end
        end
        TX_RX_DELAY: begin // tx rx delay & check buffer
            if (tx_rx_dly_end) begin
                if (buf_valid)
                    st_next = DATA_BYTE;
                else
                    st_next = WAIT_BUF;
            end
        end
        WAIT_BUF: begin
            if (buf_valid)
                st_next = DATA_BYTE;
        end
        NCS_HIGH: begin
            if (ncs_dly_end)
                st_next = IDLE;
        end
        default: begin
            st_next = IDLE;
        end
    endcase
end
//---------------------------------------------------------------------------
// Output
//---------------------------------------------------------------------------
// ncs
always @(posedge clk or negedge rstn)
    if (~rstn)
        ncs <= 1;
    else if (st_curr == IDLE && spi_start)
        ncs <= 0;
    else if (st_curr == NCS_HIGH && ncs_dly_end)
        ncs <= 1;
// output
assign sck                      = cpha ? sck_shift : sck_raw;
assign mosi                     = tx_shift[7];
assign spi_status               = { 4'h0,                   // 7:4
                                    1'b0,                   // 3
                                    st_curr[2:0]};          // 2:0

endmodule

