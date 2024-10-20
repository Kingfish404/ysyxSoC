module sdram(
    input        clk,
    input [ 1:0] cke,
    input        cs,
    input        ras,
    input        cas,
    input        we,
    input [12:0] a,
    input [ 1:0] ba,
    input [ 3:0] dqm,
    inout [31:0] dq
  );
  sdram_item
    #(.BIT_IDX(1'h0), .WORD_IDX(1'h0)) sdram_0 (
      .clk (clk),
      .cke (cke[0]),
      .cs  (cs),
      .ras (ras),
      .cas (cas),
      .we  (we),
      .a   (a),
      .ba  (ba),
      .dqm (dqm[1:0]),
      .dq  (dq[15:0])
    );
  sdram_item
    #(.BIT_IDX(1'h1), .WORD_IDX(1'h0)) sdram_1 (
      .clk (clk),
      .cke (cke[0]),
      .cs  (cs),
      .ras (ras),
      .cas (cas),
      .we  (we),
      .a   (a),
      .ba  (ba),
      .dqm (dqm[3:2]),
      .dq  (dq[31:16])
    );

  sdram_item
    #(.BIT_IDX(1'h0), .WORD_IDX(1'h1)) sdram_2 (
      .clk (clk),
      .cke (cke[1]),
      .cs  (cs),
      .ras (ras),
      .cas (cas),
      .we  (we),
      .a   (a),
      .ba  (ba),
      .dqm (dqm[1:0]),
      .dq  (dq[15:0])
    );
  sdram_item
    #(.BIT_IDX(1'h1), .WORD_IDX(1'h1)) sdram_3 (
      .clk (clk),
      .cke (cke[1]),
      .cs  (cs),
      .ras (ras),
      .cas (cas),
      .we  (we),
      .a   (a),
      .ba  (ba),
      .dqm (dqm[3:2]),
      .dq  (dq[31:16])
    );
endmodule

module sdram_item(
    input        clk,
    input        cke,
    input        cs,
    input        ras,
    input        cas,
    input        we,
    input [12:0] a,
    input [ 1:0] ba,
    input [ 1:0] dqm,
    inout [15:0] dq
  );
  parameter BIT_IDX = 1'h0;
  parameter WORD_IDX = 1'h0;
  reg [12:0] _a[3:0];
  reg [31:0] _addr = 0;
  reg [12:0] mode;
  reg [15:0] data;
  reg [2:0] counter = 0;
  reg ren = 0;
  wire [2:0] cas_latency = mode[6:4], burst_length = mode[2:0];
  wire [31:0] addr = {{4'ha}, {2'h0}, {WORD_IDX}, _a[ba], ba ,a[8:0], {1'h0}};
  assign dq = ren ? data : 16'bz;
  always @(posedge clk)
    begin
      if (cke & !cs)
        if (((ras & cas & we) ||   // NO OPERATION
             //  (!ras & cas & !we) || // PRECHARGE
             (!ras & !cas & we) || // AUTO REFRESH
             (0)) & a==13'h000 & ba==2'h0 & dqm==2'h0 & dq==16'h0000)
          begin
          end
        else
          begin
            // $display(
            //     "%h %h | sdram: %h %h %h %h | a: %h ba: %h qdm: %h dq: %h | _a: %h, _addr: %h | cl: %h, bl: %h, addr: %h",
            //     BIT_IDX, WORD_IDX,
            //     cs, ras, cas, we, a, ba, dqm, dq,
            //     _a, _addr, cas_latency, burst_length, addr);
          end
      if (cke & !cs)
        begin
          case ({ras, cas, we})
            'b111: // NO OPERATION or Residual
              begin
                if (counter != 0)
                  begin
                    counter <= counter - 1;
                    if (ren)
                      begin
                        // if (counter == 2)
                        //   begin
                        //     if (dqm[0] == 0)
                        //       sdram_read(_addr, data[7:0]);
                        //     if (dqm[1] == 0)
                        //       sdram_read(_addr+1, data[15:8]);
                        //   end
                        // else
                        if (counter == 1)
                          begin
                            if (BIT_IDX == 0)
                              begin
                                if (dqm[0] == 0)
                                  sdram_read(_addr+0, data[7:0]);
                                if (dqm[1] == 0)
                                  sdram_read(_addr+1, data[15:8]);
                              end
                            if (BIT_IDX == 1)
                              begin
                                if (dqm[0] == 0)
                                  sdram_read(_addr+2, data[7:0]);
                                if (dqm[1] == 0)
                                  sdram_read(_addr+3, data[15:8]);
                              end
                          end
                      end
                  end
                else
                  begin
                    ren <= 0;
                  end
              end
            'b011: // ACTIVE	激活目标存储体的一行
              begin
                _a[ba] <= a;
                // _ba <= ba;
              end
            'b101: // READ	读出目标存储体的一列
              begin
                counter <= cas_latency - 1;
                _addr <= addr;
                ren <= 1;
              end
            'b100: // WRITE	写入目标存储体的一列
              begin
                if (BIT_IDX == 0)
                  begin
                    if (dqm[0] == 0)
                      begin
                        sdram_write(addr + 0, dq[7:0], 'h01);
                      end
                    if (dqm[1] == 0)
                      begin
                        sdram_write(addr + 1, dq[15:8], 'h01);
                      end
                  end
                if (BIT_IDX == 1)
                  begin
                    if (dqm[0] == 0)
                      begin
                        sdram_write(addr + 2, dq[7:0], 'h01);
                      end
                    if (dqm[1] == 0)
                      begin
                        sdram_write(addr + 3, dq[15:8], 'h01);
                      end
                  end
                // _addr <= addr;
                // counter <= burst_length;
              end
            'b110: // BURST TERMINATE	停止当前的突发传输
              begin
                counter <= 0;
                ren <= 0;
              end
            'b010: // PRECHARGE	关闭存储体中已激活的行(预充电)
              begin
              end
            'b000: // LOAD MODE REGISTER	设置Mode寄存器
              begin
                mode <= a;
              end
            default:
              begin
              end
          endcase
        end
    end

endmodule
