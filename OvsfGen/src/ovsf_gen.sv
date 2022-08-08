//
// 2022, Konstantin Felukov
//

module ovsf_gen #(
    parameter integer               SF_WIDTH = 4    // 1 .. 8
) (
    input  logic                    clk,
    input  logic                    resetn,
    input  logic                    s_axis_config_tvalid,
    input  logic [7:0]              s_axis_config_tdata,

    output logic                    m_axis_data_tvalid,
    input  logic                    m_axis_data_tready,
    output logic                    m_axis_data_tlast,
    output logic [7:0]              m_axis_data_tdata,
    output logic [7:0]              m_axis_data_tuser
);

    // Constants
    localparam integer              VECTOR_WIDTH = 2**SF_WIDTH;
    localparam integer              CODE_BIT_IDX_WIDTH = $clog2(SF_WIDTH);

    // Local signals
    logic                           event_first_cfg;
    logic                           cfg_tvalid;
    logic [SF_WIDTH-1:0]            cfg_tdata;

    logic [0:SF_WIDTH-1]            code;
    logic [CODE_BIT_IDX_WIDTH-1:0]  code_bit_idx;
    logic                           code_bit;

    logic [SF_WIDTH-1:0]            src_idx;
    logic [SF_WIDTH-1:0]            src_max;
    logic [SF_WIDTH-1:0]            dst_idx;

    logic [VECTOR_WIDTH-1:0]        ovsf_vector;


    // Assigns
    assign m_axis_data_tlast = (dst_idx == VECTOR_WIDTH-1) ? 1'b1 : 1'b0;
    assign m_axis_data_tuser = 8'($unsigned(dst_idx));
    assign m_axis_data_tdata[7:1] = '{default:'0};
    assign m_axis_data_tdata[0] = (code_bit) ? ~ovsf_vector[src_idx] : ovsf_vector[src_idx];


    // Latching configuration
    always_ff @(posedge clk) begin
        // Control
        if (resetn == 1'b0) begin
            cfg_tvalid <= 1'b0;
            event_first_cfg <= 1'b0;
        end else begin
            if (s_axis_config_tvalid == 1'b1) begin
                cfg_tvalid <= 1'b1;
            end
            if (s_axis_config_tvalid == 1'b1 && cfg_tvalid == 1'b0) begin
                event_first_cfg <= 1'b1;
            end else begin
                event_first_cfg <= 1'b0;
            end
        end
        // Data
        begin
            if (s_axis_config_tvalid == 1'b1) begin
                cfg_tdata <= s_axis_config_tdata[SF_WIDTH-1:0];
            end
        end
    end

    // Applying configuration
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            code <= '{default:'0};
        end else begin
            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                code <= cfg_tdata[SF_WIDTH-1:0];
            end
        end
    end

    // OVSF code generator loop
    always_ff @(posedge clk) begin
        if (resetn == 1'b0) begin
            m_axis_data_tvalid <= 1'b0;
            ovsf_vector <= '{default:'0};
            code_bit <= 1'b0;
            code_bit_idx <= '{default:'0};
            src_idx <= '{default:'0};
            src_max <= '{default:'0};
            dst_idx <= '{default:'0};
        end else begin

            if (event_first_cfg == 1'b1) begin
                m_axis_data_tvalid <= 1'b1;
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                ovsf_vector <= '{default:'0};
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1) begin
                ovsf_vector[dst_idx] <= (code_bit) ? ~ovsf_vector[src_idx] : ovsf_vector[src_idx];
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                code_bit <= 1'b0;
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && src_idx == src_max) begin
                code_bit <= code[code_bit_idx];
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                code_bit_idx <= '{default:'0};
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && src_idx == src_max) begin
                code_bit_idx <= code_bit_idx + 'd1;
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                src_max <= '{default:'0};
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && src_idx == src_max) begin
                src_max <= (1 << code_bit_idx) - 1;
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && src_idx == src_max)) begin
                src_idx <= '{default:'0};
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1) begin
                src_idx <= src_idx + 1'd1;
            end

            if (event_first_cfg == 1'b1 || (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1 && m_axis_data_tlast == 1'b1)) begin
                dst_idx <= '{default:'0};
            end else if (m_axis_data_tvalid == 1'b1 && m_axis_data_tready == 1'b1) begin
                dst_idx <= dst_idx + 1'd1;
            end

        end
    end

endmodule
