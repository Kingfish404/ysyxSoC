module axi4_delayer(
  input         clock,
  input         reset,

  output        in_arready,
  input         in_arvalid,
  input  [3:0]  in_arid,
  input  [31:0] in_araddr,
  input  [7:0]  in_arlen,
  input  [2:0]  in_arsize,
  input  [1:0]  in_arburst,
  input         in_rready,
  output        in_rvalid,
  output [3:0]  in_rid,
  output [63:0] in_rdata,
  output [1:0]  in_rresp,
  output        in_rlast,
  output        in_awready,
  input         in_awvalid,
  input  [3:0]  in_awid,
  input  [31:0] in_awaddr,
  input  [7:0]  in_awlen,
  input  [2:0]  in_awsize,
  input  [1:0]  in_awburst,
  output        in_wready,
  input         in_wvalid,
  input  [63:0] in_wdata,
  input  [7:0]  in_wstrb,
  input         in_wlast,
                in_bready,
  output        in_bvalid,
  output [3:0]  in_bid,
  output [1:0]  in_bresp,

  input         out_arready,
  output        out_arvalid,
  output [3:0]  out_arid,
  output [31:0] out_araddr,
  output [7:0]  out_arlen,
  output [2:0]  out_arsize,
  output [1:0]  out_arburst,
  output        out_rready,
  input         out_rvalid,
  input  [3:0]  out_rid,
  input  [63:0] out_rdata,
  input  [1:0]  out_rresp,
  input         out_rlast,
  input         out_awready,
  output        out_awvalid,
  output [3:0]  out_awid,
  output [31:0] out_awaddr,
  output [7:0]  out_awlen,
  output [2:0]  out_awsize,
  output [1:0]  out_awburst,
  input         out_wready,
  output        out_wvalid,
  output [63:0] out_wdata,
  output [7:0]  out_wstrb,
  output        out_wlast,
                out_bready,
  input         out_bvalid,
  input  [3:0]  out_bid,
  input  [1:0]  out_bresp
);
  parameter integer S_DELAY = 128;
  parameter integer R_DELAY = 500 * S_DELAY / 100;
  reg [31:0] delay_counter_w = 0;
  reg [31:0] delay_counter_r = 0;
  reg state_w = 0;
  reg state_r = 0;
  reg _out_bvalid = 0;
  reg _out_rvalid = 0;
  reg [3:0] _out_rid = 0;
  reg [63:0] _out_rdata = 0;
  reg [1:0] _out_rresp = 0;
  reg _out_rlast = 0;

  always @(posedge clock or posedge reset) begin
    if (reset) begin
      delay_counter_w <= 0;
    end else begin
      if (state_w == 0) begin
        if (!out_bvalid & (in_awvalid | in_wvalid)) begin
          delay_counter_w <= delay_counter_w + R_DELAY;
          // $display("delay_counter_w: %d, state_w: %d", delay_counter_w, state_w);
        end else if (out_bvalid) begin
          state_w <= 1;
          _out_bvalid <= out_bvalid;
        end
      end else if (state_w == 1) begin
        if (delay_counter_w != 0) begin
          delay_counter_w <= delay_counter_w > S_DELAY ? delay_counter_w - S_DELAY : 0;
          // $display("delay_counter_w: %d, state_w: %d", delay_counter_w, state_w);
        end else begin
          state_w <= 0;
          _out_bvalid <= 0;
        end
      end
    end
  end

  always @(posedge clock or posedge reset) begin
    if (reset) begin
      state_r <= 0;
    end else begin
      if (state_r == 0) begin
        if (!out_rvalid & (in_arvalid | out_rvalid)) begin
          delay_counter_r <= delay_counter_r + R_DELAY;
        end else if (out_rvalid) begin
          state_r <= 1;
          _out_rvalid <= out_rvalid;
          _out_rid <= out_rid;
          _out_rdata <= out_rdata;
          _out_rresp <= out_rresp;
          _out_rlast <= out_rlast;
        end
      end else if (state_r == 1) begin
        if (delay_counter_r != 0) begin
          delay_counter_r <= delay_counter_r > S_DELAY ? delay_counter_r - S_DELAY : 0;
        end else begin
          state_r <= 0;
          _out_rvalid <= 0;
        end
        end
    end
  end

  assign in_arready = out_arready;
  assign out_arvalid = in_arvalid;
  assign out_arid = in_arid;
  assign out_araddr = in_araddr;
  assign out_arlen = in_arlen;
  assign out_arsize = in_arsize;
  assign out_arburst = in_arburst;
  assign out_rready = in_rready & delay_counter_r == 0;
  assign in_rvalid = _out_rvalid & delay_counter_r == 0;
  assign in_rid = _out_rid;
  assign in_rdata = _out_rdata;
  assign in_rresp = _out_rresp;
  assign in_rlast = _out_rlast;

  assign in_awready = out_awready;
  assign out_awvalid = in_awvalid;
  assign out_awid = in_awid;
  assign out_awaddr = in_awaddr;
  assign out_awlen = in_awlen;
  assign out_awsize = in_awsize;
  assign out_awburst = in_awburst;
  assign in_wready = out_wready;
  assign out_wvalid = in_wvalid;
  assign out_wdata = in_wdata;
  assign out_wstrb = in_wstrb;
  assign out_wlast = in_wlast;
  assign out_bready = in_bready & delay_counter_w == 0;
  assign in_bvalid = _out_bvalid & delay_counter_w == 0;
  assign in_bid = out_bid;
  assign in_bresp = out_bresp;

endmodule
