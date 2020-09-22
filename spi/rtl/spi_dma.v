
module spi_dma (
    // sys
    input                           rstn,
    input                           clk,
    // buf
    input                           tx_buf_rdy,
    output                          tx_byte_vld,
    output      [7:0]               tx_byte,
    input                           rx_buf_rdy,
    output      [7:0]               rx_byte_req,
    input       [7:0]               rx_byte,
    // reg
    input                           dma_en,
    input                           dma_start,
    input                           tx_fix_addr,
    input                           rx_fix_addr,
    input       [19:0]              tx_saddr,
    input       [19:0]              rx_saddr,
    input       [19:0]              tx_len,
    input       [19:0]              rx_len,
    // ram
    output reg                      ram_rd,
    output                          ram_wr,
    output      [3:0]               ram_rlen4,
    output      [3:0]               ram_wlen4,
    output      [19:0]              ram_addr,
    output      [31:0]              ram_wdata,
    input       [31:0]              ram_rdata,
    input                           ram_bus_ready,
    input                           ram_rdata_ready,
    // status
    output                          dma_done_pulse,
    output      [7:0]               dma_status
);

// macro
localparam IDLE                     = 3'd0;
localparam POLL_TX_BUF              = 3'd1;
localparam READ_MEM                 = 3'd2;
localparam FILL_TX_BUF              = 3'd3;
localparam POLL_RX_BUF              = 3'd4;
localparam WRITE_MEM                = 3'd5;
// var
reg [19:0] tx_cnt, rx_cnt, ram_waddr, ram_raddr; wire tx_end, rx_end;
reg [31:0] rdata_buf; reg [2:0] rdata_cnt; wire rdata_vld;

//---------------------------------------------------------------------------
// Assignment
//---------------------------------------------------------------------------
// end
assign tx_end               = tx_cnt == tx_len;
assign rx_end               = rx_cnt == rx_len;
assign rdata_vld            = rdata_cnt != 0;


//---------------------------------------------------------------------------
// Sync
//---------------------------------------------------------------------------
// ram_raddr
always @(posedge clk or negedge rstn)
    if (~rstn)
        ram_raddr <= 0;
    else if (~dma_en)
        ram_raddr <= tx_saddr;
    else if (st_curr == IDLE && dma_start)
        ram_raddr <= tx_saddr;
    else if (st_curr == READ_MEM && ram_rdata_ready)
        ram_raddr <= tx_fix_addr ? ram_raddr : ram_raddr + 4;
// tx_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        tx_cnt <= 0;
    else if (~dma_en)
        tx_cnt <= 0;
    else if (st_curr == IDLE && dma_start)
        tx_cnt <= 0;
    else if (st_curr == POLL_TX_BUF && st_next != POLL_TX_BUF)
        tx_cnt <= tx_cnt + 1;
// rdata_buf
always @(posedge clk)
    if (st_curr == READ_MEM && ram_rdata_ready) begin
        rdata_buf <= ram_rdata;
    end
// rdata_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        rdata_cnt <= 0;
    else if (~dma_en)
        rdata_cnt <= 0;
    else if (st_curr == READ_MEM && ram_rdata_ready)
        rdata_cnt <= 4;
    else if (st_curr == FILL_TX_BUF)
        rdata_cnt <= rdata_cnt - 1;
// ram_waddr
always @(posedge clk or negedge rstn)
    if (~rstn)
        ram_waddr <= 0;
    else if (~dma_en)
        ram_waddr <= rx_saddr;
    else if (st_curr == IDLE && dma_start)
        ram_waddr <= rx_saddr;
    else if (st_curr == WRITE_MEM && ram_bus_ready)
        ram_waddr <= rx_fix_addr ? ram_waddr : ram_waddr + 1;
// rx_cnt
always @(posedge clk or negedge rstn)
    if (~rstn)
        rx_cnt <= 0;
    else if (~dma_en)
        rx_cnt <= 0;
    else if (st_curr == IDLE && dma_start)
        rx_cnt <= 0;
    else if (st_curr == POLL_RX_BUF && st_next != POLL_RX_BUF)
        rx_cnt <= rx_cnt + 1;
//---------------------------------------------------------------------------
// FSM
//---------------------------------------------------------------------------
// fsm_sync
always @(posedge clk or negedge rstn)
    if (~rstn)
        st_curr <= IDLE;
    else if (~dma_en)
        st_curr <= IDLE;
    else
        st_curr <= st_next;
// fsm_comb
always @(*) begin
    st_next = st_curr;
    case(st_curr)
        IDLE: begin
            if (dma_start) begin
                if (~tx_end)
                    st_next = POLL_TX_BUF;
                else if (~rx_end)
                    st_next = POLL_RX_BUF;
            end
        end
        POLL_TX_BUF: begin
            if (tx_buf_rdy) begin
                if (rdata_vld)
                    st_next = FILL_TX_BUF;
                else
                    st_next = READ_MEM;
            end
            else if (~rx_end) begin
                st_next = POLL_RX_BUF;
            end
        end
        READ_MEM: begin
            if (ram_rdata_ready) begin
                st_next = FILL_TX_BUF;
            end
        end
        FILL_TX_BUF: begin
            if (~rx_end)
                st_next = POLL_RX_BUF;
            else if (~tx_end)
                st_next = POLL_TX_BUF;
            else
                st_next = IDLE;
        end
        POLL_RX_BUF: begin
            if (rx_buf_rdy)
                st_next = WRITE_MEM;
            else if (~tx_end)
                st_next = POLL_TX_BUF;
        end
        WRITE_MEM: begin
            if (ram_bus_ready) begin
                if (~tx_end)
                    st_next = POLL_TX_BUF;
                else if (~rx_end)
                    st_next = POLL_RX_BUF;
                else
                    st_next = IDLE;
            end
        end
        default: begin
            st_next = IDLE;
        end
    endcase
end
//---------------------------------------------------------------------------
// Output
//---------------------------------------------------------------------------
// buf
assign rx_byte_req                  = ram_wr & ram_bus_ready;
assign tx_byte_vld                  = st_curr == FILL_TX_BUF;
assign tx_byte                      = rdata_cnt == 2'b00 ? rdata_buf[7:0] : rdata_cnt == 2'b01 ? rdata_buf[15:8] : rdata_cnt == 2'b01 ? rdata_buf[23:16] : rdata_buf[31:24];
// ram_rd
always @(posedge clk or negedge rstn)
    if (~rstn)
        ram_rd <= 0;
    else if (~dma_en)
        ram_rd <= 0;
    else if (st_curr != READ_MEM && st_next == READ_MEM)
        ram_rd <= 1;
    else if (st_curr == READ_MEM && ram_bus_ready)
        ram_rd <= 0;
assign ram_rlen4                    = 4'hf; // always read 4-byte
assign ram_wr                       = st_curr == WRITE_MEM;
assign ram_wlen4                    = ram_waddr[1:0] == 2'b00 ? 4'b0001 : ram_waddr[1:0] == 2'b01 ? 4'b0010 : ram_waddr[1:0] == 2'b10 ? 4'b0100 : 4'b1000;
assign ram_addr                     = ram_wr ? ram_waddr : ram_raddr;
assign ram_wdata                    = rx_byte;
assign dma_done_pulse               = ((st_curr == FILL_TX_BUF) || (st_curr == WRITE_MEM && ram_bus_ready)) && tx_end && rx_end;

endmodule

