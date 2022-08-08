//
// 2022, Konstantin Felukov
//

module crossbar_fifo #(
    parameter integer                           FIFO_DEPTH = 4,
    parameter integer                           FIFO_WIDTH = 32
)(
    input  logic                                clk,
    input  logic                                resetn,

    input  logic                                s_axis_data_tvalid,
    output logic                                s_axis_data_tready,
    input  logic [FIFO_WIDTH-1:0]               s_axis_data_tdata,

    output logic                                m_axis_data_tvalid,
    input  logic                                m_axis_data_tready,
    output logic [FIFO_WIDTH-1:0]               m_axis_data_tdata
);

    // Constants
    localparam integer                          ADDR_WIDTH = $clog2(FIFO_DEPTH);

    // Local signals
    logic                                       wr_data_tvalid;
    logic                                       wr_data_tready;
    logic [FIFO_WIDTH-1:0]                      wr_data_tdata;
    logic [ADDR_WIDTH-1:0]                      wr_addr;
    logic [ADDR_WIDTH-1:0]                      wr_addr_next;

    logic                                       rd_data_tvalid;
    logic                                       rd_data_tready;
    logic [ADDR_WIDTH-1:0]                      rd_addr;
    logic [ADDR_WIDTH-1:0]                      rd_addr_next;

    logic [FIFO_WIDTH-1:0]                      fifo_data[FIFO_DEPTH];
    logic [ADDR_WIDTH-1:0]                      fifo_cnt;


    // Assigns
    assign wr_data_tvalid = s_axis_data_tvalid;
    assign s_axis_data_tready = wr_data_tready;
    assign wr_data_tdata = s_axis_data_tdata;

    assign m_axis_data_tvalid = rd_data_tvalid;
    assign rd_data_tready = m_axis_data_tready;
    assign m_axis_data_tdata = fifo_data[rd_addr];


    // Controlling fifo throughput
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            fifo_cnt <= '{default:'0};
            wr_data_tready <= 1'b1;
            rd_data_tvalid <= 1'b0;
        end else begin

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
                fifo_cnt <= fifo_cnt;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                fifo_cnt <= fifo_cnt + 'd1;
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
                fifo_cnt <= fifo_cnt - 'd1;
            end

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
                wr_data_tready <= wr_data_tready;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                if ((fifo_cnt + 'd1) == FIFO_DEPTH-1) begin
                    wr_data_tready <= 1'b0;
                end
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
                wr_data_tready <= 1'b1;
            end

            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1 && rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
                rd_data_tvalid <= rd_data_tvalid;
            end else if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                rd_data_tvalid <= 1'b1;
            end else if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
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

    // Writing
    always_ff @(posedge clk) begin
        // Control
        if (resetn == 1'b0) begin
            wr_addr <= '{default:'0};
        end else begin
            wr_addr <= wr_addr_next;
        end
        // Data
        begin
            if (wr_data_tvalid == 1'b1 && wr_data_tready == 1'b1) begin
                fifo_data[wr_addr] <= wr_data_tdata;
            end
        end
    end

    // Next read address
    always_comb begin
        if (rd_data_tvalid == 1'b1 && rd_data_tready == 1'b1) begin
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
            rd_addr <= rd_addr_next;
        end
    end

endmodule
