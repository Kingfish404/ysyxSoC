module ps2_top_apb(
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

    input         ps2_clk,
    input         ps2_data
  );
  reg [7:0] ps2_data_reg = 0;
  reg pready = 0;
  assign in_prdata[7:0] = ps2_data_reg == 8'hf0 ? 0 : ps2_data_reg;
  assign in_prdata[31:8] = 0;
  assign in_pready = pready;
  always @(posedge clock)
    begin
      if (reset)
        begin
          ps2_data_reg <= 0;
          pready <= 0;
        end
      else if (in_penable)
        begin
          pready <= 1;
          if (!pressed)
            begin
              ps2_data_reg <= 0;
            end
        end

    end

  ps2_keyboard
    my_keyboard (
      .clk(clock),
      .clrn(~reset),
      .ps2_clk(ps2_clk),
      .ps2_data(ps2_data),
      .nextdata_n(1'b0),

      .data(data),
      .ready(ready),
      .overflow(overflow)
    );


  reg [7:0] data;
  reg [23:0] buffer;
  reg ready;
  reg overflow;
  wire pressed = (state == 2'b01);

  reg [1:0] state = 2'b00;
  reg [1:0] nextstate = 2'b00;

  always @(posedge clock)
    begin
      if (reset == 1)
        begin
          buffer = 0;
          state = 2'b00;
        end
      else
        begin
          if (ready)
            begin
              buffer = {buffer[15:8], buffer[7:0], data};
              if (buffer[15:8] != 8'hf0)
                begin
                  ps2_data_reg <= data;
                end
              // $display(
              //     "data=%x, buffer=%x%x%x, ready=%d, overflow=%d, state=%b",
              //     data, buffer[23:16], buffer[15:8], buffer[7:0], ready, overflow, state);
              case (state)
                2'b00:
                  begin
                    nextstate = 2'b01;
                  end
                2'b01:
                  begin
                    if (buffer[15:8] == buffer[7:0])
                      begin
                        nextstate = 2'b01;
                      end
                    else
                      begin
                        nextstate = 2'b10;
                      end
                  end
                2'b10:
                  nextstate = 2'b00;
                default:
                  nextstate = 2'b00;
              endcase
            end
          else
            ;
        end
    end
endmodule


module ps2_keyboard(clk,clrn,ps2_clk,ps2_data,data,
                      ready,nextdata_n,overflow);
  input clk,clrn,ps2_clk,ps2_data;
  input nextdata_n;
  output [7:0] data;
  output reg ready;
  output reg overflow;     // fifo overflow
  // internal signal, for test
  reg [9:0] buffer;        // ps2_data bits
  reg [7:0] fifo[7:0];     // data fifo
  reg [2:0] w_ptr,r_ptr;   // fifo write and read pointers
  reg [3:0] count;  // count ps2_data bits
  // detect falling edge of ps2_clk
  reg [2:0] ps2_clk_sync;

  always @(posedge clk)
    begin
      ps2_clk_sync <=  {ps2_clk_sync[1:0],ps2_clk};
    end

  wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];

  always @(posedge clk)
    begin
      if (clrn == 0)
        begin // reset
          count <= 0;
          w_ptr <= 0;
          r_ptr <= 0;
          overflow <= 0;
          ready<= 0;
        end
      else
        begin
          if ( ready )
            begin // read to output next data
              if(nextdata_n == 1'b0) //read next data
                begin
                  r_ptr <= r_ptr + 3'b1;
                  if(w_ptr==(r_ptr+1'b1)) //empty
                    ready <= 1'b0;
                end
            end
          if (sampling)
            begin
              if (count == 4'd10)
                begin
                  if ((buffer[0] == 0) &&  // start bit
                      (ps2_data)       &&  // stop bit
                      (^buffer[9:1]))
                    begin      // odd  parity
                      fifo[w_ptr] <= buffer[8:1];  // kbd scan code
                      w_ptr <= w_ptr+3'b1;
                      ready <= 1'b1;
                      overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                    end
                  count <= 0;     // for next
                end
              else
                begin
                  buffer[count] <= ps2_data;  // store ps2_data
                  count <= count + 3'b1;
                end
            end
        end
    end
  assign data = fifo[r_ptr]; //always set output data

endmodule
