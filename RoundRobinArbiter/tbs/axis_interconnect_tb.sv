`timescale 1ns/1ns

module axis_interconnect_tb;
    // parameters
    parameter int                           PORTS_QTY = 4;
    parameter int                           TDATA_WIDTH = 32;
    parameter int                           TUSER_WIDTH = 16;
    parameter int                           PKT_QTY = 100;

    // AXIS_S interface
    interface axis_s_intf(input logic aclk, input logic aresetn);
        // signals
        logic                       tvalid;
        logic                       tready;
        logic                       tlast;
        logic [TDATA_WIDTH-1:0]     tdata;
        logic [TUSER_WIDTH-1:0]     tuser;

        task send_data(
            input [TDATA_WIDTH-1:0] data_tdata,
            input [TUSER_WIDTH-1:0] data_tuser,
            input                   data_tlast
        );
            // local declarations
            int rnd_delay;

            // sending data
            begin
                tvalid = 1;
                tdata = data_tdata;
                tuser = data_tuser;
                tlast = data_tlast;
                @(posedge aclk);
            end
            // wait handshake
            while (tready == 0) begin
                @(posedge aclk);
            end

            // delay
            rnd_delay = $urandom_range(2, 0);
            begin
                tvalid = 0;
                if (rnd_delay > 0) begin
                    repeat (rnd_delay) @(posedge aclk);
                end
            end
        endtask

    endinterface

    // AXIS_M interface
    interface axis_m_intf(input logic aclk, input logic aresetn);
        // signals
        logic                       tvalid;
        logic                       tready;
        logic                       tlast;
        logic [TDATA_WIDTH-1:0]     tdata;
        logic [TUSER_WIDTH-1:0]     tuser;
        int                         cnt = 0;

        task wait_data(
            output [TDATA_WIDTH-1:0] data_tdata,
            output [TUSER_WIDTH-1:0] data_tuser,
            output                   data_tlast
        );
            // local declarations
            int rnd_delay;

            // set ready
            begin
                tready = 1;
                @(posedge aclk);
                cnt++;
            end
            // wait tvalid
            while (tvalid == 0) begin
                @(posedge aclk);
            end
            data_tdata = tdata;
            data_tuser = tuser;
            data_tlast = tlast;
            rnd_delay = $urandom_range(2, 0);
            begin
                tready = 0;
                if (rnd_delay > 0) begin
                    repeat (rnd_delay) @(posedge aclk);
                end
            end
        endtask

        task set_busy();
            // set ready
            tready = 0;
            @(posedge aclk);
        endtask

    endinterface

    // Data packet
    class packet_c;
        int                     len;
        logic [TDATA_WIDTH-1:0] data[];
        logic [TUSER_WIDTH-1:0] user;

        function new(int pkt_len, logic [TUSER_WIDTH-1:0] tuser);
            len = pkt_len;
            data = new[len];
            user = tuser;
            for (int d = 0; d < len; d++) begin
                data[d] = $urandom_range(2**TDATA_WIDTH-1, 0);
            end
        endfunction
    endclass

    // Driver
    class data_driver_c;
        virtual axis_s_intf s_axis_int;
        int                 init_delay;
        int                 rnd_val;

        function new(virtual axis_s_intf intf, int seed);
            s_axis_int = intf;

            rnd_val = $urandom(seed);
            init_delay = $urandom_range(10, 0);

            s_axis_int.tvalid = 0;
            s_axis_int.tlast = 0;
        endfunction

        task wait_after_reset();
            wait (s_axis_int.aresetn == 1);
            repeat(init_delay) @(posedge s_axis_int.aclk);
        endtask

        task send_rnd_pkt(logic [TUSER_WIDTH-1:0] tuser);
            int pkt_len;

            pkt_len = $urandom_range(1000, 1);

            for (int d = 0; d < pkt_len; d++) begin
                s_axis_int.send_data(d, tuser, (d == pkt_len - 1));
            end
        endtask

        task send_pkt(ref packet_c pkt);
            for (int d = 0; d < pkt.len; d++) begin
                s_axis_int.send_data(pkt.data[d], pkt.user, (d == pkt.len - 1));
            end
        endtask

    endclass

    // Monitor
    class data_monitor_c;
        virtual axis_m_intf m_axis_int;
        int                 init_delay;
        int                 rnd_val;
        packet_c            pkt = null;

        function new(virtual axis_m_intf intf, int seed);
            m_axis_int = intf;

            rnd_val = $urandom(seed);
            init_delay = $urandom_range(10, 0);

            m_axis_int.tready = 0;
        endfunction

        task wait_after_reset();
            wait (m_axis_int.aresetn == 1);
            repeat(init_delay) @(posedge m_axis_int.aclk);
        endtask

        task wait_pkt();
            logic [TDATA_WIDTH-1:0] pkt_data[$] = {};
            logic [TUSER_WIDTH-1:0] pkt_user[$] = {};
            logic                   pkt_last[$] = {};
            logic [TDATA_WIDTH-1:0] tmp_data;
            logic [TUSER_WIDTH-1:0] tmp_user;
            logic                   tmp_last;

            while (1) begin
                m_axis_int.wait_data(tmp_data, tmp_user, tmp_last);
                pkt_data.push_back(tmp_data);
                pkt_user.push_back(tmp_user);
                pkt_last.push_back(tmp_last);

                if (tmp_last == 1) begin
                    break;
                end
            end

            pkt = new(pkt_data.size(), pkt_user[0]);
            foreach (pkt_data[d]) begin
                pkt.data[d] = pkt_data[d];
            end
            pkt.user = pkt_user[0];
        endtask
    endclass

    // Scoreboard
    class data_scoreboard_c;
        int pkt_cnt_ttl = 0;
        int pkt_cnt_ch[PORTS_QTY] = '{default:'0};
        int errcnt = 0;

        task reg_and_validate(ref packet_c pkt);
            // task variables
            int ch_idx = pkt.user;
            int pkt_idx = pkt_cnt_ch[pkt.user];

            // task logic
            if (din_packets[ch_idx][pkt_idx].len != pkt.len) begin
                $error("Size mismatch ch=%0d, pkt=%0d. Actual: %d, Expected: %d", ch_idx, pkt_idx, pkt.len, din_packets[ch_idx][pkt_idx].len);
                errcnt++;
            end

            foreach(pkt.data[d]) begin
                if (din_packets[ch_idx][pkt_idx].data[d] != pkt.data[d]) begin
                    $error("Data mismatch ch=%0d, pkt=%0d. Actual: %h, Expected: %h", ch_idx, pkt_idx, pkt.data[d], din_packets[ch_idx][pkt_idx].data[d]);
                    errcnt++;
                    if (errcnt > 20) begin
                        $stop();
                    end
                end
            end

            if (errcnt != 0) begin
                $stop();
            end

            if (pkt_cnt_ttl == PKT_QTY * PORTS_QTY - 1) begin
                $display("Testbench completed");
                $finish();
            end

            pkt_cnt_ttl++;
            pkt_cnt_ch[pkt.user]++;
        endtask
    endclass

    // local signals
    logic                                   clk;
    logic                                   resetn;

    logic [PORTS_QTY-1:0]                   s_axis_tvalid;
    logic [PORTS_QTY-1:0]                   s_axis_tready;
    logic [PORTS_QTY-1:0]                   s_axis_tlast;
    logic [PORTS_QTY-1:0][TDATA_WIDTH-1:0]  s_axis_tdata;
    logic [PORTS_QTY-1:0][TUSER_WIDTH-1:0]  s_axis_tuser;
    logic                                   m_axis_tvalid;
    logic                                   m_axis_tready;
    logic                                   m_axis_tlast;
    logic [TDATA_WIDTH-1:0]                 m_axis_tdata;
    logic [TUSER_WIDTH-1:0]                 m_axis_tuser;

    packet_c                                din_packets[][];
    data_scoreboard_c                       scoreboard = new();

    // Interfaces
    axis_m_intf                             m_axis_int(clk, resetn);


    // dut
    axis_round_robin_interconnect #(
        .PORTS_QTY                          (PORTS_QTY),
        .TDATA_WIDTH                        (TDATA_WIDTH),
        .TUSER_WIDTH                        (TUSER_WIDTH)
    ) axis_round_robin_interconnect_inst (
        .clk                                (clk),
        .resetn                             (resetn),
        .s_axis_data_tvalid                 (s_axis_tvalid),
        .s_axis_data_tready                 (s_axis_tready),
        .s_axis_data_tlast                  (s_axis_tlast),
        .s_axis_data_tdata                  (s_axis_tdata),
        .s_axis_data_tuser                  (s_axis_tuser),
        .m_axis_data_tvalid                 (m_axis_tvalid),
        .m_axis_data_tready                 (m_axis_tready),
        .m_axis_data_tlast                  (m_axis_tlast),
        .m_axis_data_tdata                  (m_axis_tdata),
        .m_axis_data_tuser                  (m_axis_tuser)
    );


    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    initial begin
        resetn = 0;
        repeat (40) @(posedge clk);
        resetn = 1;
    end

    // Preparing data
    initial begin
        din_packets = new[PORTS_QTY];
        foreach(din_packets[ch]) begin
            din_packets[ch] = new[PKT_QTY];

            foreach (din_packets[ch][p]) begin
                din_packets[ch][p] = new($urandom_range(1000, 1), ch);
            end
        end
    end

    // Sending data
    generate
        for (genvar i = 0; i < PORTS_QTY; i++) begin: data_gen
            axis_s_intf      s_axis_int(clk, resetn);

            assign s_axis_tvalid[i] = s_axis_int.tvalid;
            assign s_axis_int.tready = s_axis_tready[i];
            assign s_axis_tlast[i] = s_axis_int.tlast;
            assign s_axis_tdata[i] = s_axis_int.tdata;
            assign s_axis_tuser[i] = s_axis_int.tuser;

            initial begin
                // local variables
                automatic data_driver_c   data_driver = null;

                // behaviour
                data_driver = new(s_axis_int, 100 + i);

                data_driver.wait_after_reset();

                for (int p = 0; p < PKT_QTY; p++) begin
                    data_driver.send_pkt(din_packets[i][p]);

                    if (p == 10 && i == 1) begin
                        repeat (50000) @(posedge clk);
                    end
                end
            end

        end
    endgenerate

    // Receiving data
    assign m_axis_int.tvalid = m_axis_tvalid;
    assign m_axis_tready = m_axis_int.tready;
    assign m_axis_int.tlast = m_axis_tlast;
    assign m_axis_int.tdata = m_axis_tdata;
    assign m_axis_int.tuser = m_axis_tuser;

    initial begin
        // local variables
        automatic data_monitor_c  data_monitor = null;

        // behaviour
        data_monitor = new (m_axis_int, 0);
        data_monitor.wait_after_reset();

        for (int p = 0; p < PKT_QTY*PORTS_QTY; p++) begin
            data_monitor.wait_pkt();
            scoreboard.reg_and_validate(data_monitor.pkt);
        end

    end

endmodule
