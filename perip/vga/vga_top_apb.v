module vga_top_apb(
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

    output [7:0]  vga_r,
    output [7:0]  vga_g,
    output [7:0]  vga_b,
    output        vga_hsync,
    output        vga_vsync,
    output        vga_valid
  );

  reg pready;
  reg [31:0] prdata;
  reg [23:0] vga_mem [524287:0];

  wire [9:0] h_addr;
  wire [9:0] v_addr;
  wire [23:0] vga_data;

  vga_ctrl
    my_vga_ctrl(
      .pclk(clock),
      .reset(reset),
      .vga_data(vga_data),
      .h_addr(h_addr),
      .v_addr(v_addr),
      .hsync(vga_hsync),
      .vsync(vga_vsync),
      .valid(vga_valid),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b)
    );

  assign vga_data = vga_mem[{h_addr, v_addr[8:0]}];
  assign in_pready = pready;
  assign in_prdata = prdata;
  assign in_pslverr = 0;

  always@(posedge clock)
    begin
      if(reset)
        begin
          pready <= 0;
          prdata <= 0;
        end
      else
        begin
          if(in_penable)
            begin
              pready <= 1;
              // $display("in_paddr = %h, in_pwrite = %b, in_pwdata = %h", in_paddr, in_pwrite, in_pwdata);
              if(in_pwrite)
                begin
                  vga_mem[in_paddr[20:2]] <= in_pwdata[23:0];
                end
              else
                begin
                  prdata[23:0] <= vga_mem[in_paddr[20:2]];
                end
            end
        end
    end

endmodule

module vga_ctrl (
    input pclk,
    input reset,
    input [23:0] vga_data,
    output [9:0] h_addr,
    output [9:0] v_addr,
    output hsync,
    output vsync,
    output valid,
    output [7:0] vga_r,
    output [7:0] vga_g,
    output [7:0] vga_b
  );

  parameter h_frontporch = 96;
  parameter h_active = 144;
  parameter h_backporch = 784;
  parameter h_total = 800;

  parameter v_frontporch = 2;
  parameter v_active = 35;
  parameter v_backporch = 515;
  parameter v_total = 525;

  reg [9:0] x_cnt;
  reg [9:0] y_cnt;
  wire h_valid;
  wire v_valid;

  always @(posedge pclk)
    begin
      if(reset == 1'b1)
        begin
          x_cnt <= 1;
          y_cnt <= 1;
        end
      else
        begin
          if(x_cnt == h_total)
            begin
              x_cnt <= 1;
              if(y_cnt == v_total)
                y_cnt <= 1;
              else
                y_cnt <= y_cnt + 1;
            end
          else
            x_cnt <= x_cnt + 1;
        end
    end

  //生成同步信号
  assign hsync = (x_cnt > h_frontporch);
  assign vsync = (y_cnt > v_frontporch);
  //生成消隐信号
  assign h_valid = (x_cnt > h_active) & (x_cnt <= h_backporch);
  assign v_valid = (y_cnt > v_active) & (y_cnt <= v_backporch);
  assign valid = h_valid & v_valid;
  //计算当前有效像素坐标
  assign h_addr = h_valid ? (x_cnt - 10'd145) : 10'd0;
  assign v_addr = v_valid ? (y_cnt - 10'd36) : 10'd0;
  //设置输出的颜色值
  assign {vga_r, vga_g, vga_b} = vga_data;

endmodule
