`timescale 1ns/1ns

module ovsf_gen_tb;
    parameter integer                       SF_WIDTH = 8;

    localparam integer                      OVSF_LEN = 2**SF_WIDTH;
    localparam integer                      TDATA_WIDTH = 8;
    localparam integer                      TUSER_WIDTH = 8;


    // AXIS_S interface
    interface axis_s_intf(input logic aclk, input logic aresetn);
        // signals
        logic                       tvalid;
        logic [TDATA_WIDTH-1:0]     tdata;

        // interface methods
        task send_data(
            input [TDATA_WIDTH-1:0] data_tdata
        );
            // local declarations
            int rnd_delay;

            // sending data
            begin
                tvalid = 1;
                tdata = data_tdata;
                @(posedge aclk);
                tvalid = 0;
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

        // interface methods
        task wait_data(
            output [TDATA_WIDTH-1:0] data_tdata,
            output [TUSER_WIDTH-1:0] data_tuser,
            output                   data_tlast
        );
            // task variables
            int rnd_delay;

            // task logic
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

    endinterface

    // Data packet
    class packet_c;
        // class fields
        int                     m_len;
        logic [TDATA_WIDTH-1:0] m_data[];
        logic [TUSER_WIDTH-1:0] m_user[];

        // class methods
        function new(int pkt_len, logic [TUSER_WIDTH-1:0] tuser);
            m_len = pkt_len;
            m_data = new[pkt_len];
            m_user = tuser;
            for (int d = 0; d < pkt_len; d++) begin
                m_data[d] = $urandom_range(2**TDATA_WIDTH-1, 0);
            end
        endfunction
    endclass

    // Monitor
    class data_monitor_c;
        // class fields
        virtual axis_m_intf m_axis_int;
        int                 m_init_delay;
        packet_c            m_pkt = null;

        // class methods
        function new(virtual axis_m_intf intf, int seed);
            // function variables
            int rnd_val;

            // function logic
            m_axis_int = intf;

            rnd_val = $urandom(seed);
            m_init_delay = $urandom_range(10, 0);

            m_axis_int.tready = 0;
        endfunction

        task wait_after_reset();
            wait (m_axis_int.aresetn == 1);
            repeat(m_init_delay) @(posedge m_axis_int.aclk);
        endtask

        task wait_pkt();
            // task variables
            logic [TDATA_WIDTH-1:0] pkt_data[$] = {};
            logic [TUSER_WIDTH-1:0] pkt_user[$] = {};
            logic                   pkt_last[$] = {};
            logic [TDATA_WIDTH-1:0] tmp_data;
            logic [TUSER_WIDTH-1:0] tmp_user;
            logic                   tmp_last;

            // task logic
            while (1) begin
                m_axis_int.wait_data(tmp_data, tmp_user, tmp_last);
                pkt_data.push_back(tmp_data);
                pkt_user.push_back(tmp_user);
                pkt_last.push_back(tmp_last);

                if (tmp_last == 1) begin
                    break;
                end
            end

            m_pkt = new(pkt_data.size(), pkt_user[0]);
            foreach (pkt_data[d]) begin
                m_pkt.m_data[d] = pkt_data[d];
                m_pkt.m_user[d] = pkt_user[d];
            end
        endtask
    endclass

    class scoreboard_c;
        // class fields
        int m_ovsf_num = 0;
        int m_pkt_cnt = 0;
        int m_err_cnt = 0;

        // class methods
        task check_pkt(ref packet_c hw_pkt);
            // task variables
            logic [OVSF_LEN-1:0] expected_num;

            // task logic
            expected_num = get_ovsf_code(m_ovsf_num);

            if (hw_pkt.m_len != OVSF_LEN) begin
                $error("Invalid packet length: %0d", hw_pkt.m_len);
                m_err_cnt++;
            end

            foreach(hw_pkt.m_data[d]) begin
                if (hw_pkt.m_data[d][0] != expected_num[d]) begin
                    $error("Invalid value. Expected: %h, received: %h, word: %0d, full_vector: %b, m_ovsf_num: %0d",
                        hw_pkt.m_data[d][0], expected_num[d], d, expected_num, m_ovsf_num);
                    m_err_cnt++;
                end
            end

            if (m_ovsf_num == OVSF_LEN-1 && m_pkt_cnt == 9) begin
                $display("Testbench completed. Errors: %0d", m_err_cnt);
                $finish();
            end

            if (m_pkt_cnt == 9) begin
                m_ovsf_num++;
                m_pkt_cnt = 0;
            end else begin
                m_pkt_cnt++;
            end
        endtask

        function logic[OVSF_LEN-1:0] get_ovsf_code(input int ovsf_num);
            // task variables
            logic [OVSF_LEN-1:0] vector = 0;
            logic [OVSF_LEN-1:0] tmp;
            logic [OVSF_LEN-1:0] result;
            logic [0:SF_WIDTH-1] code;

            int msb = 0;

            // task logic
            code = ovsf_num;
            vector[msb] = 1'b0;

            for (int i = 0; i < SF_WIDTH; i++) begin
                msb = (2 ** i) - 1;
                tmp = '{default:'0};

                for (int d = 0; d <= msb; d++) begin
                    if (code[i] == 1) begin
                        tmp[d] = ~vector[d];
                    end else begin
                        tmp[d] = vector[d];
                    end
                end

                for (int d = msb+1, s = 0; d < (msb+1)*2; d++, s++) begin
                    vector[d] = tmp[s];
                end
            end

            foreach (vector[i]) begin
                result[i] = vector[i];
            end

            return result;

        endfunction
    endclass

    // local signals
    logic                                   clk;
    logic                                   resetn;

    logic                                   s_axis_config_tvalid;
    logic [7:0]                             s_axis_config_tdata;
    logic                                   m_axis_tvalid;
    logic                                   m_axis_tready;
    logic                                   m_axis_tlast;
    logic [7:0]                             m_axis_tdata;
    logic [7:0]                             m_axis_tuser;

    // interfaces
    axis_s_intf                             s_axis_int(clk, resetn);
    axis_m_intf                             m_axis_int(clk, resetn);

    scoreboard_c                            scoreboard = new();
    data_monitor_c                          data_monitor = new (m_axis_int, 0);


    // dut
    ovsf_gen #(
        .SF_WIDTH                           (SF_WIDTH)
    ) ovsf_gen_inst (
        .clk                                (clk),
        .resetn                             (resetn),
        .s_axis_config_tvalid               (s_axis_config_tvalid),
        .s_axis_config_tdata                (s_axis_config_tdata),
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


    // Sending data
    assign s_axis_config_tvalid = s_axis_int.tvalid;
    assign s_axis_config_tdata = s_axis_int.tdata;

    int pkt_cnt = 0;
    initial begin
        // process variables
        automatic int sf_code = 0;
        // process logic
        s_axis_int.tvalid = 0;

        // wait reset
        wait (resetn == 1);
        @(posedge clk);

        s_axis_int.send_data(sf_code);
        sf_code++;

        // configuring each 10 packets new config
        for (int i = 0; i < OVSF_LEN; i++) begin
            pkt_cnt = 0;
            // wait 9 packets and set config on the 10th
            for (int p = 0; p < 9; p++) begin
                while (1) begin
                    @(posedge clk);
                    if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
                        break;
                    end
                end
                pkt_cnt++;
            end

            s_axis_int.send_data(sf_code);
            sf_code++;

            // wait 10th packet
            while (1) begin
                @(posedge clk);
                if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
                    break;
                end
            end
        end
    end

    // Receiving data
    assign m_axis_int.tvalid = m_axis_tvalid;
    assign m_axis_tready = m_axis_int.tready;
    assign m_axis_int.tlast = m_axis_tlast;
    assign m_axis_int.tdata = m_axis_tdata;
    assign m_axis_int.tuser = m_axis_tuser;

    initial begin
        data_monitor.wait_after_reset();

        forever begin
            data_monitor.wait_pkt();
            scoreboard.check_pkt(data_monitor.pkt);
        end

    end

endmodule
