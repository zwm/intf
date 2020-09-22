
module tb_top();
// macro
`include "tb_define.v"
// port
reg                             rstn;
reg                             clk;
reg                             tx_buf_vld; // one data byte valid to be transmitted
reg         [7:0]               tx_buf_byte;
reg                             rx_buf_vld; // rx buffer is empty to receive one byte
reg                             spi_en;
reg                             spi_start_pulse;
reg                             tx_rx_seq;
reg         [19:0]              tx_len;
reg         [19:0]              rx_len;
reg         [3 :0]              clk_div;
reg                             cpha;
reg                             cpol;
reg                             rx_adj_en;
reg         [3 :0]              rx_adj_clk;
reg         [2 :0]              ncs_dly;
reg         [3 :0]              trx_dly;
wire                            miso;
wire                            tx_buf_req;
wire                            rx_buf_req;
wire        [7:0]               rx_buf_byte;
wire                            ncs;
wire                            sck;
wire                            mosi;
wire        [7:0]               spi_status;
// global
integer err_cnt, cmp_cnt, case_num;
reg [48*8-1:0] log_dir;
reg sim_end;

// loopback
assign miso = mosi;

// main
initial begin
    // init
    sys_init;
    #1_000;

    // main
    main_loop;

    // disp
    #1_000;
    disp_sum;

    #1_000;
    $finish;
end

// inst
spi_master u_spi_master (
    .rstn                       ( rstn                          ),
    .clk                        ( clk                           ),
    .tx_buf_vld                 ( tx_buf_vld                    ),
    .tx_buf_byte                ( tx_buf_byte                   ),
    .tx_buf_req                 ( tx_buf_req                    ),
    .rx_buf_req                 ( rx_buf_req                    ),
    .rx_buf_byte                ( rx_buf_byte                   ),
    .rx_buf_vld                 ( rx_buf_vld                    ),
    .spi_en                     ( spi_en                        ),
    .spi_start_pulse            ( spi_start_pulse               ),
    .tx_rx_seq                  ( tx_rx_seq                     ),
    .tx_len                     ( tx_len                        ),
    .rx_len                     ( rx_len                        ),
    .clk_div                    ( clk_div                       ),
    .cpha                       ( cpha                          ),
    .cpol                       ( cpol                          ),
    .rx_adj_en                  ( rx_adj_en                     ),
    .rx_adj_clk                 ( rx_adj_clk                    ),
    .ncs_dly                    ( ncs_dly                       ),
    .trx_dly                    ( trx_dly                       ),
    .ncs                        ( ncs                           ),
    .sck                        ( sck                           ),
    .mosi                       ( mosi                          ),
    .miso                       ( miso                          ),
    .spi_status                 ( spi_status                    )
);

// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
    `ifdef DUMP_ARRAY
        $fsdbDumpMDA();
    `endif
end
`endif

// clk gen
initial begin
    clk = 0;
    rstn = 1;
    fork
        // rstn
        begin
            #50;
            rstn = 0;
            #100;
            rstn = 1;
        end
        // clk
        begin
            #100;
            forever #1 clk = ~clk;
        end
    join
end

// sys_init
task sys_init;
    begin
        case_num                = 0;
        cmp_cnt                 = 0;
        err_cnt                 = 0;
        sim_end                 = 0;
        tx_buf_vld              = 0;
        tx_buf_byte             = 0;
        rx_buf_vld              = 0;
        spi_en                  = 0;
        spi_start_pulse         = 0;
        tx_rx_seq               = 0;
        tx_len                  = 0;
        rx_len                  = 0;
        clk_div                 = 0;
        cpha                    = 0;
        cpol                    = 0;
        rx_adj_en               = 0;
        rx_adj_clk              = 0;
        ncs_dly                 = 0;
        trx_dly                 = 0;
    end
endtask

task main_loop;
    integer fp, ret, i, j, k, tmp;
    begin
        case1(0, 0, 4'h0, 0, 1, 0);
        case1(0, 1, 4'h0, 0, 1, 0);
        case1(1, 0, 4'h0, 0, 1, 0);
        case1(1, 1, 4'h0, 0, 1, 0);
        case1(0, 0, 4'h3, 0, 1, 0);
        case1(0, 1, 4'h3, 0, 1, 0);
        case1(1, 0, 4'h3, 0, 1, 0);
        case1(1, 1, 4'h3, 0, 1, 0);

        case1(0, 0, 4'h0, 0, 19, 0);
        case1(0, 1, 4'h0, 0, 19, 0);
        case1(1, 0, 4'h0, 0, 19, 0);
        case1(1, 1, 4'h0, 0, 19, 0);

        case1(1, 0, 4'h0, 1,  1, 1);
        case1(1, 0, 4'h0, 1, 19, 0);
        case1(1, 0, 4'h0, 1,  0, 19);

    end
endtask

task case1;
    input cpha_i;
    input cpol_i;
    input [3:0] clk_div_i;
    input tx_rx_seq_i;
    input [19:0] tx_len_i;
    input [19:0] rx_len_i;
    integer i, j, k, l, m, n, t, r;
    begin
        // delay
        fork
            // driv
            begin
                sim_end                 = 0;
                spi_en                  = 1;
                cpha                    = cpha_i;
                cpol                    = cpol_i;
                clk_div                 = clk_div_i;
                tx_len                  = tx_len_i;
                rx_len                  = rx_len_i;
                tx_rx_seq               = tx_rx_seq_i;
                #100;
                tx_buf_byte             = 0;
                tx_buf_vld              = 0;
                rx_buf_vld              = 0;
                rx_adj_en               = 0;
                rx_adj_clk              = 0;
                ncs_dly                 = 0;
                trx_dly                 = 0;
                trig;
            end
            // tx buf
            begin
                begin: LOOP_TX
                    while(1) begin
                        @(posedge clk);
                        if (spi_start_pulse) begin
                            tx_buf_byte             = 8'ha5;
                            tx_buf_vld              = 1;
                        end
                        if (tx_buf_req) begin
                            tx_buf_vld              = 0;
                            t = {$random}%30;
                            for(i = 0; i < t; i = i + 1) begin
                                @(posedge clk);
                            end
                            tx_buf_vld              = 1;
                        end
                        if (sim_end) begin
                            disable LOOP_TX;
                        end
                    end
                end
            end
            // rx buf
            begin
                begin: LOOP_RX
                    while(1) begin
                        @(posedge clk);
                        if (spi_start_pulse) begin
                            rx_buf_vld              = 1;
                        end
                        if (rx_buf_req) begin
                            rx_buf_vld              = 0;
                            r = {$random}%30;
                            for(j = 0; j < r; j = j + 1) begin
                                @(posedge clk);
                            end
                            rx_buf_vld              = 1;
                        end
                        if (sim_end) begin
                            disable LOOP_RX;
                        end
                    end
                end
            end
            // finish
            begin
                @(posedge ncs);
                sim_end = 1;
                #100;
            end
        join
    end
endtask

task case2;
    input cpha_i;
    input cpol_i;
    input [3:0] clk_div_i;
    begin
        // delay
        fork
            // driv
            begin
                spi_en                  = 1;
                cpha                    = cpha_i;
                cpol                    = cpol_i;
                clk_div                 = clk_div_i;
                #100;
                tx_rx_seq               = 0;
                tx_len                  = 1;
                rx_len                  = 0;
                tx_buf_byte             = 0;
                tx_buf_vld              = 0;
                rx_buf_vld              = 0;
                rx_adj_en               = 0;
                rx_adj_clk              = 0;
                ncs_dly                 = 0;
                trx_dly                 = 0;
                trig;
            end
            // tx buf
            begin
                @(posedge spi_start_pulse);
                //repeat(10) @(posedge clk);
                tx_buf_byte             = 8'ha5;
                tx_buf_vld              = 1;
                @(posedge tx_buf_req);
                @(posedge clk);
                tx_buf_vld              = 0;
            end
            // rx buf
            begin
                @(posedge spi_start_pulse);
                //repeat(20) @(posedge clk);
                rx_buf_vld              = 1;
                @(posedge rx_buf_req);
                @(posedge clk);
                rx_buf_vld              = 0;
            end
            // finish
            begin
                @(posedge ncs);
                #100;
            end
        join
    end
endtask

task trig;
    begin
        @(posedge clk);
        spi_start_pulse = 1;
        repeat(1) @(posedge clk);
        spi_start_pulse = 0;
    end
endtask


task disp_sum;
    begin
        $display("---------------------------------------------------");
        $display("---------------------------------------------------");
        $display("---------------------------------------------------");
        $display("  cmp_cnt: %d", cmp_cnt);
        if (err_cnt == 0) begin
            $display("      PASS.");
        end
        else begin
            $display("  err_cnt: %d", err_cnt);
            $display("      FAIL!");
        end
        $display("---------------------------------------------------");
    end
endtask

endmodule

