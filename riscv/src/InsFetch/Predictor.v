`include "define.v"

module Predictor (
   input clk,
   input rst,
   input rdy,
   
   // interact with InsFetcher
   input wire [`ADDR_WIDTH] pc_cur,
   input wire [`INS_WIDTH] ins_cur,
   output wire [`ADDR_WIDTH] pc_pred,
   output wire predict_jump_to_dispatcher,

   // interact with ROB (to train predictor)
   input wire enable_from_rob,
   input wire if_jump, 
   input wire [`INS_WIDTH] code
);

wire is_JALR = ins_cur[6:0] == 7'b1100111;

assign pr_pred = pc_cur + 4;
assign predict_jump_to_dispatcher = 1;
   
endmodule