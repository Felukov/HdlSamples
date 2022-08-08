//
// 2022, Konstantin Felukov
//

module crossbar_rob #(
    parameter integer                           S_QTY = 4,
    parameter integer                           TDATA_WIDTH = 32,
    parameter integer                           TUSER_WIDTH = 4
)(
    input  logic                                clk,
    input  logic                                resetn,

    output logic                                m_axis_tag_tvalid,
    input  logic                                m_axis_tag_tready,
    output logic [TUSER_WIDTH-1:0]              m_axis_tag_tdata,

    input  logic [S_QTY-1:0]                    s_axis_data_tvalid,
    input  logic [S_QTY-1:0][TDATA_WIDTH-1:0]   s_axis_data_tdata,
    input  logic [S_QTY-1:0][TUSER_WIDTH-1:0]   s_axis_data_tuser,

    output logic                                m_axis_data_tvalid,
    input  logic                                m_axis_data_tready,
    output logic [TDATA_WIDTH-1:0]              m_axis_data_tdata
);

    // Constants
    localparam integer                          FIFO_DEPTH = 2**TUSER_WIDTH;

    // Local signals
    logic                                       wr_data_tvalid;
    logic                                       wr_data_tready;
    logic [TUSER_WIDTH-1:0]                     wr_addr;
    logic [TUSER_WIDTH-1:0]                     wr_addr_next;

    logic                                       rd_data_tvalid;
    logic                                       rd_data_tready;
    logic [TUSER_WIDTH-1:0]                     rd_addr;
    logic [TUSER_WIDTH-1:0]                     rd_addr_next;

    logic [FIFO_DEPTH-1:0]                      fifo_valid;
    logic [FIFO_DEPTH-1:0][TDATA_WIDTH-1:0]     fifo_data;

    logic [S_QTY-1:0]                           upd_tvalid;
    logic [S_QTY-1:0][TDATA_WIDTH-1:0]          upd_tdata;
    logic [S_QTY-1:0][TUSER_WIDTH-1:0]          upd_addr;

    logic [TUSER_WIDTH-1:0]                     fifo_cnt;


    // Assigns
    assign m_axis_tag_tvalid = wr_data_tready;
    assign wr_data_tvalid = m_axis_tag_tready;
    assign m_axis_tag_tdata = wr_addr;
    assign upd_tvalid = s_axis_data_tvalid;
    assign upd_tdata = s_axis_data_tdata;
    assign upd_addr = s_axis_data_tuser;

    assign rd_data_tready = ~m_axis_data_tvalid | m_axis_data_tready;


    // Controlling fifo throughput
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            fifo_cnt <= '{default:'0};
            wr_data_tready <= 1'b1;
            rd_data_tvalid <= 1'b0;
        end else begin

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                fifo_cnt <= fifo_cnt;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                fifo_cnt <= fifo_cnt + 'd1;
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                fifo_cnt <= fifo_cnt - 'd1;
            end

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                wr_data_tready <= wr_data_tready;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                if ((fifo_cnt + 'd1) == FIFO_DEPTH-1) begin
                    wr_data_tready <= 1'b0;
                end
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                wr_data_tready <= 1'b1;
            end

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                rd_data_tvalid <= rd_data_tvalid;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                rd_data_tvalid <= 1'b1;
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                if ((fifo_cnt - 'd1) == 0) begin
                    rd_data_tvalid <= 1'b0;
                end
            end

        end
    end

    // Next write address logic
    always_comb begin
        if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
            wr_addr_next = wr_addr + 'd1;
        end else begin
            wr_addr_next = wr_addr;
        end
    end

    // Writing to queue
    always_ff @(posedge clk) begin
        // Control
        if (resetn == 1'b0) begin
            wr_addr <= '{default:'0};
            fifo_valid <= '{default:'0};
        end else begin
            wr_addr <= wr_addr_next;

            for (int i = 0; i < FIFO_DEPTH; i++) begin
                if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && i[TDATA_WIDTH-1:0] == wr_addr) begin
                    // reserving slot for response
                    fifo_valid[i] <= 1'b0;
                end else begin
                    for (int s_idx = 0; s_idx < S_QTY; s_idx++) begin
                        if (upd_tvalid[s_idx] == 1'b1 && i[TUSER_WIDTH-1:0] == upd_addr[s_idx]) begin
                            // updating slot as valid
                            fifo_valid[i] <= 1'b1;
                        end
                    end
                end
            end
        end
        // Data
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            for (int s_idx = 0; s_idx < S_QTY; s_idx++) begin
                if (upd_tvalid[s_idx] == 1'b1 && i[TUSER_WIDTH-1:0] == upd_addr[s_idx]) begin
                    fifo_data[i] <= upd_tdata[s_idx];
                end
            end
        end
    end

    // Next read address
    always_comb begin
        if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
            rd_addr_next = rd_addr + 'd1;
        end else begin
            rd_addr_next = rd_addr;
        end
    end

    // Latching read address
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            rd_addr <= '{default:'0};
        end else begin
            if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                rd_addr <= rd_addr_next;
            end
        end
    end

    // Forming output
    always_ff @(posedge clk) begin
        // Control
        if (resetn == 1'b0) begin
            m_axis_data_tvalid <= 1'b0;
        end else begin
            if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1 && fifo_valid[rd_addr] == 1'b1) begin
                m_axis_data_tvalid <= 1'b1;
            end else if (m_axis_data_tready == 1'b1) begin
                m_axis_data_tvalid <= 1'b0;
            end
        end
        // Data
        begin
            if (rd_data_tready == 1'b1) begin
                m_axis_data_tdata <= fifo_data[rd_addr];
            end
        end
    end

endmodule
