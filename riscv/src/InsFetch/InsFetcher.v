`include "define.v"

module InsFetcher(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with predictor
   input wire [`ADDR_WIDTH] pc_pred_from_predictor,
   input wire predict_jump_from_predictor,
   output reg [`INS_WIDTH] code_to_predictor,
   output reg [`ADDR_WIDTH] pc_to_predictor,

   // interact with MemCtrl
   input wire ok_from_memctrl,
   input wire [`INS_WIDTH] ins_from_memctrl,
   output reg enable_to_memctrl,
   output reg [`ADDR_WIDTH] addr_to_memctrl,

   // interact with Dispatcher
   input wire enable_from_dispatcher,
   output reg enable_to_dispatcher,
   output reg predict_jump_to_dispatcher,
   output reg [`ADDR_WIDTH] pc_to_dispatcher,
   output reg [`INS_WIDTH] ins_to_dispatcher,
   output reg [`ADDR_WIDTH] pc_pred_to_dispatcher, 

   // interact with ROB
   input wire enable_from_rob,
   input wire mispredict,
   input wire [`ADDR_WIDTH] pc_next
); 

parameter
STALL = 0,
INS_FETCH_A = 1,            // A: fetch instruction and send to dispatcher
INS_FETCH_B = 2,            // B: fetch instruction but not send to dispatchar(just keep in icache)
WAIT_PREDICT_A = 3,
WAIT_PREDICT_B = 4,
SEND_INS = 5;

reg [2:0] work_statu;

// direct mapping instruction cache
reg valid[`ICACHE_SIZE_ARR][`IC_BLOCK_SIZE_ARR];
reg [`TAG_RANGE] tags[`ICACHE_SIZE_ARR][`IC_BLOCK_SIZE_ARR];
reg [`INS_WIDTH] datas[`ICACHE_SIZE_ARR][`IC_BLOCK_SIZE_ARR];
// reg predict_jump[`ICACHE_SIZE_ARR][`IC_BLOCK_SIZE_ARR];
// reg [`ADDR_WIDTH] pc_pred[`ICACHE_SIZE_ARR][`IC_BLOCK_SIZE_ARR];

// pc
reg mem_pc_new_valid;
reg [`ADDR_WIDTH] pc, dsp_pc, mem_pc, mem_pc_new;

wire hit = enable_from_dispatcher 
            && tags[dsp_pc[`INDEX_RANGE]][dsp_pc[`BLOCK_RANGE]] == dsp_pc[`TAG_RANGE] 
            && valid[dsp_pc[`INDEX_RANGE]][dsp_pc[`BLOCK_RANGE]] == 1;

integer i, j;

always @(posedge clk) begin
   if (rst) begin
      pc <= 0;
      dsp_pc <= 0;
      mem_pc <= 0;
      mem_pc_new_valid <= 0;
      mem_pc_new <= 0;
      pc_to_predictor <= 0;
      code_to_predictor <= 0;
      enable_to_memctrl <= 0;
      addr_to_memctrl <= 0;
      enable_to_dispatcher <= 0;
      pc_to_dispatcher <= 0;
      ins_to_dispatcher <= 0;
      work_statu = STALL;
      for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
         for (j = 0; j < `IC_BLOCK_SIZE; j = j + 1) begin
            valid[i][j] <= 0;
            tags[i][j] <= 0;
            datas[i][j] <= 0;
         end
      end
   end
   else if (!rdy) begin
      // do nothing 
   end
   else begin
      if (enable_from_rob) begin
         pc <= pc_next;
      end
      if (mispredict) begin
         if (work_statu == SEND_INS || work_statu == STALL) begin  // case1, is sending ins to dispatcher: stop sending.    
            enable_to_dispatcher <= 0;      // dispatcher will recieve the same signal from rob, 
            mem_pc <= pc_next;              // and enable_from_dispatcher will be set to 0 in the next cycle
            dsp_pc <= pc_next;
         end                                
         else if (work_statu == INS_FETCH_A || work_statu == INS_FETCH_B || work_statu == WAIT_PREDICT_A || work_statu == WAIT_PREDICT_B) begin
            mem_pc_new_valid <= 1;          // case2, is fetching ins from memctrl: wait for current ins_fetch.
            mem_pc_new <= pc_next;          // record new pc_next(sent from rob), update mem_pc to mem_pc_new after finishing ins_fetch
            dsp_pc <= pc_next;
         end
      end
      else begin
         if (work_statu == STALL) begin
            if (enable_from_dispatcher) begin
               if (!hit) begin
                  work_statu <= INS_FETCH_A;
                  enable_to_memctrl <= 1;
                  addr_to_memctrl <= pc;
                  mem_pc <= dsp_pc;
               end
               else begin
                  work_statu <= WAIT_PREDICT_A;
                  enable_to_memctrl <= 0;
                  enable_to_dispatcher <= 0;
                  ins_to_dispatcher <= datas[dsp_pc[`INDEX_RANGE]][dsp_pc[`BLOCK_RANGE]];
                  pc_to_dispatcher <= dsp_pc;
                  code_to_predictor <= datas[dsp_pc[`INDEX_RANGE]][dsp_pc[`BLOCK_RANGE]];
                  pc_to_predictor <= dsp_pc;
               end
            end
            else begin
               work_statu <= INS_FETCH_B;
               enable_to_memctrl <= 1;
               addr_to_memctrl <= mem_pc;
            end
         end
         else if (work_statu == INS_FETCH_A || work_statu == INS_FETCH_B) begin
            if (ok_from_memctrl) begin
               valid[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] = 1;
               tags[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= mem_pc[`TAG_RANGE];
               datas[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= ins_from_memctrl;
               ins_to_dispatcher <= ins_from_memctrl;
               pc_to_dispatcher <= mem_pc;
               enable_to_memctrl <= 0;
               code_to_predictor <= ins_from_memctrl;
               pc_to_predictor <= mem_pc;
               if (work_statu == INS_FETCH_A) work_statu <= WAIT_PREDICT_A;
               else work_statu <= WAIT_PREDICT_B;
            end
         end
         else if (work_statu == WAIT_PREDICT_A || work_statu == WAIT_PREDICT_B) begin
            predict_jump_to_dispatcher <= predict_jump_from_predictor;
            pc_pred_to_dispatcher <= pc_pred_from_predictor;
            mem_pc <= pc_pred_from_predictor;
            if (enable_from_dispatcher && work_statu == WAIT_PREDICT_A) begin
               enable_to_dispatcher <= 1;
               dsp_pc <= pc_pred_from_predictor;
               work_statu <= SEND_INS;
            end
            else work_statu <= STALL;
         end
         else if (work_statu == SEND_INS) begin
            enable_to_dispatcher <= 0;
            work_statu <= STALL;
            if (mem_pc_new_valid) begin
               mem_pc <= mem_pc_new;
               mem_pc_new_valid <= 0;
            end
         end
      end
   end
end
endmodule

/*
      if (enable_from_rob) begin          // an instruction is commited from rob 
         pc <= pc_next;                        // modify pc instantly,
         if (mispredict) begin                 // if mispredict happens
            if (work_statu == SEND_INS) begin  // case1, is sending ins to dispatcher: stop sending.    
               enable_to_dispatcher <= 0;      // dispatcher will recieve the same signal from rob, 
               mem_pc <= pc_next;              // and enable_from_dispatcher will be set to 0 in the next cycle
            end                                
            if (work_statu == INS_FETCH) begin
               mem_pc_new_valid <= 1;          // case2, is fetching ins from memctrl: wait for current ins_fetch.
               mem_pc_new <= pc_next;          // record new pc_next(sent from rob), update mem_pc to mem_pc_new after finishing ins_fetch
            end
         end
      end
      else begin
         if (enable_from_dispatcher) begin
            if (work_statu == INS_FETCH) begin
               // wait for ins_fetch from mem_ctrl
            end
            else if (work_statu == SEND_INS) begin
               work_statu <= STALL;
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
                  predict_jump_to_dispatcher <= predict_jump[pc[`INDEX_RANGE]][pc[`BLOCK_RANGE]];
                  pc_pred_to_dispatcher <= pc_pred[pc[`INDEX_RANGE]][pc[`BLOCK_RANGE]];
                  pc <= pc_pred[pc[`INDEX_RANGE]][pc[`BLOCK_RANGE]];
               end
            end
         end
         else begin
            if (work_statu == STALL && !full_any_component) begin
               work_statu <= INS_FETCH;
               enable_to_memctrl <= 1;
               addr_to_memctrl <= mem_pc;
            end
         end

         if (work_statu == INS_FETCH) begin
            enable_to_dispatcher <= 0;
            if (ok_from_memctrl) begin
               valid[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] = 1;
               tags[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= mem_pc[`TAG_RANGE];
               datas[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= ins_from_memctrl;
               work_statu <= WAIT_PREDICT;
               enable_to_memctrl <= 0;
            end
         end
         if (work_statu == WAIT_PREDICT) begin
            if (pc_pred_enable) begin
               pc_pred[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= pc_pred_from_predictor;
               predict_jump[mem_pc[`INDEX_RANGE]][mem_pc[`BLOCK_RANGE]] <= predict_jump_from_predictor;
               work_statu <= STALL;
               if (mem_pc_new_valid) begin
                  mem_pc_new_valid <= 0;
                  mem_pc <= mem_pc_new;
               end
               else mem_pc <= pc_pred_from_predictor;
            end
         end
      end */
