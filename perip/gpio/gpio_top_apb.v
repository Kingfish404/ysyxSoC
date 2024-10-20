module gpio_top_apb(
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

    output [15:0] gpio_out,
    input  [15:0] gpio_in,
    output [7:0]  gpio_seg_0,
    output [7:0]  gpio_seg_1,
    output [7:0]  gpio_seg_2,
    output [7:0]  gpio_seg_3,
    output [7:0]  gpio_seg_4,
    output [7:0]  gpio_seg_5,
    output [7:0]  gpio_seg_6,
    output [7:0]  gpio_seg_7
  );
  reg [15:0] gpio = 0;
  reg [31:0] seg_num = 0;

  reg pready = 0;
  assign in_pready = pready;
  assign gpio_out = gpio;
  assign in_prdata[15:0] = (
           ({16{(in_paddr == 32'h10002000)}} & gpio) |
           ({16{(in_paddr == 32'h10002008)}} & gpio_in) |
           (0)
         );
  assign in_prdata[31:16] = (
           ({16{(in_paddr == 32'h10002000)}} & gpio_in) |
           (0)
         );
  always @(posedge clock)
    begin
      if (reset)
        begin
          pready <= 0;
        end
      else if (in_penable)
        begin
          // $display(
          //     "in_paddr: %h, in_psel: %h, in_penable: %h, in_pprot: %h, in_pwrite: %h, in_pwdata: %h, in_pstrb: %h, gpio_in: %h | gpio: %h",
          //     in_paddr, in_psel, in_penable, in_pprot, in_pwrite, in_pwdata, in_pstrb, gpio_in, gpio
          //   );
          pready <= 1;
          gpio <= (in_pwrite & (in_paddr == 32'h10002000)) ? in_pwdata[15:0] : gpio;
          seg_num[7:0] <= (in_pwrite & (in_paddr == 32'h10002008) & in_pstrb[0]) ? in_pwdata[7:0] : seg_num[7:0];
          seg_num[15:8] <= (in_pwrite & (in_paddr == 32'h10002009) & in_pstrb[1]) ? in_pwdata[15:8] : seg_num[15:8];
          seg_num[23:16] <= (in_pwrite & (in_paddr == 32'h1000200a) & in_pstrb[2]) ? in_pwdata[23:16] : seg_num[23:16];
          seg_num[31:24] <= (in_pwrite & (in_paddr == 32'h1000200b) & in_pstrb[3]) ? in_pwdata[31:24] : seg_num[31:24];
        end
    end

  num_to_seg_rom num_to_seg0(.en(1), .num(seg_num[3:0]), .seg(gpio_seg_0));
  num_to_seg_rom num_to_seg1(.en(1), .num(seg_num[7:4]), .seg(gpio_seg_1));
  num_to_seg_rom num_to_seg2(.en(1), .num(seg_num[11:8]), .seg(gpio_seg_2));
  num_to_seg_rom num_to_seg3(.en(1), .num(seg_num[15:12]), .seg(gpio_seg_3));
  num_to_seg_rom num_to_seg4(.en(1), .num(seg_num[19:16]), .seg(gpio_seg_4));
  num_to_seg_rom num_to_seg5(.en(1), .num(seg_num[23:20]), .seg(gpio_seg_5));
  num_to_seg_rom num_to_seg6(.en(1), .num(seg_num[27:24]), .seg(gpio_seg_6));
  num_to_seg_rom num_to_seg7(.en(1), .num(seg_num[31:28]), .seg(gpio_seg_7));

endmodule

module num_to_seg_rom(
    input en,
    input [3:0] num,
    output reg [7:0] seg
  );
  reg [7:0] mem [0:15] = {
        8'b11111101, 8'b01100000, 8'b11011010, 8'b11110010,
        8'b01100110, 8'b10110110, 8'b10111110, 8'b11100000,

        8'b11111110, 8'b11110110, 8'b11101110, 8'b00111110,
        8'b10011101, 8'b01111010, 8'b10011110, 8'b10001110
      };
  always @(*)
    begin
      if (en)
        begin
          seg = ~mem[num];
        end
      else
        begin
          seg = ~8'b00000000;
        end
    end
endmodule
