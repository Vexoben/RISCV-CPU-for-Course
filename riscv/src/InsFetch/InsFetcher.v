`include "define.v"

module InsFetcher(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with predictor
   output wire [`ADDRESS_WIDTH] pc_cur,
   output wire [`INS_WIDTH] ins_cur,
   input wire pc_pred_enable,
   input wire [`ADDRESS_WIDTH] pr_pred,

   // instruction to issue
   output reg [`INS_WIDTH] ins_fetch, 
    

   // interact with ROB
   input wire [`ADDRESS_WIDTH] pc_jump_real,
   input rollback_signal
); 

endmodule