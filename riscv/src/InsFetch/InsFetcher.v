`include "define.v"

module InsFetcher(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with predictor
   input wire pc_pred_enable,
   input wire [`ADDR_WIDTH] pc_pred,
   output reg [`ADDR_WIDTH] ins_pc,
   output reg [`INS_WIDTH] ins_cur,

   // interact with MemCtrl
   input wire enable_from_memctrl,
   input wire [`INS_WIDTH] ins_from_memctrl,
   output reg enable_to_memctrl,
   output reg [`ADDR_WIDTH] addr_to_memctrl,

   // interact with Dispatcher
   input wire enable_from_dispatcher,
   output reg enable_to_dispatcher,
   output reg [`ADDR_WIDTH] pc_to_dispatcher,
   output reg [`INS_WIDTH] ins_to_dispatcher,

   // interact with ROB
   input wire enable_from_rob,
   input wire mispredict,
   input wire [`ADDR_WIDTH] pc_next
); 

parameter
STALL = 0,
INS_FETCH = 1,
SEND_INS = 2;

reg work_statu;

// direct mapping instruction cache
reg valid[`ICACHE_SIZE - 1 : 0];
reg [`TAG_RANGE] tags[`ICACHE_SIZE - 1 : 0][`IC_BLOCK_SIZE - 1 : 0];
reg [`INS_WIDTH] datas[`ICACHE_SIZE - 1 : 0][`IC_BLOCK_SIZE - 1 : 0];

reg mem_pc_new_valid;
reg [`ADDR_WIDTH] pc, mem_pc, mem_pc_new;

wire hit = enable_from_dispatcher && tags[pc[`INDEX_RANGE]][pc[`BLOCK_RANGE]] == pc[`TAG_RANGE];

always @(posedge clk) begin
   if (rst) begin
      ins_pc <= 0;
      ins_cur <= 0;
      enable_to_memctrl <= 0;
      addr_to_memctrl <= 0;
      enable_to_dispatcher <= 0;
      pc_to_dispatcher <= 0;
      ins_to_dispatcher <= 0;
      work_statu = STALL;
      for (integer i = 0; i < `ICACHE_SIZE; i = i + 1) begin
         valid[i] <= 0;
         for (integer j = 0; j < `IC_BLOCK_SIZE; j = j + 1) begin
            tags[i][j] <= 0;
            datas[i][j] <= 0;
         end
      end
      mem_pc_new_valid <= 0;
      pc <= 0;
      mem_pc <= 0;
      mem_pc_new <= 0;
   end
   else if (~rdy) begin
      // do nothing 
   end
   else if (enable_from_rob) begin
      if ()
      pc <= pc_next;
      enable_to_dispatcher <= 0;
   end
   else begin
      if (enable_from_dispatcher) begin
         if (work_statu == INS_FETCH) begin
            // wait for ins_fetch from mem_ctrl
         end
         else if (work_statu == SEND_INS) begin
            work_statu <= STALL;
            enable_to_dispatcher <= 0;
            enable_to_memctrl <= 0;
         end
         else if (work_statu == STALL) begin
            if (!hit) begin
               work_statu <= INS_FETCH;
               enable_to_memctrl <= 1;
               addr_to_memctrl <= pc;
            end
            else begin
               work_statu <= SEND_INS;
               enable_to_memctrl <= 0;
               enable_to_dispatcher <= 1;
               ins_to_dispatcher <= datas[pc[`INDEX_RANGE]][pc[`BLOCK_RANGE]];
               pc_to_dispatcher <= pc;
            end
         end
      end
      else begin
         if (work_statu == STALL) begin
            work_statu <= INS_FETCH;
            enable_to_memctrl <= 1;
            addr_to_memctrl <= mem_pc;
         end         
      end

      if (work_statu == INS_FETCH) begin
         if (enable_from_memctrl) begin
            valid[mem_pc[`INDEX_RANGE]] = 1;
            tags[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= mem_pc[`TAG_RANGE];
            datas[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= ins_from_memctrl;
            enable_to_memctrl <= 0;
            if (pc_pred_enable) mem_pc <= pc_pred;
            else mem_pc = mem_pc + 4;
         end
      end
   end
end
endmodule