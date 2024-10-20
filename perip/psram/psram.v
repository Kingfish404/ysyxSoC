module psram(
    input sck,
    input ce_n,
    inout [3:0] dio
  );
  reg [7:0] command;
  reg [3:0] counter;
  reg [23:0] paddr;
  reg [31:0] mem_data_buf, mem_data;
  reg en_qpi = 1'b0;
  typedef enum [1:0] {cmd, addr, cmd_stall, data} state_t;
  reg [1:0] state = cmd;
  always @(posedge sck or posedge ce_n)
    begin
      if (ce_n == 1'b0)
        begin
          // $display("s: %h, dio: %h, counter: %h, cmd: %h | sck: %h, ce_n: %h",
          //          state, dio, counter, command, sck, ce_n);
          case (state)
            cmd:
              begin
                if (en_qpi && counter < 2)
                  begin
                    command <= {command[3:0], {dio}};
                    counter <= counter + 1;
                  end
                else if (!en_qpi && counter < 8)
                  begin
                    command <= {command[6:0], dio[0]};
                    counter <= counter + 1;
                    if ({command[6:0], dio[0]} == 8'h35)
                      begin
                        // $display("QPI Mode Enable: %h", {command[6:0], dio[0]});
                        en_qpi <= 1'b1;
                        state <= cmd;
                        counter <= 0;
                      end
                  end
                else
                  begin
                    counter <= 1;
                    paddr <= {paddr[19:0], {dio}};
                    state <= addr;
                  end
              end
            addr:
              begin
                if (counter < 6)
                  begin
                    paddr <= {paddr[19:0], {dio}};
                    counter <= counter + 1;
                  end
                else
                  begin
                    counter <= 1;
                    case (command)
                      8'heb: // Fast Quad IO Read, EBh (Max frequency: 104MHz)
                        begin
                          pmem_read({{8'h80} ,{paddr}}, mem_data_buf);
                          mem_data <= {
                            {mem_data_buf[27:24]},
                            {mem_data_buf[31:28]},
                            {mem_data_buf[19:16]},
                            {mem_data_buf[23:20]},
                            {mem_data_buf[11:8]},
                            {mem_data_buf[15:12]},
                            {mem_data_buf[3:0]},
                            {mem_data_buf[7:4]}
                          };
                          state <= cmd_stall;
                          // $display("psram: Quad IO Read: %h, %h", paddr, mem_data);
                        end
                      8'h38: // Quad IO Write command 38h
                        begin
                          // $display("psram: Quad IO Write: %h", paddr);
                          state <= data;
                          mem_data <= {{dio}, {mem_data[31:4]}};
                        end
                      default:
                        begin
                        end
                    endcase
                  end
              end
            cmd_stall:
              begin
                if (counter < 6)
                  begin
                    counter <= counter + 1;
                  end
                else
                  begin
                    counter <= 1;
                    state <= data;
                  end
              end
            data:
              begin
                begin
                  if (
                    (command == 8'heb && counter < 8) ||
                    (command == 8'h38 && counter < 7)
                  )
                    begin
                      counter <= counter + 1;
                      mem_data <= {{dio}, {mem_data[31:4]}};
                      if (command == 8'h38)
                        begin
                          case (counter)
                            'h1:
                              begin
                                pmem_write(
                                  {{8'h80} ,{paddr}} + 0,
                                  {{24'h0}, {mem_data[31:28]}, {dio}},
                                  'h01);
                              end
                            'h3:
                              begin
                                pmem_write(
                                  {{8'h80} ,{paddr}} + 1,
                                  {{24'h0}, {mem_data[31:28]}, {dio}},
                                  'h01);
                              end
                            'h5:
                              begin
                                pmem_write(
                                  {{8'h80} ,{paddr}} + 2,
                                  {{24'h0}, {mem_data[31:28]}, {dio}},
                                  'h01);
                              end
                          endcase
                        end
                    end
                  else
                    begin
                      counter <= 0;
                      state <= cmd;
                      case (command)
                        8'h38:
                          begin
                            pmem_write(
                              {{8'h80} ,{paddr}} + 3,
                              {{24'h0}, {mem_data[31:28]}, {dio}},
                              'h01);
                          end
                        default:
                          begin
                          end
                      endcase
                    end
                end
              end
            default:
              begin
                state <= cmd;
                counter <= 0;
              end
          endcase
        end
      else
        begin
          state <= cmd;
          counter <= 0;
        end
    end
  assign dio = (state == data && command == 8'heb) ? mem_data[3:0] : 4'bz;
  // assign dio = 4'bz;
endmodule
