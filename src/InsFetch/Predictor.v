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

parameter SIZE = 9;

wire is_JALR = ins_cur[6:0] == 7'b1100111;
wire is_JAL = ins_cur[6:0] == 7'b1101111;
wire is_branch = ins_cur[6:0] == 7'b1100011;
wire [SIZE - 1 : 0] hash = ins_cur[5 + SIZE : 6];
wire [SIZE - 1 : 0] hash_upd = code[5 + SIZE : 6];
wire [`DATA_WIDTH] imm;
assign imm = is_JAL ? {{12{ins_cur[31]}}, ins_cur[19:12], ins_cur[20], ins_cur[30:21], 1'b0} : {{20{ins_cur[31]}}, ins_cur[7], ins_cur[30:25], ins_cur[11:8], 1'b0};

// assign pc_pred = pc_cur + 4;
// assign predict_jump_to_dispatcher = 0;

// assign pc_pred = is_JAL || is_branch ? pc_cur + imm : pc_cur + 4;
// assign predict_jump_to_dispatcher = is_JAL || is_branch ? 1 : 0;

reg [1:0] bht[2 ** SIZE - 1 : 0];

integer i;

assign predict_jump_to_dispatcher = is_JALR ? 0 : is_JAL ? 1 : is_branch ? bht[hash][1] : 0;
assign pc_pred = is_JALR ? pc_cur + 4 : predict_jump_to_dispatcher ? pc_cur + imm : pc_cur + 4;

always @(posedge clk) begin
   if (rst) begin
      for (i = 0; i < 2 ** SIZE; i = i + 1) begin
         bht[i] = 1;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_rob) begin
         if (if_jump) begin
            bht[hash_upd] <= bht[hash_upd] == 3 ? 3 : bht[hash_upd] + 1;
         end
         else begin
            bht[hash_upd] <= bht[hash_upd] == 0 ? 0 : bht[hash_upd] - 1;
         end
      end
   end
end
   
endmodule