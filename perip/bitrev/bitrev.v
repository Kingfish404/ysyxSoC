module bitrev (
    input  sck,
    input  ss,
    input  mosi,
    output miso
  );
  wire reset = ss;
  assign miso = ss ? 1'b1 : (counter < 8'd8 ? 1'b0 : cmd[0]);
  reg [7:0] cmd = 8'b0;
  reg [7:0] counter = 8'b0;
  always @(posedge sck or posedge reset)
    if (reset)
      begin
        counter <= 8'd0;
        cmd <= 8'd0;
      end
    else
      begin
        // $display("sck: %b, ss: %b, mosi: %b, miso: %b, cmd: %b, c: %b ++",
        //          sck, ss, mosi, miso, cmd, counter);
        if (counter < 8'd8)
          begin
            cmd <= {cmd[6:0], mosi};
          end
        else
          begin
            cmd <= {1'b0, cmd[7:1]};
          end
        counter <= counter + 1;
      end

endmodule
