`include "define.v"

module Memctrl(
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with ram
   input wire [7:0] data_from_ram,
   input wire uart_full_signal,
   output reg signal_to_ram,             // read/write select (read: 1, write: 0)
   output reg [7:0] data_to_ram,
   output reg [`MEM_WIDTH] addr_to_ram,

   // interact with InsFetcher
   input wire enable_from_if,
   input wire [`ADDR_WIDTH] addr_from_if,
   output reg enable_to_if,
   output reg [`INS_WIDTH] ins_to_if,

   // interact with lsb
   input wire enable_from_lsb,
   input wire read_or_write, // read:1, write:0
   input wire [2:0] width_from_lsb,
   input wire [`ADDR_WIDTH] addr_from_lsb,
   input wire [`DATA_WIDTH] data_from_lsb,
   output reg [`DATA_WIDTH] data_to_lsb,
   output reg ok_to_lsb
);

parameter
STALL = 0,
INS_FETCH = 1,
READ_DATA = 2,
WRITE_DATA = 3;

reg [2:0] work_statu;
reg [2:0] remain_step; // 1-4: not ready; 0: ready; 5:wait; 7: out of work
reg last_response;     // 0: if; 1: lsb

always @(posedge clk) begin
   if (rst) begin
      work_statu <= STALL;
      remain_step <= 7;
      data_to_ram <= 0;
      signal_to_ram <= 0;
      enable_to_if <= 0;
      ok_to_lsb <= 0;
      ins_to_if <= 0;
      last_response = 0;
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (work_statu == STALL) begin
         if (enable_from_lsb && (last_response == 0 || !enable_from_if)) begin
            enable_to_if <= 0;
            signal_to_ram <= read_or_write;
            work_statu = read_or_write ? READ_DATA : WRITE_DATA;
            data_to_ram <= 0;
            addr_to_ram <= addr_from_lsb;
            remain_step <= 5;
            last_response <= 1;
         end
         else if (enable_from_if && (last_response == 1 || !enable_from_lsb)) begin
            work_statu <= INS_FETCH;
            remain_step <= 5;
            signal_to_ram <= 0;
            addr_to_ram <= addr_from_if;
            last_response <= 0;
         end
      end
      else if (work_statu == INS_FETCH) begin
         if (enable_from_if) begin
            case (remain_step)
               5: begin
                  addr_to_ram <= addr_to_ram + 1;
                  remain_step <= 4;
               end
               4: begin
                  ins_to_if[7:0] <= data_from_ram;
                  addr_to_ram <= addr_to_ram + 1;
                  remain_step <= 3;
               end 
               3: begin
                  ins_to_if[15:8] <= data_from_ram;
                  addr_to_ram <= addr_to_ram + 1;
                  remain_step <= 2;
               end 
               2: begin
                  ins_to_if[23:16] <= data_from_ram;
                  remain_step <= 1;
               end 
               1: begin
                  enable_to_if <= 1;
                  ins_to_if[31:24] <= data_from_ram;
                  remain_step <= 0;
               end
               0: begin
                  remain_step <= 7;
                  enable_to_if <= 0;
                  work_statu <= STALL;
               end
            endcase
         end
         else begin // interrupted
            remain_step <= 7;
            enable_to_if <= 0;
            work_statu = STALL;
         end
      end
      else if (work_statu == READ_DATA) begin
         if (enable_from_lsb && read_or_write == 1) begin
            case (remain_step)
               4: begin
                  data_to_lsb[7:0] <= data_from_ram;
                  if (width_from_lsb == 1) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 3;
               end 
               3: begin
                  data_to_lsb[15:8] <= data_from_ram;
                  if (width_from_lsb == 2) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 2;
               end 
               2: begin
                  data_to_lsb[23:16] <= data_from_ram;
                  if (width_from_lsb == 3) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 1;
               end 
               1: begin
                  ok_to_lsb <= 1;
                  data_to_lsb[31:24] <= data_from_ram;
                  remain_step <= 0;
               end
               0: begin
                  remain_step <= 7;
                  ok_to_lsb <= 0;
                  work_statu <= STALL;
               end
            endcase
         end
         else begin // interrupted
            remain_step <= 7;
            ok_to_lsb <= 0;
            work_statu = STALL;
         end
      end
      else if (work_statu == WRITE_DATA) begin
         if (enable_from_lsb && read_or_write == 0) begin
            case (remain_step)
               4: begin
                  data_to_ram <= data_from_lsb[7:0];
                  if (width_from_lsb == 1) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 3;
               end 
               3: begin
                  data_to_ram <= data_from_lsb[15:8];
                  if (width_from_lsb == 2) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 2;
               end 
               2: begin
                  data_to_ram <= data_from_lsb[23:16];
                  if (width_from_lsb == 3) begin
                     ok_to_lsb <= 1;
                     remain_step <= 0;
                  end
                  else remain_step <= 1;
               end 
               1: begin
                  ok_to_lsb <= 1;
                  data_to_ram <= data_from_lsb[31:24];
                  remain_step <= 0;
               end
               0: begin
                  remain_step <= 7;
                  ok_to_lsb <= 0;
                  work_statu <= STALL;
               end
            endcase            
         end
         else begin // interrupted
            remain_step <= 7;
            ok_to_lsb <= 0;
            work_statu = STALL;
         end
      end
   end
end
endmodule