module sdram_top_axi(
  input         clock,
  input         reset,
  output        in_awready,
  input         in_awvalid,
  input  [31:0] in_awaddr,
  input  [3:0]  in_awid,
  input  [7:0]  in_awlen,
  input  [2:0]  in_awsize,
  input  [1:0]  in_awburst,
  output        in_wready,
  input         in_wvalid,
  input  [31:0] in_wdata,
  input  [3:0]  in_wstrb,
  input         in_wlast,
  input         in_bready,
  output        in_bvalid,
  output [1:0]  in_bresp,
  output [3:0]  in_bid,
  output        in_arready,
  input         in_arvalid,
  input  [31:0] in_araddr,
  input  [3:0]  in_arid,
  input  [7:0]  in_arlen,
  input  [2:0]  in_arsize,
  input  [1:0]  in_arburst,
  input         in_rready,
  output        in_rvalid,
  output [1:0]  in_rresp,
  output [31:0] in_rdata,
  output        in_rlast,
  output [3:0]  in_rid,

  output        sdram_clk,
  output [1:0]  sdram_cke,
  output        sdram_cs,
  output        sdram_ras,
  output        sdram_cas,
  output        sdram_we,
  output [12:0] sdram_a,
  output [ 1:0] sdram_ba,
  output [ 3:0] sdram_dqm,
  inout  [31:0] sdram_dq
);

  wire sdram_dout_en;
  wire [31:0] sdram_dout;
  assign sdram_dq = sdram_dout_en ? sdram_dout : 32'bz;

  localparam integer ArDepth = 8;
  reg [31:0] ar_addr_q[0:ArDepth-1];
  reg [3:0] ar_id_q[0:ArDepth-1];
  reg [7:0] ar_len_q[0:ArDepth-1];
  reg [1:0] ar_burst_q[0:ArDepth-1];
  reg [2:0] ar_read_ptr_q;
  reg [2:0] ar_write_ptr_q;
  reg [3:0] ar_count_q;
  reg ar_active_q;

  wire queued_arvalid = (ar_count_q != 0) && !ar_active_q;
  wire queued_arready;
  wire ar_push = in_arvalid && in_arready;
  wire ar_pop = queued_arvalid && queued_arready;
  wire read_done = in_rvalid && in_rready && in_rlast;

  assign in_arready = ar_count_q < ArDepth;

  always @(posedge clock or posedge reset)
    if (reset)
      begin
        ar_read_ptr_q <= 0;
        ar_write_ptr_q <= 0;
        ar_count_q <= 0;
        ar_active_q <= 0;
      end
    else
      begin
        if (ar_push)
          begin
            ar_addr_q[ar_write_ptr_q] <= in_araddr;
            ar_id_q[ar_write_ptr_q] <= in_arid;
            ar_len_q[ar_write_ptr_q] <= in_arlen;
            ar_burst_q[ar_write_ptr_q] <= in_arburst;
            ar_write_ptr_q <= ar_write_ptr_q + 1'b1;
          end

        if (ar_pop)
          begin
            ar_read_ptr_q <= ar_read_ptr_q + 1'b1;
            ar_active_q <= 1'b1;
          end
        else if (read_done)
          ar_active_q <= 1'b0;

        case ({ar_push, ar_pop})
          2'b10: ar_count_q <= ar_count_q + 1'b1;
          2'b01: ar_count_q <= ar_count_q - 1'b1;
          default: ar_count_q <= ar_count_q;
        endcase
      end

  sdram_axi #(
    .SDRAM_MHZ(100),
    .SDRAM_ADDR_W(24),
    .SDRAM_COL_W(9),
    .SDRAM_READ_LATENCY(2)
  ) u_sdram_axi(
    .clk_i(clock),
    .rst_i(reset),
    .inport_awvalid_i(in_awvalid),
    .inport_awaddr_i(in_awaddr),
    .inport_awid_i(in_awid),
    .inport_awlen_i(in_awlen),
    .inport_awburst_i(in_awburst),
    .inport_wvalid_i(in_wvalid),
    .inport_wdata_i(in_wdata),
    .inport_wstrb_i(in_wstrb),
    .inport_wlast_i(in_wlast),
    .inport_bready_i(in_bready),
    .inport_arvalid_i(queued_arvalid),
    .inport_araddr_i(ar_addr_q[ar_read_ptr_q]),
    .inport_arid_i(ar_id_q[ar_read_ptr_q]),
    .inport_arlen_i(ar_len_q[ar_read_ptr_q]),
    .inport_arburst_i(ar_burst_q[ar_read_ptr_q]),
    .inport_rready_i(in_rready),

    .inport_awready_o(in_awready),
    .inport_wready_o(in_wready),
    .inport_bvalid_o(in_bvalid),
    .inport_bresp_o(in_bresp),
    .inport_bid_o(in_bid),
    .inport_arready_o(queued_arready),
    .inport_rvalid_o(in_rvalid),
    .inport_rdata_o(in_rdata),
    .inport_rresp_o(in_rresp),
    .inport_rid_o(in_rid),
    .inport_rlast_o(in_rlast),
    .sdram_clk_o(sdram_clk),
    .sdram_cke_o(sdram_cke),
    .sdram_cs_o(sdram_cs),
    .sdram_ras_o(sdram_ras),
    .sdram_cas_o(sdram_cas),
    .sdram_we_o(sdram_we),
    .sdram_dqm_o(sdram_dqm),
    .sdram_addr_o(sdram_a),
    .sdram_ba_o(sdram_ba),
    .sdram_data_input_i(sdram_dq),
    .sdram_data_output_o(sdram_dout),
    .sdram_data_out_en_o(sdram_dout_en)
  );

endmodule
