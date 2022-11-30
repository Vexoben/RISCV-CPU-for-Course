`include "define.v"

module ROB(
   // control signal
   input wire clk,
   input wire rst,
   input wire rdy,

   // interact with Instruction Fetcher
   output reg enable_to_if,
   output reg [`ADDR_WIDTH] pc_next_if,

   // interact with Dispatcher
   input wire enable_from_dsp,
   input wire predict_jump_from_dsp,
   input wire [`ADDR_WIDTH] pc_from_dsp,
   input wire [`ADDR_WIDTH] pred_pc_from_dsp,
   input wire [`REG_NUMBER_WIDTH] rd_to_rob,
   output reg [`ROB_SIZE_ARR] rob_id_to_dsp,

   // interact with predictor
   output reg enable_to_predictor,
   output reg if_jump_to_predictor,
   output reg [`ADDR_WIDTH] pc_to_predictor,

   // interact with cdb
   input wire enable_cdb_lsb,
   input wire [`ROB_SIZE_ARR] cdb_lsb_rob_id,
   input wire [`DATA_WIDTH] cdb_lsb_value,
   input wire enable_cdb_rs,
   input wire [`ROB_SIZE_ARR] cdb_rs_rob_id,
   input wire [`DATA_WIDTH] cdb_rs_value,

   // to stall CPU when mispredict
   output reg mispredict,

   // to global 
   output reg full_rob
);

reg [`ROB_ID_TYPE] Qj[`ROB_SIZE_ARR], Qk[`ROB_SIZE_ARR];
reg [`ADDR_WIDTH] pc[`ROB_SIZE_ARR];
reg [`ROB_SIZE_ARR] busy, ready;

reg [`ROB_ID_TYPE] head, tail;
wire next_head = head == (`ROB_SIZE - 1) ? 0 : head + 1;
wire next_tail = tail == (`ROB_SIZE - 1) ? 0 : tail + 1;

always @(posedge clk) begin
   if (rst) begin
      
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (busy[])
   end
end


endmodule