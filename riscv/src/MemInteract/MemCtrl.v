`include "define.v"

module Memctrl(
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with ram
   input wire [`MEM_WIDTH] ins_from_ram,
   input wire uart_full_signal,
   output reg signal_to_ram,             // 0:none, 1:read, 2:write
   output reg [`MEM_WIDTH] data_to_ram,
   output reg [`ADDR_WIDTH] addr_to_ram,

   // interact with InsFetcher
   input wire [`ADDR_WIDTH] addr_from_if,
   input wire enable_from_if,
   output reg enable_to_if,
   output reg [`INS_WIDTH] ins_to_if
);

parameter
STALL = 0,
INS_FETCH = 1;

reg [2:0] work_statu;
reg [2:0] remain_step; // 1-4: not ready; 0: ready; 7: out of work

always @(posedge clk) begin
   if (rst) begin
      work_statu <= 0;
      remain_step <= 7;
      data_to_ram <= 0;
      signal_to_ram <= 0;
      enable_to_if <= 0;
      ins_to_if <= 0;
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_if) begin
         if (remain_step == 7) begin
            remain_step <= 4;
            signal_to_ram <= 1;
            data_to_ram <= 0;
            addr_to_ram <= addr_from_if;
            enable_to_if <= 0;
            work_statu <= INS_FETCH;
         end
         else begin
            if (work_statu == INS_FETCH) begin
               case (remain_step)
                  4: begin
                     enable_to_if <= 0;
                     ins_to_if[7:0] <= ins_from_ram;
                     remain_step <= 3;
                  end 
                  3: begin
                     enable_to_if <= 0;
                     ins_to_if[15:8] <= ins_from_ram;
                     remain_step <= 2;
                  end 
                  2: begin
                     enable_to_if <= 0;
                     ins_to_if[23:16] <= ins_from_ram;
                     remain_step <= 1;
                  end 
                  1: begin
                     enable_to_if <= 1;
                     ins_to_if[31:24] <= ins_from_ram;
                     remain_step <= 0;
                  end
                  0: begin
                     remain_step <= 7;
                     enable_to_if <= 0;
                     work_statu <= STALL;
                  end
               endcase
            end
         end
      end
      else begin
         remain_step <= 7;
         enable_to_if <= 0;
         work_statu = STALL;
      end
   end
end
endmodule