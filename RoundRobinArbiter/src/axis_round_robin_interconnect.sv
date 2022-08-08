//
module axis_round_robin_interconnect #(
    parameter integer                           PORTS_QTY = 8,
    parameter integer                           TDATA_WIDTH = 16,
    parameter integer                           TUSER_WIDTH = 8
)(
    input logic                                 clk,
    input logic                                 resetn,

    input  logic [PORTS_QTY-1:0]                s_axis_data_tvalid,
    output logic [PORTS_QTY-1:0]                s_axis_data_tready,
    input  logic [PORTS_QTY-1:0]                s_axis_data_tlast,
    input  logic [PORTS_QTY*TDATA_WIDTH-1:0]    s_axis_data_tdata,
    input  logic [PORTS_QTY*TUSER_WIDTH-1:0]    s_axis_data_tuser,

    output logic                                m_axis_data_tvalid,
    input  logic                                m_axis_data_tready,
    output logic                                m_axis_data_tlast,
    output logic [TDATA_WIDTH-1:0]              m_axis_data_tdata,
    output logic [TUSER_WIDTH-1:0]              m_axis_data_tuser
);

    // Constants
    localparam integer                          BASE_WIDTH = $clog2(PORTS_QTY);

    // local signals
    logic [PORTS_QTY-1:0][TDATA_WIDTH-1:0]      s_axis_data_tdata_part;
    logic [PORTS_QTY-1:0][TUSER_WIDTH-1:0]      s_axis_data_tuser_part;
    logic [PORTS_QTY-1:0]                       s_axis_data_grant;
    logic [PORTS_QTY-1:0]                       s_axis_data_mask;

    logic [PORTS_QTY-1:0]                       req_shifted;
    logic [PORTS_QTY-1:0]                       req_shifted_grant;

    logic [BASE_WIDTH-1:0]                      sel_idx;
    logic [BASE_WIDTH-1:0]                      base;


    // Assigns
    generate
        for (genvar i = 0; i < PORTS_QTY; i++) begin
            assign s_axis_data_tready[i] = (~m_axis_data_tvalid | m_axis_data_tready) & s_axis_data_mask[i];
        end
    endgenerate

    assign s_axis_data_tdata_part = s_axis_data_tdata;
    assign s_axis_data_tuser_part = s_axis_data_tuser;


    // Arbitration
    always_comb begin
        // rotate according to base
        req_shifted = circshift_right(s_axis_data_tvalid, base);

        // priority encoder
        req_shifted_grant = req_shifted & ~(req_shifted - 1);

        // unrotate
        s_axis_data_grant = circshift_left(req_shifted_grant, base);
    end

    // Internal state
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            base <= '{default:'0};
            s_axis_data_mask <= '{default:'0};
        end else begin
            if (s_axis_data_mask == 'd0) begin
                s_axis_data_mask <= s_axis_data_grant;
            end else if (|(s_axis_data_tvalid & s_axis_data_tready & s_axis_data_tlast) == 1'b1) begin
                s_axis_data_mask <= '{default:'0};
            end

            if (|(s_axis_data_tvalid & s_axis_data_tready & s_axis_data_tlast) == 1'b1) begin
                base <= base + 'd1;
            end
        end
    end

    // Forwarding input to output process
    always_ff @(posedge clk) begin
        // control path
        if (resetn == 1'b0) begin
            m_axis_data_tvalid <= 1'b0;
            m_axis_data_tlast <= 1'b0;
        end else begin
            if (|(s_axis_data_tvalid & s_axis_data_tready) == 1'b1) begin
                m_axis_data_tvalid <= 1'b1;
            end else if (m_axis_data_tready == 1'b1) begin
                m_axis_data_tvalid <= 1'b0;
            end

            if (|(s_axis_data_tvalid & s_axis_data_tready) == 1'b1) begin
                m_axis_data_tlast <= s_axis_data_tlast[sel_idx];
            end
        end
        // data path
        begin
            if (|(s_axis_data_tvalid & s_axis_data_tready) == 1'b1) begin
                m_axis_data_tdata <= s_axis_data_tdata_part[sel_idx];
                m_axis_data_tuser <= s_axis_data_tuser_part[sel_idx];
            end
        end
    end

    // Determining current port
    always_comb begin
        sel_idx = 0;
        for (int i = 0; i < PORTS_QTY; i++) begin
            if (s_axis_data_mask[i] == 1'b1) begin
                sel_idx = i;
            end
        end
    end

    // helper functions
    function logic[PORTS_QTY-1:0] circshift_left(logic [PORTS_QTY-1:0] vector, logic [PORTS_QTY-1:0] steps);
        // The shift operator fills in vacated bits
        // with zeros. We would like it filled in with
        // the bits that were pushed out. This is implemented
        // by concatenating req onto itself, doing a shift,
        // then taking the leftmost bits.
        logic [2*PORTS_QTY-1:0] vector2x;
        vector2x = {vector, vector} << steps;
        return vector2x[2*PORTS_QTY-1:PORTS_QTY];
    endfunction

    function logic[PORTS_QTY-1:0] circshift_right(logic [PORTS_QTY-1:0] vector, logic [PORTS_QTY-1:0] steps);
        // The shift operator fills in vacated bits
        // with zeros. We would like it filled in with
        // the bits that were pushed out. This is implemented
        // by concatenating req onto itself, doing a shift,
        // then taking the rightmost bits.
        logic [2*PORTS_QTY-1:0] vector2x;
        vector2x = {vector, vector} >> steps;
        return vector2x[PORTS_QTY-1:0];
    endfunction

endmodule
