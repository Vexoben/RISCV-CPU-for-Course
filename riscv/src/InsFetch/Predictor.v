`include "define.v"

module Predictor (
   input clk,
   input rst,
   input rdy,
   
   // interact with InsFetcher
   input wire [`ADDR_WIDTH] pc_cur,
   input wire [`INS_WIDTH] ins_cur,
   output wire pc_pred_enable,
   output wire [`ADDR_WIDTH] pr_pred,
   output wire predict_jump_to_dispatcher,

   // interact with ROB (to train predictor)
   input wire enable_from_rob,
   input wire if_jump, 
   input wire [`ADDR_WIDTH] pc_finish
);

assign pr_pred = pc_cur + 4;
assign pc_pred_enable = 1;
assign predict_jump_to_dispatcher = 0;
   
endmodule