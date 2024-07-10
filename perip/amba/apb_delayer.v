module apb_delayer(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [31:0] out_paddr,
  output        out_psel,
  output        out_penable,
  output [2:0]  out_pprot,
  output        out_pwrite,
  output [31:0] out_pwdata,
  output [3:0]  out_pstrb,
  input         out_pready,
  input  [31:0] out_prdata,
  input         out_pslverr
);
  parameter integer S_DELAY = 128;
  parameter integer R_DELAY = 500 * S_DELAY / 100;
  reg [31:0] delay_counter = 0;
  reg state = 0;
  reg _out_pready = 0;
  reg [31:0] _out_prdata = 0;
  reg _out_pslverr = 0;

  always @(posedge clock or posedge reset) begin
    if (reset) begin
      delay_counter <= 0;
    end else begin
      if (in_psel) begin
        if (state == 0) begin
          if (!out_pready) begin
            delay_counter <= delay_counter + R_DELAY;
          end else begin
            state <= 1;
            _out_pready <= out_pready;
            _out_prdata <= out_prdata;
            _out_pslverr <= out_pslverr;
          end
        end else if (state == 1) begin
          if (delay_counter != 0) begin
            delay_counter <= delay_counter > S_DELAY ? delay_counter - S_DELAY : 0;
          end
        end
      end else begin
        state <= 0;
        delay_counter <= 0;
      end
      // $display("delay_counter: %d, state: %d", delay_counter, state);
    end
  end

  assign out_paddr   = in_paddr;
  assign out_psel    = state == 0 & in_psel;
  assign out_penable = in_penable;
  assign out_pprot   = in_pprot;
  assign out_pwrite  = in_pwrite;
  assign out_pwdata  = in_pwdata;
  assign out_pstrb   = in_pstrb;
  assign in_pready   = R_DELAY == 0 ? out_pready : (delay_counter == 0) & _out_pready;
  assign in_prdata   = R_DELAY == 0 ? out_prdata : (delay_counter == 0) ? _out_prdata : 32'h0;
  assign in_pslverr  = R_DELAY == 0 ? out_pslverr : (delay_counter == 0) ? _out_pslverr : 1'b0;

endmodule
