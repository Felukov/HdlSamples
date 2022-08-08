//
// 2022, Konstantin Felukov
//

module crossbar #(
    parameter integer                               TADDR_WIDTH = 32,
    parameter integer                               TDATA_WIDTH = 32
)(
    input  logic                                    clk,
    input  logic                                    resetn,
    // master 0
    input  logic                                    master_0_req,
    input  logic [TADDR_WIDTH-1:0]                  master_0_addr,
    input  logic                                    master_0_cmd,
    input  logic [TDATA_WIDTH-1:0]                  master_0_wdata,
    output logic                                    master_0_ack,
    output logic                                    master_0_resp,
    output logic [TDATA_WIDTH-1:0]                  master_0_rdata,
    // master 1
    input  logic                                    master_1_req,
    input  logic [TADDR_WIDTH-1:0]                  master_1_addr,
    input  logic                                    master_1_cmd,
    input  logic [TDATA_WIDTH-1:0]                  master_1_wdata,
    output logic                                    master_1_ack,
    output logic                                    master_1_resp,
    output logic [TDATA_WIDTH-1:0]                  master_1_rdata,
    // master 2
    input  logic                                    master_2_req,
    input  logic [TADDR_WIDTH-1:0]                  master_2_addr,
    input  logic                                    master_2_cmd,
    input  logic [TDATA_WIDTH-1:0]                  master_2_wdata,
    output logic                                    master_2_ack,
    output logic                                    master_2_resp,
    output logic [TDATA_WIDTH-1:0]                  master_2_rdata,
    // master 3
    input  logic                                    master_3_req,
    input  logic [TADDR_WIDTH-1:0]                  master_3_addr,
    input  logic                                    master_3_cmd,
    input  logic [TDATA_WIDTH-1:0]                  master_3_wdata,
    output logic                                    master_3_ack,
    output logic                                    master_3_resp,
    output logic [TDATA_WIDTH-1:0]                  master_3_rdata,
    // slave 0
    output logic                                    slave_0_req,
    output logic [TADDR_WIDTH-1:0]                  slave_0_addr,
    output logic                                    slave_0_cmd,
    output logic [TDATA_WIDTH-1:0]                  slave_0_wdata,
    input  logic                                    slave_0_ack,
    input  logic                                    slave_0_resp,
    input  logic [TDATA_WIDTH-1:0]                  slave_0_rdata,
    // slave 1
    output logic                                    slave_1_req,
    output logic [TADDR_WIDTH-1:0]                  slave_1_addr,
    output logic                                    slave_1_cmd,
    output logic [TDATA_WIDTH-1:0]                  slave_1_wdata,
    input  logic                                    slave_1_ack,
    input  logic                                    slave_1_resp,
    input  logic [TDATA_WIDTH-1:0]                  slave_1_rdata,
    // slave 2
    output logic                                    slave_2_req,
    output logic [TADDR_WIDTH-1:0]                  slave_2_addr,
    output logic                                    slave_2_cmd,
    output logic [TDATA_WIDTH-1:0]                  slave_2_wdata,
    input  logic                                    slave_2_ack,
    input  logic                                    slave_2_resp,
    input  logic [TDATA_WIDTH-1:0]                  slave_2_rdata,
    // slave 3
    output logic                                    slave_3_req,
    output logic [TADDR_WIDTH-1:0]                  slave_3_addr,
    output logic                                    slave_3_cmd,
    output logic [TDATA_WIDTH-1:0]                  slave_3_wdata,
    input  logic                                    slave_3_ack,
    input  logic                                    slave_3_resp,
    input  logic [TDATA_WIDTH-1:0]                  slave_3_rdata
);

    // Constants
    localparam integer                              M_QTY = 4;
    localparam integer                              S_QTY = 4;
    localparam integer                              ADDR_CH_BITS = $clog2(S_QTY);
    localparam integer                              ARB_WIDTH = $clog2(M_QTY);
    localparam integer                              TAG_WIDTH = 3;

    // Local signals
    logic [M_QTY-1:0]                               master_req;
    logic [M_QTY-1:0]                               master_rdy;
    logic [M_QTY-1:0][TADDR_WIDTH-1:0]              master_addr;
    logic [M_QTY-1:0]                               master_cmd;
    logic [M_QTY-1:0][TDATA_WIDTH-1:0]              master_wdata;
    logic [M_QTY-1:0]                               master_ack;
    logic [M_QTY-1:0]                               master_tag_tvalid;
    logic [M_QTY-1:0][TAG_WIDTH-1:0]                master_tag_tdata;
    logic [M_QTY-1:0]                               master_resp;
    logic [M_QTY-1:0][TDATA_WIDTH-1:0]              master_rdata;
    logic [M_QTY-1:0][ADDR_CH_BITS-1:0]             master_s_id;

    logic [S_QTY-1:0]                               slave_req;
    logic [S_QTY-1:0]                               slave_rdy;
    logic [S_QTY-1:0][TADDR_WIDTH-1:0]              slave_addr;
    logic [S_QTY-1:0]                               slave_cmd;
    logic [S_QTY-1:0][TDATA_WIDTH-1:0]              slave_wdata;
    logic [S_QTY-1:0]                               slave_ack;
    logic [S_QTY-1:0]                               slave_resp;
    logic [S_QTY-1:0][TDATA_WIDTH-1:0]              slave_rdata;
    logic [S_QTY-1:0][TAG_WIDTH-1:0]                slave_s_tag;
    logic [S_QTY-1:0][ARB_WIDTH-1:0]                slave_s_m_id;
    logic [S_QTY-1:0][TAG_WIDTH-1:0]                slave_m_tag;
    logic [S_QTY-1:0][ARB_WIDTH-1:0]                slave_m_m_id;
    logic [M_QTY-1:0][S_QTY-1:0]                    s2m_resp;

    logic [S_QTY-1:0][M_QTY-1:0]                    m2a_req;
    logic [S_QTY-1:0][M_QTY-1:0]                    m2a_rdy;
    logic [S_QTY-1:0][M_QTY-1:0][TADDR_WIDTH-1:0]   m2a_addr;
    logic [S_QTY-1:0][M_QTY-1:0]                    m2a_cmd;
    logic [S_QTY-1:0][M_QTY-1:0][TAG_WIDTH-1:0]     m2a_tag;
    logic [S_QTY-1:0][M_QTY-1:0][TDATA_WIDTH-1:0]   m2a_wdata;
    logic [S_QTY-1:0][M_QTY-1:0]                    m2a_ack;
    logic [S_QTY-1:0][M_QTY-1:0]                    m2a_grant;
    logic [S_QTY-1:0][ARB_WIDTH-1:0]                m2a_idx;
    logic [S_QTY-1:0][ARB_WIDTH-1:0]                m2a_base;


    // assigns
    assign slave_0_req = slave_req[0];
    assign slave_0_addr = slave_addr[0];
    assign slave_0_cmd = slave_cmd[0];
    assign slave_0_wdata = slave_wdata[0];
    assign slave_ack[0] = slave_0_ack;
    assign slave_resp[0] = slave_0_resp;
    assign slave_rdata[0] = slave_0_rdata;

    assign slave_1_req = slave_req[1];
    assign slave_1_addr = slave_addr[1];
    assign slave_1_cmd = slave_cmd[1];
    assign slave_1_wdata = slave_wdata[1];
    assign slave_ack[1] = slave_1_ack;
    assign slave_resp[1] = slave_1_resp;
    assign slave_rdata[1] = slave_1_rdata;

    assign slave_2_req = slave_req[2];
    assign slave_2_addr = slave_addr[2];
    assign slave_2_cmd = slave_cmd[2];
    assign slave_2_wdata = slave_wdata[2];
    assign slave_ack[2] = slave_2_ack;
    assign slave_resp[2] = slave_2_resp;
    assign slave_rdata[2] = slave_2_rdata;

    assign slave_3_req = slave_req[3];
    assign slave_3_addr = slave_addr[3];
    assign slave_3_cmd = slave_cmd[3];
    assign slave_3_wdata = slave_wdata[3];
    assign slave_ack[3] = slave_3_ack;
    assign slave_resp[3] = slave_3_resp;
    assign slave_rdata[3] = slave_3_rdata;

    assign master_req[0] = master_0_req;
    assign master_addr[0] = master_0_addr;
    assign master_cmd[0] = master_0_cmd;
    assign master_wdata[0] = master_0_wdata;
    assign master_0_ack = master_ack[0];
    assign master_0_resp = master_resp[0];
    assign master_0_rdata = master_rdata[0];

    assign master_req[1] = master_1_req;
    assign master_addr[1] = master_1_addr;
    assign master_cmd[1] = master_1_cmd;
    assign master_wdata[1] = master_1_wdata;
    assign master_1_ack = master_ack[1];
    assign master_1_resp = master_resp[1];
    assign master_1_rdata = master_rdata[1];

    assign master_req[2] = master_2_req;
    assign master_addr[2] = master_2_addr;
    assign master_cmd[2] = master_2_cmd;
    assign master_wdata[2] = master_2_wdata;
    assign master_2_ack = master_ack[2];
    assign master_2_resp = master_resp[2];
    assign master_2_rdata = master_rdata[2];

    assign master_req[3] = master_3_req;
    assign master_addr[3] = master_3_addr;
    assign master_cmd[3] = master_3_cmd;
    assign master_wdata[3] = master_3_wdata;
    assign master_3_ack = master_ack[3];
    assign master_3_resp = master_resp[3];
    assign master_3_rdata = master_rdata[3];


    generate
        genvar s_id;
        genvar m_id;

        for (s_id = 0; s_id < S_QTY; s_id++) begin : gen_fifo

            // module crossbar_fifo instantiation
            crossbar_fifo #(
                .FIFO_DEPTH         (8),
                .FIFO_WIDTH         (TAG_WIDTH + ARB_WIDTH)
            ) crossbar_fifo_inst (
                .clk                (clk),
                .resetn             (resetn),
                .s_axis_data_tvalid (slave_ack[s_id] & ~slave_cmd[s_id]),
                .s_axis_data_tready (),
                .s_axis_data_tdata  ({slave_s_tag[s_id], slave_s_m_id[s_id]}),
                .m_axis_data_tvalid (),
                .m_axis_data_tready (slave_resp[s_id]),
                .m_axis_data_tdata  ({slave_m_tag[s_id], slave_m_m_id[s_id]})
            );

        end

        for (m_id = 0; m_id < M_QTY; m_id++) begin : gen_rob

            // module crossbar_rob instantiation
            crossbar_rob #(
                .TDATA_WIDTH        (TDATA_WIDTH),
                .TUSER_WIDTH        (TAG_WIDTH)
            ) crossbar_rob_inst (
                .clk                (clk),
                .resetn             (resetn),
                .m_axis_tag_tvalid  (master_tag_tvalid[m_id]),
                .m_axis_tag_tready  (master_ack[m_id] & ~master_cmd[m_id]),
                .m_axis_tag_tdata   (master_tag_tdata[m_id]),
                .s_axis_data_tvalid (s2m_resp[m_id]),
                .s_axis_data_tdata  (slave_rdata),
                .s_axis_data_tuser  (slave_m_tag),
                .m_axis_data_tvalid (master_resp[m_id]),
                .m_axis_data_tready (1'b1),
                .m_axis_data_tdata  (master_rdata[m_id])
            );

        end

    endgenerate

    // master ready/ack
    always_comb begin
        for (int m_id = 0; m_id < M_QTY; m_id++) begin
            master_s_id[m_id] = master_addr[m_id][TADDR_WIDTH-1:TADDR_WIDTH-ADDR_CH_BITS];

            master_rdy[m_id] = (~m2a_req[master_s_id[m_id]][m_id] | m2a_rdy[master_s_id[m_id]][m_id]) & master_tag_tvalid[m_id];
            master_ack[m_id] = master_req[m_id] & master_rdy[m_id];
        end
    end

    // master to arbiter registers
    always_ff @(posedge clk) begin
        // control
        if (resetn == 1'b0) begin
            m2a_req <= '{default:'0};
        end else begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                for (int m_id = 0; m_id < M_QTY; m_id++) begin
                    if (master_req[m_id] == 1'b1 && master_rdy[m_id] == 1'b1 && master_s_id[m_id] == s_id[ADDR_CH_BITS-1:0]) begin
                        m2a_req[s_id][m_id] <= 1'b1;
                    end else if (m2a_ack[s_id][m_id] == 1'b1) begin
                        m2a_req[s_id][m_id] <= 1'b0;
                    end
                end
            end
        end
        //data
        begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                for (int m_id = 0; m_id < M_QTY; m_id++) begin
                    if (master_req[m_id] == 1'b1 && master_rdy[m_id] == 1'b1 && master_s_id[m_id] == s_id[ADDR_CH_BITS-1:0]) begin
                        m2a_addr[s_id][m_id] <= master_addr[m_id];
                        m2a_cmd[s_id][m_id] <= master_cmd[m_id];
                        m2a_wdata[s_id][m_id] <= master_wdata[m_id];
                        m2a_tag[s_id][m_id] <= master_tag_tdata[m_id];
                    end
                end
            end
        end
    end

    // master to arbiter ready/ack
    always_comb begin
        for (int s_id = 0; s_id < S_QTY; s_id++) begin
            for (int m_id = 0; m_id < M_QTY; m_id++) begin
                m2a_rdy[s_id][m_id] = m2a_grant[s_id][m_id] & (~slave_req[s_id] | slave_rdy[s_id]);
                m2a_ack[s_id][m_id] = m2a_req[s_id][m_id] & m2a_rdy[s_id][m_id];
            end
        end
    end

    // round robin arbitration
    always_comb begin
        for (int s_id = 0; s_id < S_QTY; s_id++) begin
            m2a_grant[s_id] = round_robin_grant(m2a_req[s_id], m2a_base[s_id]);

            m2a_idx[s_id] = 'd0;
            for (int m_id = 0; m_id < M_QTY; m_id++) begin
                if (m2a_grant[s_id][m_id] == 1'b1) begin
                    m2a_idx[s_id] = m_id[ARB_WIDTH-1:0];
                end
            end
        end
    end

    // round robin arbitration state
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            m2a_base <= '{default:'0};
        end else begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                if (|(m2a_req[s_id] & m2a_rdy[s_id]) == 1'b1) begin
                    if (m2a_base[s_id] == M_QTY-1) begin
                        m2a_base[s_id] <= '{default:'0};
                    end else begin
                        m2a_base[s_id] <= m2a_base[s_id] + 'd1;
                    end
                end
            end
        end
    end

    // slave ready
    always_comb begin
        for (int s_id = 0; s_id < S_QTY; s_id++) begin
            slave_rdy[s_id] = ~slave_req[s_id] | (slave_req[s_id] & slave_ack[s_id]);
        end
    end

    // master to slave arbiter
    always_ff @(posedge clk) begin
        // control
        if (resetn == 1'b0) begin
            slave_req <= '{default:'0};
        end else begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                if (|(m2a_req[s_id] & m2a_rdy[s_id]) == 1'b1) begin
                    slave_req[s_id] <= 1'b1;
                end else if (slave_ack[s_id] == 1'b1) begin
                    slave_req[s_id] <= 1'b0;
                end
            end
        end
        // data
        begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                 if (|(m2a_req[s_id] & m2a_rdy[s_id]) == 1'b1) begin
                    slave_s_m_id[s_id] <= m2a_idx[s_id];
                    slave_s_tag[s_id] <= m2a_tag[s_id][m2a_idx[s_id]];
                    slave_cmd[s_id] <= m2a_cmd[s_id][m2a_idx[s_id]];
                    slave_addr[s_id] <= m2a_addr[s_id][m2a_idx[s_id]];
                    slave_wdata[s_id] <= m2a_wdata[s_id][m2a_idx[s_id]];
                end
            end
        end
    end

    always_comb begin
        for (int m_id = 0; m_id < M_QTY; m_id++) begin
            for (int s_id = 0; s_id < S_QTY; s_id++) begin
                s2m_resp[m_id][s_id] = (slave_resp[s_id] == 1'b1 && (slave_m_m_id[s_id] == m_id[ARB_WIDTH-1:0])) ? 1'b1 : 1'b0;
            end
        end
    end

    // helper functions
    function logic[M_QTY-1:0] circshift_left(input logic [M_QTY-1:0] vector, input logic [M_QTY-1:0] steps);
        // The shift operator fills in vacated bits
        // with zeros. We would like it filled in with
        // the bits that were pushed out. This is implemented
        // by concatenating req onto itself, doing a shift,
        // then taking the leftmost bits.
        logic [2*M_QTY-1:0] vector2x;
        vector2x = {vector, vector} << steps;
        return vector2x[2*M_QTY-1:M_QTY];
    endfunction

    function logic[M_QTY-1:0] circshift_right(input logic [M_QTY-1:0] vector, input logic [M_QTY-1:0] steps);
        // The shift operator fills in vacated bits
        // with zeros. We would like it filled in with
        // the bits that were pushed out. This is implemented
        // by concatenating req onto itself, doing a shift,
        // then taking the rightmost bits.
        logic [2*M_QTY-1:0] vector2x;
        vector2x = {vector, vector} >> steps;
        return vector2x[M_QTY-1:0];
    endfunction

    function logic[M_QTY-1:0] round_robin_grant(input logic [M_QTY-1:0] vector, input logic [ARB_WIDTH-1:0] base);
        logic [M_QTY-1:0] req_shifted;
        logic [M_QTY-1:0] req_shifted_grant;

        // rotate according to base
        req_shifted = circshift_right(vector, base);

        // priority encoder
        req_shifted_grant = req_shifted & ~(req_shifted - 1);

        // unrotate
        return circshift_left(req_shifted_grant, base);
    endfunction

endmodule
