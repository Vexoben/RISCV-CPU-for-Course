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
   input wire [`REG_NUMBER_WIDTH] rd_from_dsp,
   input wire [`OPE_WIDTH] type_from_dsp,
   output wire [`ROB_SIZE_ARR] rob_id_to_dsp,
   input wire [`ROB_SIZE_ARR] Qj_from_dsp, Qk_from_dsp,
   output wire [`DATA_WIDTH] Vj_to_dsp, Vk_to_dsp,
   output wire Qj_ready_to_dsp, Qk_ready_to_dsp,

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
   input wire cdb_rs_jump,
   input wire [`ADDR_WIDTH] cdb_rs_pc_next,

   // interact with regFile
   output reg enable_to_reg,
   output reg [`DATA_WIDTH] V_to_reg,
   output reg [`ROB_ID_TYPE] Q_to_reg,

   // to stall CPU when mispredict
   output reg mispredict,

   // to global 
   output reg full_rob
);

reg [`OPE_WIDTH] type[`ROB_SIZE_ARR];
reg [`ADDR_WIDTH] pc[`ROB_SIZE_ARR], pred_pc[`ROB_SIZE_ARR], pc_next[`ROB_SIZE_ARR];
reg [`REG_NUMBER_WIDTH] rd[`REG_SIZE_ARR];
reg [`ROB_SIZE_ARR] predict_jump, actu_jump;
reg [`ROB_SIZE_ARR] busy, ready;
reg [`DATA_WIDTH] result[`ROB_SIZE_ARR];

reg [`ROB_ID_TYPE] head, tail;

assign rob_id_to_dsp = tail;
assign Vj_to_dsp = Qj_from_dsp != `NON_DEPENDENT ? result[Qj_from_dsp] : 0;
assign Vk_to_dsp = Qk_from_dsp != `NON_DEPENDENT ? result[Qk_from_dsp] : 0;
assign Qj_ready_to_dsp = Qj_from_dsp != `NON_DEPENDENT ? ready[Qj_from_dsp] : 1;
assign Qk_ready_to_dsp = Qk_from_dsp != `NON_DEPENDENT ? ready[Qk_from_dsp] : 1;

wire head_is_store = busy[head] && (type[head] == `LB || type[head] == `LH || type[head] == `LBU || type[head] == `LHU || type[head] == `LW);
wire head_maybe_change_pc;
wire head_is_jump;

always @(posedge clk) begin
   if (rst || mispredict) begin
      mispredict <= 0;
      enable_to_if <= 0;
      pc_next_if <= 0;
      predict_jump <= 0;
      actu_jump <= 0;
      for (integer i = 0; i < `ROB_SIZE; ++i) begin
         type[i] <= 0;
         pc[i] <= 0; pred_pc[i] <= 0; pc_next[i] <= 0;
         rd[i] <= 0; 
         busy[i] <= 0; ready[i] <= 0;
         result[i] <= 0;
      end
   end
   else if (!rdy) begin
      // do nothing
   end
   else begin
      if (enable_from_dsp) begin
         tail <= tail == (`ROB_SIZE - 1) ? 0 : tail + 1;
         busy[tail] <= 1;
         ready[tail] <= 0;
         type[tail] <= type_from_dsp;
         pc[tail] <= pc_from_dsp;
         pred_pc[tail] <= pred_pc_from_dsp;
         rd[tail] <= rd_from_dsp;
         predict_jump[tail] <= predict_jump_from_dsp;
         actu_jump[tail] <= 0;
         result[tail] <= 0;
      end
      if (enable_cdb_lsb && busy[cdb_lsb_rob_id]) begin
         ready[cdb_lsb_rob_id] <= 1;
         result[cdb_lsb_rob_id] <= cdb_lsb_value;
      end
      if (enable_cdb_rs && busy[cdb_rs_rob_id]) begin
         ready[cdb_rs_rob_id] <= 1;
         result[cdb_rs_rob_id] <= cdb_rs_value;
         actu_jump[cdb_rs_rob_id] <= cdb_rs_jump;
         pc_next[cdb_rs_rob_id] <= cdb_rs_pc_next;
      end
      if (ready[head] || head_is_store) begin   // commit
         head <= head == (`ROB_SIZE - 1) ? 0 : head + 1;
         enable_to_reg <= 1;
         V_to_reg <= result[head];
         Q_to_reg <= head;
         if (head_is_jump) begin
            // train predictor
            enable_to_predictor <= 1;
            if_jump_to_predictor <= actu_jump[head];
            pc_to_predictor <= pc[head];

            enable_to_if <= 1;
            pc_next_if <= pc[head];
            // mispredict
            if (predict_jump[head] != actu_jump[head]) begin
               mispredict <= 1;
            end
         end
         if (head_is_store) begin
            
         end
      end

   end
end


endmodule