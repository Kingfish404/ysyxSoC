// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
`define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
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

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else

wire flash_valid = (
  (in_psel && !in_penable) &&
  (in_paddr >= 'h30000000) && (in_paddr <= 'h3fffffff)
);
typedef enum [2:0] {cmd, ss_enable, ctrl, ss_disable, rx, accomplish} state_t;
reg xpi_enable = 1'b0;
reg [2:0] state = cmd;
reg [4:0] wb_adr;
reg [31:0]wb_dat;
reg wb_we, wb_stb, wb_cyc;
always @(posedge clock) begin
  if (reset) begin
    xpi_enable <= 1'b0;
  end
  else begin
    if (flash_valid) begin
      xpi_enable <= 1'b1;
      state <= ss_enable;
      wb_adr <= 'h4;
      wb_dat <= {{{8'h03}}, in_paddr[23:2], 2'b0};
      wb_we <= 1'b1;
      wb_stb <= 1'b1;
      wb_cyc <= 1'b1;
    end 
    // else if (in_psel && !in_penable)  begin
    //   $display("|spi| in_paddr: %h, wb_dat: %h, spi_dat: %h, sel: %h, we: %h, stb: %h, cyc: %h", 
    //     in_paddr[4:0], in_pwdata, spi_dat, in_pstrb, in_pwrite, in_psel, in_penable);
    // end 
    // else if (xpi_enable && !wb_cyc) begin
    //   $display("|xpi| in_paddr: %h, wb_dat: %h, spi_dat: %h, sel: %h, we: %h, stb: %h, cyc: %h",
    //     wb_adr, wb_dat, spi_dat, 'b010, wb_we, in_psel, wb_cyc);
    // end 
    // else if (in_pready) begin
    //   $display("|final| in_paddr: %h, wb_dat: %h, spi_dat: %h", in_paddr[4:0], in_pwdata, spi_dat);
    // end
    if (xpi_enable) begin
      if (spi_ready) begin
        wb_cyc <= 1'b1;
      end else begin
        wb_cyc <= 1'b0;
      end
      case (state)
        ss_enable: begin
          if (spi_ready) begin
            state <= ctrl;
            wb_adr <= 'h18;
            wb_dat <= 'h01;
            wb_we <= 1'b1;
          end
        end
        ctrl: begin
          if (spi_ready) begin
            state <= ss_disable;
            wb_adr <= 'h10;
            wb_dat <= 'h1540;
            wb_we <= 1'b1;
          end
        end
        ss_disable: begin
          if (spi_irq_out) begin
            state <= rx;
            wb_adr <= 'h18;
            wb_dat <= 'h0;
            wb_we <= 1'b1;
          end
        end
        rx: begin
          if (spi_ready) begin
            state <= accomplish;
            wb_adr <= 'h0;
          end
        end
        accomplish: begin
          if (spi_ready) begin
            state <= cmd;
            xpi_enable <= 1'b0;
          end
        end
        default: begin
          state <= cmd;
          xpi_enable <= 1'b0;
        end
     endcase
    end
  end
end

assign in_pready = spi_ready & (!xpi_enable | (xpi_enable & (state == accomplish)));
assign in_prdata = xpi_enable ? {spi_dat[7:0], spi_dat[15:8], spi_dat[23:16], spi_dat[31:24]} : spi_dat;
wire spi_ready;
wire [31:0] spi_dat;
spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i(xpi_enable ? wb_adr : in_paddr[4:0]),
  .wb_dat_i(xpi_enable ? wb_dat : in_pwdata),
  .wb_dat_o(spi_dat),
  .wb_sel_i(xpi_enable ? 'hf : in_pstrb),
  .wb_we_i (xpi_enable ? wb_we : in_pwrite),
  .wb_stb_i(xpi_enable ? 'h1 : in_psel),
  .wb_cyc_i(xpi_enable ? wb_cyc: in_penable),
  .wb_ack_o(spi_ready),
  .wb_err_o(in_pslverr),
  .wb_int_o(spi_irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

`endif // FAST_FLASH

endmodule
