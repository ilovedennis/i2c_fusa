// apb_tasks.sv - APB interface driving tasks
task apb_write(input [31:0] addr, input [31:0] data);
  begin
    @(posedge clk);
    paddr   = addr;
    pwrite  = 1;
    pwdata  = data;
    psel    = 1;
    @(posedge clk);
    penable = 1;
    forever begin
      @(posedge clk);
      if (pready) break;
    end
    psel    = 0;
    penable = 0;
    pwrite  = 0;
  end
endtask

task apb_read(input [31:0] addr, output [31:0] data);
  begin
    @(posedge clk);
    paddr   = addr;
    pwrite  = 0;
    psel    = 1;
    @(posedge clk);
    penable = 1;
    forever begin
      @(posedge clk);
      if (pready) begin
        data = prdata;
        break;
      end
    end
    psel    = 0;
    penable = 0;
  end
endtask
