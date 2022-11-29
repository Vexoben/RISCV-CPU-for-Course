`include "define.v"

module Dispatcher(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with instruction fetcher
   input enable_from_if,
   input predict_jump_from_if,
   input [`ADDR_WIDTH] pc_from_if,
   input [`INS_WIDTH] ins_from_if,
   output reg enable_to_if,

   // interact with decoder                           // combinational circuit
   output reg [`INS_WIDTH] code_to_decoder,
   output reg [`ADDR_WIDTH] pc_to_decoder,
   input wire [`OPE_WIDTH] ins_type,
   input wire [`REG_NUMBER_WIDTH] ins_rd, ins_rs1, ins_rs2,  // reg destination, reg source1, reg source2
   input wire [`DATA_WIDTH] ins_imm,

   // interact with RS 
   

   // interact with LSB


   // interact with ROB
   input wire mispredict,
   input wire ok_from_rob,
   input wire [`ROB_SIZE_ARR] rename,   
   output reg enable_to_rob,
   output reg predict_jump_to_rob,
   output reg [`ADDR_WIDTH] pc_pred_to_rob,
   output reg [`INS_WIDTH] ins_to_rob
);

parameter
STALL = 0,
INS_FETCH = 1,
RENAMING = 2,
SEND_TO_RS = 3,
SEND_TO_LSB = 4;

reg [2:0] work_statu;




always @(posedge clk) begin
   if (rst) begin
      
   end
   else if (!rdy) begin
      
   end
   else if (mispredict) begin
      
   end
   else begin
      if (work_statu == STALL) begin
         work_statu <= INS_FETCH;
         enable_to_if <= 1;
      end
      else if (work_statu == INS_FETCH) begin
            
      end
      else if (work_statu == RENAMING) begin
         
      end
      else if (work_statu == SEND_TO_LSB) begin
         
      end
      else begin
         
      end
   end
end



endmodule